"use strict";

const navNames = ["accounts", "drive", "backups", "settings"];
const navOld = { display: "settings" };
const navNarrow = window.matchMedia("(max-width: 719px)");

function navOrient() {
  byId("tabs").setAttribute("aria-orientation", navNarrow.matches ? "horizontal" : "vertical");
}

function navShow(name, focus) {
  if (byId("part-" + name).hidden) window.scrollTo(0, 0);
  for (const n of navNames) {
    const on = n === name;
    const tab = byId("tab-" + n);
    tab.setAttribute("aria-selected", on ? "true" : "false");
    tab.tabIndex = on ? 0 : -1;
    byId("part-" + n).hidden = !on;
    if (on && focus) tab.focus();
  }
  history.replaceState(null, "", "#" + name);
}

function navStep(name, key) {
  const at = navNames.indexOf(name);
  const last = navNames.length - 1;
  if (at < 0) return "";
  if (key === "ArrowDown" || key === "ArrowRight") return navNames[at === last ? 0 : at + 1];
  if (key === "ArrowUp" || key === "ArrowLeft") return navNames[at === 0 ? last : at - 1];
  if (key === "Home") return navNames[0];
  if (key === "End") return navNames[last];
  return "";
}

function navAsked() {
  const asked = location.hash.slice(1);
  if (navNames.includes(asked)) return asked;
  return navOld[asked] || navNames[0];
}

function navInit() {
  for (const n of navNames) byId("tab-" + n).addEventListener("click", () => navShow(n, false));
  byId("tabs").addEventListener("keydown", (e) => {
    const tab = e.target.closest("[role=tab]");
    const next = tab ? navStep(tab.id.replace(/^tab-/, ""), e.key) : "";
    if (!next) return;
    e.preventDefault();
    navShow(next, true);
  });
  navOrient();
  navNarrow.addEventListener("change", navOrient);
  navShow(navAsked(), false);
}

clm.inits.push(navInit);
