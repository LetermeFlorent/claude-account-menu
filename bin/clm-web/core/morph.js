"use strict";

const morphKept = new Set(["aria-expanded", "style"]);

function morphKey(node, at) {
  if (node.nodeType === 1 && node.dataset.key) return "k:" + node.dataset.key;
  return "i:" + at + ":" + node.nodeName;
}

function morphAttrs(old, neu, own) {
  const kept = (name) => morphKept.has(name) || (own && name === "hidden");
  for (const { name } of [...old.attributes]) if (!kept(name) && !neu.hasAttribute(name)) old.removeAttribute(name);
  for (const { name, value } of [...neu.attributes]) if (!kept(name) && old.getAttribute(name) !== value) old.setAttribute(name, value);
  if (old.style.cssText !== neu.style.cssText) old.style.cssText = neu.style.cssText;
}

function morphProps(old, neu) {
  if (old.tagName !== "INPUT") return;
  if (old.checked !== neu.checked) old.checked = neu.checked;
  if (old.indeterminate !== neu.indeterminate) old.indeterminate = neu.indeterminate;
  if (old !== document.activeElement && old.value !== neu.value) old.value = neu.value;
}

function morphOn(old, neu) {
  const fresh = neu.clmOn || {};
  for (const type of Object.keys(fresh)) clmOn(old, type, fresh[type]);
  for (const type of Object.keys(old.clmOn || {})) if (!(type in fresh)) old.clmOn[type] = null;
}

function morphNode(old, neu) {
  if (old.nodeType === 3) {
    if (old.nodeValue !== neu.nodeValue) old.nodeValue = neu.nodeValue;
    return;
  }
  if (old.nodeType !== 1) return;
  const own = old.hasAttribute("data-own");
  morphAttrs(old, neu, own);
  morphProps(old, neu);
  morphOn(old, neu);
  old.clmData = neu.clmData;
  if (!own) morphKids(old, [...neu.childNodes]);
}

function morphKids(root, kids) {
  const pool = new Map();
  [...root.childNodes].forEach((node, at) => pool.set(morphKey(node, at), node));
  const next = kids.map((node, at) => {
    const key = morphKey(node, at);
    const was = pool.get(key);
    if (!was || was.nodeName !== node.nodeName) return node;
    pool.delete(key);
    morphNode(was, node);
    return was;
  });
  for (const node of pool.values()) node.remove();
  next.forEach((node, at) => {
    if (root.childNodes[at] !== node) root.insertBefore(node, root.childNodes[at] || null);
  });
}

function clmMorph(root, kids) {
  clmKeepFocus(() => morphKids(root, kids.filter((kid) => kid !== null && kid !== undefined)));
}
