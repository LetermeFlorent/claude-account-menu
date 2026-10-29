"use strict";

let menuOpen = null;

function menuClose(focusBack) {
  const m = menuOpen;
  if (!m) return;
  menuOpen = null;
  m.list.hidden = true;
  m.button.setAttribute("aria-expanded", "false");
  if (focusBack) m.button.focus();
}

function menuItems(list) {
  return [...list.querySelectorAll("[role=menuitem]:not(:disabled)")];
}

function menuEntry(entry) {
  return el("button", {
    type: "button", role: "menuitem", tabindex: "-1", class: entry.danger ? "danger" : "", text: entry.text, disabled: entry.disabled === true,
    onclick: () => {
      menuClose(true);
      entry.run();
    },
  });
}

function menuShow(host, last) {
  menuClose(false);
  const list = host.querySelector("[role=menu]");
  const button = host.querySelector("button[aria-haspopup]");
  list.replaceChildren(...host.clmData().map(menuEntry));
  menuOpen = { button, list };
  list.hidden = false;
  button.setAttribute("aria-expanded", "true");
  const items = menuItems(list);
  if (items.length > 0) items[last ? items.length - 1 : 0].focus();
}

function menuStep(key, at, count) {
  if (key === "ArrowDown") return (at + 1) % count;
  if (key === "ArrowUp") return (at - 1 + count) % count;
  if (key === "Home") return 0;
  if (key === "End") return count - 1;
  return -1;
}

function menuKey(e) {
  if (!menuOpen) return;
  if (e.key === "Escape") {
    e.preventDefault();
    menuClose(true);
    return;
  }
  if (e.key === "Tab") {
    menuClose(false);
    return;
  }
  const items = menuItems(menuOpen.list);
  const next = items.length > 0 ? menuStep(e.key, items.indexOf(document.activeElement), items.length) : -1;
  if (next < 0) return;
  e.preventDefault();
  items[next].focus();
}

function menuNew(entries) {
  const glyph = el("span", { class: "glyph", "aria-hidden": "true", text: "\u22ef" });
  const button = el("button", { type: "button", class: "icon more", "aria-haspopup": "menu", "aria-expanded": "false" }, [glyph]);
  const list = el("div", { role: "menu", class: "menu", hidden: true, "data-own": "" });
  const host = el("div", { class: "menu-host" }, [button, list]);
  host.clmData = entries;
  button.addEventListener("click", () => (menuOpen && menuOpen.button === button ? menuClose(true) : menuShow(host, false)));
  button.addEventListener("keydown", (e) => {
    if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return;
    e.preventDefault();
    menuShow(host, e.key === "ArrowUp");
  });
  list.addEventListener("keydown", menuKey);
  return host;
}

function menuLabel(host, label) {
  const button = host.querySelector("button[aria-haspopup]");
  clmSetAttr(button, "aria-label", label);
  clmSetAttr(button, "title", label);
  clmSetAttr(host.querySelector("[role=menu]"), "aria-label", label);
}

function menuInit() {
  document.addEventListener("pointerdown", (e) => {
    if (menuOpen && !menuOpen.list.parentNode.contains(e.target)) menuClose(false);
  });
}

clm.inits.push(menuInit);
