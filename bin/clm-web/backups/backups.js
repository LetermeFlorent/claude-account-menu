"use strict";

const backupOff = new Set();
const backupWarn = ["backups.warnReplace", "backups.warnSaved", "backups.warnClose", "backups.warnLogin"];
let backupAsked = false;

function backupChecks(list, keepOff) {
  return list.map((a) => {
    const flip = (e) => (e.currentTarget.checked ? backupOff.delete(a.dir) : backupOff.add(a.dir));
    const props = { type: "checkbox", checked: !(keepOff && backupOff.has(a.dir)), value: a.dir };
    if (keepOff) props.onchange = flip;
    return el("label", { class: "check", "data-key": a.dir }, [
      el("input", props),
      el("span", { text: a.label }),
      el("span", { class: "muted mono", text: a.dir }),
    ]);
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
  const picks = clmPicks(clmText("backups.restorePick", clmDate(item.when)), backupChecks(accs, false));
  const extra = [picks, ...backupWarn.map((key) => el("p", { class: "muted", text: clmText(key) }))];
  if (!(await clmAsk(clmText("backups.restoreTitle", item.name), [], clmText("backups.restoreYes"), extra, true))) return;
  const dirs = backupPicked(picks);
  if (dirs.length === 0) {
    clmStatus(clmText("backups.noneRestore"), "alert");
    return;
  }
  clmAct({ do: "restore", name: item.name, accs: dirs }, backupListView);
}

function backupRow(item) {
  return el("li", { class: "backup", "data-key": item.name }, [
    el("span", { class: "backup-when", text: clmDate(item.when) }),
    el("span", { class: "backup-name mono", text: item.name }),
    el("span", { class: "backup-mb muted", text: clmText("backups.mb", clmNumber(item.mb, 1)) }),
    el("button", { type: "button", class: "small", text: clmText("backups.restore"), "aria-label": clmText("backups.restoreTitle", item.name), onclick: () => backupRestore(item) }),
  ]);
}

function backupListView(b) {
  if (!b) return;
  clm.backupLast = b;
  if (!clmChanged("backups", b)) return;
  clmSetText(byId("backup-dir"), clmText("backups.dir", b.dir));
  const rows = b.items.length === 0 ? [el("li", { class: "muted empty", text: clmText("backups.none") })] : b.items.map(backupRow);
  clmMorph(byId("backup-list"), rows);
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
  if (clmChanged("saveList", accs)) clmMorph(byId("save-list"), backupChecks(accs, true));
  byId("save-btn").disabled = accs.length === 0;
  backupListView(clm.backupLast);
  if (backupAsked) return;
  backupAsked = true;
  backupLoad();
}

function backupInit() {
  byId("save-btn").addEventListener("click", () => {
    const dirs = backupPicked(byId("save-list"));
    if (dirs.length === 0) {
      clmStatus(clmText("backups.noneSave"), "alert");
      return;
    }
    clmAct({ do: "save", accs: dirs }, backupListView);
  });
}

clm.views.push(backupView);
clm.inits.push(backupInit);
