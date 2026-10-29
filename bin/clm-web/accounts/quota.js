"use strict";

const quotaTones = { ok: "ok", alert: "alert", warn: "warn" };

function quotaPaceWord(word) {
  const key = "quota.paceWord." + word;
  const text = clmText(key);
  return text === key ? word : text;
}

function quotaLevel(pct) {
  if (pct >= 90) return 2;
  if (pct >= 70) return 1;
  return 0;
}

function quotaFill(q) {
  const fill = el("span", { class: "fill lv" + (q.pct === null ? 0 : quotaLevel(q.pct)) });
  if (q.pct !== null) fill.style.setProperty("--pct", Math.min(100, Math.max(0, q.pct)) + "%");
  return fill;
}

function quotaMeter(kind, q, shown) {
  if (q.pct === null) return el("div", { class: "bar", role: "img", "aria-label": kind + " " + shown }, [quotaFill(q)]);
  return el("div", {
    class: "bar", role: "meter", "aria-label": kind, "aria-valuemin": "0", "aria-valuemax": "100",
    "aria-valuenow": String(Math.min(100, Math.max(0, q.pct))), "aria-valuetext": shown,
  }, [quotaFill(q)]);
}

function quotaInfo(q) {
  const info = [];
  if (q.left && q.left !== "-") info.push(el("span", { class: "muted", text: clmText("quota.left", q.left) }));
  if (q.pace) info.push(el("span", { class: quotaTones[q.tone] || "muted", text: clmText("quota.pace", quotaPaceWord(q.pace)) }));
  return el("div", { class: "quota-info" }, info);
}

function quotaBar(name, q, pending) {
  const kind = clmText("quota." + name);
  let shown = pending ? clmText("quota.reading") : clmText("quota.unknown");
  if (q.pct !== null) shown = q.pct + "%";
  return el("div", { class: "quota " + name }, [
    el("div", { class: "quota-head" }, [
      el("span", { class: "quota-kind muted", text: kind }),
      el("span", { class: "quota-pct", text: shown }),
    ]),
    quotaMeter(kind, q, shown),
    quotaInfo(q),
  ]);
}
