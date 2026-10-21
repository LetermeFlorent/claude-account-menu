"use strict";

const displayChoices = {
  palette: [["auto", "Auto, suit le système"], ["dark", "Sombre"], ["light", "Clair"]],
  anim: [["auto", "Auto"], ["on", "Oui"], ["off", "Non"]],
};

function displayView(s) {
  const d = s.display;
  document.documentElement.dataset.theme = d.theme;
  for (const name of Object.keys(displayChoices)) {
    const sel = byId(name);
    if (document.activeElement !== sel) sel.value = d[name];
  }
  byId("palette-env").hidden = !d.paletteEnv;
  byId("anim-env").hidden = !d.animEnv;
}

function displayKeepClear() {
  const top = document.querySelector("header.top");
  const pad = () => (document.documentElement.style.scrollPaddingTop = top.offsetHeight + 12 + "px");
  new ResizeObserver(pad).observe(top);
}

function displayInit() {
  displayKeepClear();
  const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  document.documentElement.dataset.theme = dark ? "dark" : "light";
  for (const [name, list] of Object.entries(displayChoices)) {
    const sel = byId(name);
    sel.replaceChildren(...list.map(([value, text]) => el("option", { value, text })));
    sel.addEventListener("change", async () => {
      const r = await clmAct({ do: "display", [name]: sel.value });
      if ((!r || !r.ok) && clm.state) sel.value = clm.state.display[name];
    });
  }
}

clm.views.push(displayView);
clm.inits.push(displayInit);
