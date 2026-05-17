(function () {
  'use strict';

  function listRecruitment(orgCode, filters) {
    if (typeof orgCode === 'object') {
      filters = orgCode;
      orgCode = filters && filters.orgCode;
    }

    filters = filters || {};
    if (orgCode) filters.orgCode = orgCode;

    return window.MZOrgNui.callNuiData('recruitment:list', filters).then(function (items) {
      return Array.isArray(items) ? items : [];
    });
  }

  function getRecruitment(id) {
    if (!id) return Promise.reject(new Error('Identificador da candidatura ausente.'));
    return window.MZOrgNui.callNuiData('recruitment:get', { id: id }).then(function (data) {
      return data || null;
    });
  }

  function createRecruitment(orgCode, payload) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    payload = payload || {};
    payload.orgCode = orgCode;
    return window.MZOrgNui.callNuiData('recruitment:create', payload).then(function (data) {
      return data || {};
    });
  }

  function approveRecruitment(id, options) {
    if (!id) return Promise.reject(new Error('Identificador da candidatura ausente.'));
    options = options || {};
    options.id = id;
    return window.MZOrgNui.callNuiData('recruitment:approve', options).then(function (data) {
      return data || {};
    });
  }

  function rejectRecruitment(id, reason) {
    if (!id) return Promise.reject(new Error('Identificador da candidatura ausente.'));
    return window.MZOrgNui.callNuiData('recruitment:reject', {
      id: id,
      reason: reason || ''
    }).then(function (data) {
      return data || {};
    });
  }

  function cancelRecruitment(id, reason) {
    if (!id) return Promise.reject(new Error('Identificador da candidatura ausente.'));
    return window.MZOrgNui.callNuiData('recruitment:cancel', {
      id: id,
      reason: reason || ''
    }).then(function (data) {
      return data || {};
    });
  }

  window.MZOrgRecruitmentService = {
    listRecruitment: listRecruitment,
    getRecruitment: getRecruitment,
    createRecruitment: createRecruitment,
    approveRecruitment: approveRecruitment,
    rejectRecruitment: rejectRecruitment,
    cancelRecruitment: cancelRecruitment
  };
}());
