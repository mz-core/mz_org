(function () {
  'use strict';

  function getOrgBank(orgCode) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('org-bank:get', { orgCode: orgCode }).then(function (data) {
      return data || null;
    });
  }

  function listOrgBankTransactions(orgCode, filters) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('org-bank:transactions', { orgCode: orgCode, filters: filters || { limit: 50 } }).then(function (items) {
      return Array.isArray(items) ? items : [];
    });
  }

  function depositOrgAccount(orgCode, amount, reason) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('org-bank:deposit', {
      orgCode: orgCode,
      amount: amount,
      reason: reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  function withdrawOrgAccount(orgCode, amount, reason) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('org-bank:withdraw', {
      orgCode: orgCode,
      amount: amount,
      reason: reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  window.MZOrgBankService = {
    getOrgBank: getOrgBank,
    listOrgBankTransactions: listOrgBankTransactions,
    depositOrgAccount: depositOrgAccount,
    withdrawOrgAccount: withdrawOrgAccount
  };
}());
