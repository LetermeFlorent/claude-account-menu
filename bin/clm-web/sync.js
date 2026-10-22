"use strict";

function syncOff() {
  return [
    el("p", { text: "Drive n'est pas connecté sur ce PC. Une fois connecté, les skills, les MCP et les réglages restent pareils sur chaque PC." }),
    el("button", { type: "button", text: "Connecter Google Drive", onclick: () => clmAct({ do: "drivelogin" }) }),
    el("p", { class: "dim", text: "La connexion Google s'ouvre dans le navigateur, le terminal attend la réponse." }),
  ];
}

function syncOn(d) {
  const auto = el("input", { type: "checkbox", checked: d.auto, onchange: (e) => clmAct({ do: "driveauto", on: e.target.checked }) });
  return [
    el("p", {}, [el("span", { text: "Ce PC : " }), el("span", { class: "mono", text: d.pc }), el("span", { class: "dim when", text: ", " + d.tag })]),
    d.failed ? el("p", { class: "alert", text: "La dernière synchro a échoué, le terminal en donne la raison." }) : null,
    el("label", { class: "check" }, [auto, el("span", { text: "Synchro automatique" })]),
    el("div", { class: "row" }, [
      el("button", { type: "button", text: d.running ? "Synchro en cours..." : "Synchroniser maintenant", disabled: d.running, onclick: () => clmAct({ do: "drivesync" }) }),
    ]),
  ];
}

function syncView(s) {
  const d = s.drive;
  const box = byId("drive");
  if (clmChanged("drive", Object.assign({}, d, { tag: "" }))) box.replaceChildren(...(d.connected ? syncOn(d) : syncOff()).filter((x) => x !== null));
  const when = box.querySelector(".when");
  if (when) when.textContent = ", " + d.tag;
  if (!d.connected) {
    delete clm.keys.prefsAt;
    syncPrefsView({ connected: false });
    return;
  }
  if (clmChanged("prefsAt", [d.running ? "" : d.tag, d.running, s.open])) syncLoadPrefs();
}

clm.views.push(syncView);
