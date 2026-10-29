"use strict";

function driveOff() {
  return [
    el("p", { text: clmText("drive.offIntro") }),
    el("div", { class: "actions" }, [el("button", { type: "button", class: "accent", text: clmText("drive.connect"), onclick: () => clmAct({ do: "drivelogin" }) })]),
    el("p", { class: "muted", text: clmText("drive.connectNote") }),
  ];
}

function driveAuto(d) {
  const box = el("input", { type: "checkbox", role: "switch", checked: d.auto, onchange: (e) => clmAct({ do: "driveauto", on: e.currentTarget.checked }) });
  return el("label", { class: "switch" }, [box, el("span", { text: clmText("drive.auto") })]);
}

function driveOn(d) {
  return [
    el("p", { class: "drive-pc" }, [
      el("span", { text: clmText("drive.thisPc") }),
      el("span", { class: "mono", text: d.pc }),
      el("span", { class: "muted", text: d.tag }),
    ]),
    d.failed ? el("p", { class: "alert", text: clmText("drive.failed") }) : null,
    driveAuto(d),
    el("div", { class: "actions" }, [
      el("button", { type: "button", text: d.running ? clmText("drive.running") : clmText("drive.syncNow"), disabled: d.running, onclick: () => clmAct({ do: "drivesync" }) }),
    ]),
  ];
}

function driveView(s) {
  const d = s.drive;
  if (clmChanged("drive", d)) clmMorph(byId("drive"), d.connected ? driveOn(d) : driveOff());
  if (!d.connected) {
    delete clm.keys.prefsAt;
    prefsView({ connected: false });
    return;
  }
  if (clmChanged("prefsAt", [d.running ? "" : d.tag, d.running, s.open])) prefsLoad();
  else if (clm.prefsLast && clmChanged("prefsLang", "")) prefsDraw(clm.prefsLast);
}

clm.views.push(driveView);
