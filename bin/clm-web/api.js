"use strict";

const clm = {
  token: new URLSearchParams(location.search).get("t") || "",
  pollMs: 2000,
  readMs: 4000,
  state: null,
  pending: false,
  busy: false,
  polling: false,
  again: false,
  timer: 0,
  keys: {},
  views: [],
  inits: [],
};

class ClmGone extends Error {}
class ClmBusy extends Error {}

function clmGone() {
  byId("app").hidden = true;
  document.documentElement.dataset.theme = "light";
  const dlg = byId("ask");
  if (dlg.open) dlg.close("");
}

function clmFail(err) {
  if (err instanceof ClmGone) clmGone();
  else if (err instanceof ClmBusy) clm.busy = true;
  else clmStatus(err.message, "alert");
}

async function clmFetch(path, init, timeoutMs) {
  const ctrl = new AbortController();
  const timer = timeoutMs > 0 ? setTimeout(() => ctrl.abort(), timeoutMs) : 0;
  const headers = Object.assign({ "X-Clm-Token": clm.token }, init.headers);
  let res;
  try {
    res = await fetch(path, Object.assign({}, init, { headers, cache: "no-store", credentials: "omit", signal: ctrl.signal }));
  } catch (err) {
    throw err.name === "AbortError" ? new ClmBusy() : new ClmGone();
  } finally {
    clearTimeout(timer);
  }
  let body;
  try {
    body = await res.json();
  } catch (err) {
    body = { ok: false, msg: "réponse illisible de clm (" + res.status + ")" };
  }
  return { status: res.status, body };
}

async function clmRead(view) {
  const r = await clmFetch("/api/" + view, { method: "GET" }, clm.readMs);
  if (r.status !== 200) throw new Error(r.body.msg || "erreur " + r.status);
  return r.body;
}

async function clmSend(args) {
  const init = { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(args) };
  const r = await clmFetch("/api/action", init, 0);
  return r.body;
}
