(function () {
  'use strict';

  var sessionTimer = null;

  function current() {
    return window.MZOrgState.state;
  }

  function inFiveM() {
    return typeof window.GetParentResourceName === 'function';
  }

  function resourceName() {
    return inFiveM() ? window.GetParentResourceName() : 'mz_org';
  }

  function fetchNui(eventName, payload) {
    if (!inFiveM()) return mockNui(eventName, payload || {});

    return fetch('https://' + resourceName() + '/' + eventName, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload || {})
    }).then(function (response) {
      return response.json();
    }).catch(function () {
      return { ok: false, error: 'Falha ao comunicar com a NUI.' };
    });
  }

  function callNuiData(eventName, payload) {
    return fetchNui(eventName, payload || {}).then(function (response) {
      if (response && response.ok) return response.data;
      throw new Error((response && response.error) || 'Nao foi possivel carregar dados.');
    });
  }

  function openPanel(initialModule, panelMode) {
    var state = current();
    var permissions = window.MZOrgPermissions;
    var panel = permissions.getPanel(panelMode || 'hub');

    state.isOpen = true;
    state.loadingSession = true;
    state.sessionError = null;
    state.requestedPanel = panelMode || 'hub';
    state.activePanel = panelMode || 'hub';
    state.activeShell = panelMode || 'hub';
    state.activeOrgCode = null;
    state.activeOrgType = null;
    state.activeSection = 'overview';
    state.currentContext = state.activePanel;
    state.requestedInitialModule = initialModule || panel.initialModule || 'dashboard';
    state.activeModule = 'dashboard';
    state.session = null;

    window.MZOrgRouter.render();

    fetchNui('session:get').then(function (response) {
      if (response && response.ok === false) {
        state.loadingSession = false;
        state.sessionError = response.error || 'Nao foi possivel solicitar sessao.';
        window.MZOrgRouter.render();
      }
    });

    window.clearTimeout(sessionTimer);
    sessionTimer = window.setTimeout(function () {
      if (state.isOpen && state.loadingSession) {
        state.loadingSession = false;
        state.sessionError = 'A sessao nao chegou do servidor.';
        window.MZOrgRouter.render();
      }
    }, 8000);
  }

  function closePanel() {
    current().isOpen = false;
    window.MZOrgRouter.render();
    fetchNui('close');
  }

  function receiveSession(session) {
    var state = current();
    window.clearTimeout(sessionTimer);
    state.session = window.MZOrgSessionService.normalizeSession(session);
    state.loadingSession = false;
    state.sessionError = null;
    window.MZOrgRouter.applyInitialModule();
    window.MZOrgRouter.render();
    window.MZOrgRouter.loadActiveModule();
  }

  function init() {
    window.addEventListener('message', function (event) {
      var data = event.data || {};
      var payload = data.payload || {};

      if (data.action === 'open') openPanel(payload.initialModule, payload.mode || payload.panelMode || 'hub');
      if (data.action === 'close') {
        current().isOpen = false;
        window.MZOrgRouter.render();
      }
      if (data.action === 'session:set') receiveSession(payload);
    });

    window.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && current().isOpen) closePanel();
    });

    window.MZOrgRouter.render();
  }

  function mockNui(eventName, payload) {
    payload = payload || {};
    if (eventName === 'session:get') {
      window.setTimeout(function () {
        receiveSession({
          user: { source: 1, name: 'Dev User', isOwner: true, globalPermissions: ['group.mz_owner'] },
          orgs: [
            { code: 'police', name: 'Policia', type: 'legal', grade: 3, gradeCode: 'sargento', gradeName: 'Sargento', capabilities: ['org.view', 'account.view', 'logs.view', 'goals.manage'] },
            { code: 'mafia', name: 'Mafia', type: 'gang', grade: 4, gradeCode: 'lider', gradeName: 'Lider', capabilities: ['org.view', 'account.view', 'logs.view'] }
          ],
          modules: ['dashboard', 'legal', 'gang', 'staff', 'vip', 'business', 'government', 'event', 'orgs', 'recruitment', 'goals', 'logs', 'settings']
        });
      }, 250);
      return Promise.resolve({ ok: true });
    }

    if (eventName === 'orgs:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'orgs:get') return Promise.resolve({ ok: true, data: {} });
    if (eventName === 'members:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'members:invite') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, targetSource: payload.targetId, grade: payload.gradeLevel || 1, gradeCode: payload.gradeCode || 'recruta' } });
    if (eventName === 'members:remove') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, targetCitizenId: payload.citizenid, removed: true } });
    if (eventName === 'members:promote') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, targetCitizenId: payload.citizenid, action: 'promote', oldGrade: 1, newGrade: 2 } });
    if (eventName === 'members:demote') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, targetCitizenId: payload.citizenid, action: 'demote', oldGrade: 2, newGrade: 1 } });
    if (eventName === 'logs:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'org-bank:get') return Promise.resolve({ ok: true, data: { orgCode: 'police', balance: 0, currency: 'R$' } });
    if (eventName === 'org-bank:transactions') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'org-bank:deposit') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, balance: Number(payload.amount) || 0, currency: 'R$' } });
    if (eventName === 'org-bank:withdraw') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, balance: 0, currency: 'R$' } });
    if (eventName === 'recruitment:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'recruitment:get') return Promise.resolve({ ok: true, data: {} });
    if (eventName === 'goals:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'goals:get') return Promise.resolve({ ok: true, data: {} });
    if (eventName === 'goals:create') return Promise.resolve({ ok: true, data: { id: Date.now(), orgCode: payload.orgCode, title: payload.title, type: payload.type || 'manual', status: 'active', target: payload.target || 1, progress: 0, progressPercent: 0 } });
    if (eventName === 'org-access:get') return Promise.resolve({ ok: true, data: { orgCode: 'police', orgName: 'Policia', type: 'legal', baseCapabilities: ['org.view'], grades: [
      { level: 1, code: 'recruta', name: 'Recruta', salary: 0, capabilities: ['org.view'] },
      { level: 2, code: 'membro', name: 'Membro', salary: 0, capabilities: ['org.view', 'members.invite'] },
      { level: 3, code: 'lider', name: 'Lider', salary: 0, capabilities: ['org.view', 'members.invite', 'manage.members'] }
    ], playerOverrides: [] } });
    return Promise.resolve({ ok: true });
  }

  window.MZOrgNui = {
    init: init,
    inFiveM: inFiveM,
    resourceName: resourceName,
    fetchNui: fetchNui,
    callNuiData: callNuiData,
    openPanel: openPanel,
    closePanel: closePanel,
    receiveSession: receiveSession
  };
}());
