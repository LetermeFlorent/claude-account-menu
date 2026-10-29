"use strict";

function clmAsk(title, lines, yesText, extra, danger) {
  const dlg = byId("ask");
  byId("ask-title").textContent = title;
  byId("ask-body").replaceChildren(...lines.map((l) => el("p", { text: l })), ...(extra || []));
  const yes = byId("ask-yes");
  yes.textContent = yesText;
  yes.className = danger ? "danger" : "accent";
  dlg.returnValue = "";
  dlg.showModal();
  const field = dlg.querySelector("#ask-body input[type=text]");
  if (field) field.select();
  else byId(danger ? "ask-no" : "ask-yes").focus();
  return new Promise((resolve) => dlg.addEventListener("close", () => resolve(dlg.returnValue === "yes"), { once: true }));
}

function clmPicks(legend, boxes) {
  return el("fieldset", { class: "group" }, [el("legend", { text: legend }), el("div", { class: "checks column" }, boxes)]);
}

function askInit() {
  const dlg = byId("ask");
  byId("ask-no").addEventListener("click", () => dlg.close("no"));
  byId("ask-yes").addEventListener("click", () => dlg.close("yes"));
  dlg.addEventListener("keydown", (e) => {
    if (e.key !== "Enter" || !e.target.matches("input[type=text]")) return;
    e.preventDefault();
    dlg.close("yes");
  });
}

clm.inits.push(askInit);
