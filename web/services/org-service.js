(function () {
  'use strict';

  function listOrgs() {
    return window.MZOrgNui.callNuiData('orgs:list').then(function (items) {
      return Array.isArray(items) ? items : [];
    });
  }

  function getOrg(orgCode) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('orgs:get', { orgCode: orgCode }).then(function (data) {
      return data || null;
    });
  }

  function createOrgFromTemplate(payload) {
    payload = payload || {};
    return window.MZOrgNui.callNuiData('orgs:createFromTemplate', {
      type: payload.type,
      code: payload.code,
      name: payload.name,
      hasSalary: payload.hasSalary === true,
      hasSharedAccount: payload.hasSharedAccount === true,
      hasStorage: payload.hasStorage === true,
      reason: payload.reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  window.MZOrgService = {
    listOrgs: listOrgs,
    getOrg: getOrg,
    createOrgFromTemplate: createOrgFromTemplate
  };
}());
