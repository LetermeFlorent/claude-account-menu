"use strict";

let accAt;

function accLevel(pct) {
  if (pct >= 70) return 2;
  if (pct >= 30) return 1;
  return 0;
}

function accQuota(kind, cls, q, pending) {
  const fill = el("div", { class: "fill" });
  let pct = pending ? "..." : "?";
  if (q.pct !== null) {
    fill.style.width = Math.min(100, Math.max(0, q.pct)) + "%";
    fill.classList.add("lv" + accLevel(q.pct));
    pct = q.pct + "%";
  }
  const info = el("span", { class: "info" }, [
    q.left && q.left !== "-" ? el("span", { class: "dim", text: "fin dans " + q.left + (q.pace ? ", " : "") }) : null,
    q.pace ? el("span", { class: q.tone, text: "rythme " + q.pace }) : null,
  ]);
  return el("div", { class: "quota " + cls }, [
    el("span", { class: "kind dim", text: kind }),
    el("div", { class: "bar", role: "img", "aria-label": kind + " " + pct }, [fill]),
    el("span", { class: "pct", text: pct }),
    info,
  ]);
}

function accFacts(a) {
  const facts = [];
  if (a.error) facts.push(el("p", { class: "alert", text: a.error }));
  else if (a.pending && !a.seen) facts.push(el("p", { class: "dim", text: "lecture du quota..." }));
  if (a.badge) facts.push(el("p", { class: "alert", text: a.badge }));
  if (a.away) facts.push(el("p", { class: "warn", text: a.away }));
  if (a.note) facts.push(el("p", { class: "dim", text: a.note }));
  return facts;
}

async function accRename(a) {
  const field = el("input", { type: "text", maxlength: "40", value: a.label, "aria-label": "Nouveau nom" });
  if (!(await clmAsk("Renommer " + a.label, ["Le dossier " + a.dir + " garde son nom, seul le menu change."], "Renommer", [field]))) return;
  const name = field.value.trim();
  if (name && name !== a.label) clmAct({ do: "rename", acc: a.dir, name });
}

async function accRemove(a) {
  const lines = ["Le compte quitte le menu de clm. Sans autre choix, son dossier " + a.dir + " reste en place."];
  const extra = [];
  let box = null;
  if (a.erasable) {
    box = el("input", { type: "checkbox" });
    extra.push(el("label", { class: "check" }, [box, el("span", { text: "Effacer aussi son dossier : connexion, historique, réglages" })]));
    extra.push(el("p", { class: "dim", text: "Une archive de sécurité est d'abord rangée dans Téléchargements." }));
  } else {
    extra.push(el("p", { class: "dim", text: "Le dossier " + a.dir + " n'est jamais effacé d'ici." }));
  }
  if (!(await clmAsk("Retirer " + a.label, lines, "Retirer", extra, true))) return;
  clmAct({ do: "remove", acc: a.dir, erase: box !== null && box.checked });
}

function accButton(a, text, onclick, extra) {
  return el("button", Object.assign({ type: "button", class: "small", text, onclick, "data-at": a.dir + " " + text }, extra));
}

function accRow(a, count) {
  const move = (rank) => () => clmAct({ do: "move", acc: a.dir, rank });
  return el("li", { class: a.selected ? "sel" : "" }, [
    el("div", { class: "who" }, [
      el("span", { class: "n", text: String(a.n) }),
      el("span", { class: "label", text: a.label }),
      a.email ? el("span", { class: "dim", text: a.email }) : null,
      a.plan ? el("span", { class: "dim", text: a.plan }) : null,
      el("span", { class: "dim mono", text: a.dir }),
      a.selected ? el("span", { class: "ok", text: "choisi dans le terminal" }) : null,
    ]),
    accQuota("5h", "q5", a.q5, a.pending),
    accQuota("7d", "q7", a.q7, a.pending),
    ...accFacts(a),
    el("div", { class: "acts" }, [
      accButton(a, "Relire", () => clmAct({ do: "refresh", acc: a.dir })),
      accButton(a, "Renommer", () => accRename(a)),
      accButton(a, "Monter", move(a.n - 1), { disabled: a.n <= 1 }),
      accButton(a, "Descendre", move(a.n + 1), { disabled: a.n >= count }),
      accButton(a, "Retirer", () => accRemove(a), { class: "small danger" }),
    ]),
  ]);
}

function accView(s) {
  if (!clmChanged("accounts", s.accounts)) return;
  const list = byId("account-list");
  if (s.accounts.length === 0) {
    list.replaceChildren(el("li", { class: "dim", text: "Aucun compte pour l'instant." }));
    return;
  }
  list.replaceChildren(...s.accounts.map((a) => accRow(a, s.accounts.length)));
  const now = document.activeElement;
  if (accAt === undefined || (now !== document.body && !list.contains(now))) return;
  const back = [...list.querySelectorAll("button")].find((b) => b.dataset.at === accAt);
  if (back) back.focus({ preventScroll: true });
}

async function accAdd() {
  const field = byId("add-name");
  const r = await clmAct({ do: "add", name: field.value.trim() });
  if (r && r.ok) field.value = "";
}

function accInit() {
  document.addEventListener("focusin", (e) => (accAt = byId("account-list").contains(e.target) ? e.target.dataset.at : undefined));
  byId("add-btn").addEventListener("click", accAdd);
  byId("add-name").addEventListener("keydown", (e) => {
    if (e.key !== "Enter") return;
    e.preventDefault();
    accAdd();
  });
}

clm.views.push(accView);
clm.inits.push(accInit);
