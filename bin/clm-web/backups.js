"use strict";

const backupOff = new Set();
const backupWarn = [
  "Les fichiers de ces comptes seront remplacés par ceux de la sauvegarde.",
  "Leur état actuel est d'abord sauvegardé dans Téléchargements.",
  "Ferme les autres sessions Claude Code avant, sinon leurs fichiers ouverts seront ignorés.",
  "Une connexion utilisée ou renouvelée depuis la sauvegarde demandera un /login.",
];
let backupAsked = false;

function backupChecks(list, keepOff) {
  return list.map((a) => {
    const box = el("input", { type: "checkbox", checked: !(keepOff && backupOff.has(a.dir)), value: a.dir });
    if (keepOff) box.addEventListener("change", () => (box.checked ? backupOff.delete(a.dir) : backupOff.add(a.dir)));
    return el("label", { class: "check" }, [box, el("span", { text: a.label }), el("span", { class: "dim mono", text: a.dir })]);
  });
}

function backupPicked(root) {
  return [...root.querySelectorAll("input[type=checkbox]")].filter((b) => b.checked).map((b) => b.value);
}

async function backupAccounts(name) {
  const r = await clmAct({ do: "backups-of", name });
  return r && r.ok ? r.data || [] : null;
}

async function backupRestore(item) {
  const accs = await backupAccounts(item.name);
  if (accs === null) return;
  const picks = el("div", { class: "checks" }, backupChecks(accs, false));
  const lines = ["Sauvegarde du " + item.date + ", comptes à restaurer :"];
  const extra = [picks, ...backupWarn.map((w) => el("p", { class: "dim", text: w }))];
  if (!(await clmAsk("Restaurer " + item.name, lines, "Restaurer", extra, true))) return;
  const dirs = backupPicked(picks);
  if (dirs.length === 0) {
    clmStatus("Aucun compte coché, rien n'est restauré.", "alert");
    return;
  }
  clmAct({ do: "restore", name: item.name, accs: dirs }, backupListView);
}

function backupListView(b) {
  if (!b || !clmChanged("backups", b)) return;
  byId("backup-dir").textContent = "Dossier : " + b.dir;
  const list = byId("backup-list");
  if (b.items.length === 0) {
    list.replaceChildren(el("li", { class: "dim empty", text: "Aucune sauvegarde dans ce dossier." }));
    return;
  }
  list.replaceChildren(...b.items.map((item) => el("li", {}, [
    el("span", { class: "mono", text: item.date }),
    el("span", { class: "mb dim", text: item.mb + " Mo" }),
    el("span", { class: "name mono", text: item.name }),
    el("button", { type: "button", class: "small", text: "Restaurer...", onclick: () => backupRestore(item) }),
  ])));
}

async function backupLoad() {
  try {
    backupListView(await clmRead("backups"));
  } catch (err) {
    backupAsked = false;
    clmFail(err);
  }
}

function backupView(s) {
  const accs = s.accounts.map((a) => ({ label: a.label, dir: a.dir }));
  if (clmChanged("saveList", accs)) byId("save-list").replaceChildren(...backupChecks(accs, true));
  byId("save-btn").disabled = accs.length === 0;
  if (backupAsked) return;
  backupAsked = true;
  backupLoad();
}

function backupInit() {
  byId("save-btn").addEventListener("click", () => {
    const dirs = backupPicked(byId("save-list"));
    if (dirs.length === 0) {
      clmStatus("Coche au moins un compte à sauvegarder.", "alert");
      return;
    }
    clmAct({ do: "save", accs: dirs }, backupListView);
  });
}

clm.views.push(backupView);
clm.inits.push(backupInit);
