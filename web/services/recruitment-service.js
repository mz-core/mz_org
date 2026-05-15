(function () {
  'use strict';

  function listRecruitment(filters) {
    return window.MZOrgNui.callNuiData('recruitment:list', filters || {}).then(function (items) {
      return Array.isArray(items) ? items : [];
    });
  }

  function getRecruitment(id) {
    if (!id) return Promise.reject(new Error('Identificador da candidatura ausente.'));
    return window.MZOrgNui.callNuiData('recruitment:get', { id: id }).then(function (data) {
      return data || null;
    });
  }

  window.MZOrgRecruitmentService = {
    listRecruitment: listRecruitment,
    getRecruitment: getRecruitment
  };
}());
