"use strict";

function prefsPcs(p) {
  const self = { name: p.me, self: true, ready: true, sub: p.sub, lines: p.lines };
  return [self].concat((p.pcs || []).map((pc) => Object.assign({ self: false }, pc)));
}

function prefsPcRow(pcs, cur) {
  if (pcs.length < 2) return null;
  const pick = (pc) => () => {
    clm.prefsPc = pc.name;
    prefsDraw(clm.prefsLast);
  };
  const buttons = pcs.map((pc) => el("button", {
    type: "button", class: "small", "aria-pressed": pc === cur ? "true" : "false", "data-key": pc.name,
    text: pc.self ? clmText("prefs.thisPc", pc.name) : pc.name, onclick: pick(pc),
  }));
  return el("div", { class: "segmented", role: "group", "aria-label": clmText("prefs.pcs") }, buttons);
}

function prefsEmpty(cur) {
  if (!cur.ready || cur.lines.length > 0) return null;
  return el("p", { class: "muted", text: cur.self ? clmText("prefs.nothing") : clmText("prefs.nothingPc") });
}

function prefsDraw(p) {
  const pcs = prefsPcs(p);
  const cur = pcs.find((pc) => pc.name === clm.prefsPc) || pcs[0];
  const out = [el("h3", { text: clmText("prefs.title") }), prefsPcRow(pcs, cur), el("p", { class: "muted", text: cur.sub })];
  for (const part of prefsSections(cur.lines)) out.push(prefsPart(part, p.warn, cur));
  out.push(prefsEmpty(cur));
  clmMorph(byId("prefs"), out);
  prefsFilterApply();
}

function prefsView(p) {
  if (!p || !clmChanged("prefs", p)) return;
  if (!p.connected) {
    byId("prefs").replaceChildren();
    return;
  }
  clm.prefsLast = p;
  prefsDraw(p);
}

async function prefsLoad() {
  try {
    prefsView(await clmRead("prefs"));
  } catch (err) {
    delete clm.keys.prefsAt;
    clmFail(err);
  }
}
