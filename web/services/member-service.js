(function () {
  'use strict';

  function listMembers(orgCode) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    return window.MZOrgNui.callNuiData('members:list', { orgCode: orgCode }).then(function (items) {
      return Array.isArray(items) ? items : [];
    });
  }

  function inviteMember(orgCode, citizenid, grade) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!citizenid) return Promise.reject(new Error('CitizenID do player alvo ausente.'));
    var payload = { orgCode: orgCode, citizenid: citizenid };
    if (grade && grade.gradeLevel) payload.gradeLevel = grade.gradeLevel;
    if (grade && grade.gradeCode) payload.gradeCode = grade.gradeCode;

    return window.MZOrgNui.callNuiData('members:invite', payload).then(function (data) {
      return data || {};
    });
  }

  function inviteMemberBySource(orgCode, targetId, grade) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!targetId) return Promise.reject(new Error('ID do player alvo ausente.'));
    var payload = { orgCode: orgCode, targetId: targetId };
    if (grade && grade.gradeLevel) payload.gradeLevel = grade.gradeLevel;
    if (grade && grade.gradeCode) payload.gradeCode = grade.gradeCode;

    return window.MZOrgNui.callNuiData('members:invite', payload).then(function (data) {
      return data || {};
    });
  }

  function removeMember(orgCode, citizenid) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!citizenid) return Promise.reject(new Error('CitizenID do membro ausente.'));
    return window.MZOrgNui.callNuiData('members:remove', { orgCode: orgCode, citizenid: citizenid }).then(function (data) {
      return data || {};
    });
  }

  function promoteMember(orgCode, citizenid) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!citizenid) return Promise.reject(new Error('CitizenID do membro ausente.'));
    return window.MZOrgNui.callNuiData('members:promote', { orgCode: orgCode, citizenid: citizenid }).then(function (data) {
      return data || {};
    });
  }

  function demoteMember(orgCode, citizenid) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!citizenid) return Promise.reject(new Error('CitizenID do membro ausente.'));
    return window.MZOrgNui.callNuiData('members:demote', { orgCode: orgCode, citizenid: citizenid }).then(function (data) {
      return data || {};
    });
  }

  function setOrgLeader(orgCode, citizenid, reason) {
    if (!orgCode) return Promise.reject(new Error('Codigo da org ausente.'));
    if (!citizenid) return Promise.reject(new Error('CitizenID do player ausente.'));
    return window.MZOrgNui.callNuiData('members:setLeader', {
      orgCode: orgCode,
      citizenid: citizenid,
      reason: reason || ''
    }).then(function (data) {
      return data || {};
    });
  }

  window.MZOrgMemberService = {
    listMembers: listMembers,
    inviteMember: inviteMember,
    inviteMemberBySource: inviteMemberBySource,
    removeMember: removeMember,
    promoteMember: promoteMember,
    demoteMember: demoteMember,
    setOrgLeader: setOrgLeader
  };
}());
