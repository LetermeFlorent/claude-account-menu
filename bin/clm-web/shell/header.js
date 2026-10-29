"use strict";

function headerView(s) {
  const name = s.version || "clm";
  clmSetText(byId("version"), name);
  if (document.title !== name) document.title = name;
  const up = byId("update");
  up.hidden = !s.update.ready;
  clmSetText(up, s.update.latest ? clmText("update.button", s.update.latest) : clmText("update.buttonAny"));
  const d = s.drive;
  clmSetText(byId("drive-tag"), d.connected ? clmText("drive.tagOn", d.tag, d.pc) : clmText("drive.tagOff"));
}

async function headerUpdate() {
  if (await clmAsk(clmText("update.title"), [clmText("update.line")], clmText("update.yes"))) clmAct({ do: "selfupdate" });
}

function headerInit() {
  byId("update").addEventListener("click", headerUpdate);
}

clm.views.push(headerView);
clm.inits.push(headerInit);
