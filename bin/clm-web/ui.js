"use strict";

function byId(id) {
  return document.getElementById(id);
}

function el(tag, props, kids) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(props || {})) {
    if (k === "text") node.textContent = v;
    else if (k === "class") node.className = v;
    else if (k.startsWith("on")) node.addEventListener(k.slice(2), v);
    else if (k === "value" || typeof v === "boolean") node[k] = v;
    else node.setAttribute(k, v);
  }
  for (const kid of kids || []) if (kid !== null && kid !== undefined) node.append(kid);
  return node;
}

function clmChanged(name, value) {
  const key = JSON.stringify(value);
  if (clm.keys[name] === key) return false;
  clm.keys[name] = key;
  return true;
}

function clmStatus(text, tone) {
  const s = byId("status");
  s.textContent = text || "";
  s.className = "status " + (tone || "dim");
}

function clmLockNote() {
  const s = clm.state;
  if (clm.pending) return "";
  if (clm.busy) return "clm est occupé dans le terminal (saisie, connexion ou travail en cours). La page reprend quand il revient au menu.";
  if (s && s.startup) return "clm finit de démarrer, les boutons arrivent dans un instant.";
  if (s && !s.open) return "clm est sur une autre page dans le terminal. Les boutons reviennent quand il revient au menu.";
  return "";
}

function clmRefreshLock() {
  const note = clmLockNote();
  const locked = note !== "" || clm.pending;
  byId("controls").disabled = locked;
  byId("update").disabled = locked;
  byId("busy").textContent = note;
  byId("busy").hidden = note === "";
}

function clmAsk(title, lines, yesText, extra, danger) {
  const dlg = byId("ask");
  byId("ask-title").textContent = title;
  byId("ask-body").replaceChildren(...lines.map((l) => el("p", { text: l })), ...(extra || []));
  const yes = byId("ask-yes");
  yes.textContent = yesText;
  yes.className = danger ? "danger" : "";
  dlg.returnValue = "";
  dlg.showModal();
  const field = dlg.querySelector("#ask-body input[type=text]");
  if (field) field.select();
  return new Promise((resolve) => dlg.addEventListener("close", () => resolve(dlg.returnValue === "yes"), { once: true }));
}

function clmHeaderView(s) {
  byId("version").textContent = s.version || "clm";
  document.title = s.version || "clm";
  const up = byId("update");
  up.hidden = !s.update.ready;
  up.textContent = "Installer " + (s.update.latest || "la mise à jour");
  const d = s.drive;
  byId("drive-tag").textContent = d.connected ? "Drive : " + d.tag + ", PC " + d.pc : "Drive non connecté";
}

async function clmPoll() {
  if (clm.polling) {
    clm.again = true;
    return;
  }
  clm.polling = true;
  clearTimeout(clm.timer);
  try {
    const s = await clmRead("state");
    clm.busy = false;
    clm.state = s;
    byId("app").hidden = false;
    for (const view of clm.views) view(s);
    if (!clm.pending && s.msg.text && clmChanged("msg", s.msg)) clmStatus(s.msg.text, s.msg.tone);
  } catch (err) {
    clmFail(err);
  } finally {
    clm.polling = false;
  }
  clmRefreshLock();
  clm.timer = setTimeout(clmPoll, clm.again ? 0 : clm.pollMs);
  clm.again = false;
}

async function clmAct(args, onData) {
  if (clm.pending) return null;
  clm.pending = true;
  clmRefreshLock();
  clmStatus("Envoyé au terminal...", "dim");
  let r = null;
  try {
    r = await clmSend(args);
    clmStatus(r.msg || "", r.ok ? "ok" : "alert");
    if (r.ok && onData) onData(r.data);
    return r;
  } catch (err) {
    clmFail(err);
    return null;
  } finally {
    if (!r || !r.ok) clm.keys = { msg: clm.keys.msg };
    clm.pending = false;
    clmRefreshLock();
    clmPoll();
  }
}

function clmStart() {
  const dlg = byId("ask");
  byId("ask-no").addEventListener("click", () => dlg.close("no"));
  byId("ask-yes").addEventListener("click", () => dlg.close("yes"));
  dlg.addEventListener("keydown", (e) => {
    if (e.key !== "Enter" || !e.target.matches("input[type=text]")) return;
    e.preventDefault();
    dlg.close("yes");
  });
  byId("update").addEventListener("click", async () => {
    const lines = ["clm installe sa nouvelle version puis redémarre. Cette page se ferme et une nouvelle s'ouvre."];
    if (await clmAsk("Mettre clm à jour", lines, "Installer")) clmAct({ do: "selfupdate" });
  });
  for (const init of clm.inits) init();
  clmPoll();
}

clm.views.push(clmHeaderView);
document.addEventListener("DOMContentLoaded", clmStart);
