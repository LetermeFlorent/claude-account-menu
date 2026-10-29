"use strict";

function rowFacts(a) {
  const facts = [];
  if (a.error) facts.push(el("p", { class: "alert", text: a.error }));
  else if (a.pending && !a.seen) facts.push(el("p", { class: "muted", text: clmText("accounts.reading") }));
  if (a.badge) facts.push(el("p", { class: "alert", text: a.badge }));
  if (a.away) facts.push(el("p", { class: "warn", text: a.away }));
  if (a.note) facts.push(el("p", { class: "muted", text: a.note }));
  return facts.length === 0 ? null : el("div", { class: "account-facts" }, facts);
}

function rowWho(a) {
  return el("div", { class: "account-who" }, [
    el("div", { class: "account-name" }, [
      el("span", { class: "account-label", text: a.label }),
      a.selected ? el("span", { class: "pill", text: clmText("accounts.chosen") }) : null,
    ]),
    el("div", { class: "account-sub muted" }, [
      a.email ? el("span", { text: a.email }) : null,
      a.plan ? el("span", { text: a.plan }) : null,
      el("span", { class: "mono", text: a.dir }),
    ]),
  ]);
}

function rowNode(a, count) {
  const menu = menuNew(accEntries(a, count));
  menuLabel(menu, clmText("accounts.actions", a.label));
  return el("li", { class: a.selected ? "account selected" : "account", "data-key": a.dir }, [
    el("span", { class: "account-n", text: String(a.n), "aria-hidden": "true" }),
    rowWho(a),
    quotaBar("q5", a.q5, a.pending),
    quotaBar("q7", a.q7, a.pending),
    menu,
    rowFacts(a),
  ]);
}
