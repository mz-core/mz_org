(function () {
  'use strict';

  function state() {
    return window.MZOrgState.state;
  }

  function getPanels() {
    return window.MZOrgPanels || window.MZ_PANEL_DEFINITIONS || {};
  }

  function getPanel(panelId) {
    return getPanels()[panelId] || window.MZOrgState.panelFallback;
  }

  function panelModules(panelId) {
    var panel = getPanel(panelId || state().activePanel);
    return Array.isArray(panel.modules) ? panel.modules : [];
  }

  function normalizeOrgType(value) {
    value = String(value || '').toLowerCase();
    if (value === 'job') return 'legal';
    if (value === 'illegal') return 'gang';
    return value || 'legal';
  }

  function isOwner(session) {
    session = session || state().session;
    return !!(session && session.user && session.user.isOwner);
  }

  function hasGlobalPermission(session, permission) {
    if (typeof session === 'string') {
      permission = session;
      session = state().session;
    }
    if (!session) return false;
    if (isOwner(session)) return true;
    return Array.isArray(session.user && session.user.globalPermissions) && session.user.globalPermissions.indexOf(permission) !== -1;
  }

  function hasModule(session, moduleId) {
    if (typeof session === 'string') {
      moduleId = session;
      session = state().session;
    }
    if (!session) return false;
    if (isOwner(session)) return true;
    return Array.isArray(session.modules) && session.modules.indexOf(moduleId) !== -1;
  }

  function moduleType(moduleId) {
    if (moduleId === 'legal') return 'legal';
    if (moduleId === 'gang') return 'gang';
    if (moduleId === 'vip') return 'vip';
    if (moduleId === 'business') return 'business';
    if (moduleId === 'government') return 'government';
    if (moduleId === 'event') return 'event';
    return null;
  }

  function orgsByType(type, session) {
    session = session || state().session;
    if (!session || !Array.isArray(session.orgs)) return [];
    return session.orgs.filter(function (org) { return normalizeOrgType(org.type) === type; });
  }

  function hasOrgType(session, type) {
    if (typeof session === 'string') {
      type = session;
      session = state().session;
    }
    return orgsByType(type, session).length > 0;
  }

  function canViewModule(session, moduleId) {
    if (typeof session === 'string') {
      moduleId = session;
      session = state().session;
    }
    if (!session) return false;
    if (isOwner(session)) return true;
    if (hasModule(session, moduleId)) return true;

    var type = moduleType(moduleId);
    if (type && hasOrgType(session, type)) return true;

    return false;
  }

  function visibleModules(panelId) {
    var current = state();
    var modules = [];
    panelModules(panelId || current.activePanel).forEach(function (id) {
      var module = window.MZOrgState.moduleById[id];
      if (module && canViewModule(current.session, id)) modules.push(module);
    });

    if (!modules.length && canViewModule(current.session, 'dashboard')) {
      modules.push(window.MZOrgState.moduleById.dashboard);
    }

    return modules;
  }

  function canOpenPanel(session, panelId) {
    if (typeof session === 'string') {
      panelId = session;
      session = state().session;
    }
    return visibleModules(panelId).some(function (module) {
      return canViewModule(session, module.id);
    });
  }

  function isStaffAccess(session) {
    session = session || state().session;
    return canViewModule(session, 'staff')
      || hasGlobalPermission(session, 'staff.panel.open')
      || hasGlobalPermission(session, 'staff.orgs.view')
      || hasGlobalPermission(session, 'staff.orgs.manage')
      || hasGlobalPermission(session, 'staff.orgs.create')
      || hasGlobalPermission(session, 'staff.orgs.set_leader')
      || hasGlobalPermission(session, 'staff.logs.view');
  }

  function getAccessLabel(session) {
    session = session || state().session;
    if (!session) return 'PLAYER';
    if (isOwner(session)) return 'OWNER';
    if (isStaffAccess(session)) return 'STAFF';
    if (session.orgs && session.orgs.length) return 'ORG USER';
    return 'PLAYER';
  }

  function getAccessVariant(session) {
    var label = getAccessLabel(session);
    if (label === 'OWNER') return 'owner';
    if (label === 'STAFF') return 'info';
    if (label === 'ORG USER') return 'success';
    return 'muted';
  }

  function contextOrgsForActiveModule() {
    var current = state();
    var type = moduleType(current.activeModule);
    if (type) return orgsByType(type, current.session);

    var panel = getPanel(current.activePanel);
    if (current.session && Array.isArray(panel.orgTypes) && panel.orgTypes.length) {
      return current.session.orgs.filter(function (org) {
        return panel.orgTypes.indexOf(normalizeOrgType(org.type)) !== -1;
      });
    }

    return current.session && Array.isArray(current.session.orgs) ? current.session.orgs : [];
  }

  window.MZOrgPermissions = {
    getPanel: getPanel,
    panelModules: panelModules,
    normalizeOrgType: normalizeOrgType,
    isOwner: isOwner,
    hasGlobalPermission: hasGlobalPermission,
    hasModule: hasModule,
    hasModuleInSession: hasModule,
    hasOrgType: hasOrgType,
    moduleType: moduleType,
    orgsByType: orgsByType,
    canOpenPanel: canOpenPanel,
    canViewPanel: canOpenPanel,
    canUseModule: canViewModule,
    canViewModule: canViewModule,
    visibleModules: visibleModules,
    isStaffAccess: isStaffAccess,
    getAccessLabel: getAccessLabel,
    getAccessVariant: getAccessVariant,
    contextOrgsForActiveModule: contextOrgsForActiveModule
  };
}());
