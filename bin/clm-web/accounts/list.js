"use strict";

function accView(s) {
  if (!clmChanged("accounts", s.accounts)) return;
  const count = s.accounts.length;
  const list = byId("account-list");
  byId("account-empty").hidden = count > 0;
  list.hidden = count === 0;
  clmMorph(list, s.accounts.map((a) => rowNode(a, count)));
}

function accInit() {
  byId("add-btn").addEventListener("click", accAdd);
}

clm.views.push(accView);
clm.inits.push(accInit);
