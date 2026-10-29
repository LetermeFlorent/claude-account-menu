"use strict";

clm.prefsOpen = {};
clm.prefsFilter = "";

function prefsUnchecked(line) {
  return line.type === "item" && !line.all && !line.on && !line.erasing;
}

function prefsList(lines, warn, pc, grid) {
  if (lines.length === 0) return [];
  const props = { class: grid ? "prefs grid" : "prefs", "data-key": grid ? "grid" : "list" };
  return [el("ul", props, lines.map((line) => prefsItem(line, warn, pc, grid)))];
}

function prefsFold(key, lines, warn, pc, grid) {
  if (lines.length === 0) return [];
  const remember = (e) => {
    clm.prefsOpen[key] = !e.currentTarget.parentNode.open;
  };
  const head = el("summary", { text: clmText("prefs.unchecked", lines.length), onclick: remember });
  const props = { class: grid ? "off filtered" : "off", "data-key": "fold", "data-fold": key };
  const fold = el("details", props, [head].concat(prefsList(lines, warn, pc, grid)));
  fold.open = clm.prefsOpen[key] === true;
  return [fold];
}

function prefsSections(lines) {
  const parts = [];
  for (const line of lines) {
    if (line.type === "head" || parts.length === 0) parts.push({ head: line.type === "head" ? line : null, lines: [] });
    if (line.type !== "head") parts[parts.length - 1].lines.push(line);
  }
  return parts;
}

function prefsFilterBox() {
  return el("input", {
    type: "search", class: "filter", placeholder: clmText("prefs.filter"), "aria-label": clmText("prefs.filterLabel"), value: clm.prefsFilter,
    oninput: (e) => {
      clm.prefsFilter = e.currentTarget.value;
      prefsFilterApply();
    },
  });
}

function prefsFilterApply() {
  const box = byId("prefs");
  const q = clm.prefsFilter.trim().toLowerCase();
  let seen = 0;
  for (const li of box.querySelectorAll("ul.grid > li")) {
    li.hidden = q !== "" && !li.dataset.name.toLowerCase().includes(q);
    if (!li.hidden) seen++;
  }
  for (const fold of box.querySelectorAll("details.filtered")) {
    fold.open = q === "" ? clm.prefsOpen[fold.dataset.fold] === true : fold.querySelector("li:not([hidden])") !== null;
  }
  const none = box.querySelector(".nomatch");
  if (none) none.hidden = q === "" || seen > 0;
}

function prefsPart(part, warn, pc) {
  const grid = part.lines.some((line) => line.kind === "skills");
  const shown = part.lines.filter((line) => !prefsUnchecked(line));
  const name = part.head ? part.head.label : clmText("prefs.title");
  const out = [el("legend", { text: name })];
  if (grid) {
    out.push(prefsFilterBox());
    out.push(...prefsList(shown.filter((line) => line.all), warn, pc, false));
    out.push(...prefsList(shown.filter((line) => !line.all), warn, pc, true));
  } else {
    out.push(...prefsList(shown, warn, pc, false));
  }
  out.push(...prefsFold(pc.name + "|" + name, part.lines.filter(prefsUnchecked), warn, pc, grid));
  if (grid) out.push(el("p", { class: "muted nomatch", text: clmText("prefs.noMatch"), hidden: true }));
  return el("fieldset", { class: "group card", "data-key": pc.name + "|" + name }, out);
}
