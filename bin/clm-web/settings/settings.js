"use strict";

const settingsChoices = {
  palette: ["auto", "dark", "light"],
  anim: ["auto", "on", "off"],
};

function settingsView(s) {
  const d = s.display;
  for (const name of Object.keys(settingsChoices)) {
    const sel = byId(name);
    if (document.activeElement !== sel && sel.value !== d[name]) sel.value = d[name];
  }
  byId("palette-env").hidden = !d.paletteEnv;
  byId("anim-env").hidden = !d.animEnv;
}

async function settingsChoose(name, sel) {
  const r = await clmAct({ do: "display", [name]: sel.value });
  if ((!r || !r.ok) && clm.state) sel.value = clm.state.display[name];
}

function settingsInit() {
  for (const [name, list] of Object.entries(settingsChoices)) {
    const sel = byId(name);
    sel.replaceChildren(...list.map((value) => el("option", { value, "data-text": "settings." + name + "." + value })));
    clmApplyTexts(sel);
    sel.addEventListener("change", () => settingsChoose(name, sel));
  }
}

clm.views.push(settingsView);
clm.inits.push(settingsInit);
