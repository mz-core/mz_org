(function () {
  'use strict';

  var sessionTimer = null;
  var requestSequence = 0;

  function current() {
    return window.MZOrgState.state;
  }

  function inFiveM() {
    return typeof window.GetParentResourceName === 'function';
  }

  function resourceName() {
    return inFiveM() ? window.GetParentResourceName() : 'mz_org';
  }

  function activeContextKey() {
    var state = current();
    if (state.activePanel === 'staff') {
      return state.activeOrgCode ? 'staff:org:' + state.activeOrgCode : 'staff';
    }
    return state.activeOrgCode ? 'org:' + state.activeOrgCode : (state.activePanel || 'hub');
  }

  function contextualRequest(eventName, payload) {
    if (eventName === 'session:get' || eventName === 'close') return null;
    var state = current();
    var session = state.session || {};
    requestSequence += 1;
    if (requestSequence > 999999) requestSequence = 1;
    return {
      version: 2,
      requestId: 'nui-' + requestSequence,
      sessionRevision: session.revision || session.sessionId || null,
      contextKey: activeContextKey(),
      payload: payload || {}
    };
  }

  function responseIsCurrent(envelope) {
    if (!envelope) return true;
    var state = current();
    var session = state.session || {};
    return state.isOpen === true
      && envelope.sessionRevision === (session.revision || session.sessionId || null)
      && envelope.contextKey === activeContextKey();
  }

  function fetchNui(eventName, payload) {
    if (!inFiveM()) return mockNui(eventName, payload || {});

    var envelope = contextualRequest(eventName, payload || {});

    return fetch('https://' + resourceName() + '/' + eventName, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(envelope || payload || {})
    }).then(function (response) {
      return response.json();
    }).then(function (response) {
      if (!responseIsCurrent(envelope)) {
        return { ok: false, error: 'stale_context', stale: true };
      }
      return response;
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

    var requestedEntry = panelMode === 'staff' ? 'staff' : (panelMode === 'hub' ? 'hub' : 'organization');
    var requestedType = panelMode === 'illegal' ? 'gang' : panelMode;
    fetchNui('session:get', {
      requestedEntry: requestedEntry,
      requestedType: requestedEntry === 'organization' ? requestedType : null,
      command: panelMode || 'hub'
    }).then(function (response) {
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
          user: { source: 1, name: 'Dev User', citizenid: 'DEV12345', isOwner: true, globalPermissions: ['group.mz_owner', 'staff.orgs.set_leader', 'staff.orgs.create'] },
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
    if (eventName === 'orgs:createFromTemplate') return Promise.resolve({ ok: true, data: { org: { code: payload.code, name: payload.name, type: payload.type }, template: payload.type } });
    if (eventName === 'orgs:updateBasic') return Promise.resolve({ ok: true, data: { org: { code: payload.orgCode, name: payload.name, status: payload.status, active: payload.status !== 'inactive', is_public: payload.status === 'public', hasSalary: payload.hasSalary, hasSharedAccount: payload.hasSharedAccount, hasStorage: payload.hasStorage } } });
    if (eventName === 'orgs:createGrade') return Promise.resolve({ ok: true, data: { grade: { code: payload.code, name: payload.name, level: payload.level, salary: payload.salary, priority: payload.priority, inheritsLevel: payload.inheritsLevel, active: true } } });
    if (eventName === 'orgs:updateGradeBasic') return Promise.resolve({ ok: true, data: { grade: { id: payload.gradeId, name: payload.name, level: payload.level, salary: payload.salary, priority: payload.priority, inheritsLevel: payload.inheritsLevel, active: true } } });
    if (eventName === 'orgs:archive') return Promise.resolve({ ok: true, data: { org: { code: payload.orgCode, active: false, status: 'inactive' } } });
    if (eventName === 'orgs:reactivate') return Promise.resolve({ ok: true, data: { org: { code: payload.orgCode, active: true, status: 'private' } } });
    if (eventName === 'orgs:disableGrade') return Promise.resolve({ ok: true, data: { grade: { id: payload.gradeId, active: false } } });
    if (eventName === 'orgs:reactivateGrade') return Promise.resolve({ ok: true, data: { grade: { id: payload.gradeId, active: true } } });
    if (eventName === 'orgs:addGradePermission') return Promise.resolve({ ok: true, data: { gradeId: payload.gradeId, permission: payload.permission } });
    if (eventName === 'orgs:removeGradePermission') return Promise.resolve({ ok: true, data: { gradeId: payload.gradeId, permission: payload.permission } });
    if (eventName === 'members:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'members:invite') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, targetCitizenId: payload.citizenid, grade: payload.gradeLevel || 1, gradeCode: payload.gradeCode || 'recruta' } });
    if (eventName === 'members:remove') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, targetCitizenId: payload.citizenid, removed: true } });
    if (eventName === 'members:promote') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, targetCitizenId: payload.citizenid, action: 'promote', oldGrade: 1, newGrade: 2 } });
    if (eventName === 'members:demote') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, targetCitizenId: payload.citizenid, action: 'demote', oldGrade: 2, newGrade: 1 } });
    if (eventName === 'members:setLeader') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, orgName: payload.orgCode, targetCitizenId: payload.citizenid, gradeLevel: 4, gradeCode: 'lider', gradeName: 'Lider' } });
    if (eventName === 'logs:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'org-bank:get') return Promise.resolve({ ok: true, data: { orgCode: 'police', balance: 0, currency: 'R$' } });
    if (eventName === 'org-bank:transactions') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'org-bank:deposit') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, balance: Number(payload.amount) || 0, currency: 'R$' } });
    if (eventName === 'org-bank:withdraw') return Promise.resolve({ ok: true, data: { orgCode: payload.orgCode, balance: 0, currency: 'R$' } });
    if (eventName === 'recruitment:list') return Promise.resolve({ ok: true, data: [
      { id: 1, orgCode: payload.orgCode || 'police', candidateName: 'Candidato Dev', candidateCitizenId: 'DEV99881', status: 'pending', desiredGradeLevel: 1, note: 'Triagem inicial', createdAt: new Date().toISOString() }
    ] });
    if (eventName === 'recruitment:get') return Promise.resolve({ ok: true, data: {} });
    if (eventName === 'recruitment:create') return Promise.resolve({ ok: true, data: { id: Date.now(), orgCode: payload.orgCode, candidateCitizenId: payload.citizenid, status: 'pending', desiredGradeLevel: payload.desiredGradeLevel || null, note: payload.note || '', createdAt: new Date().toISOString() } });
    if (eventName === 'recruitment:approve') return Promise.resolve({ ok: true, data: { recruitment: { id: payload.id, status: 'approved' } } });
    if (eventName === 'recruitment:reject') return Promise.resolve({ ok: true, data: { id: payload.id, status: 'rejected' } });
    if (eventName === 'recruitment:cancel') return Promise.resolve({ ok: true, data: { id: payload.id, status: 'cancelled' } });
    if (eventName === 'goals:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'goals:get') return Promise.resolve({ ok: true, data: {} });
    if (eventName === 'goals:create') return Promise.resolve({ ok: true, data: { id: Date.now(), orgCode: payload.orgCode, title: payload.title, type: payload.type || 'manual', status: 'active', target: payload.target || 1, progress: 0, progressPercent: 0 } });
    if (eventName === 'org-access:get') return Promise.resolve({ ok: true, data: { orgCode: 'police', orgName: 'Policia', type: 'legal', baseCapabilities: ['org.view'], grades: [
      { id: 1, level: 1, code: 'recruta', name: 'Recruta', salary: 0, priority: 1, active: true, capabilities: ['org.view'], directCapabilities: ['org.view'] },
      { id: 2, level: 2, code: 'membro', name: 'Membro', salary: 0, priority: 2, active: true, capabilities: ['org.view', 'members.invite'], directCapabilities: ['members.invite'] },
      { id: 3, level: 3, code: 'lider', name: 'Lider', salary: 0, priority: 3, active: true, capabilities: ['org.view', 'members.invite', 'manage.members'], directCapabilities: ['manage.members'] }
    ] } });
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
