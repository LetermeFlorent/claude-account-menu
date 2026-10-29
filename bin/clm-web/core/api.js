"use strict";

const clm = {
  pollMs: 2000,
  readMs: 4000,
  goneMaxMs: 30000,
  goneMs: 0,
  state: null,
  look: null,
  pending: false,
  busy: false,
  gone: false,
  denied: false,
  polling: false,
  again: false,
  timer: 0,
  keys: {},
  views: [],
  inits: [],
  texts: {},
  lang: "en",
};

class ClmGone extends Error {}
class ClmBusy extends Error {}
class ClmDenied extends Error {}

async function clmFetch(path, init, timeoutMs) {
  const ctrl = new AbortController();
  const timer = timeoutMs > 0 ? setTimeout(() => ctrl.abort(), timeoutMs) : 0;
  let res;
  try {
    res = await fetch(path, Object.assign({}, init, { cache: "no-store", credentials: "same-origin", signal: ctrl.signal }));
  } catch (err) {
    throw err.name === "AbortError" ? new ClmBusy() : new ClmGone();
  } finally {
    clearTimeout(timer);
  }
  if (res.status === 403) throw new ClmDenied();
  let body;
  try {
    body = await res.json();
  } catch (err) {
    body = { ok: false, msg: clmText("error.unreadable", res.status) };
  }
  return { status: res.status, body };
}

async function clmRead(view) {
  const r = await clmFetch("/api/" + view, { method: "GET" }, clm.readMs);
  if (r.status !== 200) throw new Error(r.body.msg || clmText("error.code", r.status));
  return r.body;
}

async function clmSend(args) {
  const init = { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(args) };
  const r = await clmFetch("/api/action", init, 0);
  return r.body;
}

async function clmLoadText(code) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), clm.readMs);
  try {
    const res = await fetch("/lang/" + code + ".json", { cache: "no-store", credentials: "same-origin", signal: ctrl.signal });
    const data = await res.json();
    return data && typeof data === "object" ? data : null;
  } catch (err) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function clmLoadTexts() {
  let added = false;
  for (const code of ["en", "fr"]) {
    if (clm.texts[code]) continue;
    const data = await clmLoadText(code);
    if (data) clm.texts[code] = data;
    added = added || Boolean(data);
  }
  return added;
}
