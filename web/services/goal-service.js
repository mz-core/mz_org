(function () {
  'use strict';

  function listGoals(filters) {
    return window.MZOrgNui.callNuiData('goals:list', filters || {}).then(function (items) {
      return Array.isArray(items) ? items : [];
    });
  }

  function getGoal(id) {
    if (!id) return Promise.reject(new Error('Identificador da meta ausente.'));
    return window.MZOrgNui.callNuiData('goals:get', { id: id }).then(function (data) {
      return data || null;
    });
  }

  function createGoal(orgCode, payload) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    payload = payload || {};

    return window.MZOrgNui.callNuiData('goals:create', {
      orgCode: orgCode,
      title: payload.title,
      description: payload.description,
      type: payload.type,
      target: payload.target,
      startsAt: payload.startsAt,
      endsAt: payload.endsAt
    }).then(function (data) {
      return data || {};
    });
  }

  window.MZOrgGoalService = {
    listGoals: listGoals,
    getGoal: getGoal,
    createGoal: createGoal
  };
}());
