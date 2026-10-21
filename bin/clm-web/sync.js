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

async function syncErase(item, warn) {
  const lines = [warn[item.kind] || "", "Ce choix vaut pour tous les PC reliés au Drive."];
  if (await clmAsk("Supprimer " + item.label + " partout", lines, "Supprimer partout", [], true)) {
    clmAct({ do: "pref", id: item.id, move: "erase" }, syncPrefsView);
  }
}

function syncItem(item, warn) {
  const box = el("input", { type: "checkbox", checked: item.on, "aria-label": item.label });
  box.indeterminate = item.mixed;
  box.addEventListener("change", () => clmAct({ do: "pref", id: item.id, move: box.checked ? "on" : "off" }, syncPrefsView));
  const kids = [
    item.erasing ? null : box,
    el("span", { class: "grow" }, [el("span", { text: item.label + " " }), item.tag ? el("span", { class: "dim", text: item.tag }) : null]),
  ];
  if (item.erasing) {
    kids.push(el("span", { class: "alert", text: "effacé partout à la prochaine synchro" }));
    kids.push(el("button", { type: "button", class: "small", text: "Annuler l'effacement", onclick: () => clmAct({ do: "pref", id: item.id, move: "on" }, syncPrefsView) }));
  } else if (!item.all) {
    kids.push(el("button", { type: "button", class: "small danger", text: "Supprimer partout", onclick: () => syncErase(item, warn) }));
  }
  return el("li", { class: item.erasing ? "erasing" : "" }, kids);
}

function syncPrefsView(p) {
  if (!p || !clmChanged("prefs", p)) return;
  const box = byId("prefs");
  if (!p.connected) {
    box.replaceChildren();
    return;
  }
  const out = [el("h3", { text: "Skills et MCP" }), el("p", { class: "dim", text: p.sub })];
  let list = null;
  for (const line of p.lines) {
    if (line.type === "item") {
      if (list === null) {
        list = el("ul", { class: "prefs" });
        out.push(list);
      }
      list.append(syncItem(line, p.warn));
      continue;
    }
    out.push(el(line.type === "head" ? "h4" : "p", { class: line.type === "head" ? "" : "subhead", text: line.label }));
    list = null;
  }
  if (p.lines.length === 0) out.push(el("p", { class: "dim", text: "Rien à synchroniser pour l'instant." }));
  box.replaceChildren(...out);
}

async function syncLoadPrefs() {
  try {
    syncPrefsView(await clmRead("prefs"));
  } catch (err) {
    delete clm.keys.prefsAt;
    clmFail(err);
  }
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
