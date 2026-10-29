"use strict";

const lookDark = window.matchMedia("(prefers-color-scheme: dark)");
const lookThemes = ["light", "dark"];

function lookTheme(look) {
  if (!look) return lookDark.matches ? "dark" : "light";
  if (lookThemes.includes(look.themePref)) return look.themePref;
  return look.themeFound === "dark" ? "dark" : "light";
}

function lookPaint(look) {
  const root = document.documentElement;
  const theme = lookTheme(look);
  root.dataset.theme = theme;
  const pair = look && look.accent ? look.accent[theme] : null;
  if (pair) {
    root.style.setProperty("--accent", pair.fill);
    root.style.setProperty("--on-accent", pair.ink);
  } else {
    root.style.removeProperty("--accent");
    root.style.removeProperty("--on-accent");
  }
}

function lookShow() {
  const look = clm.look;
  const changed = clmSetLang(clmPickLang(look));
  lookPaint(look);
  const picks = { "lang-pick": look ? look.langPref : "auto", "theme-pick": look ? look.themePref : "system" };
  for (const [id, value] of Object.entries(picks)) {
    const sel = byId(id);
    if (document.activeElement !== sel && sel.value !== value) sel.value = value;
  }
  return changed;
}

function lookKeep(look) {
  clm.look = look;
  if (clm.state) clm.state.look = look;
  if (lookShow()) clmRedraw();
}

function lookView(s) {
  if (!s.look) return;
  clm.look = s.look;
  lookShow();
}

async function lookChoose(name, value) {
  const before = clm.look;
  const guess = Object.assign({}, before);
  if (name === "lang") {
    guess.langPref = value;
    guess.lang = langCodes.includes(value) ? value : guess.langFound || "";
  } else guess.themePref = value;
  lookKeep(guess);
  const r = await clmAct({ do: "look", [name]: value });
  lookKeep(r && r.ok && r.data ? r.data : before);
}

async function lookSystemChanged() {
  if (!clm.look) {
    lookPaint(null);
    return;
  }
  if (clm.look.themePref !== "system") return;
  try {
    const r = await clmSend({ do: "look" });
    if (r && r.ok && r.data) lookKeep(r.data);
  } catch (err) {
    clmFail(err);
  }
}

function lookInit() {
  lookPaint(null);
  lookDark.addEventListener("change", lookSystemChanged);
  byId("lang-pick").addEventListener("change", (e) => lookChoose("lang", e.target.value));
  byId("theme-pick").addEventListener("change", (e) => lookChoose("theme", e.target.value));
}

clm.views.push(lookView);
clm.inits.push(lookInit);
