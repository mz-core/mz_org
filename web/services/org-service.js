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

  function updateOrgBasic(orgCode, payload) {
    payload = payload || {};
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('orgs:updateBasic', {
      orgCode: orgCode,
      name: payload.name,
      status: payload.status,
      hasSalary: payload.hasSalary === true,
      hasSharedAccount: payload.hasSharedAccount === true,
      hasStorage: payload.hasStorage === true,
      reason: payload.reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  function createOrgGrade(orgCode, payload) {
    payload = payload || {};
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('orgs:createGrade', {
      orgCode: orgCode,
      code: payload.code,
      name: payload.name,
      level: payload.level,
      salary: payload.salary,
      priority: payload.priority,
      inheritsLevel: payload.inheritsLevel,
      reason: payload.reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  function updateOrgGradeBasic(orgCode, gradeId, payload) {
    payload = payload || {};
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!gradeId) return Promise.reject(new Error('Cargo ausente.'));
    return window.MZOrgNui.callNuiData('orgs:updateGradeBasic', {
      orgCode: orgCode,
      gradeId: gradeId,
      name: payload.name,
      level: payload.level,
      salary: payload.salary,
      priority: payload.priority,
      inheritsLevel: payload.inheritsLevel,
      reason: payload.reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  function archiveOrg(orgCode, reason) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('orgs:archive', {
      orgCode: orgCode,
      reason: reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  function reactivateOrg(orgCode, reason) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('orgs:reactivate', {
      orgCode: orgCode,
      reason: reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  function disableOrgGrade(orgCode, gradeId, reason) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!gradeId) return Promise.reject(new Error('Cargo ausente.'));
    return window.MZOrgNui.callNuiData('orgs:disableGrade', {
      orgCode: orgCode,
      gradeId: gradeId,
      reason: reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  function reactivateOrgGrade(orgCode, gradeId, reason) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!gradeId) return Promise.reject(new Error('Cargo ausente.'));
    return window.MZOrgNui.callNuiData('orgs:reactivateGrade', {
      orgCode: orgCode,
      gradeId: gradeId,
      reason: reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  function addGradePermission(orgCode, gradeId, permission, reason) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!gradeId) return Promise.reject(new Error('Cargo ausente.'));
    if (!permission) return Promise.reject(new Error('Permissao ausente.'));
    return window.MZOrgNui.callNuiData('orgs:addGradePermission', {
      orgCode: orgCode,
      gradeId: gradeId,
      permission: permission,
      reason: reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  function removeGradePermission(orgCode, gradeId, permission, reason) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!gradeId) return Promise.reject(new Error('Cargo ausente.'));
    if (!permission) return Promise.reject(new Error('Permissao ausente.'));
    return window.MZOrgNui.callNuiData('orgs:removeGradePermission', {
      orgCode: orgCode,
      gradeId: gradeId,
      permission: permission,
      reason: reason || ''
    }).then(function (data) {
      return data || null;
    });
  }

  window.MZOrgService = {
    listOrgs: listOrgs,
    getOrg: getOrg,
    createOrgFromTemplate: createOrgFromTemplate,
    updateOrgBasic: updateOrgBasic,
    createOrgGrade: createOrgGrade,
    updateOrgGradeBasic: updateOrgGradeBasic,
    archiveOrg: archiveOrg,
    reactivateOrg: reactivateOrg,
    disableOrgGrade: disableOrgGrade,
    reactivateOrgGrade: reactivateOrgGrade,
    addGradePermission: addGradePermission,
    removeGradePermission: removeGradePermission
  };
}());
