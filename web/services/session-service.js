(function () {
  'use strict';

  function normalizeSession(session) {
    session = session || {};
    var user = session.user || {};
    var format = window.MZOrgFormat;
    var permissions = window.MZOrgPermissions;

    return {
      version: session.version || session.contractVersion || 1,
      revision: session.revision || session.sessionId || '',
      entryAllowed: session.entryAllowed !== false,
      denialReason: session.denialReason || null,
      defaultContextId: session.defaultContextId || null,
      requestedEntry: session.requestedEntry || null,
      global: session.global || { permissions: [], permissionGrants: [], features: [] },
      organizations: Array.isArray(session.organizations) ? session.organizations : [],
      staff: session.staff || session.staffContext || null,
      user: {
        source: user.source || 0,
        name: user.name || 'Player',
        citizenid: user.citizenid || user.citizenId || user.citizen_id || '',
        isOwner: user.isOwner === true,
        globalPermissions: Array.isArray(user.globalPermissions) ? user.globalPermissions : []
      },
      orgs: Array.isArray(session.orgs) ? session.orgs.map(function (org) {
        return {
          code: org.code || org.orgCode || '',
          name: org.name || org.code || 'Organizacao',
          type: permissions.normalizeOrgType(org.type || org.orgType),
          grade: format.asNumber(org.grade, 0),
          gradeCode: org.gradeCode || org.grade_code || '',
          gradeName: org.gradeName || org.grade_name || org.gradeCode || org.grade_code || '',
          capabilities: Array.isArray(org.capabilities) ? org.capabilities : []
        };
      }).filter(function (org) { return org.code; }) : [],
      modules: Array.isArray(session.modules)
        ? session.modules
        : (session.compatibility && Array.isArray(session.compatibility.modules) ? session.compatibility.modules : [])
    };
  }

  function getSession() {
    return window.MZOrgState.state.session;
  }

  function firstOrgByType(type) {
    return window.MZOrgPermissions.orgsByType(type, getSession())[0] || null;
  }

  window.MZOrgSessionService = {
    normalizeSession: normalizeSession,
    getSession: getSession,
    firstOrgByType: firstOrgByType,
    firstLegalOrg: function () { return firstOrgByType('legal'); },
    firstGangOrg: function () { return firstOrgByType('gang'); },
    firstBusinessOrg: function () { return firstOrgByType('business'); },
    firstGovernmentOrg: function () { return firstOrgByType('government'); },
    firstVipOrg: function () { return firstOrgByType('vip'); }
  };
}());
