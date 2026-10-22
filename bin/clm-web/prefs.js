"use strict";

clm.prefsOpen = {};
clm.prefsFilter = "";

async function syncErase(item, warn) {
  const lines = [warn[item.kind] || "", "Ce choix vaut pour tous les PC reliés au Drive."];
  if (await clmAsk("Supprimer " + item.label + " partout", lines, "Supprimer partout", [], true)) {
    clmAct({ do: "pref", id: item.id, move: "erase" }, syncPrefsView);
  }
}

function syncItem(item, warn, pc, grid) {
  const box = el("input", { type: "checkbox", checked: item.on, "aria-label": item.label });
  box.indeterminate = item.mixed;
  box.addEventListener("change", async () => {
    if (!box.checked && !(await clmAsk("Décocher " + item.label, item.off || [], "Décocher", [], true))) {
      box.checked = true;
      box.indeterminate = item.mixed;
      return;
    }
    clmAct({ do: "pref", id: item.id, move: box.checked ? "on" : "off", pc: pc.name }, syncPrefsView);
  });
  const kids = [
    item.erasing ? null : box,
    el("span", { class: "grow", title: item.label }, [el("span", { text: item.label + " " }), item.tag ? el("span", { class: "dim", text: item.tag }) : null]),
  ];
  if (item.wait) kids.push(el("span", { class: "dim", title: "en attente de sa prochaine synchro", text: grid ? "en attente" : "en attente de sa prochaine synchro" }));
  if (item.erasing) {
    if (!grid) kids.push(el("span", { class: "alert", text: "effacé partout à la prochaine synchro" }));
    kids.push(el("button", { type: "button", class: "small", title: "Annuler l'effacement", text: grid ? "Annuler" : "Annuler l'effacement", onclick: () => clmAct({ do: "pref", id: item.id, move: "on" }, syncPrefsView) }));
  } else if (!item.all && pc.self) {
    const label = "Supprimer " + item.label + " partout";
    kids.push(el("button", { type: "button", class: grid ? "small danger cross" : "small danger", title: label, "aria-label": label, text: grid ? "×" : "Supprimer partout", onclick: () => syncErase(item, warn) }));
  }
  const props = { class: item.erasing ? "erasing" : "", "data-name": item.label };
  if (item.erasing && grid) props.title = "effacé partout à la prochaine synchro";
  return el("li", props, kids);
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

function syncList(lines, warn, pc, grid) {
  if (lines.length === 0) return [];
  return [el("ul", { class: grid ? "prefs grid" : "prefs" }, lines.map((line) => syncItem(line, warn, pc, grid)))];
}

function syncFold(key, lines, warn, pc, grid) {
  if (lines.length === 0) return [];
  const head = el("summary", { text: "Décochés (" + lines.length + ")" });
  const fold = el("details", { class: grid ? "off filtered" : "off", "data-key": key }, [head].concat(syncList(lines, warn, pc, grid)));
  fold.open = clm.prefsOpen[key] === true;
  head.addEventListener("click", () => { clm.prefsOpen[key] = !fold.open; });
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

function syncFilterHead(head) {
  const filter = el("input", { type: "text", class: "filter", placeholder: "Filtrer les skills", "aria-label": "Filtrer les skills par nom", value: clm.prefsFilter });
  filter.addEventListener("input", () => {
    clm.prefsFilter = filter.value;
    syncFilterApply();
  });
  return el("div", { class: "row filterhead" }, [el("h4", { text: head.label }), filter]);
}

function syncFilterApply() {
  const box = byId("prefs");
  const q = clm.prefsFilter.trim().toLowerCase();
  let seen = 0;
  for (const li of box.querySelectorAll("ul.grid > li")) {
    li.hidden = q !== "" && !li.dataset.name.toLowerCase().includes(q);
    if (!li.hidden) seen++;
  }
  for (const fold of box.querySelectorAll("details.filtered")) {
    fold.open = q === "" ? clm.prefsOpen[fold.dataset.key] === true : fold.querySelector("li:not([hidden])") !== null;
  }
  const none = box.querySelector(".nomatch");
  if (none) none.hidden = q === "" || seen > 0;
}

function syncPart(part, warn, pc) {
  const grid = part.lines.some((line) => line.kind === "skills");
  const shown = part.lines.filter((line) => !syncUnchecked(line));
  const out = [];
  if (part.head) out.push(grid ? syncFilterHead(part.head) : el("h4", { text: part.head.label }));
  if (grid) {
    out.push(...syncList(shown.filter((line) => line.all), warn, pc, false));
    out.push(...syncList(shown.filter((line) => !line.all), warn, pc, true));
  } else {
    out.push(...syncList(shown, warn, pc, false));
  }
  out.push(...syncFold(pc.name + "|" + (part.head ? part.head.label : ""), part.lines.filter(syncUnchecked), warn, pc, grid));
  if (grid) out.push(el("p", { class: "dim nomatch", text: "Aucun skill ne correspond.", hidden: true }));
  return out;
}

function syncPrefsDraw(p) {
  const pcs = syncPcs(p);
  const cur = pcs.find((pc) => pc.name === clm.prefsPc) || pcs[0];
  const out = [el("h3", { text: "Skills et MCP" }), syncPcRow(pcs, cur), el("p", { class: "dim", text: cur.sub })];
  for (const part of syncSections(cur.lines)) out.push(...syncPart(part, p.warn, cur));
  if (cur.ready && cur.lines.length === 0) out.push(el("p", { class: "dim", text: cur.self ? "Rien à synchroniser pour l'instant." : "Rien à régler sur ce PC pour l'instant." }));
  const box = byId("prefs");
  const was = box.querySelector("input.filter");
  const typing = was && document.activeElement === was ? was.selectionStart : null;
  box.replaceChildren(...out.filter((x) => x !== null));
  syncFilterApply();
  const filter = box.querySelector("input.filter");
  if (typing !== null && filter) {
    filter.focus();
    filter.setSelectionRange(typing, typing);
  }
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
