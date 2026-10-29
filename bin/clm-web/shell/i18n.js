"use strict";

const langCodes = ["en", "fr"];

const textPrefix = "web.";

function clmText(key, ...values) {
  let text = (clm.texts[clm.lang] || {})[textPrefix + key];
  if (text === undefined) text = (clm.texts.en || {})[textPrefix + key];
  if (text === undefined) return key;
  values.forEach((v, i) => {
    text = text.split("{" + i + "}").join(String(v));
  });
  return text;
}

function clmPickLang(look) {
  if (look && langCodes.includes(look.lang)) return look.lang;
  const asked = String(navigator.language || "").toLowerCase();
  return asked.startsWith("fr") ? "fr" : "en";
}

function clmApplyTexts(root) {
  for (const node of root.querySelectorAll("[data-text]")) clmSetText(node, clmText(node.dataset.text));
  for (const node of root.querySelectorAll("[data-label]")) clmSetAttr(node, "aria-label", clmText(node.dataset.label));
}

function clmSetLang(code) {
  if (code === clm.lang && document.documentElement.lang === code) return false;
  clm.lang = code;
  document.documentElement.lang = code;
  clmApplyTexts(document);
  return true;
}

function clmTextsArrived() {
  clm.keys = {};
  clmApplyTexts(document);
}

function clmNumber(value, digits) {
  return new Intl.NumberFormat(clm.lang, { maximumFractionDigits: digits }).format(value);
}

function clmDate(iso) {
  const when = new Date(iso);
  if (Number.isNaN(when.getTime())) return iso;
  return new Intl.DateTimeFormat(clm.lang, { dateStyle: "medium", timeStyle: "short" }).format(when);
}

function i18nInit() {
  clm.lang = "";
  clmSetLang(clmPickLang(null));
}

clm.inits.push(i18nInit);
