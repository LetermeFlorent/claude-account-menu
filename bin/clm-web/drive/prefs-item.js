"use strict";

async function prefsErase(item, warn) {
  const lines = [warn[item.kind] || "", clmText("prefs.allPcs")].filter((line) => line !== "");
  if (await clmAsk(clmText("prefs.eraseTitle", item.label), lines, clmText("prefs.eraseYes"), [], true)) {
    clmAct({ do: "pref", id: item.id, move: "erase" }, prefsView);
  }
}

async function prefsToggle(e, item, pc) {
  const box = e.currentTarget;
  if (!box.checked && !(await clmAsk(clmText("prefs.offTitle", item.label), item.off || [], clmText("prefs.offYes"), [], true))) {
    box.checked = true;
    box.indeterminate = item.mixed;
    return;
  }
  clmAct({ do: "pref", id: item.id, move: box.checked ? "on" : "off", pc: pc.name }, prefsView);
}

function prefsName(item) {
  return el("span", { class: "pref-name", title: item.label }, [
    el("span", { text: item.label }),
    item.tag ? el("span", { class: "muted", text: " " + item.tag }) : null,
  ]);
}

function prefsBox(item, pc) {
  const box = el("input", { type: "checkbox", checked: item.on, onchange: (e) => prefsToggle(e, item, pc) });
  box.indeterminate = item.mixed;
  return el("label", { class: "check" }, [box, prefsName(item)]);
}

function prefsEraseButton(item, warn, grid) {
  const label = clmText("prefs.eraseTitle", item.label);
  const glyph = grid ? el("span", { class: "glyph", "aria-hidden": "true", text: "\u00d7" }) : null;
  return el("button", {
    type: "button", class: grid ? "small danger cross" : "small danger", title: label, "aria-label": label,
    text: grid ? "" : clmText("prefs.eraseYes"), onclick: () => prefsErase(item, warn),
  }, [glyph]);
}

function prefsUndoButton(item, grid) {
  return el("button", {
    type: "button", class: "small", title: clmText("prefs.undoErase"),
    text: grid ? clmText("prefs.undo") : clmText("prefs.undoErase"),
    onclick: () => clmAct({ do: "pref", id: item.id, move: "on" }, prefsView),
  });
}

function prefsItem(item, warn, pc, grid) {
  const kids = [item.erasing ? el("span", { class: "check" }, [prefsName(item)]) : prefsBox(item, pc)];
  if (item.wait) kids.push(el("span", { class: "muted", title: clmText("prefs.waitLong"), text: grid ? clmText("prefs.wait") : clmText("prefs.waitLong") }));
  if (item.erasing) {
    if (!grid) kids.push(el("span", { class: "alert", text: clmText("prefs.erasing") }));
    kids.push(prefsUndoButton(item, grid));
  } else if (!item.all && pc.self) {
    kids.push(prefsEraseButton(item, warn, grid));
  }
  const props = { class: item.erasing ? "pref erasing" : "pref", "data-name": item.label, "data-key": item.id };
  if (item.erasing && grid) props.title = clmText("prefs.erasing");
  return el("li", props, kids);
}
