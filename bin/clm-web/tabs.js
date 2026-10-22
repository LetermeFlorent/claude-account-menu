"use strict";

const tabNames = ["accounts", "drive", "display", "backups"];

function tabShow(name, focus) {
  if (byId("part-" + name).hidden) window.scrollTo(0, 0);
  for (const n of tabNames) {
    const on = n === name;
    const tab = byId("tab-" + n);
    tab.setAttribute("aria-selected", on ? "true" : "false");
    tab.tabIndex = on ? 0 : -1;
    byId("part-" + n).hidden = !on;
    if (on && focus) tab.focus();
  }
  history.replaceState(null, "", "#" + name);
}

function tabStep(name, key) {
  const at = tabNames.indexOf(name);
  const last = tabNames.length - 1;
  if (at < 0) return "";
  if (key === "ArrowRight") return tabNames[at === last ? 0 : at + 1];
  if (key === "ArrowLeft") return tabNames[at === 0 ? last : at - 1];
  if (key === "Home") return tabNames[0];
  if (key === "End") return tabNames[last];
  return "";
}

function tabInit() {
  for (const n of tabNames) byId("tab-" + n).addEventListener("click", () => tabShow(n, false));
  byId("tabs").addEventListener("keydown", (e) => {
    const next = tabStep(e.target.id.replace(/^tab-/, ""), e.key);
    if (!next) return;
    e.preventDefault();
    tabShow(next, true);
  });
  const asked = location.hash.slice(1);
  tabShow(tabNames.includes(asked) ? asked : tabNames[0], false);
}

clm.inits.push(tabInit);
