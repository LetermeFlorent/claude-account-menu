"use strict";

function clmStatus(text, tone) {
  const s = byId("status");
  clmSetText(s, text || "");
  s.className = "status " + (tone || "muted");
}

function clmLockNote() {
  const s = clm.state;
  if (clm.denied) return clmText("lock.denied");
  if (clm.gone) return clmText("lock.gone", Math.round(clm.goneMs / 1000));
  if (clm.pending) return "";
  if (clm.busy) return clmText("lock.busy");
  if (s && s.startup) return clmText("lock.startup");
  if (s && !s.open) return clmText("lock.away");
  return "";
}

function clmRefreshLock() {
  const note = clmLockNote();
  const locked = note !== "" || clm.pending;
  byId("controls").disabled = locked;
  byId("update").disabled = locked;
  const busy = byId("busy");
  clmSetText(busy, note);
  busy.classList.toggle("quiet", note === "");
  busy.classList.toggle("alert", clm.denied || clm.gone);
}

function clmFail(err) {
  if (err instanceof ClmGone) {
    clm.gone = true;
    clm.goneMs = Math.min(clm.goneMaxMs, Math.max(clm.pollMs, clm.goneMs * 2));
    const dlg = byId("ask");
    if (dlg.open) dlg.close("");
  } else if (err instanceof ClmDenied) clm.denied = true;
  else if (err instanceof ClmBusy) clm.busy = true;
  else clmStatus(err.message, "alert");
}

function clmRedraw() {
  if (clm.state) for (const view of clm.views) view(clm.state);
}

function clmNextPoll(ms) {
  clearTimeout(clm.timer);
  clm.timer = 0;
  if (document.hidden || clm.denied) return;
  clm.timer = setTimeout(clmPoll, ms);
}

async function clmPoll() {
  if (clm.polling) {
    clm.again = true;
    return;
  }
  clm.polling = true;
  clearTimeout(clm.timer);
  let wait = clm.pollMs;
  try {
    const s = await clmRead("state");
    clm.busy = false;
    clm.gone = false;
    clm.goneMs = 0;
    clm.state = s;
    if (await clmLoadTexts()) clmTextsArrived();
    clmRedraw();
    if (!clm.pending && s.msg.text && clmChanged("msg", s.msg)) clmStatus(s.msg.text, s.msg.tone);
  } catch (err) {
    clmFail(err);
    if (clm.gone) wait = clm.goneMs;
  } finally {
    clm.polling = false;
  }
  clmRefreshLock();
  clmNextPoll(clm.again ? 0 : wait);
  clm.again = false;
}

async function clmAct(args, onData) {
  if (clm.pending) return null;
  const had = document.activeElement;
  clm.pending = true;
  clmRefreshLock();
  clmStatus(clmText("status.sent"), "muted");
  let r = null;
  try {
    r = await clmSend(args);
    clmStatus(r.msg || "", r.ok ? "ok" : "alert");
    if (r.ok && onData) onData(r.data);
    return r;
  } catch (err) {
    clmFail(err);
    clmStatus("", "muted");
    return null;
  } finally {
    if (!r || !r.ok) clm.keys = { msg: clm.keys.msg };
    clm.pending = false;
    clmRefreshLock();
    clmRefocus(had);
    clmPoll();
  }
}

function clmWatchVisible() {
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) clmNextPoll(0);
    else clmPoll();
  });
}

async function clmStart() {
  await clmLoadTexts();
  for (const init of clm.inits) init();
  clmRefreshLock();
  byId("shell").hidden = false;
  clmWatchVisible();
  clmPoll();
}

document.addEventListener("DOMContentLoaded", clmStart);
