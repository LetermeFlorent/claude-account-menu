"use strict";

function byId(id) {
  return document.getElementById(id);
}

function clmOn(node, type, fn) {
  if (!node.clmOn) node.clmOn = {};
  if (!(type in node.clmOn)) {
    node.addEventListener(type, (e) => {
      const run = node.clmOn[type];
      if (run) run(e);
    });
  }
  node.clmOn[type] = fn;
}

function el(tag, props, kids) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(props || {})) {
    if (k === "text") node.textContent = v;
    else if (k === "class") node.className = v;
    else if (k.startsWith("on")) clmOn(node, k.slice(2), v);
    else if (k === "value" || typeof v === "boolean") node[k] = v;
    else node.setAttribute(k, v);
  }
  for (const kid of kids || []) if (kid !== null && kid !== undefined) node.append(kid);
  return node;
}

function clmSetText(node, text) {
  const value = text === null || text === undefined ? "" : String(text);
  if (node.textContent !== value) node.textContent = value;
}

function clmSetAttr(node, name, value) {
  if (value === null || value === undefined) node.removeAttribute(name);
  else if (node.getAttribute(name) !== String(value)) node.setAttribute(name, value);
}

function clmChanged(name, value) {
  const key = JSON.stringify([clm.lang, value]);
  if (clm.keys[name] === key) return false;
  clm.keys[name] = key;
  return true;
}

function clmRefocus(had) {
  const lost = !document.activeElement || document.activeElement === document.body;
  if (lost && had && had !== document.body && had.isConnected && !had.disabled) had.focus({ preventScroll: true });
}

function clmKeepFocus(change) {
  const had = document.activeElement;
  change();
  if (had && had !== document.body && had.isConnected && document.activeElement !== had) had.focus({ preventScroll: true });
}
