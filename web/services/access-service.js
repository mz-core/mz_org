(function () {
  'use strict';

  function getOrgAccess(orgCode) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('org-access:get', { orgCode: orgCode }).then(function (data) {
      return data || null;
    });
  }

  window.MZOrgAccessService = {
    getOrgAccess: getOrgAccess
  };
}());
