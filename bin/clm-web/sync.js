"use strict";

clm.prefsOpen = {};

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

function syncItem(item, warn, pc) {
  const box = el("input", { type: "checkbox", checked: item.on, "aria-label": item.label });
  box.indeterminate = item.mixed;
  box.addEventListener("change", () => clmAct({ do: "pref", id: item.id, move: box.checked ? "on" : "off", pc: pc.name }, syncPrefsView));
  const kids = [
    item.erasing ? null : box,
    el("span", { class: "grow" }, [el("span", { text: item.label + " " }), item.tag ? el("span", { class: "dim", text: item.tag }) : null]),
  ];
  if (item.wait) kids.push(el("span", { class: "dim", text: "en attente de sa prochaine synchro" }));
  if (item.erasing) {
    kids.push(el("span", { class: "alert", text: "effacé partout à la prochaine synchro" }));
    kids.push(el("button", { type: "button", class: "small", text: "Annuler l'effacement", onclick: () => clmAct({ do: "pref", id: item.id, move: "on" }, syncPrefsView) }));
  } else if (!item.all && pc.self) {
    kids.push(el("button", { type: "button", class: "small danger", text: "Supprimer partout", onclick: () => syncErase(item, warn) }));
  }
  return el("li", { class: item.erasing ? "erasing" : "" }, kids);
}

function syncPcs(p) {
  const self = { name: p.me, self: true, ready: true, sub: p.sub, lines: p.lines };
  return [self].concat((p.pcs || []).map((pc) => Object.assign({ self: false }, pc)));
}

function syncPcRow(pcs, cur) {
  if (pcs.length < 2) return null;
  const pick = (pc) => {
    clm.prefsPc = pc.name;
    syncPrefsDraw(clm.prefsLast);
  };
  const buttons = pcs.map((pc) => el("button", {
    type: "button", class: "small", "aria-pressed": pc === cur ? "true" : "false",
    text: pc.self ? pc.name + " (ce PC)" : pc.name, onclick: () => pick(pc),
  }));
  return el("div", { class: "row pcs", role: "group", "aria-label": "PC à régler" }, buttons);
}

function syncUnchecked(line) {
  return line.type === "item" && !line.all && !line.on && !line.erasing;
}

function syncBlock(lines, warn, pc) {
  const out = [];
  let list = null;
  let sub = null;
  for (const line of lines) {
    if (line.type === "sub") {
      sub = line;
      list = null;
      continue;
    }
    if (sub !== null) out.push(el("p", { class: "subhead", text: sub.label }));
    sub = null;
    if (list === null) {
      list = el("ul", { class: "prefs" });
      out.push(list);
    }
    list.append(syncItem(line, warn, pc));
  }
  return out;
}

function syncFold(key, lines, warn, pc) {
  const n = lines.filter((line) => line.type === "item").length;
  if (n === 0) return [];
  const fold = el("details", { class: "off" }, [el("summary", { text: "Décochés (" + n + ")" })].concat(syncBlock(lines, warn, pc)));
  fold.open = clm.prefsOpen[key] === true;
  fold.addEventListener("toggle", () => { clm.prefsOpen[key] = fold.open; });
  return [fold];
}

function syncSections(lines) {
  const parts = [];
  for (const line of lines) {
    if (line.type === "head" || parts.length === 0) parts.push({ head: line.type === "head" ? line : null, lines: [] });
    if (line.type !== "head") parts[parts.length - 1].lines.push(line);
  }
  return parts;
}

function syncPrefsDraw(p) {
  const pcs = syncPcs(p);
  const cur = pcs.find((pc) => pc.name === clm.prefsPc) || pcs[0];
  const out = [el("h3", { text: "Skills et MCP" }), syncPcRow(pcs, cur), el("p", { class: "dim", text: cur.sub })];
  for (const part of syncSections(cur.lines)) {
    if (part.head) out.push(el("h4", { text: part.head.label }));
    out.push(...syncBlock(part.lines.filter((line) => !syncUnchecked(line)), p.warn, cur));
    const off = part.lines.filter((line) => line.type === "sub" || syncUnchecked(line));
    out.push(...syncFold(cur.name + "|" + (part.head ? part.head.label : ""), off, p.warn, cur));
  }
  if (cur.ready && cur.lines.length === 0) out.push(el("p", { class: "dim", text: cur.self ? "Rien à synchroniser pour l'instant." : "Rien à régler sur ce PC pour l'instant." }));
  byId("prefs").replaceChildren(...out.filter((x) => x !== null));
}

function syncPrefsView(p) {
  if (!p || !clmChanged("prefs", p)) return;
  if (!p.connected) {
    byId("prefs").replaceChildren();
    return;
  }
  clm.prefsLast = p;
  syncPrefsDraw(p);
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
