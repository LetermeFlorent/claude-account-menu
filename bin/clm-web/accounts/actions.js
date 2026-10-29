"use strict";

function accField(value, label, hint) {
  return el("input", { type: "text", maxlength: "40", value, "aria-label": label, placeholder: hint || "" });
}

async function accAdd() {
  const field = accField("", clmText("accounts.addName"), clmText("accounts.addHint"));
  if (!(await clmAsk(clmText("accounts.addTitle"), [clmText("accounts.addLine")], clmText("accounts.addYes"), [field]))) return;
  clmAct({ do: "add", name: field.value.trim() });
}

async function accRename(a) {
  const field = accField(a.label, clmText("accounts.newName"));
  const lines = [clmText("accounts.renameLine", a.dir)];
  if (!(await clmAsk(clmText("accounts.renameTitle", a.label), lines, clmText("accounts.renameYes"), [field]))) return;
  const name = field.value.trim();
  if (name && name !== a.label) clmAct({ do: "rename", acc: a.dir, name });
}

function accEraseBox() {
  const box = el("input", { type: "checkbox" });
  const extra = [
    el("label", { class: "check" }, [box, el("span", { text: clmText("accounts.eraseBox") })]),
    el("p", { class: "muted", text: clmText("accounts.eraseNote") }),
  ];
  return { box, extra };
}

async function accRemove(a) {
  const lines = [clmText("accounts.removeLine", a.dir)];
  const erase = a.erasable ? accEraseBox() : null;
  const extra = erase ? erase.extra : [el("p", { class: "muted", text: clmText("accounts.keepNote", a.dir) })];
  if (!(await clmAsk(clmText("accounts.removeTitle", a.label), lines, clmText("accounts.removeYes"), extra, true))) return;
  clmAct({ do: "remove", acc: a.dir, erase: erase !== null && erase.box.checked });
}

function accEntries(a, count) {
  const move = (rank) => () => clmAct({ do: "move", acc: a.dir, rank });
  return () => [
    { text: clmText("accounts.refresh"), run: () => clmAct({ do: "refresh", acc: a.dir }) },
    { text: clmText("accounts.rename"), run: () => accRename(a) },
    { text: clmText("accounts.up"), run: move(a.n - 1), disabled: a.n <= 1 },
    { text: clmText("accounts.down"), run: move(a.n + 1), disabled: a.n >= count },
    { text: clmText("accounts.remove"), run: () => accRemove(a), danger: true },
  ];
}
