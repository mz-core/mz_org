(function () {
  'use strict';

  var PANEL_DEFINITIONS = window.MZ_PANEL_DEFINITIONS || {};

  var MODULES = [
    { id: 'dashboard', label: 'Dashboard', icon: 'assets/icons/dashboard.svg', fallback: 'D', description: 'Resumo do acesso atual.' },
    { id: 'legal', label: 'Organização', icon: 'assets/icons/legal.svg', fallback: 'O', description: 'Painel legal da sua org.' },
    { id: 'gang', label: 'Gang', icon: 'assets/icons/gang.svg', fallback: 'G', description: 'Painel ilegal privado.' },
    { id: 'staff', label: 'Staff', icon: 'assets/icons/staff.svg', fallback: 'S', description: 'Área administrativa.' },
    { id: 'vip', label: 'VIP', icon: 'assets/icons/vip.svg', fallback: 'V', description: 'Benefícios e vínculo VIP.' },
    { id: 'business', label: 'Empresa', icon: 'assets/icons/business.svg', fallback: 'B', description: 'Painel de empresas.' },
    { id: 'government', label: 'Governo', icon: 'assets/icons/government.svg', fallback: 'P', description: 'Prefeitura e governo.' },
    { id: 'event', label: 'Eventos', icon: 'assets/icons/event.svg', fallback: 'E', description: 'Painel de eventos.' },
    { id: 'orgs', label: 'Organizações', icon: 'assets/icons/orgs.svg', fallback: 'L', description: 'Consulta administrativa.' },
    { id: 'recruitment', label: 'Recrutamento', icon: 'assets/icons/recruitment.svg', fallback: 'R', description: 'Candidaturas e triagem.' },
    { id: 'goals', label: 'Metas', icon: 'assets/icons/goals.svg', fallback: 'M', description: 'Metas da organização.' },
    { id: 'logs', label: 'Logs', icon: 'assets/icons/logs.svg', fallback: 'A', description: 'Auditoria read-only.' },
    { id: 'settings', label: 'Configurações', icon: 'assets/icons/settings.svg', fallback: 'C', description: 'Configurações futuras.' }
  ];

  var MODULE_BY_ID = MODULES.reduce(function (acc, item) {
    acc[item.id] = item;
    return acc;
  }, {});

  var PANEL_FALLBACK = {
    id: 'hub',
    title: 'Painel Geral',
    subtitle: 'Entrada contextual para os módulos liberados.',
    initialModule: 'dashboard',
    modules: ['dashboard']
  };

  var state = {
    isOpen: false,
    loadingSession: false,
    sessionError: null,
    requestedPanel: 'hub',
    requestedInitialModule: 'dashboard',
    activePanel: 'hub',
    activeModule: 'dashboard',
    session: null,
    orgs: { loading: false, loaded: false, error: null, data: [] },
    orgView: {
      selectedByPanel: {},
      detailLoading: false,
      membersLoading: false,
      bankLoading: false,
      transactionsLoading: false,
      detailError: null,
      membersError: null,
      bankError: null,
      transactionsError: null,
      detail: null,
      members: [],
      bank: null,
      transactions: [],
      loadedKey: ''
    },
    logs: { loading: false, loaded: false, error: null, data: [], filters: { category: 'all', severity: 'all', org: 'all', search: '' } },
    sidebarCollapsed: false
  };

  var app = document.getElementById('app');

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
      throw new Error((response && response.error) || 'Não foi possível carregar dados.');
    });
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function text(value, fallback) {
    if (value === null || value === undefined || value === '') return escapeHtml(fallback || '—');
    return escapeHtml(value);
  }

  function asNumber(value, fallback) {
    var number = Number(value);
    return Number.isFinite(number) ? number : (fallback || 0);
  }

  function formatMoney(value, currency) {
    var amount = asNumber(value, 0);
    try {
      return amount.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
    } catch (error) {
      return (currency || 'R$') + ' ' + amount.toFixed(2).replace('.', ',');
    }
  }

  function formatDate(value) {
    if (!value) return '—';
    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return escapeHtml(value);
    return date.toLocaleString('pt-BR');
  }

  function badge(label, variant) {
    return '<span class="badge ' + escapeHtml(variant || 'muted') + '"><span>' + text(label) + '</span></span>';
  }

  function card(title, description, body, className) {
    return '<section class="card ' + escapeHtml(className || '') + '">' +
      (title ? '<div class="card-header"><h3 class="card-title">' + text(title) + '</h3>' + (description ? '<p class="card-desc">' + text(description) + '</p>' : '') + '</div>' : '') +
      '<div class="card-body">' + (body || '') + '</div>' +
    '</section>';
  }

  function loading(title) {
    return '<div class="loading"><strong>' + text(title || 'Carregando') + '</strong></div>';
  }

  function empty(title, description) {
    return '<div class="empty"><strong>' + text(title || 'Nada por aqui') + '</strong><span>' + text(description || '') + '</span></div>';
  }

  function errorBox(message) {
    return '<div class="error"><strong>Erro</strong><span>' + text(message || 'Não foi possível carregar os dados.') + '</span></div>';
  }

  function getPanel(panelId) {
    return PANEL_DEFINITIONS[panelId] || PANEL_FALLBACK;
  }

  function panelModules(panelId) {
    var panel = getPanel(panelId || state.activePanel);
    return Array.isArray(panel.modules) ? panel.modules : [];
  }

  function hasModuleInSession(moduleId) {
    if (!state.session) return false;
    if (state.session.user && state.session.user.isOwner) return true;
    return Array.isArray(state.session.modules) && state.session.modules.indexOf(moduleId) !== -1;
  }

  function canViewModule(moduleId) {
    if (!state.session) return false;
    if (state.session.user && state.session.user.isOwner) return true;
    if (hasModuleInSession(moduleId)) return true;

    var type = moduleType(moduleId);
    if (type && orgsByType(type).length > 0) return true;

    return false;
  }

  function visibleModules() {
    var ids = panelModules();
    var modules = [];

    ids.forEach(function (id) {
      var module = MODULE_BY_ID[id];
      if (module && canViewModule(id)) modules.push(module);
    });

    if (!modules.length && canViewModule('dashboard')) modules.push(MODULE_BY_ID.dashboard);
    return modules;
  }

  function hasGlobalPermission(permission) {
    if (!state.session) return false;
    if (state.session.user && state.session.user.isOwner) return true;
    return Array.isArray(state.session.user.globalPermissions) && state.session.user.globalPermissions.indexOf(permission) !== -1;
  }

  function isStaffAccess() {
    return canViewModule('staff') || hasGlobalPermission('staff.orgs.manage') || hasGlobalPermission('staff.panel.open');
  }

  function getAccessLabel() {
    if (!state.session) return 'PLAYER';
    if (state.session.user && state.session.user.isOwner) return 'OWNER';
    if (isStaffAccess()) return 'STAFF';
    if (state.session.orgs && state.session.orgs.length) return 'ORG USER';
    return 'PLAYER';
  }

  function getAccessVariant() {
    var label = getAccessLabel();
    if (label === 'OWNER') return 'owner';
    if (label === 'STAFF') return 'info';
    if (label === 'ORG USER') return 'success';
    return 'muted';
  }

  function normalizeOrgType(value) {
    value = String(value || '').toLowerCase();
    if (value === 'job') return 'legal';
    if (value === 'illegal') return 'gang';
    return value || 'legal';
  }

  function normalizeSession(session) {
    session = session || {};
    var user = session.user || {};
    return {
      user: {
        source: user.source || 0,
        name: user.name || 'Player',
        isOwner: user.isOwner === true,
        globalPermissions: Array.isArray(user.globalPermissions) ? user.globalPermissions : []
      },
      orgs: Array.isArray(session.orgs) ? session.orgs.map(function (org) {
        return {
          code: org.code || org.orgCode || '',
          name: org.name || org.code || 'Organização',
          type: normalizeOrgType(org.type || org.orgType),
          grade: asNumber(org.grade, 0),
          gradeCode: org.gradeCode || org.grade_code || '',
          gradeName: org.gradeName || org.grade_name || org.gradeCode || org.grade_code || '',
          capabilities: Array.isArray(org.capabilities) ? org.capabilities : []
        };
      }).filter(function (org) { return org.code; }) : [],
      modules: Array.isArray(session.modules) ? session.modules : []
    };
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

  function orgsByType(type) {
    if (!state.session || !Array.isArray(state.session.orgs)) return [];
    return state.session.orgs.filter(function (org) { return normalizeOrgType(org.type) === type; });
  }

  function contextOrgsForActiveModule() {
    var type = moduleType(state.activeModule);
    if (type) return orgsByType(type);

    var panel = getPanel(state.activePanel);
    if (Array.isArray(panel.orgTypes) && panel.orgTypes.length) {
      return state.session.orgs.filter(function (org) {
        return panel.orgTypes.indexOf(normalizeOrgType(org.type)) !== -1;
      });
    }

    return state.session && Array.isArray(state.session.orgs) ? state.session.orgs : [];
  }

  function firstAllowedModule() {
    var modules = visibleModules();
    return modules.length ? modules[0].id : 'dashboard';
  }

  function applyInitialModule() {
    var requested = state.requestedInitialModule || getPanel(state.activePanel).initialModule || 'dashboard';
    state.activeModule = canViewModule(requested) ? requested : firstAllowedModule();
  }

  function openPanel(initialModule, panelMode) {
    state.isOpen = true;
    state.loadingSession = true;
    state.sessionError = null;
    state.requestedPanel = panelMode || 'hub';
    state.activePanel = panelMode || 'hub';
    state.requestedInitialModule = initialModule || getPanel(state.activePanel).initialModule || 'dashboard';
    state.activeModule = 'dashboard';
    state.session = null;
    render();

    fetchNui('session:get').then(function (response) {
      if (response && response.ok === false) {
        state.loadingSession = false;
        state.sessionError = response.error || 'Não foi possível solicitar sessão.';
        render();
      }
    });

    window.clearTimeout(openPanel.sessionTimer);
    openPanel.sessionTimer = window.setTimeout(function () {
      if (state.isOpen && state.loadingSession) {
        state.loadingSession = false;
        state.sessionError = 'A sessão não chegou do servidor.';
        render();
      }
    }, 8000);
  }

  function closePanel() {
    state.isOpen = false;
    render();
    fetchNui('close');
  }

  function receiveSession(session) {
    window.clearTimeout(openPanel.sessionTimer);
    state.session = normalizeSession(session);
    state.loadingSession = false;
    state.sessionError = null;
    applyInitialModule();
    render();
    loadActiveModule();
  }

  function setActiveModule(moduleId) {
    if (!canViewModule(moduleId)) return;
    state.activeModule = moduleId;
    render();
    loadActiveModule();
  }

  function loadActiveModule() {
    if (!state.session) return;
    if (state.activeModule === 'orgs') loadOrgs();
    if (isOrgPanelModule(state.activeModule)) loadOrgPanel();
    if (state.activeModule === 'logs') loadLogs();
  }

  function isOrgPanelModule(moduleId) {
    return ['legal', 'gang', 'vip', 'business', 'government', 'event'].indexOf(moduleId) !== -1;
  }

  function resetOrgPanelData() {
    state.orgView.detail = null;
    state.orgView.members = [];
    state.orgView.bank = null;
    state.orgView.transactions = [];
    state.orgView.detailError = null;
    state.orgView.membersError = null;
    state.orgView.bankError = null;
    state.orgView.transactionsError = null;
    state.orgView.loadedKey = '';
  }

  function selectedOrgCode() {
    var type = moduleType(state.activeModule) || 'all';
    var stored = state.orgView.selectedByPanel[type];
    var available = contextOrgsForActiveModule();

    if (stored && available.some(function (org) { return org.code === stored; })) return stored;
    return available.length ? available[0].code : '';
  }

  function loadOrgPanel() {
    var code = selectedOrgCode();
    if (!code) return;

    var key = state.activeModule + ':' + code;
    if (state.orgView.loadedKey === key && !state.orgView.detailLoading && !state.orgView.membersLoading && !state.orgView.bankLoading) return;

    state.orgView.loadedKey = key;
    state.orgView.detailLoading = true;
    state.orgView.membersLoading = true;
    state.orgView.bankLoading = true;
    state.orgView.transactionsLoading = true;
    state.orgView.detailError = null;
    state.orgView.membersError = null;
    state.orgView.bankError = null;
    state.orgView.transactionsError = null;
    render();

    callNuiData('orgs:get', { orgCode: code }).then(function (data) {
      state.orgView.detail = data || null;
    }).catch(function (err) {
      state.orgView.detailError = err.message;
    }).finally(function () {
      state.orgView.detailLoading = false;
      render();
    });

    callNuiData('members:list', { orgCode: code }).then(function (data) {
      state.orgView.members = Array.isArray(data) ? data : [];
    }).catch(function (err) {
      state.orgView.membersError = err.message;
    }).finally(function () {
      state.orgView.membersLoading = false;
      render();
    });

    callNuiData('org-bank:get', { orgCode: code }).then(function (data) {
      state.orgView.bank = data || null;
    }).catch(function (err) {
      state.orgView.bankError = err.message;
    }).finally(function () {
      state.orgView.bankLoading = false;
      render();
    });

    callNuiData('org-bank:transactions', { orgCode: code, filters: { limit: 50 } }).then(function (data) {
      state.orgView.transactions = Array.isArray(data) ? data : [];
    }).catch(function (err) {
      state.orgView.transactionsError = err.message;
    }).finally(function () {
      state.orgView.transactionsLoading = false;
      render();
    });
  }

  function loadOrgs() {
    if (state.orgs.loading || state.orgs.loaded) return;
    state.orgs.loading = true;
    state.orgs.error = null;
    render();

    callNuiData('orgs:list').then(function (items) {
      state.orgs.data = Array.isArray(items) ? items : [];
      state.orgs.loaded = true;
    }).catch(function (err) {
      state.orgs.error = err.message;
    }).finally(function () {
      state.orgs.loading = false;
      render();
    });
  }

  function loadLogs() {
    if (state.logs.loading || state.logs.loaded) return;
    state.logs.loading = true;
    state.logs.error = null;
    render();

    callNuiData('logs:list', { limit: 100 }).then(function (data) {
      state.logs.data = Array.isArray(data) ? data : [];
      state.logs.loaded = true;
    }).catch(function (err) {
      state.logs.error = err.message;
    }).finally(function () {
      state.logs.loading = false;
      render();
    });
  }

  function render() {
    if (!state.isOpen) {
      app.innerHTML = '<div class="mz-root"></div>';
      return;
    }

    app.innerHTML = '<div class="mz-root is-open">' + renderPanel() + '</div>';
    bindEvents();
  }

  function renderPanel() {
    if (state.loadingSession) {
      return '<div class="panel-shell"><main class="main full-main">' + loading('Carregando sessão') + '</main></div>';
    }

    if (state.sessionError) {
      return '<div class="panel-shell"><main class="main full-main padded-main">' + errorBox(state.sessionError) + '<button class="btn btn-primary" data-action="close">Fechar</button></main></div>';
    }

    if (!state.session) {
      return '<div class="panel-shell"><main class="main full-main">' + empty('Sem sessão', 'Abra o painel novamente.') + '</main></div>';
    }

    return '<section class="panel-shell' + (state.sidebarCollapsed ? ' sidebar-collapsed' : '') + '">' +
      renderSidebar() +
      '<main class="main">' + renderHeader() + '<div class="content">' + renderActivePage() + '</div></main>' +
    '</section>';
  }

  function renderIcon(icon, fallback, className) {
    var fallbackText = escapeHtml(fallback || '?');
    return '<span class="' + escapeHtml(className || 'nav-icon-box') + '" aria-hidden="true">' +
      '<img class="nav-icon" src="' + escapeHtml(icon || 'assets/icons/default.svg') + '" alt="" onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'grid\';" />' +
      '<span class="nav-icon-fallback">' + fallbackText + '</span>' +
    '</span>';
  }

  function renderSidebar() {
    var panel = getPanel(state.activePanel);
    var modules = visibleModules();
    var nav = modules.map(function (module) {
      var active = module.id === state.activeModule ? ' is-active' : '';
      return '<button class="nav-item' + active + '" data-module="' + escapeHtml(module.id) + '" title="' + text(module.label) + '">' +
        renderIcon(module.icon, module.fallback, 'nav-icon-box') +
        '<span class="nav-text"><span class="nav-label">' + text(module.label) + '</span><span class="nav-desc">' + text(module.description) + '</span></span>' +
      '</button>';
    }).join('');

    return '<aside class="sidebar">' +
      '<div class="brand">' +
        '<div class="brand-top">' +
          '<div class="brand-title"><span class="brand-mark">MZ</span><span class="brand-name">' + text(panel.title || 'MZ Org') + '</span></div>' +
          '<button class="sidebar-toggle" data-action="toggle-sidebar" title="Recolher menu" aria-label="Recolher menu">' + (state.sidebarCollapsed ? '›' : '‹') + '</button>' +
        '</div>' +
        '<div class="brand-subtitle">' + text(panel.subtitle || 'Módulos integrados ao mz_core.') + '</div>' +
      '</div>' +
      '<nav class="nav-list">' + nav + '</nav>' +
      '<div class="sidebar-footer"><div class="session-mini"><strong class="truncate">' + text(state.session.user.name) + '</strong><span>' + text(modules.length) + ' módulos neste painel</span><div class="session-badge">' + badge(getAccessLabel(), getAccessVariant()) + '</div></div></div>' +
    '</aside>';
  }

  function renderHeader() {
    var panel = getPanel(state.activePanel);
    var module = MODULE_BY_ID[state.activeModule] || MODULE_BY_ID.dashboard;
    return '<header class="header">' +
      '<div class="header-left"><div class="header-title"><span class="header-kicker">' + text(panel.title || 'Painel') + '</span><h1 class="truncate">' + text(module.label) + '</h1><p class="truncate">' + text(module.description || panel.subtitle || 'Painel operacional do mz_core.') + '</p></div></div>' +
      '<div class="header-right">' +
        '<div class="user-info"><span class="user-avatar">' + text((state.session.user.name || 'P').slice(0, 1).toUpperCase()) + '</span><div class="user-meta"><strong class="truncate">' + text(state.session.user.name) + '</strong><span class="truncate">ID ' + text(state.session.user.source) + ' · ' + text(state.session.orgs.length) + ' org(s)</span></div></div>' +
        badge(getAccessLabel(), getAccessVariant()) +
        '<button class="btn btn-ghost close-btn" data-action="close">Fechar</button>' +
      '</div>' +
    '</header>';
  }

  function renderActivePage() {
    if (state.activeModule === 'dashboard') return renderDashboard();
    if (state.activeModule === 'orgs') return renderOrgsPage();
    if (isOrgPanelModule(state.activeModule)) return renderOrgPanelPage();
    if (state.activeModule === 'staff') return renderStaffPage();
    if (state.activeModule === 'logs') return renderLogsPage();
    if (state.activeModule === 'recruitment') return renderPlaceholder('Recrutamento', 'Triagem e candidaturas serão integradas depois.', 'assets/icons/recruitment.svg', 'R');
    if (state.activeModule === 'goals') return renderPlaceholder('Metas', 'Metas reais ainda serão integradas de forma segura.', 'assets/icons/goals.svg', 'M');
    if (state.activeModule === 'settings') return renderPlaceholder('Configurações', 'Configurações globais ficarão restritas ao owner.', 'assets/icons/settings.svg', 'C');
    return renderDashboard();
  }

  function metricCard(icon, value, label, fallback) {
    return '<div class="metric-card">' + renderIcon(icon, fallback || '•', 'metric-icon') + '<strong>' + text(value) + '</strong><span>' + text(label) + '</span></div>';
  }

  function renderDashboard() {
    var modules = visibleModules();
    var orgs = state.session.orgs || [];
    var panel = getPanel(state.activePanel);
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Visão geral</span><h2>' + text(panel.title || 'Central da sessão') + '</h2><p>Dados read-only filtrados pelo servidor e pelo painel atual.</p></div>' + badge(getAccessLabel(), getAccessVariant()) + '</div>' +
      '<div class="metric-grid">' +
        metricCard('assets/icons/dashboard.svg', modules.length, 'Módulos visíveis', 'D') +
        metricCard('assets/icons/orgs.svg', orgs.length, 'Orgs vinculadas', 'O') +
        metricCard('assets/icons/shield.svg', getAccessLabel(), 'Status da sessão', 'S') +
      '</div>' +
      '<div class="two-col">' +
        card('Módulos deste painel', 'Somente o que esta sessão pode abrir.', '<div class="badge-row">' + modules.map(function (module) { return badge(module.label, 'info'); }).join('') + '</div>') +
        card('Contexto vinculado', 'Resumo das organizações retornadas pelo core.', orgs.length ? orgs.map(function (org) { return '<div class="mini-row"><strong>' + text(org.name) + '</strong><span>' + text(org.code) + ' / ' + text(org.gradeCode || org.grade) + '</span></div>'; }).join('') : empty('Sem org vinculada', 'Use um painel permitido ou aguarde vínculo no core.')) +
      '</div>' +
    '</div>';
  }

  function renderOrgsPage() {
    var body = state.orgs.loading ? loading('Carregando organizações') : state.orgs.error ? errorBox(state.orgs.error) : !state.orgs.data.length ? empty('Nenhuma organização visível', 'O servidor não retornou orgs para esta sessão.') : renderOrgTable(state.orgs.data);
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Consulta segura</span><h2>Organizações visíveis</h2><p>Lista read-only filtrada pelo servidor para a sessão atual.</p></div>' + badge((state.orgs.data || []).length + ' encontradas', 'info') + '</div>' +
      card('Organizações', 'Dados administrativos sem ações de escrita.', body) +
    '</div>';
  }

  function renderOrgTable(items) {
    return '<div class="table-scroll"><table><thead><tr><th>Nome</th><th>Code</th><th>Tipo</th><th>Cargo</th><th>Status</th></tr></thead><tbody>' + items.map(function (org) {
      return '<tr><td class="cell-strong">' + text(org.name || org.code) + '</td><td>' + text(org.code) + '</td><td>' + badge(org.type || 'legal', org.type === 'gang' ? 'danger' : 'info') + '</td><td>' + text(org.gradeName || org.gradeCode || org.playerRole || org.grade) + '</td><td>' + badge(org.is_public ? 'pública' : 'privada', org.is_public ? 'success' : 'muted') + '</td></tr>';
    }).join('') + '</tbody></table></div>';
  }

  function renderOrgPanelPage() {
    var module = MODULE_BY_ID[state.activeModule] || MODULE_BY_ID.legal;
    var available = contextOrgsForActiveModule();
    var code = selectedOrgCode();
    var contextOrg = available.filter(function (org) { return org.code === code; })[0] || null;

    if (!available.length) {
      return '<div class="screen">' +
        '<div class="page-heading"><div><span class="module-kicker">Sem vínculo</span><h2>' + text(module.label) + '</h2><p>O core não retornou uma organização compatível para este painel.</p></div>' + badge('sem acesso', 'warning') + '</div>' +
        empty('Nenhuma organização encontrada', 'Este comando abre apenas o painel do tipo correspondente ao seu vínculo.') +
      '</div>';
    }

    if (code && state.orgView.loadedKey !== state.activeModule + ':' + code && !state.orgView.detailLoading) {
      window.setTimeout(loadOrgPanel, 0);
    }

    var selector = available.length > 1 ? renderOrgSelector(available, code) : '';
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">' + text(module.label) + '</span><h2>' + text(contextOrg && contextOrg.name || module.label) + '</h2><p>Leitura limitada aos dados permitidos pelo servidor.</p></div>' + badge(text(contextOrg && contextOrg.code || code), 'info') + '</div>' +
      selector +
      '<div class="two-col">' + renderOrgSummary(contextOrg) + renderOrgAccess(contextOrg) + '</div>' +
      renderCapabilities(contextOrg) +
      '<div class="two-col">' + renderBankCard() + renderTransactionsCard() + '</div>' +
      renderMembersCard() +
    '</div>';
  }

  function renderOrgSelector(orgs, selected) {
    return '<label class="org-selector"><span>Selecionar contexto</span><select data-action="select-org">' + orgs.map(function (org) {
      return '<option value="' + text(org.code) + '" ' + (org.code === selected ? 'selected' : '') + '>' + text(org.name) + ' · ' + text(org.gradeCode || org.grade) + '</option>';
    }).join('') + '</select></label>';
  }

  function renderOrgSummary(contextOrg) {
    if (state.orgView.detailLoading) return card('Resumo da organização', 'Dados retornados pelo servidor.', loading('Carregando org'));
    if (state.orgView.detailError) return card('Resumo da organização', 'Dados retornados pelo servidor.', errorBox(state.orgView.detailError));
    var detail = state.orgView.detail || {};
    var org = detail.code ? detail : (contextOrg || {});
    return card('Resumo da organização', 'Dados retornados pelo servidor para a org selecionada.', '<div class="detail-grid"><span>Nome</span><strong>' + text(org.name) + '</strong><span>Código</span><strong>' + text(org.code) + '</strong><span>Tipo</span><strong>' + text(org.type) + '</strong><span>Status</span><strong>' + text(org.is_public ? 'Pública' : 'Privada') + '</strong></div>' + '<div class="badge-row">' + badge('read-only', 'info') + '</div>');
  }

  function renderOrgAccess(org) {
    org = org || {};
    return card('Meu acesso', 'Cargo e contexto retornados pela sessão.', '<div class="detail-grid"><span>Grade</span><strong>' + text(org.grade) + '</strong><span>Código do cargo</span><strong>' + text(org.gradeCode) + '</strong><span>Nome do cargo</span><strong>' + text(org.gradeName) + '</strong><span>Capabilities</span><strong>' + text((org.capabilities || []).length) + '</strong></div>');
  }

  function renderCapabilities(contextOrg) {
    var detail = state.orgView.detail || {};
    var caps = Array.isArray(detail.capabilities) && detail.capabilities.length ? detail.capabilities : (contextOrg && contextOrg.capabilities || []);
    return card('Capabilities', 'Permissões visuais retornadas pelo contexto/detalhe. Ações futuras ainda validarão no server.', caps.length ? '<div class="badge-row">' + caps.map(function (cap) { return badge(cap, cap === 'org.view' ? 'success' : 'muted'); }).join('') + '</div>' : empty('Sem capabilities retornadas', 'Nenhuma permissão crítica foi inventada no frontend.'));
  }

  function renderBankCard() {
    if (state.orgView.bankLoading) return card('Banco da organização', 'Consulta read-only.', loading('Carregando saldo'));
    if (state.orgView.bankError) return card('Banco da organização', 'Consulta read-only.', errorBox(state.orgView.bankError));
    var bank = state.orgView.bank || {};
    return card('Banco da organização', 'Consulta read-only.', '<div class="bank-balance"><span>Saldo atual</span><strong>' + formatMoney(bank.balance, bank.currency) + '</strong></div><div class="badge-row">' + badge('read-only', 'info') + badge('sem ações financeiras', 'warning') + '</div>');
  }

  function renderTransactionsCard() {
    if (state.orgView.transactionsLoading) return card('Extrato', 'Histórico financeiro read-only.', loading('Carregando extrato'));
    if (state.orgView.transactionsError) return card('Extrato', 'Histórico financeiro read-only.', errorBox(state.orgView.transactionsError));
    var items = state.orgView.transactions || [];
    if (!items.length) return card('Extrato', 'Histórico financeiro read-only.', empty('Extrato ainda indisponível', 'Não existe fonte real de transações dedicada nesta etapa.'));
    return card('Extrato', 'Histórico financeiro read-only.', '<div class="table-scroll transactions-scroll"><table><thead><tr><th>Data</th><th>Tipo</th><th>Valor</th><th>Motivo</th><th>Autor</th></tr></thead><tbody>' + items.map(function (tx) {
      return '<tr><td>' + formatDate(tx.createdAt) + '</td><td>' + text(tx.type) + '</td><td class="amount ' + (asNumber(tx.amount) < 0 ? 'negative' : 'positive') + '">' + formatMoney(tx.amount) + '</td><td>' + text(tx.reason) + '</td><td>' + text(tx.actorName || tx.actorCitizenId) + '</td></tr>';
    }).join('') + '</tbody></table></div>');
  }

  function renderMembersCard() {
    if (state.orgView.membersLoading) return card('Membros', 'Lista read-only.', loading('Carregando membros'));
    if (state.orgView.membersError) return card('Membros', 'Lista read-only.', errorBox(state.orgView.membersError));
    var items = state.orgView.members || [];
    if (!items.length) return card('Membros', 'Lista read-only.', empty('Nenhum membro retornado', 'A org pode estar vazia ou o backend não retornou dados.'));
    return card('Membros', 'Lista read-only retornada pelo mz_core.', '<div class="table-scroll members-scroll"><table><thead><tr><th>Nome</th><th>CitizenID</th><th>Cargo</th><th>Líder</th><th>Duty</th><th>Status</th><th>Entrada</th><th>Última atividade</th></tr></thead><tbody>' + items.map(function (member) {
      return '<tr><td class="cell-strong">' + text(member.name || member.citizenid) + '</td><td>' + text(member.citizenid) + '</td><td>' + text(member.gradeName || member.gradeCode || member.grade) + '</td><td>' + (member.isLeader ? badge('sim', 'owner') : badge('não', 'muted')) + '</td><td>' + (member.isDuty ? badge('em serviço', 'success') : badge('fora', 'muted')) + '</td><td>' + badge(member.status || 'ativo', 'info') + '</td><td>' + text(member.joinedAt) + '</td><td>' + text(member.lastSeen) + '</td></tr>';
    }).join('') + '</tbody></table></div>');
  }

  function renderStaffPage() {
    if (!canViewModule('staff')) return '<div class="screen">' + errorBox('Sem permissão para visualizar staff.') + '</div>';
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Staff</span><h2>Área administrativa</h2><p>Leitura administrativa. Ações críticas ainda não foram implementadas.</p></div>' + badge(getAccessLabel(), getAccessVariant()) + '</div>' +
      '<div class="metric-grid">' + metricCard('assets/icons/staff.svg', 'Liberado', 'Permissão staff/owner', 'S') + metricCard('assets/icons/logs.svg', canViewModule('logs') ? 'Disponível' : 'Oculto', 'Logs') + metricCard('assets/icons/lock.svg', 'Bloqueadas', 'Actions perigosas', 'B') + '</div>' +
      card('Próximas etapas', 'Tudo abaixo ainda depende de validação server-side, logs e rate limit.', '<ul class="placeholder-list"><li>Convidar membro</li><li>Promover/rebaixar</li><li>Gerenciar banco com auditoria</li><li>Configurar permissões com CanOrg</li></ul>') +
    '</div>';
  }

  function renderLogsPage() {
    var logs = filteredLogs();
    var categoryOptions = unique(state.logs.data.map(function (log) { return log.category; }));
    var severityOptions = unique(state.logs.data.map(function (log) { return log.severity; }));
    var orgOptions = unique(state.logs.data.map(function (log) { return log.orgCode; }));
    var listBody = state.logs.loading ? loading('Carregando logs') : state.logs.error ? errorBox(state.logs.error) : !logs.length ? empty('Nenhum log visível', 'Não há logs permitidos para esta sessão ou os filtros removeram todos.') : renderLogsTable(logs);

    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Auditoria</span><h2>Logs</h2><p>Consulta read-only de eventos seguros retornados pelo servidor.</p></div>' + badge(logs.length + ' visíveis', 'info') + '</div>' +
      '<div class="metric-grid">' + metricCard('assets/icons/logs.svg', state.logs.data.length, 'Total retornado', 'L') + metricCard('assets/icons/warning.svg', state.logs.data.filter(function (l) { return l.severity === 'warning' || l.severity === 'warn'; }).length, 'Warnings', 'W') + metricCard('assets/icons/alert.svg', state.logs.data.filter(function (l) { return l.severity === 'danger' || l.severity === 'error'; }).length, 'Danger/Error', 'A') + '</div>' +
      card('Filtros locais', 'Refinam somente a lista já permitida pelo servidor.', renderLogFilters(categoryOptions, severityOptions, orgOptions)) +
      card('Eventos', 'Nenhum dado sensível bruto é exibido nesta tabela.', listBody) +
    '</div>';
  }

  function unique(items) {
    var seen = {};
    return items.filter(function (item) {
      if (!item) return false;
      if (seen[item]) return false;
      seen[item] = true;
      return true;
    }).sort();
  }

  function filteredLogs() {
    var filters = state.logs.filters;
    var query = String(filters.search || '').toLowerCase().trim();
    return state.logs.data.filter(function (log) {
      if (filters.category !== 'all' && log.category !== filters.category) return false;
      if (filters.severity !== 'all' && log.severity !== filters.severity) return false;
      if (filters.org !== 'all' && log.orgCode !== filters.org) return false;
      if (!query) return true;
      return [log.category, log.action, log.orgCode, log.actorName, log.actorCitizenId, log.targetName, log.targetCitizenId, log.message, log.reason].join(' ').toLowerCase().indexOf(query) !== -1;
    });
  }

  function renderLogFilters(categories, severities, orgs) {
    return '<div class="filter-bar">' +
      selectFilter('category', 'Categoria', categories) +
      selectFilter('severity', 'Severidade', severities) +
      selectFilter('org', 'Org', orgs) +
      '<label class="search-field"><span>Busca</span><input data-log-filter="search" maxlength="80" value="' + text(state.logs.filters.search) + '" placeholder="ação, autor, org..." /></label>' +
      '<button class="btn btn-ghost" disabled title="Exportação será implementada depois">Exportar</button>' +
    '</div>';
  }

  function selectFilter(key, label, options) {
    return '<label><span>' + text(label) + '</span><select data-log-filter="' + escapeHtml(key) + '"><option value="all">Todas</option>' + options.map(function (option) {
      return '<option value="' + text(option) + '" ' + (state.logs.filters[key] === option ? 'selected' : '') + '>' + text(option) + '</option>';
    }).join('') + '</select></label>';
  }

  function renderLogsTable(logs) {
    return '<div class="table-scroll logs-scroll"><table><thead><tr><th>Data</th><th>Sev.</th><th>Categoria</th><th>Ação</th><th>Org</th><th>Autor</th><th>Alvo</th><th>Mensagem</th></tr></thead><tbody>' + logs.map(function (log) {
      return '<tr><td>' + formatDate(log.createdAt) + '</td><td>' + badge(log.severity || 'info', severityVariant(log.severity)) + '</td><td>' + text(log.category) + '</td><td class="cell-strong">' + text(log.action) + '</td><td>' + text(log.orgCode) + '</td><td>' + text(log.actorName || log.actorCitizenId) + '</td><td>' + text(log.targetName || log.targetCitizenId) + '</td><td>' + text(log.message || log.reason) + '</td></tr>';
    }).join('') + '</tbody></table></div>';
  }

  function severityVariant(severity) {
    if (severity === 'success') return 'success';
    if (severity === 'warning' || severity === 'warn') return 'warning';
    if (severity === 'danger' || severity === 'error') return 'danger';
    return 'info';
  }

  function renderPlaceholder(title, description, icon, fallback) {
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Em construção</span><h2>' + text(title) + '</h2><p>' + text(description) + '</p></div>' + badge('read-only', 'info') + '</div>' +
      card(title, 'Módulo reservado para integração futura.', '<div class="empty">' + renderIcon(icon, fallback || '•', 'empty-icon') + '<span>Nenhuma ação real foi implementada nesta etapa.</span></div>') +
    '</div>';
  }

  function bindEvents() {
    app.querySelectorAll('[data-action="close"]').forEach(function (button) { button.addEventListener('click', closePanel); });
    app.querySelectorAll('[data-module]').forEach(function (button) { button.addEventListener('click', function () { setActiveModule(button.getAttribute('data-module')); }); });

    var sidebarToggle = app.querySelector('[data-action="toggle-sidebar"]');
    if (sidebarToggle) {
      sidebarToggle.addEventListener('click', function () {
        state.sidebarCollapsed = !state.sidebarCollapsed;
        render();
      });
    }

    var orgSelect = app.querySelector('[data-action="select-org"]');
    if (orgSelect) {
      orgSelect.addEventListener('change', function (event) {
        var type = moduleType(state.activeModule) || 'all';
        state.orgView.selectedByPanel[type] = event.target.value;
        resetOrgPanelData();
        render();
        loadOrgPanel();
      });
    }

    app.querySelectorAll('[data-log-filter]').forEach(function (input) {
      input.addEventListener('input', function (event) {
        state.logs.filters[input.getAttribute('data-log-filter')] = event.target.value;
        render();
      });
      input.addEventListener('change', function (event) {
        state.logs.filters[input.getAttribute('data-log-filter')] = event.target.value;
        render();
      });
    });
  }

  window.addEventListener('message', function (event) {
    var data = event.data || {};
    var payload = data.payload || {};

    if (data.action === 'open') openPanel(payload.initialModule, payload.mode || payload.panelMode || 'hub');
    if (data.action === 'close') {
      state.isOpen = false;
      render();
    }
    if (data.action === 'session:set') receiveSession(payload);
  });

  window.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && state.isOpen) closePanel();
  });

  function mockNui(eventName) {
    if (eventName === 'session:get') {
      window.setTimeout(function () {
        receiveSession({
          user: { source: 1, name: 'Dev User', isOwner: true, globalPermissions: ['group.mz_owner'] },
          orgs: [
            { code: 'police', name: 'Polícia', type: 'legal', grade: 3, gradeCode: 'sargento', gradeName: 'Sargento', capabilities: ['org.view', 'account.view', 'logs.view', 'goals.manage'] },
            { code: 'mafia', name: 'Máfia', type: 'gang', grade: 4, gradeCode: 'lider', gradeName: 'Líder', capabilities: ['org.view', 'account.view', 'logs.view'] }
          ],
          modules: ['dashboard', 'legal', 'gang', 'staff', 'orgs', 'recruitment', 'goals', 'logs', 'settings']
        });
      }, 250);
      return Promise.resolve({ ok: true });
    }

    if (eventName === 'orgs:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'orgs:get') return Promise.resolve({ ok: true, data: {} });
    if (eventName === 'members:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'logs:list') return Promise.resolve({ ok: true, data: [] });
    if (eventName === 'org-bank:get') return Promise.resolve({ ok: true, data: { orgCode: 'police', balance: 0, currency: 'R$' } });
    if (eventName === 'org-bank:transactions') return Promise.resolve({ ok: true, data: [] });
    return Promise.resolve({ ok: true });
  }

  render();
}());
