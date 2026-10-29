"use strict";

const usagePoll = { seconds: null, min: 15, max: 600, asked: false };

function usagePollShow() {
  const input = byId("usage-poll");
  input.min = String(usagePoll.min);
  input.max = String(usagePoll.max);
  if (usagePoll.seconds !== null && document.activeElement !== input) input.value = String(usagePoll.seconds);
  clmSetText(byId("usage-poll-hint"), clmText("settings.usagePollHint", usagePoll.min, usagePoll.max));
}

function usagePollKeep(data) {
  if (!data) return;
  usagePoll.seconds = data.seconds;
  usagePoll.min = data.min;
  usagePoll.max = data.max;
  usagePollShow();
}

async function usagePollAsk() {
  usagePoll.asked = true;
  try {
    const r = await clmSend({ do: "usagepoll" });
    if (r && r.ok) usagePollKeep(r.data);
    else usagePoll.asked = false;
  } catch (err) {
    usagePoll.asked = false;
  }
}

function usagePollView() {
  usagePollShow();
  if (!usagePoll.asked) usagePollAsk();
}

function usagePollSave() {
  const seconds = byId("usage-poll").value.trim();
  clmAct({ do: "usagepoll", seconds }, usagePollKeep);
}

function usagePollInit() {
  byId("usage-poll-save").addEventListener("click", usagePollSave);
  byId("usage-poll").addEventListener("keydown", (e) => {
    if (e.key === "Enter") usagePollSave();
  });
}

clm.views.push(usagePollView);
clm.inits.push(usagePollInit);
