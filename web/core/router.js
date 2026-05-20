(function () {
  'use strict';

  function state() { return window.MZOrgState.state; }
  function ui() { return window.MZOrgUI; }
  function fmt() { return window.MZOrgFormat; }
  function perms() { return window.MZOrgPermissions; }

  function registerPanels() {
    window.MZOrgPanels = window.MZOrgPanels || {};
    var legacy = window.MZ_PANEL_DEFINITIONS || {};
    Object.keys(legacy).forEach(function (key) {
      if (!window.MZOrgPanels[key]) window.MZOrgPanels[key] = legacy[key];
    });
  }

  function getPanel(panelId) {
    return perms().getPanel(panelId);
  }

  var shellModules = {
    hub: 'dashboard',
    legal: 'legal',
    illegal: 'gang',
    staff: 'staff',
    vip: 'vip',
    business: 'business',
    government: 'government',
    event: 'event'
  };

  var moduleShells = {
    dashboard: 'hub',
    legal: 'legal',
    gang: 'illegal',
    staff: 'staff',
    vip: 'vip',
    business: 'business',
    government: 'government',
    event: 'event'
  };

  var shellOrgTypes = {
    legal: ['legal', 'job'],
    illegal: ['gang', 'illegal'],
    vip: ['vip'],
    business: ['business'],
    government: ['government'],
    event: ['event']
  };

  var orgContextSections = [
    { id: 'overview', label: 'Visao geral' },
    { id: 'members', label: 'Membros' },
    { id: 'grades', label: 'Cargos' },
    { id: 'goals', label: 'Metas' },
    { id: 'bank', label: 'Banco' },
    { id: 'recruitment', label: 'Recrutamento' },
    { id: 'logs', label: 'Logs' }
  ];

  var staffSections = [
    { id: 'overview', label: 'Visao geral' },
    { id: 'orgs', label: 'Organizacoes' },
    { id: 'logs', label: 'Logs' },
    { id: 'audit', label: 'Auditoria' },
    { id: 'actions', label: 'Acoes administrativas' }
  ];

  var staffOrgCreateTypes = [
    { id: 'job', label: 'Organizacao/Job' },
    { id: 'gang', label: 'Gang/Faccao' },
    { id: 'business', label: 'Empresa' },
    { id: 'government', label: 'Governo' },
    { id: 'vip', label: 'VIP' },
    { id: 'event', label: 'Evento' }
  ];

  var staffOrgDetailTabs = [
    { id: 'summary', label: 'Resumo' },
    { id: 'grades', label: 'Cargos' },
    { id: 'members', label: 'Membros' },
    { id: 'bank', label: 'Banco' },
    { id: 'goals', label: 'Metas' },
    { id: 'recruitment', label: 'Recrutamento' },
    { id: 'logs', label: 'Logs' },
    { id: 'actions', label: 'Acoes' }
  ];

  var sensitiveAuditActions = [
    'org.member.set_leader',
    'org.create',
    'org.member.invite',
    'org.member.remove',
    'org.member.promote',
    'org.member.demote',
    'org.account.deposit',
    'org.account.withdraw',
    'org.recruitment.approve',
    'org.recruitment.reject',
    'org.goal.create'
  ];

  function moduleForShell(shell) {
    return shellModules[shell] || 'dashboard';
  }

  function shellForModule(moduleId) {
    return moduleShells[moduleId] || null;
  }

  function normalizeOrgType(value) {
    return perms().normalizeOrgType(value);
  }

  function orgTypesForShell(shell) {
    return shellOrgTypes[shell] || [];
  }

  function orgsForShell(shell) {
    var current = state();
    var types = orgTypesForShell(shell || current.activeShell);
    if (!current.session || !Array.isArray(current.session.orgs) || !types.length) return [];
    return current.session.orgs.filter(function (org) {
      return types.indexOf(normalizeOrgType(org.type)) !== -1;
    });
  }

  function getFirstOrgByType(type) {
    type = normalizeOrgType(type);
    var current = state();
    if (!current.session || !Array.isArray(current.session.orgs)) return null;
    return current.session.orgs.filter(function (org) {
      return normalizeOrgType(org.type) === type;
    })[0] || null;
  }

  function visibleShells() {
    var order = ['hub', 'legal', 'illegal', 'staff', 'vip', 'business', 'government', 'event'];
    return order.map(function (shell) {
      var module = window.MZOrgState.moduleById[moduleForShell(shell)];
      if (!module) return null;
      if (shell === 'hub') return { id: shell, module: module };
      if (orgTypesForShell(shell).length) {
        if (!perms().isOwner(state().session) && !orgsForShell(shell).length && !perms().canViewModule(state().session, moduleForShell(shell))) return null;
        return { id: shell, module: module };
      }
      if (!perms().canOpenPanel(state().session, shell)) return null;
      return { id: shell, module: module };
    }).filter(Boolean);
  }

  function resetContextLoads() {
    var current = state();
    current.logs.loaded = false;
    current.logs.loadedKey = '';
    current.logs.data = [];
    current.recruitment.loaded = false;
    current.recruitment.loadedKey = '';
    current.recruitment.data = [];
    current.goals.loaded = false;
    current.goals.loadedKey = '';
    current.goals.data = [];
  }

  function syncActiveOrg(options) {
    var current = state();
    var shell = current.activeShell || current.activePanel || 'hub';
    var type = normalizeOrgType(orgTypesForShell(shell)[0] || '');
    var available = orgsForShell(shell);
    var requested = options && options.orgCode;
    var stored = type ? current.orgView.selectedByPanel[type] : null;
    var code = requested || current.activeOrgCode || stored || (available[0] && available[0].code) || null;
    var org = available.filter(function (item) { return item.code === code; })[0] || available[0] || null;

    current.activeOrgCode = org ? org.code : null;
    current.activeOrgType = org ? normalizeOrgType(org.type) : null;
    if (org && type) current.orgView.selectedByPanel[type] = org.code;

    return org;
  }

  function getActiveOrg() {
    var code = selectedOrgCode();
    return orgsForShell(state().activeShell).filter(function (org) { return org.code === code; })[0] || null;
  }

  function firstAllowedModule() {
    var modules = perms().visibleModules();
    return modules.length ? modules[0].id : 'dashboard';
  }

  function applyInitialModule() {
    var current = state();
    var requested = current.requestedInitialModule || getPanel(current.activePanel).initialModule || 'dashboard';
    current.activeModule = perms().canViewModule(current.session, requested) ? requested : firstAllowedModule();
    current.activeShell = current.activePanel || shellForModule(current.activeModule) || 'hub';
    if (current.activeShell === 'legal' || current.activeShell === 'illegal') {
      current.activeSection = current.activeSection || 'overview';
      syncActiveOrg();
    }
  }

  function setActivePanel(panelId, options) {
    setActiveShell(panelId, options);
  }

  function setActiveShell(shell, options) {
    var current = state();
    var panel = getPanel(shell || 'hub');
    current.activeShell = panel.id || shell || 'hub';
    current.activePanel = current.activeShell;
    current.requestedPanel = current.activePanel;
    current.currentContext = current.activePanel;
    current.requestedInitialModule = (options && options.initialModule) || panel.initialModule || 'dashboard';
    current.activeModule = moduleForShell(current.activeShell);
    if (current.activeShell === 'legal' || current.activeShell === 'illegal') {
      current.activeSection = (options && options.section) || 'overview';
      syncActiveOrg(options);
      window.MZOrgState.resetOrgPanelData();
      resetContextLoads();
    } else {
      current.activeOrgCode = null;
      current.activeOrgType = null;
      current.activeSection = 'overview';
    }
    render();
    loadActiveModule();
  }

  function setActiveModule(moduleId) {
    var shell = shellForModule(moduleId);
    if (shell) {
      setActiveShell(shell, { initialModule: moduleId });
      return;
    }
    if (!perms().canViewModule(state().session, moduleId)) return;
    state().activeModule = moduleId;
    render();
    loadActiveModule();
  }

  function setActiveOrg(orgCode, orgType) {
    var current = state();
    current.activeOrgCode = orgCode || null;
    current.activeOrgType = orgType ? normalizeOrgType(orgType) : null;
    if (current.activeOrgType && orgCode) current.orgView.selectedByPanel[current.activeOrgType] = orgCode;
    window.MZOrgState.resetOrgPanelData();
    resetContextLoads();
    render();
    loadActiveModule();
  }

  function setActiveSection(section) {
    state().activeSection = section || 'overview';
    render();
    loadActiveModule();
  }

  function isOrgPanelModule(moduleId) {
    return ['legal', 'gang', 'vip', 'business', 'government', 'event'].indexOf(moduleId) !== -1;
  }

  function selectedOrgCode() {
    var current = state();
    if (current.activeOrgCode) return current.activeOrgCode;
    var type = perms().moduleType(current.activeModule) || 'all';
    var stored = current.orgView.selectedByPanel[type];
    var available = orgsForShell(current.activeShell).length ? orgsForShell(current.activeShell) : perms().contextOrgsForActiveModule();

    if (stored && available.some(function (org) { return org.code === stored; })) return stored;
    return available.length ? available[0].code : '';
  }

  function loadActiveModule() {
    var current = state();
    if (!current.session) return;
    if (current.activeShell === 'legal' || current.activeShell === 'illegal') {
      loadOrgPanel();
      if (current.activeSection === 'overview' || current.activeSection === 'goals') loadGoals();
      if (current.activeSection === 'recruitment') loadRecruitment();
      if (current.activeSection === 'logs') loadLogs({ orgCode: selectedOrgCode() });
      return;
    }
    if (current.activeShell === 'staff') {
      loadStaffDashboardData();
      return;
    }
    if (current.activeModule === 'orgs') loadOrgs();
    if (isOrgPanelModule(current.activeModule)) loadOrgPanel();
    if (current.activeModule === 'logs') loadLogs();
    if (current.activeModule === 'recruitment') loadRecruitment();
    if (current.activeModule === 'goals') loadGoals();
  }

  function loadOrgPanel() {
    var current = state();
    var code = selectedOrgCode();
    if (!code) return;

    var key = current.activeModule + ':' + code;
    if (current.orgView.loadedKey === key && !current.orgView.detailLoading && !current.orgView.membersLoading && !current.orgView.bankLoading) return;

    current.orgView.loadedKey = key;
    current.orgView.detailLoading = true;
    current.orgView.membersLoading = true;
    current.orgView.bankLoading = true;
    current.orgView.transactionsLoading = true;
    current.orgView.accessLoading = true;
    current.orgView.detailError = null;
    current.orgView.membersError = null;
    current.orgView.bankError = null;
    current.orgView.transactionsError = null;
    current.orgView.accessError = null;
    render();

    window.MZOrgService.getOrg(code).then(function (data) {
      current.orgView.detail = data || null;
    }).catch(function (err) {
      current.orgView.detailError = err.message;
    }).finally(function () {
      current.orgView.detailLoading = false;
      render();
    });

    window.MZOrgMemberService.listMembers(code).then(function (data) {
      current.orgView.members = Array.isArray(data) ? data : [];
    }).catch(function (err) {
      current.orgView.membersError = err.message;
    }).finally(function () {
      current.orgView.membersLoading = false;
      render();
    });

    window.MZOrgBankService.getOrgBank(code).then(function (data) {
      current.orgView.bank = data || null;
    }).catch(function (err) {
      current.orgView.bankError = err.message;
    }).finally(function () {
      current.orgView.bankLoading = false;
      render();
    });

    window.MZOrgBankService.listOrgBankTransactions(code, { limit: 50 }).then(function (data) {
      current.orgView.transactions = Array.isArray(data) ? data : [];
    }).catch(function (err) {
      current.orgView.transactionsError = err.message;
    }).finally(function () {
      current.orgView.transactionsLoading = false;
      render();
    });

    window.MZOrgAccessService.getOrgAccess(code).then(function (data) {
      current.orgView.access = data || null;
      current.cache.accessByOrg[code] = current.orgView.access;
    }).catch(function (err) {
      current.orgView.accessError = err.message;
    }).finally(function () {
      current.orgView.accessLoading = false;
      render();
    });
  }

  function refreshBankData(code) {
    var current = state();
    code = code || selectedOrgCode();
    if (!code) return;

    current.orgView.bankLoading = true;
    current.orgView.transactionsLoading = true;
    current.orgView.bankError = null;
    current.orgView.transactionsError = null;
    render();

    window.MZOrgBankService.getOrgBank(code).then(function (data) {
      current.orgView.bank = data || null;
    }).catch(function (err) {
      current.orgView.bankError = err.message;
    }).finally(function () {
      current.orgView.bankLoading = false;
      render();
    });

    window.MZOrgBankService.listOrgBankTransactions(code, { limit: 50 }).then(function (data) {
      current.orgView.transactions = Array.isArray(data) ? data : [];
    }).catch(function (err) {
      current.orgView.transactionsError = err.message;
    }).finally(function () {
      current.orgView.transactionsLoading = false;
      render();
    });
  }

  function loadOrgs() {
    var current = state();
    if (current.orgs.loading || current.orgs.loaded) return;
    current.orgs.loading = true;
    current.orgs.error = null;
    render();

    window.MZOrgService.listOrgs().then(function (items) {
      current.orgs.data = Array.isArray(items) ? items : [];
      current.orgs.loaded = true;
      current.cache.orgs = current.orgs.data;
    }).catch(function (err) {
      current.orgs.error = err.message;
    }).finally(function () {
      current.orgs.loading = false;
      render();
    });
  }

  function loadLogs(filters) {
    var current = state();
    filters = filters || { limit: 100 };
    if (!filters.limit) filters.limit = 100;
    var key = filters.orgCode ? 'org:' + filters.orgCode : 'global';
    if (current.logs.loading || (current.logs.loaded && current.logs.loadedKey === key)) return;
    current.logs.loading = true;
    current.logs.error = null;
    current.logs.loadedKey = key;
    render();

    window.MZOrgLogService.listLogs(filters).then(function (data) {
      current.logs.data = Array.isArray(data) ? data : [];
      current.logs.loaded = true;
      current.cache.logs = current.logs.data;
    }).catch(function (err) {
      current.logs.error = err.message;
    }).finally(function () {
      current.logs.loading = false;
      render();
    });
  }

  function canLoadStaffGlobalLogs() {
    var current = state();
    return perms().isOwner(current.session)
      || perms().hasGlobalPermission(current.session, 'staff.logs.view')
      || perms().hasGlobalPermission(current.session, 'staff.orgs.manage');
  }

  function loadStaffDashboardData() {
    loadOrgs();
    if (canLoadStaffGlobalLogs()) {
      loadLogs({ limit: 100 });
    } else {
      state().logs.loaded = true;
      state().logs.loadedKey = 'global';
      state().logs.loading = false;
      state().logs.error = null;
      state().logs.data = [];
    }
  }

  function loadRecruitment() {
    var current = state();
    var code = selectedOrgCode();
    var key = current.activePanel + ':' + (code || 'self');
    if (current.recruitment.loading || (current.recruitment.loaded && current.recruitment.loadedKey === key)) return;

    if (!code) {
      current.recruitment.data = [];
      current.recruitment.error = null;
      current.recruitment.loaded = true;
      current.recruitment.loadedKey = key;
      render();
      return;
    }

    current.recruitment.loading = true;
    current.recruitment.error = null;
    current.recruitment.loadedKey = key;
    render();

    var filters = { limit: 50 };
    if (code) filters.orgCode = code;

    window.MZOrgRecruitmentService.listRecruitment(code, filters).then(function (items) {
      current.recruitment.data = Array.isArray(items) ? items : [];
      current.recruitment.loaded = true;
    }).catch(function (err) {
      current.recruitment.error = err.message;
    }).finally(function () {
      current.recruitment.loading = false;
      render();
    });
  }

  function reloadRecruitment() {
    var current = state();
    current.recruitment.loaded = false;
    current.recruitment.loadedKey = '';
    current.recruitment.data = [];
    return loadRecruitment();
  }

  function loadGoals() {
    var current = state();
    var code = selectedOrgCode();
    var key = current.activePanel + ':' + (code || 'none');
    if (current.goals.loading || (current.goals.loaded && current.goals.loadedKey === key)) return;

    current.goals.loading = true;
    current.goals.error = null;
    current.goals.loadedKey = key;
    render();

    var filters = { limit: 50 };
    if (code) filters.orgCode = code;

    window.MZOrgGoalService.listGoals(filters).then(function (items) {
      current.goals.data = Array.isArray(items) ? items : [];
      current.goals.loaded = true;
    }).catch(function (err) {
      current.goals.error = err.message;
    }).finally(function () {
      current.goals.loading = false;
      render();
    });
  }

  function reloadGoals() {
    var current = state();
    current.goals.loaded = false;
    current.goals.loadedKey = '';
    return loadGoals();
  }

  function render() {
    var app = document.getElementById('app');
    var current = state();
    if (!app) return;

    if (!current.isOpen) {
      app.innerHTML = '<div class="mz-root"></div>';
      return;
    }

    app.innerHTML = '<div class="mz-root is-open">' + renderPanel() + '</div>';
    bindEvents();
  }

  function renderPanel() {
    var current = state();
    if (current.loadingSession) {
      return '<div class="panel-shell"><main class="main full-main">' + ui().loading('Carregando sessao') + '</main></div>';
    }

    if (current.sessionError) {
      return '<div class="panel-shell"><main class="main full-main padded-main">' + ui().errorBox(current.sessionError) + '<button class="btn btn-primary" data-action="close">Fechar</button></main></div>';
    }

    if (!current.session) {
      return '<div class="panel-shell"><main class="main full-main">' + ui().empty('Sem sessao', 'Abra o painel novamente.') + '</main></div>';
    }

    return '<section class="panel-shell' + (current.sidebarCollapsed ? ' sidebar-collapsed' : '') + '">' +
      renderSidebar() +
      '<main class="main">' + renderHeader() + '<div class="content">' + renderActivePage() + '</div></main>' +
      renderBankModal() +
      renderGoalModal() +
      renderMemberModal() +
    '</section>';
  }

  function renderSidebar() {
    var current = state();
    var panel = getPanel(current.activeShell || current.activePanel);
    var shells = visibleShells();
    var nav = shells.map(function (item) {
      var module = item.module;
      var active = item.id === current.activeShell ? ' is-active' : '';
      return '<button class="nav-item' + active + '" data-shell="' + ui().escapeHtml(item.id) + '" title="' + ui().safeText(module.label) + '">' +
        ui().renderIcon(module.icon, module.fallback, 'nav-icon-box') +
        '<span class="nav-text"><span class="nav-label">' + ui().safeText(module.label) + '</span><span class="nav-desc">' + ui().safeText(module.description) + '</span></span>' +
      '</button>';
    }).join('');

    return '<aside class="sidebar">' +
      '<div class="brand">' +
        '<div class="brand-top">' +
          '<div class="brand-title"><span class="brand-mark">MZ</span><span class="brand-name">' + ui().safeText(panel.title || 'MZ Org') + '</span></div>' +
          '<button class="sidebar-toggle" data-action="toggle-sidebar" title="Recolher menu" aria-label="Recolher menu">' + (current.sidebarCollapsed ? '&rsaquo;' : '&lsaquo;') + '</button>' +
        '</div>' +
        '<div class="brand-subtitle">' + ui().safeText(panel.subtitle || 'Painel de organizacoes.') + '</div>' +
      '</div>' +
      '<nav class="nav-list">' + nav + '</nav>' +
      '<div class="sidebar-footer"><div class="session-mini"><strong class="truncate">' + ui().safeText(current.session.user.name) + '</strong><span>' + ui().safeText(shells.length) + ' contextos visiveis</span><div class="session-badge">' + ui().badge(perms().getAccessLabel(), perms().getAccessVariant()) + '</div></div></div>' +
    '</aside>';
  }

  function renderHeader() {
    var current = state();
    var header = getHeaderContext();
    return '<header class="header">' +
      '<div class="header-left"><div class="header-title"><span class="header-kicker">' + ui().safeText(header.kicker) + '</span><h1 class="truncate">' + ui().safeText(header.title) + '</h1><p class="truncate">' + ui().safeText(header.subtitle) + '</p></div></div>' +
      '<div class="header-right">' +
        '<div class="user-info"><span class="user-avatar">' + ui().safeText((current.session.user.name || 'P').slice(0, 1).toUpperCase()) + '</span><div class="user-meta"><strong class="truncate">' + ui().safeText(current.session.user.name) + '</strong><span class="truncate">ID ' + ui().safeText(current.session.user.source) + ' / ' + ui().safeText(current.session.orgs.length) + ' org(s)</span></div></div>' +
        ui().badge(perms().getAccessLabel(), perms().getAccessVariant()) +
        '<button class="btn btn-ghost close-btn" data-action="close">Fechar</button>' +
      '</div>' +
    '</header>';
  }

  function getHeaderContext() {
    var current = state();
    var panel = getPanel(current.activeShell || current.activePanel);
    var activeOrg = getActiveOrg();
    var detail = current.orgView.detail || {};
    var org = detail.code && detail.code === selectedOrgCode() ? detail : activeOrg;

    if (current.activeShell === 'legal') {
      return {
        kicker: 'ORGANIZACAO LEGAL',
        title: org && (org.name || org.code) || 'Organizacao',
        subtitle: 'Cargo: ' + fmt().formatGradeName(org || {})
      };
    }

    if (current.activeShell === 'illegal') {
      return {
        kicker: 'FACCAO',
        title: org && (org.name || org.code) || 'Gang',
        subtitle: 'Cargo: ' + fmt().formatGradeName(org || {})
      };
    }

    if (current.activeShell === 'staff') {
      return {
        kicker: 'STAFF',
        title: 'Administracao',
        subtitle: 'Ferramentas da equipe autorizada'
      };
    }

    if (current.activeShell === 'vip' || current.activeShell === 'business' || current.activeShell === 'government' || current.activeShell === 'event') {
      return {
        kicker: String(panel.title || current.activeShell || 'CONTEXTO').toUpperCase(),
        title: panel.title || 'Contexto',
        subtitle: panel.subtitle || 'Painel contextual'
      };
    }

    return {
      kicker: 'PAINEL GERAL',
      title: 'MZ Org',
      subtitle: 'Escolha um contexto disponivel'
    };
  }

  function renderActivePage() {
    var current = state();
    var panel = getPanel(current.activeShell || current.activePanel);
    var context = { state: current, panel: panel, moduleId: current.activeModule, router: window.MZOrgRouter };

    if (current.activeShell === 'hub') return renderDashboard();
    if (current.activeShell === 'legal' || current.activeShell === 'illegal') return renderOrgPanelPage();
    if (current.activeShell === 'staff' && current.activeModule === 'staff') return renderStaffPage();

    if (current.activeModule === 'dashboard') {
      if (panel.render && panel.id === 'hub') return panel.render(context);
      return renderDashboard();
    }
    if (current.activeModule === 'orgs') return renderOrgsPage();
    if (isOrgPanelModule(current.activeModule)) {
      if (panel.render && panel.initialModule === current.activeModule) return panel.render(context);
      return renderOrgPanelPage();
    }
    if (current.activeModule === 'staff') {
      if (panel.render && panel.id === 'staff') return panel.render(context);
      return renderStaffPage();
    }
    if (current.activeModule === 'logs') return renderLogsPage();
    if (current.activeModule === 'recruitment') return renderRecruitmentPage();
    if (current.activeModule === 'goals') return renderGoalsPage();
    if (current.activeModule === 'settings') return renderPlaceholder('Configuracoes', 'Configuracoes globais ficarao restritas ao owner.', 'assets/icons/settings.svg', 'C');
    return renderDashboard();
  }

  function renderDashboard() {
    var current = state();
    var shells = visibleShells().filter(function (item) { return item.id !== 'hub'; });
    var orgs = current.session.orgs || [];
    var panel = getPanel(current.activeShell || current.activePanel);
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Portal</span><h2>' + ui().safeText(panel.title || 'Central da sessao') + '</h2><p>Acesse os paineis liberados para sua sessao e acompanhe seus vinculos ativos.</p></div>' + ui().badge(perms().getAccessLabel(), perms().getAccessVariant()) + '</div>' +
      '<div class="metric-grid">' +
        ui().metricCard('assets/icons/dashboard.svg', shells.length, 'Contextos disponiveis', 'D') +
        ui().metricCard('assets/icons/orgs.svg', orgs.length, 'Organizacoes vinculadas', 'O') +
        ui().metricCard('assets/icons/shield.svg', perms().getAccessLabel(), 'Acesso atual', 'S') +
      '</div>' +
      '<div class="two-col">' +
        ui().card('Contextos do painel', 'Atalhos liberados para o seu personagem.', '<div class="module-card-grid">' + shells.map(function (item) {
          var module = item.module;
          return '<button class="module-card" data-shell="' + ui().escapeHtml(item.id) + '">' + ui().renderIcon(module.icon, module.fallback, 'inline-icon-box') + '<span><strong>' + ui().safeText(module.label) + '</strong><small>' + ui().safeText(module.description) + '</small></span></button>';
        }).join('') + '</div>') +
        ui().card('Seus vinculos', 'Organizacoes e cargos ativos.', orgs.length ? orgs.map(function (org) { return '<div class="mini-row"><strong>' + ui().safeText(org.name) + '</strong><span>' + ui().safeText(fmt().formatGradeName(org)) + '</span></div>'; }).join('') : ui().empty('Sem organizacao vinculada', 'Quando voce entrar em uma organizacao, ela aparece aqui.')) +
      '</div>' +
    '</div>';
  }

  function renderOrgsPage() {
    var current = state();
    var body = current.orgs.loading ? ui().loading('Carregando organizacoes') : current.orgs.error ? ui().errorBox(current.orgs.error) : !current.orgs.data.length ? ui().empty('Nenhuma organizacao visivel', 'O servidor nao retornou orgs para esta sessao.') : renderOrgTable(current.orgs.data);
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Consulta</span><h2>Organizacoes visiveis</h2><p>Lista filtrada para a sua sessao atual.</p></div>' + ui().badge((current.orgs.data || []).length + ' encontradas', 'info') + '</div>' +
      ui().card('Organizacoes', 'Resumo administrativo das organizacoes visiveis.', body) +
    '</div>';
  }

  function renderOrgTable(items) {
    return '<div class="table-scroll"><table><thead><tr><th>Nome</th><th>Tipo</th><th>Cargo</th><th>Status</th></tr></thead><tbody>' + items.map(function (org) {
      return '<tr><td class="cell-strong">' + ui().safeText(org.name || org.code) + '</td><td>' + ui().badge(fmt().formatOrgType(org.type || 'legal'), org.type === 'gang' ? 'danger' : 'info') + '</td><td>' + ui().safeText(fmt().formatGradeName(org)) + '</td><td>' + ui().badge(org.is_public ? 'Publica' : 'Privada', org.is_public ? 'success' : 'muted') + '</td></tr>';
    }).join('') + '</tbody></table></div>';
  }

  function capabilityBadges(capabilities, limit) {
    capabilities = Array.isArray(capabilities) ? capabilities : [];
    if (!capabilities.length) return ui().empty('Sem permissoes visiveis', 'Nenhuma permissao foi retornada para esta sessao.');
    var visible = typeof limit === 'number' ? capabilities.slice(0, limit) : capabilities;
    var hidden = typeof limit === 'number' && capabilities.length > limit ? ui().badge('+' + (capabilities.length - limit), 'muted') : '';
    return '<div class="badge-row">' + visible.map(function (cap) { return ui().permissionBadge(cap, cap === 'org.view' ? 'success' : 'muted'); }).join('') + hidden + '</div>';
  }

  function currentOrgDetail(contextOrg) {
    var detail = state().orgView.detail || {};
    return detail.code ? detail : (contextOrg || {});
  }

  function renderOrgPanelPage() {
    var current = state();
    if (current.activeShell === 'legal' || current.activeShell === 'illegal') {
      return renderOrgContextPage();
    }

    return renderOrgStackedPage();
  }

  function renderOrgStackedPage() {
    var current = state();
    var module = window.MZOrgState.moduleById[current.activeModule] || window.MZOrgState.moduleById.legal;
    var available = perms().contextOrgsForActiveModule();
    var code = selectedOrgCode();
    var contextOrg = available.filter(function (org) { return org.code === code; })[0] || null;

    if (!available.length) {
      return '<div class="screen">' +
        '<div class="page-heading"><div><span class="module-kicker">Sem vinculo</span><h2>' + ui().safeText(module.label) + '</h2><p>O core nao retornou uma organizacao compativel para este painel.</p></div>' + ui().badge('sem acesso', 'warning') + '</div>' +
        ui().empty('Nenhuma organizacao encontrada', 'Este comando abre apenas o painel do tipo correspondente ao seu vinculo.') +
      '</div>';
    }

    if (code && current.orgView.loadedKey !== current.activeModule + ':' + code && !current.orgView.detailLoading) {
      window.setTimeout(loadOrgPanel, 0);
    }

    if (code && current.goals.loadedKey !== current.activePanel + ':' + code && !current.goals.loading) {
      window.setTimeout(loadGoals, 0);
    }

    var selector = available.length > 1 ? renderOrgSelector(available, code) : '';
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">' + ui().safeText(module.label) + '</span><h2>' + ui().safeText(contextOrg && contextOrg.name || module.label) + '</h2><p>Resumo operacional da organizacao, com acoes e dados permitidos para o seu cargo.</p></div>' + ui().badge(fmt().formatOrgType(contextOrg && contextOrg.type), 'info') + '</div>' +
      selector +
      renderOrgOverviewCards(contextOrg) +
      '<div class="two-col">' + renderOrgSummary(contextOrg) + renderOrgAccess(contextOrg) + '</div>' +
      renderAccessModelCard() +
      '<div class="two-col">' + renderBankCard() + renderTransactionsCard() + '</div>' +
      renderMembersCard() +
    '</div>';
  }

  function renderOrgContextPage() {
    var current = state();
    var shell = current.activeShell;
    var module = window.MZOrgState.moduleById[current.activeModule] || window.MZOrgState.moduleById.legal;
    var available = orgsForShell(shell);
    var contextOrg = syncActiveOrg();
    var code = selectedOrgCode();
    var emptyTitle = shell === 'illegal' ? 'Voce nao esta vinculado a uma gang.' : 'Voce nao esta vinculado a uma organizacao legal.';
    var emptyDesc = shell === 'illegal' ? 'Este comando mostra apenas o contexto de gang/faccao.' : 'Este comando mostra apenas o contexto legal/job.';

    if (!available.length || !code) {
      return '<div class="screen">' +
        '<div class="page-heading"><div><span class="module-kicker">Sem vinculo</span><h2>' + ui().safeText(module.label) + '</h2><p>' + ui().safeText(emptyDesc) + '</p></div>' + ui().badge('sem acesso', 'warning') + '</div>' +
        ui().empty(emptyTitle, 'Abra o painel geral para ver outros contextos disponiveis.') +
      '</div>';
    }

    if (current.orgView.loadedKey !== current.activeModule + ':' + code && !current.orgView.detailLoading) {
      window.setTimeout(loadOrgPanel, 0);
    }

    if ((current.activeSection === 'overview' || current.activeSection === 'goals') && current.goals.loadedKey !== current.activePanel + ':' + code && !current.goals.loading) {
      window.setTimeout(loadGoals, 0);
    }

    if (current.activeSection === 'recruitment' && current.recruitment.loadedKey !== current.activePanel + ':' + code && !current.recruitment.loading) {
      window.setTimeout(loadRecruitment, 0);
    }

    if (current.activeSection === 'logs' && current.logs.loadedKey !== 'org:' + code && !current.logs.loading) {
      window.setTimeout(function () { loadLogs({ orgCode: code, limit: 100 }); }, 0);
    }

    return '<div class="screen">' +
      renderOrgContextHeader(available, contextOrg, module) +
      '<section class="section-panel">' + renderOrgSection(contextOrg) + '</section>' +
    '</div>';
  }

  function renderOrgContextHeader(orgs, contextOrg, module) {
    var selector = orgs.length > 1 ? renderOrgSelector(orgs, selectedOrgCode()) : '';
    var meta = selector ? '<div class="context-title-row context-title-row-compact"><div class="context-actions">' + selector + '</div></div>' : '';

    return '<div class="context-header context-header-compact">' +
      meta +
      renderContextTabs(orgContextSections) +
    '</div>';
  }

  function renderContextTabs(sections) {
    var active = state().activeSection || 'overview';
    return '<nav class="context-tabs" aria-label="Secoes do contexto">' + sections.map(function (section) {
      return '<button class="context-tab' + (section.id === active ? ' is-active' : '') + '" data-section="' + ui().escapeHtml(section.id) + '">' + ui().safeText(section.label) + '</button>';
    }).join('') + '</nav>';
  }

  function renderOrgSection(contextOrg) {
    var section = state().activeSection || 'overview';
    if (section === 'members') return renderMembersCard();
    if (section === 'grades') return renderAccessModelCard();
    if (section === 'goals') return renderGoalsSection(contextOrg);
    if (section === 'bank') return renderBankSection();
    if (section === 'recruitment') return renderRecruitmentSection(contextOrg);
    if (section === 'logs') return renderOrgLogsSection();
    return renderOverviewSection(contextOrg);
  }

  function renderOverviewSection(contextOrg) {
    return renderOrgOverviewCards(contextOrg) +
      '<div class="two-col">' + renderOrgSummary(contextOrg) + renderOrgAccess(contextOrg) + '</div>';
  }

  function renderGoalsSection(contextOrg) {
    var current = state();
    var body = current.goals.loading
      ? ui().loading('Carregando metas')
      : current.goals.error
        ? ui().errorBox(current.goals.error)
        : renderGoalList(current.goals.data || [], current.activePanel);

    return renderGoalsLayout(contextOrg, body);
  }

  function renderRecruitmentSection(contextOrg) {
    var current = state();
    var isIllegal = current.activeShell === 'illegal';
    var body = current.recruitment.loading
      ? ui().loading('Carregando recrutamento')
      : current.recruitment.error
        ? ui().errorBox(current.recruitment.error)
        : renderRecruitmentList(current.recruitment.data || [], isIllegal);

    return renderRecruitmentLayout(contextOrg, body);
  }

  function renderOrgLogsSection() {
    var current = state();
    var logs = filteredLogs();
    var listBody = current.logs.loading ? ui().loading('Carregando logs') : current.logs.error ? ui().errorBox(current.logs.error) : !logs.length ? ui().empty('Nenhum log visivel', 'Nao ha logs permitidos para esta org.') : renderLogsTable(logs);
    return ui().card('Logs da organizacao', 'Auditoria filtrada pela org ativa no servidor.', listBody);
  }

  function renderOrgSelector(orgs, selected) {
    return '<label class="org-selector"><span>Selecionar contexto</span><select data-action="select-org">' + orgs.map(function (org) {
      return '<option value="' + ui().safeText(org.code) + '" data-org-type="' + ui().safeText(org.type) + '" ' + (org.code === selected ? 'selected' : '') + '>' + ui().safeText(org.name) + ' - ' + ui().safeText(fmt().formatGradeName(org)) + '</option>';
    }).join('') + '</select></label>';
  }

  function renderOrgOverviewCards(contextOrg) {
    var current = state();
    var org = currentOrgDetail(contextOrg);
    var memberCount = current.orgView.membersLoading ? '...' : (current.orgView.members || []).length;
    var goalCount = current.goals.loading ? '...' : (current.goals && Array.isArray(current.goals.data) ? current.goals.data.filter(function (goal) {
      return String(goal.status || 'active').toLowerCase() === 'active' || String(goal.status || '').toLowerCase() === 'ativa';
    }).length : 0);
    var bank = current.orgView.bank || {};
    var bankValue = current.orgView.bankLoading ? '...' : fmt().formatMoney(bank.balance, bank.currency);

    return '<div class="stat-grid">' +
      ui().statCard('Organizacao', org.name || contextOrg && contextOrg.name || '-', fmt().formatOrgType(org.type || contextOrg && contextOrg.type), 'accent') +
      ui().statCard('Seu cargo', fmt().formatGradeName(contextOrg || org), 'Acesso validado pelo servidor', 'success') +
      ui().statCard('Membros', memberCount, 'Ativos retornados para esta org', '') +
      ui().statCard('Metas ativas', goalCount, 'Modulo de metas', 'warning') +
      ui().statCard('Banco', bankValue, 'Saldo da organizacao', 'money') +
    '</div>';
  }

  function renderOrgSummary(contextOrg) {
    var current = state();
    if (current.orgView.detailLoading) return ui().card('Resumo', 'Informacoes principais da organizacao.', ui().loading('Carregando org'));
    if (current.orgView.detailError) return ui().card('Resumo', 'Informacoes principais da organizacao.', ui().errorBox(current.orgView.detailError));
    var org = currentOrgDetail(contextOrg);
    return ui().card('Resumo', 'O que importa para operar a organizacao.', '<div class="detail-grid"><span>Nome</span><strong>' + ui().safeText(org.name) + '</strong><span>Tipo</span><strong>' + ui().safeText(fmt().formatOrgType(org.type)) + '</strong><span>Status</span><strong>' + ui().safeText(org.is_public ? 'Publica' : 'Privada') + '</strong></div>');
  }

  function renderOrgAccess(org) {
    org = org || {};
    var detail = state().orgView.detail || {};
    var caps = Array.isArray(detail.capabilities) && detail.capabilities.length ? detail.capabilities : (org.capabilities || []);
    return ui().card('Meu acesso', 'Cargo, permissoes e acoes disponiveis.', '<div class="detail-grid"><span>Cargo</span><strong>' + ui().safeText(fmt().formatGradeName(org)) + '</strong><span>Permissoes</span><strong>' + ui().safeText(caps.length) + '</strong></div>' + capabilityBadges(caps, 8));
  }

  function renderAccessModelCard() {
    var current = state();
    if (current.orgView.accessLoading) return ui().card('Cargos', 'Hierarquia e permissoes do quadro atual.', ui().loading('Carregando cargos'));
    if (current.orgView.accessError) return ui().card('Cargos', 'Hierarquia e permissoes do quadro atual.', ui().errorBox(current.orgView.accessError));

    var model = current.orgView.access || {};
    var grades = Array.isArray(model.grades) ? model.grades : [];
    var baseCaps = Array.isArray(model.baseCapabilities) ? model.baseCapabilities : [];

    var base = baseCaps.length
      ? capabilityBadges(baseCaps)
      : ui().empty('Sem permissoes base', 'Nenhuma permissao base foi retornada para esta org.');

    var gradesBody = grades.length ? renderGradesTable(grades) : ui().empty('Nenhum cargo retornado', 'O core nao retornou grades para esta organizacao.');
    var overrides = Array.isArray(model.playerOverrides) && model.playerOverrides.length
      ? '<div class="badge-row">' + model.playerOverrides.map(function (override) { return ui().permissionBadge(override.permission || '-', override.allow === false ? 'danger' : 'info'); }).join('') + '</div>'
      : ui().empty('Sem ajustes individuais', 'Nenhuma permissao individual foi retornada para sua sessao.');

    return ui().card('Cargos e permissoes', 'Hierarquia, salario e permissoes em linguagem de uso.', '<div class="access-section"><h4>Permissoes base</h4>' + base + '</div><div class="access-section"><h4>Hierarquia</h4>' + gradesBody + '</div><div class="access-section"><h4>Ajustes da sua sessao</h4>' + overrides + '</div>');
  }

  function renderGradesTable(grades) {
    return '<div class="table-scroll"><table><thead><tr><th>Nivel</th><th>Cargo</th><th>Salario</th><th>Heranca</th><th>Permissoes</th></tr></thead><tbody>' + grades.map(function (grade) {
      var caps = Array.isArray(grade.capabilities) && grade.capabilities.length
        ? capabilityBadges(grade.capabilities, 5)
        : ui().safeText('-');
      var inheritance = grade.inheritsLevel ? 'Herda do nivel ' + grade.inheritsLevel : 'Sem heranca';
      return '<tr><td>' + ui().badge('Nivel ' + grade.level, 'info') + '</td><td class="cell-strong">' + ui().safeText(grade.name || grade.code) + '</td><td>' + ui().safeText(fmt().formatMoney(grade.salary || 0)) + '</td><td>' + ui().safeText(inheritance) + '</td><td>' + caps + '</td></tr>';
    }).join('') + '</tbody></table></div>';
  }

  function activeOrgCapabilities(contextOrg) {
    var detail = state().orgView.detail || {};
    if (Array.isArray(detail.capabilities) && detail.capabilities.length) return detail.capabilities;
    contextOrg = contextOrg || getActiveOrg() || {};
    return Array.isArray(contextOrg.capabilities) ? contextOrg.capabilities : [];
  }

  function canUseBankAction(action, contextOrg) {
    if (perms().isOwner(state().session)) return true;
    var caps = activeOrgCapabilities(contextOrg);
    return caps.indexOf('account.manage') !== -1 || caps.indexOf('manage.account') !== -1 || caps.indexOf(action) !== -1;
  }

  function renderBankActionMessages() {
    var current = state();
    var message = current.orgView.bankActionMessage ? '<div class="inline-message success">' + ui().safeText(current.orgView.bankActionMessage) + '</div>' : '';
    var error = current.orgView.bankActionError ? '<div class="inline-message error-inline">' + ui().safeText(formatBankError(current.orgView.bankActionError)) + '</div>' : '';
    return message + error;
  }

  function renderBankActionButton(type, label, description, canUse) {
    var current = state();
    var disabled = !canUse || current.bankModal.loading;
    var hint = !canUse ? 'Sem permissao visual. O servidor tambem valida.' : description;
    return '<button class="bank-action-btn ' + ui().safeText(type) + '" data-action="open-bank-modal" data-bank-type="' + ui().safeText(type) + '" ' + (disabled ? 'disabled' : '') + '>' +
      '<strong>' + ui().safeText(label) + '</strong>' +
      '<span>' + ui().safeText(hint) + '</span>' +
    '</button>';
  }

  function renderBankSummaryCard() {
    var current = state();
    if (current.orgView.bankLoading) return '<article class="bank-summary-card">' + ui().loading('Carregando saldo') + '</article>';
    if (current.orgView.bankError) return '<article class="bank-summary-card">' + ui().errorBox(current.orgView.bankError) + '</article>';
    var bank = current.orgView.bank || {};
    return '<article class="bank-summary-card">' +
      '<span>Saldo atual</span>' +
      '<strong>' + fmt().formatMoney(bank.balance, bank.currency) + '</strong>' +
      '<small>Saldo disponivel da organizacao.</small>' +
    '</article>';
  }

  function renderBankSection() {
    var contextOrg = getActiveOrg();
    var canDeposit = canUseBankAction('account.deposit', contextOrg);
    var canWithdraw = canUseBankAction('account.withdraw', contextOrg);
    return '<section class="bank-section">' +
      '<div class="bank-top-grid">' +
        renderBankSummaryCard() +
        renderBankActionButton('deposit', 'Depositar', 'Enviar dinheiro da sua conta para a organizacao.', canDeposit) +
        renderBankActionButton('withdraw', 'Sacar', 'Retirar dinheiro da organizacao para sua conta.', canWithdraw) +
      '</div>' +
      renderBankActionMessages() +
      '<p class="soft-note">A NUI envia apenas org, valor e motivo. Saldos e permissoes sao calculados no servidor.</p>' +
      renderTransactionsCard() +
    '</section>';
  }

  function renderBankCard() {
    var current = state();
    if (current.orgView.bankLoading) return ui().card('Banco', 'Saldo da organizacao.', ui().loading('Carregando saldo'));
    if (current.orgView.bankError) return ui().card('Banco', 'Saldo da organizacao.', ui().errorBox(current.orgView.bankError));
    var bank = current.orgView.bank || {};
    var contextOrg = getActiveOrg();
    var canDeposit = canUseBankAction('account.deposit', contextOrg);
    var canWithdraw = canUseBankAction('account.withdraw', contextOrg);
    return ui().card('Banco', 'Saldo e operacoes da conta compartilhada.', '<div class="bank-balance"><span>Saldo atual</span><strong>' + fmt().formatMoney(bank.balance, bank.currency) + '</strong></div>' +
      renderBankActionMessages() +
      '<div class="bank-actions">' +
        renderBankActionButton('deposit', 'Depositar', 'Enviar dinheiro do seu banco para a organizacao.', canDeposit) +
        renderBankActionButton('withdraw', 'Sacar', 'Retirar dinheiro da organizacao para seu banco.', canWithdraw) +
      '</div>' +
      '<p class="soft-note">A NUI envia apenas org, valor e motivo. Saldos e permissoes sao calculados no servidor.</p>');
  }

  function renderTransactionsCard() {
    var current = state();
    if (current.orgView.transactionsLoading) return ui().card('Extrato', 'Historico financeiro.', ui().loading('Carregando extrato'));
    if (current.orgView.transactionsError) return ui().card('Extrato', 'Historico financeiro.', ui().errorBox(current.orgView.transactionsError));
    var items = current.orgView.transactions || [];
    if (!items.length) return ui().card('Extrato', 'Historico financeiro real.', ui().empty('Sem movimentacoes', 'Depositos e saques desta organizacao aparecerao aqui.'), 'bank-statement-card');
    return ui().card('Extrato', 'Historico financeiro real.', '<div class="bank-statement-scroll"><table class="bank-statement-table"><thead><tr><th>Data</th><th>Tipo</th><th>Valor</th><th>Autor</th><th>Motivo</th><th>Saldo apos</th></tr></thead><tbody>' + items.map(function (tx) {
      var type = String(tx.type || '').toLowerCase();
      var signedAmount = type === 'withdraw' ? -Math.abs(fmt().asNumber(tx.amount)) : Math.abs(fmt().asNumber(tx.amount));
      var typeLabel = type === 'withdraw' ? 'Saque' : type === 'deposit' ? 'Deposito' : fmt().formatStatusLabel(tx.type);
      return '<tr><td>' + ui().safeText(fmt().formatDate(tx.createdAt)) + '</td><td>' + ui().badge(typeLabel, type === 'withdraw' ? 'warning' : 'success') + '</td><td class="amount ' + (signedAmount < 0 ? 'negative' : 'positive') + '">' + ui().safeText(fmt().formatMoney(signedAmount)) + '</td><td>' + ui().safeText(tx.actorName || fmt().maskCitizenId(tx.actorCitizenId)) + '</td><td>' + ui().safeText(tx.reason || '-') + '</td><td>' + ui().safeText(fmt().formatMoney(tx.balanceAfter)) + '</td></tr>';
    }).join('') + '</tbody></table></div>', 'bank-statement-card');
  }

  function formatBankError(error) {
    var raw = String(error || '');
    var key = raw.toLowerCase();
    var messages = {
      invalid_amount: 'Informe um valor valido.',
      insufficient_player_funds: 'Saldo insuficiente na sua conta.',
      insufficient_org_funds: 'Saldo insuficiente na organizacao.',
      forbidden: 'Voce nao tem permissao para esta acao.',
      rate_limited: 'Aguarde alguns segundos e tente novamente.',
      invalid_org: 'Organizacao invalida.',
      org_not_found: 'Organizacao nao encontrada.'
    };

    if (messages[key]) return messages[key];
    if (key.indexOf('saldo insuficiente') !== -1) return raw;
    if (key.indexOf('permiss') !== -1) return raw;
    if (key.indexOf('valor') !== -1) return raw;
    return raw || 'Nao foi possivel concluir a operacao.';
  }

  function openBankModal(type) {
    var current = state();
    type = type === 'withdraw' ? 'withdraw' : 'deposit';
    current.bankModal.open = true;
    current.bankModal.type = type;
    current.bankModal.amount = '';
    current.bankModal.reason = '';
    current.bankModal.loading = false;
    current.bankModal.error = null;
    current.orgView.bankActionError = null;
    render();
  }

  function closeBankModal() {
    var current = state();
    if (current.bankModal.loading) return;
    current.bankModal.open = false;
    current.bankModal.type = null;
    current.bankModal.amount = '';
    current.bankModal.reason = '';
    current.bankModal.error = null;
    render();
  }

  function submitBankModal() {
    var current = state();
    var code = selectedOrgCode();
    var action = current.bankModal.type === 'withdraw' ? 'withdraw' : 'deposit';
    var app = document.getElementById('app');
    var amountInput = app && app.querySelector('[data-bank-modal-field="amount"]');
    var reasonInput = app && app.querySelector('[data-bank-modal-field="reason"]');
    var amount = Number(amountInput ? amountInput.value : current.bankModal.amount);
    var reason = reasonInput ? reasonInput.value : current.bankModal.reason;
    var serviceCall = action === 'withdraw' ? window.MZOrgBankService.withdrawOrgAccount : window.MZOrgBankService.depositOrgAccount;
    var successMessage = action === 'withdraw' ? 'Saque realizado com sucesso.' : 'Deposito realizado com sucesso.';

    current.orgView.bankActionMessage = null;
    current.orgView.bankActionError = null;
    current.bankModal.error = null;

    if (!code) {
      current.bankModal.error = 'Organizacao invalida.';
      render();
      return;
    }

    if (!Number.isFinite(amount) || amount <= 0) {
      current.bankModal.error = 'Informe um valor valido.';
      render();
      return;
    }

    current.bankModal.amount = String(amount);
    current.bankModal.reason = reason || '';
    current.bankModal.loading = true;
    render();

    serviceCall(code, amount, reason).then(function (data) {
      current.orgView.bankActionMessage = successMessage;
      current.bankModal.open = false;
      current.bankModal.type = null;
      current.bankModal.amount = '';
      current.bankModal.reason = '';
      current.bankModal.error = null;
      if (data && typeof data.balance !== 'undefined') {
        current.orgView.bank = {
          orgCode: data.orgCode || code,
          balance: data.balance,
          currency: data.currency || 'R$',
          canView: true
        };
      }
      refreshBankData(code);
    }).catch(function (err) {
      current.bankModal.error = formatBankError(err.message);
    }).finally(function () {
      current.bankModal.loading = false;
      render();
    });
  }

  function renderBankModal() {
    var current = state();
    var modal = current.bankModal || {};
    if (!modal.open) return '';

    var isWithdraw = modal.type === 'withdraw';
    var title = isWithdraw ? 'Sacar da organizacao' : 'Depositar na organizacao';
    var buttonLabel = isWithdraw ? 'Confirmar saque' : 'Confirmar deposito';
    var org = getActiveOrg() || current.orgView.detail || {};
    var subtitle = org.name || selectedOrgCode() || 'Organizacao ativa';
    var error = modal.error ? '<div class="bank-modal-error">' + ui().safeText(formatBankError(modal.error)) + '</div>' : '';

    return '<div class="bank-modal-backdrop" role="presentation">' +
      '<section class="bank-modal" role="dialog" aria-modal="true" aria-label="' + ui().safeText(title) + '">' +
        '<div class="bank-modal-header"><div><span>' + ui().safeText(isWithdraw ? 'Saque' : 'Deposito') + '</span><h3>' + ui().safeText(title) + '</h3><p>' + ui().safeText(subtitle) + '</p></div><button class="modal-close" data-action="close-bank-modal" aria-label="Cancelar">x</button></div>' +
        '<div class="bank-modal-body">' +
          '<label><span>Valor</span><input data-bank-modal-field="amount" type="number" min="1" step="1" value="' + ui().safeText(modal.amount) + '" placeholder="Ex: 1000" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Motivo</span><textarea data-bank-modal-field="reason" maxlength="255" rows="3" placeholder="Motivo da movimentacao" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.reason) + '</textarea></label>' +
          error +
        '</div>' +
        '<div class="bank-modal-actions">' +
          '<button class="btn btn-ghost" data-action="close-bank-modal" ' + (modal.loading ? 'disabled' : '') + '>Cancelar</button>' +
          '<button class="bank-confirm-btn ' + (isWithdraw ? 'withdraw' : 'deposit') + '" data-action="submit-bank-modal" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.loading ? 'Processando...' : buttonLabel) + '</button>' +
        '</div>' +
      '</section>' +
    '</div>';
  }

  function renderMembersCard() {
    var current = state();
    var code = selectedOrgCode();
    var contextOrg = perms().contextOrgsForActiveModule().filter(function (org) { return org.code === code; })[0] || null;
    var actionMessages = renderMemberActionMessages();
    var items = current.orgView.members || [];
    var body = '';

    if (current.orgView.membersLoading) {
      body = ui().loading('Carregando membros');
    } else if (current.orgView.membersError) {
      body = ui().errorBox(current.orgView.membersError);
    } else if (!items.length) {
      body = ui().empty('Nenhum membro encontrado', 'Quando houver membros visiveis para sua sessao, eles aparecem aqui.');
    } else {
      body = '<div class="table-scroll members-scroll"><table class="members-table"><thead><tr><th>Nome</th><th>Cargo</th><th>Status</th><th>Entrada</th><th>Acoes</th></tr></thead><tbody>' + items.map(function (member) {
        return '<tr><td class="cell-strong">' + ui().safeText(member.name || 'Membro') + '<span class="cell-subtitle">CID ' + ui().safeText(fmt().maskCitizenId(member.citizenid)) + '</span></td><td>' + ui().safeText(fmt().formatGradeName(member)) + '</td><td><div class="badge-row">' + (member.isLeader ? ui().badge('Lider', 'owner') : '') + (member.isDuty ? ui().badge('Em servico', 'success') : ui().badge('Fora de servico', 'muted')) + ui().badge(fmt().formatStatusLabel(member.status || 'ativo'), 'info') + '</div></td><td>' + ui().safeText(fmt().formatDate(member.joinedAt)) + '</td><td>' + renderMemberActionButtons(member, contextOrg) + '</td></tr>';
      }).join('') + '</tbody></table></div>';
    }

    return '<section class="members-section">' +
      '<div class="members-top-grid">' +
        '<article class="member-summary-card"><span>Total membros</span><strong>' + ui().safeText(items.length) + '</strong><small>Membros ativos nesta organizacao.</small></article>' +
        '<article class="member-summary-card"><span>Seu cargo</span><strong>' + ui().safeText(fmt().formatGradeName(contextOrg || current.orgView.detail || {})) + '</strong><small>Acoes liberadas dependem do cargo.</small></article>' +
        renderMemberInviteActionCard(contextOrg) +
      '</div>' +
      actionMessages +
      '<article class="card members-list-card"><div class="card-header"><h3>Lista de membros</h3><p>Equipe, cargos e acoes permitidas para a organizacao ativa.</p></div><div class="card-body">' + body + '</div></article>' +
    '</section>';
  }

  function canInviteMembers(contextOrg) {
    var current = state();
    if (!current.session) return false;
    if (current.session.user && current.session.user.isOwner) return true;
    if (perms().isStaffAccess(current.session)) return true;

    var caps = [];
    if (contextOrg && Array.isArray(contextOrg.capabilities)) caps = caps.concat(contextOrg.capabilities);
    if (current.orgView.detail && Array.isArray(current.orgView.detail.capabilities)) caps = caps.concat(current.orgView.detail.capabilities);

    return caps.indexOf('members.invite') !== -1;
  }

  function canRemoveMembers(contextOrg) {
    var current = state();
    if (!current.session) return false;
    if (current.session.user && current.session.user.isOwner) return true;
    if (perms().isStaffAccess(current.session)) return true;

    var caps = [];
    if (contextOrg && Array.isArray(contextOrg.capabilities)) caps = caps.concat(contextOrg.capabilities);
    if (current.orgView.detail && Array.isArray(current.orgView.detail.capabilities)) caps = caps.concat(current.orgView.detail.capabilities);

    return caps.indexOf('members.remove') !== -1 || caps.indexOf('members.kick') !== -1 || caps.indexOf('manage.members') !== -1;
  }

  function canChangeMemberGrade(contextOrg, action) {
    var current = state();
    if (!current.session) return false;
    if (current.session.user && current.session.user.isOwner) return true;
    if (perms().isStaffAccess(current.session)) return true;

    var caps = [];
    if (contextOrg && Array.isArray(contextOrg.capabilities)) caps = caps.concat(contextOrg.capabilities);
    if (current.orgView.detail && Array.isArray(current.orgView.detail.capabilities)) caps = caps.concat(current.orgView.detail.capabilities);

    var specific = action === 'demote' ? 'members.demote' : 'members.promote';
    return caps.indexOf(specific) !== -1 || caps.indexOf('manage.members') !== -1;
  }

  function renderMemberActionMessages() {
    var current = state();
    var inviteMessage = current.orgView.inviteMessage ? '<div class="inline-message success">' + ui().safeText(current.orgView.inviteMessage) + '</div>' : '';
    var inviteError = current.orgView.inviteError ? '<div class="inline-message error-inline">' + ui().safeText(current.orgView.inviteError) + '</div>' : '';
    var message = current.orgView.removeMessage ? '<div class="inline-message success">' + ui().safeText(current.orgView.removeMessage) + '</div>' : '';
    var error = current.orgView.removeError ? '<div class="inline-message error-inline">' + ui().safeText(current.orgView.removeError) + '</div>' : '';
    var gradeMessage = current.orgView.gradeMessage ? '<div class="inline-message success">' + ui().safeText(current.orgView.gradeMessage) + '</div>' : '';
    var gradeError = current.orgView.gradeError ? '<div class="inline-message error-inline">' + ui().safeText(current.orgView.gradeError) + '</div>' : '';
    return inviteMessage + inviteError + message + error + gradeMessage + gradeError;
  }

  function normalizeCitizenForCompare(value) {
    return String(value || '').replace(/^\s+|\s+$/g, '').toUpperCase();
  }

  function currentUserCitizenId() {
    var current = state();
    return current.session && current.session.user ? current.session.user.citizenid : '';
  }

  function isSelfMember(memberOrCitizenId) {
    var myCitizenId = normalizeCitizenForCompare(currentUserCitizenId());
    var targetCitizenId = typeof memberOrCitizenId === 'object'
      ? normalizeCitizenForCompare(memberOrCitizenId && memberOrCitizenId.citizenid)
      : normalizeCitizenForCompare(memberOrCitizenId);
    return !!myCitizenId && !!targetCitizenId && myCitizenId === targetCitizenId;
  }

  function formatMemberActionError(message, fallback) {
    var error = String(message || '');
    if (error.indexOf('self_action') !== -1 || error.indexOf('proprio cargo') !== -1) return 'Voce nao pode alterar seu proprio cargo.';
    if (error.indexOf('self_remove') !== -1 || error.indexOf('remover a si mesmo') !== -1) return 'Voce nao pode remover a si mesmo.';
    if (error.indexOf('leader_permission_required') !== -1 || error.indexOf('lideranca') !== -1 || error.indexOf('cargo maximo') !== -1) return 'Voce nao tem permissao para alterar lideranca ou cargo maximo.';
    if (error.indexOf('target_higher_or_equal') !== -1 || error.indexOf('cargo igual ou superior') !== -1) return 'Voce nao pode alterar membro de cargo igual ou superior.';
    if (error.indexOf('promotion_above_actor') !== -1) return 'Voce nao pode promover para cargo igual ou superior ao seu.';
    if (error.indexOf('protected_target') !== -1 || error.indexOf('cargo protegido') !== -1) return 'Este membro possui cargo protegido.';
    if (error.indexOf('forbidden') !== -1 || error.indexOf('Sem permissao') !== -1) return 'Voce nao tem permissao para esta acao.';
    if (error.indexOf('not_member') !== -1 || error.indexOf('membership_not_found') !== -1) return 'Membro nao encontrado nesta organizacao.';
    if (error.indexOf('already_member') !== -1) return 'Esse player ja e membro da organizacao.';
    if (error.indexOf('target_not_found') !== -1 || error.indexOf('invalid_target') !== -1) return 'Player nao encontrado.';
    if (error.indexOf('Aguarde') !== -1 || error.indexOf('rate_limited') !== -1) return 'Aguarde alguns segundos e tente novamente.';
    return error || fallback || 'Nao foi possivel concluir a acao.';
  }

  function renderMemberInviteActionCard(contextOrg) {
    var current = state();
    var allowed = canInviteMembers(contextOrg);
    return '<button class="member-action-card invite" type="button" data-action="open-member-modal" ' + (!allowed || current.memberModal.loading ? 'disabled' : '') + '>' +
      '<strong>Convidar</strong>' +
      '<span>' + ui().safeText(allowed ? 'Adicionar membro por CitizenID.' : 'Seu cargo atual nao pode convidar.') + '</span>' +
    '</button>';
  }

  function inviteGradeOptions(contextOrg) {
    var current = state();
    var model = current.orgView.access || {};
    var grades = Array.isArray(model.grades) ? model.grades.slice() : [];

    if (!grades.length) return [];
    if (current.session && current.session.user && current.session.user.isOwner) return grades;

    var caps = [];
    if (contextOrg && Array.isArray(contextOrg.capabilities)) caps = caps.concat(contextOrg.capabilities);
    if (current.orgView.detail && Array.isArray(current.orgView.detail.capabilities)) caps = caps.concat(current.orgView.detail.capabilities);
    var globalCaps = current.session && current.session.user && Array.isArray(current.session.user.globalPermissions)
      ? current.session.user.globalPermissions
      : [];
    var canSetLeader = caps.indexOf('members.set_leader') !== -1
      || globalCaps.indexOf('staff.orgs.set_leader') !== -1;
    var maxLevel = grades.reduce(function (max, grade) {
      return Math.max(max, fmt().asNumber(grade.level, 0));
    }, 0);

    if (perms().isStaffAccess(current.session)) {
      return canSetLeader ? grades : grades.filter(function (grade) {
        return fmt().asNumber(grade.level, 0) < maxLevel;
      });
    }

    var actorLevel = fmt().asNumber(contextOrg && contextOrg.grade, 0);
    return grades.filter(function (grade) {
      var level = fmt().asNumber(grade.level, 0);
      if (level <= 0 || level >= actorLevel) return false;
      if (maxLevel > 0 && level >= maxLevel && !canSetLeader) return false;
      return true;
    });
  }

  function renderInviteGradeSelect(contextOrg) {
    var current = state();
    var grades = inviteGradeOptions(contextOrg);
    var loading = current.orgView.accessLoading;
    var helper = loading ? 'Carregando cargos...' : 'Se nada for escolhido, o core usa a menor grade segura.';

    if (!grades.length) {
      return '<label><span>Grade inicial</span><select data-member-modal-grade disabled><option value="">Cargo inicial automatico</option></select><small>' + ui().safeText(helper) + '</small></label>';
    }

    return '<label><span>Grade inicial</span><select data-member-modal-grade ' + (current.memberModal.loading ? 'disabled' : '') + '>' +
      '<option value="">Cargo inicial automatico</option>' +
      grades.map(function (grade) {
        var selected = String(current.memberModal.gradeLevel || '') === String(grade.level || '') ? ' selected' : '';
        return '<option value="' + ui().escapeHtml(grade.level) + '" data-grade-code="' + ui().escapeHtml(grade.code || '') + '"' + selected + '>' + ui().safeText(grade.name || grade.code) + ' (nivel ' + ui().safeText(grade.level) + ')</option>';
      }).join('') +
      '</select><small>' + ui().safeText(helper) + '</small></label>';
  }

  function openMemberInviteModal() {
    var current = state();
    current.orgView.inviteMessage = null;
    current.orgView.inviteError = null;
    current.memberModal.open = true;
    current.memberModal.citizenid = '';
    current.memberModal.gradeLevel = '';
    current.memberModal.gradeCode = '';
    current.memberModal.loading = false;
    current.memberModal.error = null;
    render();
  }

  function closeMemberInviteModal() {
    var current = state();
    if (current.memberModal.loading) return;
    current.memberModal.open = false;
    current.memberModal.error = null;
    render();
  }

  function formatMemberInviteError(message) {
    var error = String(message || '');
    if (error.indexOf('target_not_found') !== -1 || error.indexOf('Player nao encontrado') !== -1) return 'Player nao encontrado.';
    if (error.indexOf('already_member') !== -1 || error.indexOf('ja e membro') !== -1) return 'Esse player ja e membro da organizacao.';
    if (error.indexOf('self_target') !== -1 || error.indexOf('si mesmo') !== -1) return 'Voce nao pode convidar a si mesmo.';
    if (error.indexOf('leader_permission_required') !== -1 || error.indexOf('lideranca') !== -1 || error.indexOf('cargo maximo') !== -1) return 'Voce nao tem permissao para alterar lideranca ou cargo maximo.';
    if (error.indexOf('forbidden') !== -1 || error.indexOf('Sem permissao') !== -1) return 'Voce nao tem permissao para convidar.';
    if (error.indexOf('invalid_grade') !== -1 || error.indexOf('grade_not_allowed') !== -1 || error.indexOf('Cargo inicial') !== -1) return 'Cargo inicial invalido ou nao permitido.';
    if (error.indexOf('invalid_org') !== -1 || error.indexOf('Organizacao invalida') !== -1) return 'Organizacao invalida.';
    return error || 'Nao foi possivel convidar o membro.';
  }

  function submitMemberInviteModal() {
    var current = state();
    var app = document.getElementById('app');
    var code = selectedOrgCode();
    var citizenInput = app && app.querySelector('[data-member-modal-citizenid]');
    var gradeSelect = app && app.querySelector('[data-member-modal-grade]');
    var citizenid = citizenInput ? citizenInput.value.replace(/^\s+|\s+$/g, '') : '';
    var grade = null;

    current.orgView.inviteMessage = null;
    current.orgView.inviteError = null;
    current.memberModal.error = null;

    if (!code) {
      current.memberModal.error = 'Organizacao invalida.';
      render();
      return;
    }

    if (!citizenid) {
      current.memberModal.error = 'Informe o CitizenID do player.';
      render();
      return;
    }

    if (gradeSelect && gradeSelect.value) {
      var selectedOption = gradeSelect.options[gradeSelect.selectedIndex];
      grade = {
        gradeLevel: gradeSelect.value,
        gradeCode: selectedOption ? selectedOption.getAttribute('data-grade-code') : ''
      };
    }

    current.memberModal.citizenid = citizenid;
    current.memberModal.gradeLevel = grade ? grade.gradeLevel : '';
    current.memberModal.gradeCode = grade ? grade.gradeCode : '';
    current.memberModal.loading = true;
    current.orgView.inviteLoading = true;
    render();

    window.MZOrgMemberService.inviteMember(code, citizenid, grade).then(function (data) {
      current.orgView.inviteMessage = 'Membro convidado na grade ' + (data.gradeCode || data.grade || 'inicial') + '.';
      current.memberModal.open = false;
      current.memberModal.citizenid = '';
      current.memberModal.gradeLevel = '';
      current.memberModal.gradeCode = '';
      return reloadMembers(code);
    }).catch(function (err) {
      current.memberModal.error = formatMemberInviteError(err.message);
    }).finally(function () {
      current.memberModal.loading = false;
      current.orgView.inviteLoading = false;
      render();
    });
  }

  function inviteMember() {
    submitMemberInviteModal();
  }

  function renderMemberModal() {
    var current = state();
    var modal = current.memberModal || {};
    if (!modal.open) return '';

    var org = getActiveOrg() || current.orgView.detail || {};
    var subtitle = org.name || selectedOrgCode() || 'Organizacao ativa';
    var contextOrg = perms().contextOrgsForActiveModule().filter(function (item) { return item.code === selectedOrgCode(); })[0] || null;
    var error = modal.error ? '<div class="member-modal-error">' + ui().safeText(formatMemberInviteError(modal.error)) + '</div>' : '';

    return '<div class="member-modal-backdrop" role="presentation">' +
      '<section class="member-modal" role="dialog" aria-modal="true" aria-label="Convidar membro">' +
        '<div class="member-modal-header"><div><span>Convite</span><h3>Convidar membro</h3><p>' + ui().safeText(subtitle) + '</p></div><button class="modal-close" data-action="close-member-modal" aria-label="Cancelar">x</button></div>' +
        '<div class="member-modal-body">' +
          '<label><span>CitizenID</span><input data-member-modal-citizenid maxlength="64" value="' + ui().safeText(modal.citizenid) + '" placeholder="CitizenID ou passaporte" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          renderInviteGradeSelect(contextOrg) +
          '<small class="soft-note member-modal-note">A grade e validada pelo servidor.</small>' +
          error +
        '</div>' +
        '<div class="member-modal-actions">' +
          '<button class="btn btn-ghost" data-action="close-member-modal" ' + (modal.loading ? 'disabled' : '') + '>Cancelar</button>' +
          '<button class="member-confirm-btn invite" data-action="submit-member-modal" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.loading ? 'Convidando...' : 'Confirmar convite') + '</button>' +
        '</div>' +
      '</section>' +
    '</div>';
  }

  function renderMemberActionButtons(member, contextOrg) {
    if (!member || !member.citizenid) return ui().safeText('-');

    var current = state();
    var safeCitizen = ui().escapeHtml(member.citizenid);
    var removeLoading = current.orgView.removeLoading && current.orgView.removeCitizenId === member.citizenid;
    var promoteLoading = current.orgView.gradeLoading && current.orgView.gradeAction === 'promote' && current.orgView.gradeCitizenId === member.citizenid;
    var demoteLoading = current.orgView.gradeLoading && current.orgView.gradeAction === 'demote' && current.orgView.gradeCitizenId === member.citizenid;
    var buttons = [];

    if (isSelfMember(member)) {
      return '<div class="action-row">' + ui().badge('Voce', 'info') + '</div>';
    }

    if (canChangeMemberGrade(contextOrg, 'promote')) {
      buttons.push('<button class="btn btn-ghost" data-action="promote-member" data-citizenid="' + safeCitizen + '" ' + (promoteLoading ? 'disabled' : '') + '>' + (promoteLoading ? 'Promovendo...' : 'Promover') + '</button>');
    }

    if (canChangeMemberGrade(contextOrg, 'demote')) {
      buttons.push('<button class="btn btn-ghost" data-action="demote-member" data-citizenid="' + safeCitizen + '" ' + (demoteLoading ? 'disabled' : '') + '>' + (demoteLoading ? 'Rebaixando...' : 'Rebaixar') + '</button>');
    }

    if (canRemoveMembers(contextOrg)) {
      buttons.push('<button class="btn btn-ghost danger-btn" data-action="remove-member" data-citizenid="' + safeCitizen + '" ' + (removeLoading ? 'disabled' : '') + '>' + (removeLoading ? 'Removendo...' : 'Remover') + '</button>');
    }

    if (!buttons.length) return '<button class="btn btn-ghost" disabled>Sem acesso</button>';
    return '<div class="action-row">' + buttons.join('') + '</div>';
  }

  function removeMember(citizenid) {
    var current = state();
    var code = selectedOrgCode();

    current.orgView.removeMessage = null;
    current.orgView.removeError = null;

    if (!code) {
      current.orgView.removeError = 'Organizacao invalida.';
      render();
      return;
    }

    if (!citizenid) {
      current.orgView.removeError = 'Membro alvo invalido.';
      render();
      return;
    }

    if (isSelfMember(citizenid)) {
      current.orgView.removeError = 'Voce nao pode remover a si mesmo.';
      current.orgView.removeLoading = false;
      current.orgView.removeCitizenId = null;
      render();
      return;
    }

    if (!confirmMemberInline('remove', citizenid, 'Clique novamente em Remover para confirmar esta acao.')) return;

    current.orgView.removeLoading = true;
    current.orgView.removeCitizenId = citizenid;
    render();

    window.MZOrgMemberService.removeMember(code, citizenid).then(function () {
      current.orgView.removeMessage = 'Membro removido da organizacao.';
      clearMemberInlineConfirm();
      return reloadMembers(code);
    }).catch(function (err) {
      current.orgView.removeError = formatMemberActionError(err.message, 'Nao foi possivel remover membro.');
    }).finally(function () {
      current.orgView.removeLoading = false;
      current.orgView.removeCitizenId = null;
      render();
    });
  }

  function changeMemberGrade(citizenid, action) {
    var current = state();
    var code = selectedOrgCode();
    action = action === 'demote' ? 'demote' : 'promote';

    current.orgView.gradeMessage = null;
    current.orgView.gradeError = null;

    if (!code) {
      current.orgView.gradeError = 'Organizacao invalida.';
      render();
      return;
    }

    if (!citizenid) {
      current.orgView.gradeError = 'Membro alvo invalido.';
      render();
      return;
    }

    if (isSelfMember(citizenid)) {
      current.orgView.gradeError = 'Voce nao pode alterar seu proprio cargo.';
      current.orgView.gradeLoading = false;
      current.orgView.gradeAction = null;
      current.orgView.gradeCitizenId = null;
      render();
      return;
    }

    var confirmMessage = action === 'demote'
      ? 'Clique novamente em Rebaixar para confirmar esta acao.'
      : 'Clique novamente em Promover para confirmar esta acao.';
    if (!confirmMemberInline(action, citizenid, confirmMessage)) return;

    current.orgView.gradeLoading = true;
    current.orgView.gradeAction = action;
    current.orgView.gradeCitizenId = citizenid;
    render();

    var request = action === 'demote'
      ? window.MZOrgMemberService.demoteMember(code, citizenid)
      : window.MZOrgMemberService.promoteMember(code, citizenid);

    request.then(function (data) {
      current.orgView.gradeMessage = action === 'demote'
        ? 'Membro rebaixado para ' + (data.newGradeCode || data.newGrade || 'cargo anterior') + '.'
        : 'Membro promovido para ' + (data.newGradeCode || data.newGrade || 'proximo cargo') + '.';
      clearMemberInlineConfirm();
      return reloadMembers(code);
    }).catch(function (err) {
      current.orgView.gradeError = formatMemberActionError(err.message, 'Nao foi possivel alterar cargo.');
    }).finally(function () {
      current.orgView.gradeLoading = false;
      current.orgView.gradeAction = null;
      current.orgView.gradeCitizenId = null;
      render();
    });
  }

  function confirmMemberInline(action, citizenid, message) {
    var current = state();
    var confirmed = current.orgView.confirmAction === action && current.orgView.confirmCitizenId === citizenid;
    if (confirmed) return true;

    current.orgView.confirmAction = action;
    current.orgView.confirmCitizenId = citizenid;

    if (action === 'remove') {
      current.orgView.removeMessage = message;
      current.orgView.removeError = null;
    } else {
      current.orgView.gradeMessage = message;
      current.orgView.gradeError = null;
    }

    render();
    return false;
  }

  function clearMemberInlineConfirm() {
    state().orgView.confirmAction = null;
    state().orgView.confirmCitizenId = null;
  }

  function reloadMembers(orgCode) {
    var current = state();
    current.orgView.membersLoading = true;
    current.orgView.membersError = null;
    render();

    return window.MZOrgMemberService.listMembers(orgCode).then(function (data) {
      current.orgView.members = Array.isArray(data) ? data : [];
    }).catch(function (err) {
      current.orgView.membersError = err.message;
    }).finally(function () {
      current.orgView.membersLoading = false;
    });
  }

  function renderStaffPage() {
    if (!perms().canViewModule(state().session, 'staff')) return '<div class="screen">' + ui().errorBox('Sem permissao para visualizar staff.') + '</div>';
    var current = state();
    var section = current.activeSection || 'overview';

    return '<div class="screen">' +
      '<div class="page-heading staff-heading"><div><span class="module-kicker">Staff</span><h2>Administracao</h2><p>Dashboard seguro para consulta e auditoria. Escritas restritas ficam isoladas em acoes administrativas.</p></div>' + ui().badge(perms().getAccessLabel(), perms().getAccessVariant()) + '</div>' +
      renderStaffMetrics() +
      renderStaffTabs(section) +
      '<section class="staff-section">' + renderStaffSection(section) + '</section>' +
    '</div>';
  }

  function renderStaffMetrics() {
    var current = state();
    var orgCount = current.orgs.loaded ? current.orgs.data.length : (current.orgs.loading ? '...' : '-');
    var memberTotal = staffMemberTotal();
    var logCount = current.logs.loaded ? current.logs.data.length : (current.logs.loading ? '...' : '-');
    var availableActions = (canShowStaffLeaderCard() ? 1 : 0) + (canCreateStaffOrg() ? 1 : 0);
    var actionCount = availableActions + (availableActions === 1 ? ' disponivel' : ' disponiveis');

    return '<div class="staff-grid">' +
      renderStaffMetric('assets/icons/orgs.svg', orgCount, 'Organizacoes', current.orgs.loading ? 'Carregando consulta' : 'Visiveis para sua sessao', 'O') +
      renderStaffMetric('assets/icons/staff.svg', memberTotal == null ? '-' : memberTotal, 'Membros', memberTotal == null ? 'Nao carregado sem callback dedicado' : 'Total informado pelas orgs', 'M') +
      renderStaffMetric('assets/icons/logs.svg', logCount, 'Logs recentes', current.logs.loading ? 'Carregando auditoria' : 'Retornados pelo servidor', 'L') +
      renderStaffMetric('assets/icons/lock.svg', actionCount, 'Acoes sensiveis', 'Demais acoes permanecem bloqueadas', 'A') +
    '</div>';
  }

  function renderStaffMetric(icon, value, title, description, fallback) {
    return '<div class="staff-metric-card">' +
      ui().renderIcon(icon, fallback || '*', 'metric-icon') +
      '<strong>' + ui().safeText(value) + '</strong>' +
      '<span>' + ui().safeText(title) + '</span>' +
      '<small>' + ui().safeText(description) + '</small>' +
    '</div>';
  }

  function staffMemberTotal() {
    var orgs = state().orgs.data || [];
    var total = 0;
    var hasValue = false;
    orgs.forEach(function (org) {
      var count = Number(org.memberCount);
      if (Number.isFinite(count)) {
        total += count;
        hasValue = true;
      }
    });
    return hasValue ? total : null;
  }

  function renderStaffTabs(active) {
    return '<nav class="staff-tabs" aria-label="Secoes staff">' + staffSections.map(function (section) {
      return '<button class="staff-tab' + (section.id === active ? ' is-active' : '') + '" data-section="' + ui().escapeHtml(section.id) + '">' + ui().safeText(section.label) + '</button>';
    }).join('') + '</nav>';
  }

  function renderStaffSection(section) {
    if (section === 'orgs') return renderStaffOrgsSection();
    if (section === 'logs') return renderStaffLogsSection();
    if (section === 'audit') return renderStaffAuditSection();
    if (section === 'actions') return renderStaffActionsSection();
    return renderStaffOverviewSection();
  }

  function renderStaffOverviewSection() {
    var recentLogs = (state().logs.data || []).slice(0, 5);
    var auditLogs = sensitiveStaffLogs().slice(0, 5);

    return '<div class="two-col">' +
      ui().card('Resumo administrativo', 'Consulta separada do contexto pessoal de /org e /gang.', '<div class="data-list">' +
        '<div><span>Modo</span><strong>Administrativo</strong></div>' +
        '<div><span>Permissao</span><strong>' + ui().safeText(perms().getAccessLabel()) + '</strong></div>' +
        '<div><span>Acoes reais liberadas</span><strong>' + ui().safeText([canCreateStaffOrg() ? 'Criar org' : null, canShowStaffLeaderCard() ? 'Definir lider' : null].filter(Boolean).join(', ') || 'Nenhuma') + '</strong></div>' +
        '<div><span>Criacao por template</span><strong>' + ui().safeText(canCreateStaffOrg() ? 'Disponivel' : 'Bloqueada') + '</strong></div>' +
      '</div>') +
      ui().card('Navegacao', 'Use as abas internas para consultar orgs, logs, auditoria e acoes administrativas.', '<p class="soft-note">Os atalhos duplicados foram compactados; as abas acima sao a navegacao principal do Staff.</p>') +
      ui().card('Ultimos logs', 'Resumo sem payload tecnico bruto.', renderStaffLogList(recentLogs, 'Nenhum log recente retornado.')) +
      ui().card('Eventos sensiveis', 'Recorte local dos logs recentes.', renderStaffLogList(auditLogs, 'Nenhum evento sensivel recente encontrado.')) +
    '</div>';
  }

  function renderStaffOrgsSection() {
    var current = state();
    if (current.staffOrgDetails && current.staffOrgDetails.open) {
      return renderStaffOrgDetailView() + renderStaffCreateOrgModal();
    }

    var body = current.orgs.loading
      ? ui().loading('Carregando organizacoes')
      : current.orgs.error
        ? ui().errorBox(current.orgs.error)
        : !current.orgs.data.length
          ? ui().empty('Nenhuma organizacao visivel', 'O servidor nao retornou orgs para esta sessao.')
          : renderStaffOrgList(current.orgs.data);

    return renderStaffCreateOrgPanel() +
      ui().card('Organizacoes', 'Consulta read-only das orgs retornadas para sua sessao.', body, 'staff-list-card') +
      renderStaffCreateOrgModal();
  }

  function renderStaffOrgList(items) {
    return '<div class="staff-org-list"><table><thead><tr><th>Organizacao</th><th>Tipo</th><th>Membros</th><th>Status</th><th>Detalhes</th></tr></thead><tbody>' + items.map(function (org) {
      var members = Number.isFinite(Number(org.memberCount)) ? org.memberCount : '-';
      var statusLabel = org.active === false ? 'Inativa' : (org.is_public ? 'Publica' : 'Privada');
      var statusVariant = org.active === false ? 'warning' : (org.is_public ? 'info' : 'muted');
      return '<tr><td class="cell-strong">' + ui().safeText(org.name || org.code) + '<span class="cell-subtitle">' + ui().safeText(org.code || '-') + '</span></td><td>' + ui().badge(fmt().formatOrgType(org.type || 'legal'), staffOrgVariant(org.type)) + '</td><td>' + ui().safeText(members) + '</td><td>' + ui().badge(org.locked ? 'Bloqueada' : statusLabel, org.locked ? 'warning' : statusVariant) + '</td><td><button class="btn btn-ghost" data-action="staff-view-org-details" data-org-code="' + ui().escapeHtml(org.code || '') + '">Ver detalhes</button></td></tr>';
    }).join('') + '</tbody></table></div>';
  }

  function findStaffOrgByCode(code) {
    return (state().orgs.data || []).filter(function (org) {
      return String(org.code || '') === String(code || '');
    })[0] || null;
  }

  function detailErrorMessage(error) {
    var message = error && error.message ? error.message : error;
    return message || 'Nao foi possivel carregar este bloco.';
  }

  function safeDetail(promise, fallback) {
    return promise.then(function (data) {
      return { ok: true, data: data };
    }).catch(function (error) {
      return { ok: false, data: fallback, error: detailErrorMessage(error) };
    });
  }

  function openStaffOrgDetails(orgCode, options) {
    var current = state();
    var details = current.staffOrgDetails;
    options = options || {};
    orgCode = String(orgCode || '').replace(/^\s+|\s+$/g, '');
    if (!orgCode) return;

    var switchingOrg = details.orgCode !== orgCode;
    if (switchingOrg) {
      current.staffLeader.orgCode = '';
      current.staffLeader.citizenid = '';
      current.staffLeader.reason = '';
      current.staffLeader.message = null;
      current.staffLeader.error = null;
      current.staffLeader.loading = false;
      current.staffEditOrgBasic.open = false;
      current.staffEditOrgBasic.orgCode = null;
      current.staffEditOrgBasic.message = null;
      current.staffEditOrgBasic.error = null;
      current.staffEditOrgBasic.loading = false;
      current.staffGradeModal.open = false;
      current.staffGradeModal.loading = false;
      current.staffGradeModal.message = null;
      current.staffGradeModal.error = null;
      current.staffArchiveModal.open = false;
      current.staffArchiveModal.loading = false;
      current.staffArchiveModal.error = null;
      current.staffPermissionModal.open = false;
      current.staffPermissionModal.loading = false;
      current.staffPermissionModal.error = null;
      current.staffPermissionModal.message = null;
    }

    details.open = true;
    details.orgCode = orgCode;
    details.activeTab = options.tab || (switchingOrg ? 'summary' : details.activeTab) || 'summary';
    details.loading = true;
    details.error = null;
    details.data = {
      org: findStaffOrgByCode(orgCode),
      access: null,
      members: [],
      bank: null,
      transactions: [],
      goals: [],
      recruitment: [],
      logs: [],
      errors: {}
    };
    render();

    var tasks = {
      org: safeDetail(window.MZOrgService.getOrg(orgCode), details.data.org),
      access: safeDetail(window.MZOrgAccessService.getOrgAccess(orgCode), null),
      members: safeDetail(window.MZOrgMemberService.listMembers(orgCode), []),
      bank: safeDetail(window.MZOrgBankService.getOrgBank(orgCode), null),
      transactions: safeDetail(window.MZOrgBankService.listOrgBankTransactions(orgCode, { limit: 10 }), []),
      goals: safeDetail(window.MZOrgGoalService.listGoals({ orgCode: orgCode, limit: 10 }), []),
      recruitment: safeDetail(window.MZOrgRecruitmentService.listRecruitment(orgCode, { limit: 10 }), []),
      logs: safeDetail(window.MZOrgLogService.listLogs({ orgCode: orgCode, limit: 20 }), [])
    };

    Promise.all([
      tasks.org,
      tasks.access,
      tasks.members,
      tasks.bank,
      tasks.transactions,
      tasks.goals,
      tasks.recruitment,
      tasks.logs
    ]).then(function (results) {
      var keys = ['org', 'access', 'members', 'bank', 'transactions', 'goals', 'recruitment', 'logs'];
      var data = {
        org: details.data && details.data.org,
        access: null,
        members: [],
        bank: null,
        transactions: [],
        goals: [],
        recruitment: [],
        logs: [],
        errors: {}
      };

      results.forEach(function (result, index) {
        var key = keys[index];
        data[key] = result.data;
        if (!result.ok) data.errors[key] = result.error;
      });

      if (!data.org) data.org = findStaffOrgByCode(orgCode);
      details.data = data;
    }).catch(function (error) {
      details.error = detailErrorMessage(error);
    }).finally(function () {
      details.loading = false;
      render();
    });
  }

  function closeStaffOrgDetails() {
    var details = state().staffOrgDetails;
    details.open = false;
    details.orgCode = null;
    details.activeTab = 'summary';
    details.loading = false;
    details.error = null;
    details.data = null;
    state().staffLeader.orgCode = '';
    state().staffLeader.citizenid = '';
    state().staffLeader.reason = '';
    state().staffLeader.loading = false;
    state().staffLeader.message = null;
    state().staffLeader.error = null;
    state().staffEditOrgBasic.open = false;
    state().staffEditOrgBasic.orgCode = null;
    state().staffEditOrgBasic.loading = false;
    state().staffEditOrgBasic.message = null;
    state().staffEditOrgBasic.error = null;
    state().staffGradeModal.open = false;
    state().staffGradeModal.loading = false;
    state().staffGradeModal.message = null;
    state().staffGradeModal.error = null;
    state().staffArchiveModal.open = false;
    state().staffArchiveModal.loading = false;
    state().staffArchiveModal.error = null;
    state().staffPermissionModal.open = false;
    state().staffPermissionModal.loading = false;
    state().staffPermissionModal.error = null;
    state().staffPermissionModal.message = null;
    render();
  }

  function setStaffOrgDetailTab(tab) {
    var valid = staffOrgDetailTabs.some(function (item) { return item.id === tab; });
    if (!valid) return;
    state().staffOrgDetails.activeTab = tab;
    render();
  }

  function staffOrgDetailData() {
    return state().staffOrgDetails.data || { errors: {} };
  }

  function renderStaffOrgDetailView() {
    var details = state().staffOrgDetails || {};
    var data = staffOrgDetailData();
    var org = data.org || findStaffOrgByCode(details.orgCode) || {};
    var title = org.name || details.orgCode || 'Organizacao';
    var active = details.activeTab || 'summary';

    if (details.error) {
      return '<section class="staff-org-detail">' +
        '<button class="btn btn-ghost staff-org-detail-back" data-action="staff-close-org-details">Voltar para organizacoes</button>' +
        ui().card('Detalhes da organizacao', 'Consulta read-only.', ui().errorBox(details.error), 'staff-list-card') +
      '</section>';
    }

    return '<section class="staff-org-detail">' +
      '<div class="staff-org-detail-header">' +
        '<button class="btn btn-ghost staff-org-detail-back" data-action="staff-close-org-details">Voltar para organizacoes</button>' +
        '<div><span class="module-kicker">Organizacao</span><h3>' + ui().safeText(title) + '</h3><p>' + ui().safeText(details.orgCode || org.code || '-') + ' - consulta administrativa read-only</p></div>' +
        '<div class="badge-row">' + ui().badge(fmt().formatOrgType(org.type || org.typeCode || 'legal'), staffOrgVariant(org.type || org.typeCode)) + ui().badge(details.loading ? 'Carregando' : 'Read-only', details.loading ? 'warning' : 'muted') + '</div>' +
      '</div>' +
      renderStaffOrgDetailTabs(active) +
      '<div class="staff-org-detail-body">' + renderStaffOrgDetailTab(active, data, details.loading) + '</div>' +
    '</section>';
  }

  function renderStaffOrgDetailTabs(active) {
    return '<nav class="staff-org-detail-tabs" aria-label="Detalhes da organizacao">' + staffOrgDetailTabs.map(function (tab) {
      return '<button class="staff-org-detail-tab' + (tab.id === active ? ' is-active' : '') + '" data-staff-org-detail-tab="' + ui().escapeHtml(tab.id) + '">' + ui().safeText(tab.label) + '</button>';
    }).join('') + '</nav>';
  }

  function renderStaffOrgDetailTab(tab, data, loading) {
    if (loading) return ui().card('Carregando detalhes', 'Buscando dados autorizados por orgCode.', ui().loading('Carregando detalhes da organizacao'), 'staff-org-detail-card');
    if (tab === 'grades') return renderStaffOrgDetailGrades(data);
    if (tab === 'members') return renderStaffOrgDetailMembers(data);
    if (tab === 'bank') return renderStaffOrgDetailBank(data);
    if (tab === 'goals') return renderStaffOrgDetailGoals(data);
    if (tab === 'recruitment') return renderStaffOrgDetailRecruitment(data);
    if (tab === 'logs') return renderStaffOrgDetailLogs(data);
    if (tab === 'actions') return renderStaffOrgDetailActions(data);
    return renderStaffOrgDetailSummary(data);
  }

  function renderDetailBlockError(data, key) {
    return data.errors && data.errors[key]
      ? '<div class="inline-message error-inline">' + ui().safeText(data.errors[key]) + '</div>'
      : '';
  }

  function renderStaffOrgDetailSummary(data) {
    var org = data.org || {};
    var members = Array.isArray(data.members) ? data.members : [];
    var goals = Array.isArray(data.goals) ? data.goals : [];
    var recruitment = Array.isArray(data.recruitment) ? data.recruitment : [];
    var pendingRecruitment = recruitment.filter(function (item) { return String(item.status || '').toLowerCase() === 'pending'; }).length;
    var activeGoals = goals.filter(function (goal) { return String(goal.status || 'active').toLowerCase() === 'active'; }).length;

    var flags = '<div class="badge-row">' +
      ui().badge(org.hasSalary || org.has_salary ? 'Salario' : 'Sem salario', org.hasSalary || org.has_salary ? 'info' : 'muted') +
      ui().badge(org.hasSharedAccount || org.has_shared_account ? 'Conta compartilhada' : 'Sem conta', org.hasSharedAccount || org.has_shared_account ? 'success' : 'muted') +
      ui().badge(org.hasStorage || org.has_storage ? 'Bau/storage' : 'Sem storage', org.hasStorage || org.has_storage ? 'info' : 'muted') +
      ui().badge(org.active === false ? 'Inativa' : 'Ativa', org.active === false ? 'warning' : 'success') +
    '</div>';

    return '<div class="staff-org-detail-grid">' +
      ui().card('Resumo', 'Dados principais retornados pelos callbacks de leitura.', '<div class="data-list">' +
        '<div><span>Nome</span><strong>' + ui().safeText(org.name || '-') + '</strong></div>' +
        '<div><span>Codigo</span><strong>' + ui().safeText(org.code || org.orgCode || '-') + '</strong></div>' +
        '<div><span>Tipo</span><strong>' + ui().safeText(fmt().formatOrgType(org.type || org.typeCode)) + '</strong></div>' +
        '<div><span>Status</span><strong>' + ui().safeText(org.active === false ? 'Inativa' : 'Ativa') + '</strong></div>' +
      '</div>' + flags, 'staff-org-detail-card') +
      ui().card('Indicadores', 'Resumo operacional sem permitir edicao.', '<div class="data-list">' +
        '<div><span>Membros</span><strong>' + ui().safeText(members.length || org.memberCount || '-') + '</strong></div>' +
        '<div><span>Saldo</span><strong>' + ui().safeText(data.bank ? fmt().formatMoney(data.bank.balance, data.bank.currency) : '-') + '</strong></div>' +
        '<div><span>Metas ativas</span><strong>' + ui().safeText(activeGoals) + '</strong></div>' +
        '<div><span>Candidaturas pendentes</span><strong>' + ui().safeText(pendingRecruitment) + '</strong></div>' +
      '</div>' + renderDetailBlockError(data, 'bank') + renderDetailBlockError(data, 'recruitment'), 'staff-org-detail-card') +
    '</div>';
  }

  function renderStaffOrgDetailGrades(data) {
    var access = data.access || {};
    var grades = Array.isArray(access.grades) ? access.grades : [];
    var baseCaps = Array.isArray(access.baseCapabilities) ? access.baseCapabilities : [];
    var archived = isStaffDetailOrgArchived(data);
    var base = baseCaps.length ? capabilityBadges(baseCaps, 12) : ui().empty('Sem permissoes base', 'Nenhuma permissao base foi retornada.');
    var body = grades.length ? renderStaffGradesTable(grades, data) : ui().empty('Nenhum cargo retornado', 'O core nao retornou cargos para esta organizacao.');
    var actions = archived
      ? '<span class="soft-note">Organizacao arquivada: cargos ficam em consulta ate a reativacao.</span>'
      : canManageStaffGrades()
      ? '<button class="btn btn-primary" data-action="open-staff-grade-modal" data-grade-mode="create">Criar cargo</button>'
      : '<span class="soft-note">Criar/editar cargos requer staff.orgs.manage.</span>';

    return ui().card('Cargos e permissoes', 'Gerenciamento basico de cargos. Permissoes seguem apenas leitura nesta fase.', renderDetailBlockError(data, 'access') +
      '<div class="staff-grade-toolbar"><p class="soft-note">Permissoes podem ser gerenciadas por cargo via catalogo oficial, sem campo livre.</p>' + actions + '</div>' +
      '<div class="access-section"><h4>Permissoes base</h4>' + base + '</div><div class="access-section"><h4>Hierarquia</h4>' + body + '</div>' +
      renderStaffGradeModal() + renderStaffArchiveModal() + renderStaffPermissionModal(), 'staff-org-detail-card');
  }

  function isStaffDetailOrgArchived(data) {
    var org = data && data.org ? data.org : {};
    return org.active === false || String(org.status || '').toLowerCase() === 'inactive';
  }

  function canManageStaffGrades() {
    var current = state();
    if (!current.session) return false;
    if (current.session.user && current.session.user.isOwner) return true;
    return perms().hasGlobalPermission(current.session, 'staff.orgs.manage');
  }

  function staffGradeMemberCounts(data) {
    var out = {};
    var members = Array.isArray(data.members) ? data.members : [];
    members.forEach(function (member) {
      var key = String(member.gradeLevel || member.grade || '');
      if (!key) return;
      out[key] = (out[key] || 0) + 1;
    });
    return out;
  }

  function renderStaffGradesTable(grades, data) {
    var counts = staffGradeMemberCounts(data || {});
    var archived = isStaffDetailOrgArchived(data);
    var activeGrades = grades.filter(function (grade) { return grade.active !== false; });
    var maxLevel = activeGrades.reduce(function (max, grade) {
      return Math.max(max, Number(grade.level) || 0);
    }, 0);

    return '<div class="staff-org-detail-table"><table><thead><tr><th>Nivel</th><th>Cargo</th><th>Codigo</th><th>Salario</th><th>Prioridade</th><th>Heranca</th><th>Membros</th><th>Permissoes</th><th>Acoes</th></tr></thead><tbody>' + grades.map(function (grade) {
      var caps = Array.isArray(grade.capabilities) ? grade.capabilities : [];
      var level = Number(grade.level) || 0;
      var active = grade.active !== false;
      var memberCount = counts[String(level)] || 0;
      var top = active && level === maxLevel;
      var inheritance = grade.inheritsLevel ? 'Nivel ' + grade.inheritsLevel : 'Sem heranca';
      var action = renderStaffGradeArchiveAction(grade, active, top, memberCount, archived);
      var status = active ? (top ? '<span class="cell-subtitle">Cargo maximo</span>' : '') : '<span class="cell-subtitle">Desativado</span>';
      return '<tr class="' + (active ? '' : 'is-muted-row') + '"><td>' + ui().badge('Nivel ' + level, top ? 'owner' : (active ? 'info' : 'muted')) + '</td><td class="cell-strong">' + ui().safeText(grade.name || grade.code) + status + '</td><td>' + ui().safeText(grade.code || '-') + '</td><td>' + ui().safeText(fmt().formatMoney(grade.salary || 0)) + '</td><td>' + ui().safeText(grade.priority == null ? '-' : grade.priority) + '</td><td>' + ui().safeText(inheritance) + '</td><td>' + ui().safeText(memberCount) + '</td><td>' + renderStaffGradePermissionsSummary(grade, caps) + '</td><td class="staff-grade-actions">' + action + '</td></tr>';
    }).join('') + '</tbody></table></div>';
  }

  function renderStaffGradeArchiveAction(grade, active, top, memberCount, archived) {
    if (!canManageStaffGrades()) return '<span class="soft-note">Sem permissao</span>';
    if (archived) return '<span class="soft-note">Org arquivada</span>';
    if (!active) {
      return '<button class="btn btn-ghost" data-action="open-staff-archive-modal" data-staff-archive-action="reactivate-grade" data-grade-id="' + ui().escapeHtml(grade.id || '') + '">Reativar</button>';
    }

    var manage = '<button class="btn btn-ghost" data-action="open-staff-permission-modal" data-grade-id="' + ui().escapeHtml(grade.id || '') + '">Gerenciar permissoes</button>';
    var edit = '<button class="btn btn-ghost" data-action="open-staff-grade-modal" data-grade-mode="edit" data-grade-id="' + ui().escapeHtml(grade.id || '') + '">Editar</button>';
    if (top) return manage + edit + '<span class="soft-note">Cargo maximo protegido.</span>';
    if (memberCount > 0) return manage + edit + '<span class="soft-note">Cargo possui membros.</span>';
    return manage + edit + '<button class="btn btn-ghost danger" data-action="open-staff-archive-modal" data-staff-archive-action="disable-grade" data-grade-id="' + ui().escapeHtml(grade.id || '') + '">Desativar</button>';
  }

  function renderStaffGradePermissionsSummary(grade, caps) {
    caps = Array.isArray(caps) ? caps : [];
    if (!caps.length) {
      return '<span class="staff-grade-permissions-summary muted">Sem permissoes</span>';
    }

    var preview = caps.slice(0, 3).map(function (capability) {
      return fmt().formatCapabilityLabel(capability);
    }).join(', ');
    var extra = caps.length > 3 ? ' +' + (caps.length - 3) : '';
    var chips = caps.map(function (capability) {
      return '<span class="staff-grade-permission-chip">' + ui().safeText(fmt().formatCapabilityLabel(capability)) + '</span>';
    }).join('');

    return '<details class="staff-grade-permissions-panel">' +
      '<summary class="staff-grade-permissions-toggle"><span class="staff-grade-permissions-summary">' + ui().safeText(caps.length + ' permissoes') + '</span><small>' + ui().safeText(preview + extra) + '</small></summary>' +
      '<div class="staff-grade-permission-list">' + chips + '</div>' +
    '</details>';
  }

  function isStaffPermission(permission) {
    return String(permission || '').indexOf('staff.') === 0;
  }

  function isSensitiveGradePermission(permission) {
    permission = String(permission || '');
    return permission === 'members.set_leader' || isStaffPermission(permission);
  }

  function isStaffOrgDetail(data) {
    var org = data && data.org ? data.org : {};
    var type = String(org.type || org.typeCode || org.type_code || '').toLowerCase();
    return type === 'staff';
  }

  function findStaffDetailGrade(gradeId) {
    var data = staffOrgDetailData();
    var grades = data.access && Array.isArray(data.access.grades) ? data.access.grades : [];
    return grades.find(function (grade) { return String(grade.id) === String(gradeId); }) || null;
  }

  function openStaffPermissionModal(gradeId) {
    var current = state();
    var modal = current.staffPermissionModal;
    var data = staffOrgDetailData();
    var grade = findStaffDetailGrade(gradeId);

    if (!canManageStaffGrades()) return;
    if (!grade || isStaffDetailOrgArchived(data) || grade.active === false) return;

    modal.open = true;
    modal.gradeId = grade.id;
    modal.selectedPermission = '';
    modal.search = '';
    modal.reason = '';
    modal.loading = false;
    modal.error = null;
    modal.message = null;
    render();
  }

  function closeStaffPermissionModal() {
    var modal = state().staffPermissionModal;
    if (modal.loading) return;
    modal.open = false;
    modal.error = null;
    render();
  }

  function renderStaffPermissionModal() {
    var current = state();
    var modal = current.staffPermissionModal || {};
    if (!modal.open) return '';

    var data = staffOrgDetailData();
    var grade = findStaffDetailGrade(modal.gradeId) || {};
    var direct = Array.isArray(grade.directCapabilities) ? grade.directCapabilities : [];
    var resolved = Array.isArray(grade.capabilities) ? grade.capabilities : [];
    var inherited = resolved.filter(function (capability) { return direct.indexOf(capability) === -1; });
    var error = modal.error ? '<div class="staff-org-modal-error">' + ui().safeText(formatStaffPermissionError(modal.error)) + '</div>' : '';
    var search = String(modal.search || '').toLowerCase();
    var catalog = fmt().getCapabilityCatalog().map(function (group) {
      var permissions = group.permissions.filter(function (permission) {
        if (!isStaffOrgDetail(data) && isStaffPermission(permission)) return false;
        if (!search) return true;
        return permission.toLowerCase().indexOf(search) !== -1 || fmt().formatCapabilityLabel(permission).toLowerCase().indexOf(search) !== -1;
      });
      return { id: group.id, label: group.label, permissions: permissions };
    }).filter(function (group) { return group.permissions.length; });

    var currentList = direct.length
      ? direct.map(function (permission) {
        return '<div class="staff-permission-row"><span>' + ui().safeText(fmt().formatCapabilityLabel(permission)) + (isSensitiveGradePermission(permission) ? '<small>Sensivel</small>' : '') + '</span><button class="btn btn-ghost danger" data-action="remove-staff-grade-permission" data-permission="' + ui().escapeHtml(permission) + '" ' + (modal.loading ? 'disabled' : '') + '>Remover</button></div>';
      }).join('')
      : ui().empty('Sem permissoes diretas', 'Este cargo usa apenas permissoes base/herdadas ou nenhuma permissao.');

    var inheritedList = inherited.length
      ? '<div class="staff-permission-inherited"><strong>Herdadas/base</strong><div class="badge-row">' + inherited.slice(0, 16).map(function (permission) { return ui().permissionBadge(permission, 'muted'); }).join('') + (inherited.length > 16 ? ui().badge('+' + (inherited.length - 16), 'muted') : '') + '</div></div>'
      : '';

    var catalogList = catalog.length
      ? catalog.map(function (group) {
        return '<section class="staff-permission-group"><h4>' + ui().safeText(group.label) + '</h4>' + group.permissions.map(function (permission) {
          var exists = direct.indexOf(permission) !== -1;
          var sensitive = isSensitiveGradePermission(permission);
          return '<div class="staff-permission-row ' + (exists ? 'is-muted-row' : '') + '"><span>' + ui().safeText(fmt().formatCapabilityLabel(permission)) + '<small>' + ui().safeText(permission) + (sensitive ? ' - sensivel' : '') + '</small></span><button class="btn btn-ghost" data-action="add-staff-grade-permission" data-permission="' + ui().escapeHtml(permission) + '" ' + (exists || modal.loading ? 'disabled' : '') + '>' + (exists ? 'Ja possui' : 'Adicionar') + '</button></div>';
        }).join('') + '</section>';
      }).join('')
      : ui().empty('Nenhuma permissao encontrada', 'Ajuste a busca ou selecione outro grupo.');

    return '<div class="staff-org-modal-backdrop" role="presentation">' +
      '<section class="staff-org-modal staff-permission-modal" role="dialog" aria-modal="true" aria-label="Gerenciar permissoes">' +
        '<div class="staff-org-modal-header"><div><span>Staff</span><h3>Permissoes de ' + ui().safeText(grade.name || grade.code || 'cargo') + '</h3><p>Escolha somente permissoes da lista oficial. Nao ha campo livre de capability.</p></div><button class="modal-close" data-action="close-staff-permission-modal" aria-label="Cancelar">x</button></div>' +
        '<div class="staff-org-modal-body">' +
          '<label class="staff-org-modal-wide"><span>Buscar permissao</span><input data-staff-permission-field="search" maxlength="80" value="' + ui().safeText(modal.search) + '" placeholder="Buscar por nome ou capability" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label class="staff-org-modal-wide"><span>Motivo opcional</span><textarea data-staff-permission-field="reason" maxlength="255" rows="2" placeholder="Motivo para auditoria" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.reason) + '</textarea></label>' +
          '<section class="staff-permission-panel staff-org-modal-wide"><h4>Permissoes diretas</h4>' + currentList + inheritedList + '</section>' +
          '<section class="staff-permission-panel staff-org-modal-wide"><h4>Adicionar permissao</h4>' + catalogList + '</section>' +
          '<small class="soft-note staff-org-modal-wide">Permissoes staff ficam ocultas fora de org tipo Staff. Permissoes sensiveis continuam validadas no server.</small>' +
          error +
        '</div>' +
        '<div class="staff-org-modal-actions">' +
          '<button class="btn btn-ghost" data-action="close-staff-permission-modal" ' + (modal.loading ? 'disabled' : '') + '>Fechar</button>' +
        '</div>' +
      '</section>' +
    '</div>';
  }

  function formatStaffPermissionError(error) {
    var key = String(error || '').toLowerCase();
    if (key.indexOf('invalid_permission') !== -1 || key.indexOf('permissao invalida') !== -1) return 'Permissao invalida.';
    if (key.indexOf('permission_not_allowed_for_org_type') !== -1) return 'Esta permissao nao e permitida para este tipo de organizacao.';
    if (key.indexOf('permission_not_allowed') !== -1) return 'Esta permissao nao pode ser adicionada aqui.';
    if (key.indexOf('sensitive_permission_requires_owner') !== -1) return 'Esta permissao sensivel exige owner.';
    if (key.indexOf('leader_permission_required') !== -1) return 'Definir lideranca exige permissao forte.';
    if (key.indexOf('permission_already_exists') !== -1) return 'Este cargo ja possui essa permissao.';
    if (key.indexOf('permission_not_found') !== -1) return 'Permissao nao encontrada neste cargo.';
    if (key.indexOf('org_archived') !== -1 || key.indexOf('arquivada') !== -1) return 'Organizacao arquivada nao pode ser alterada.';
    if (key.indexOf('grade_inactive') !== -1 || key.indexOf('inativo') !== -1) return 'Cargo inativo nao pode ser alterado.';
    if (key.indexOf('forbidden') !== -1 || key.indexOf('permiss') !== -1) return 'Voce nao tem permissao para gerenciar permissoes.';
    if (key.indexOf('rate_limited') !== -1 || key.indexOf('aguarde') !== -1) return 'Aguarde alguns segundos e tente novamente.';
    return error || 'Nao foi possivel alterar a permissao.';
  }

  function updateStaffPermissionModalFields() {
    var modal = state().staffPermissionModal;
    var app = document.getElementById('app');
    var search = app && app.querySelector('[data-staff-permission-field="search"]');
    var reason = app && app.querySelector('[data-staff-permission-field="reason"]');
    modal.search = search ? search.value.replace(/^\s+|\s+$/g, '') : (modal.search || '');
    modal.reason = reason ? reason.value.replace(/^\s+|\s+$/g, '') : (modal.reason || '');
  }

  function changeStaffGradePermission(action, permission) {
    var current = state();
    var modal = current.staffPermissionModal;
    var details = current.staffOrgDetails || {};
    var orgCode = String(details.orgCode || '').replace(/^\s+|\s+$/g, '');
    var gradeId = modal.gradeId;

    updateStaffPermissionModalFields();
    modal.error = null;

    if (!orgCode) { modal.error = 'Organizacao invalida.'; render(); return; }
    if (!gradeId) { modal.error = 'Cargo invalido.'; render(); return; }
    if (!permission) { modal.error = 'Permissao invalida.'; render(); return; }

    modal.loading = true;
    render();

    var request = action === 'remove'
      ? window.MZOrgService.removeGradePermission(orgCode, gradeId, permission, modal.reason)
      : window.MZOrgService.addGradePermission(orgCode, gradeId, permission, modal.reason);

    request.then(function () {
      modal.open = false;
      modal.error = null;
      return openStaffOrgDetails(orgCode, { tab: 'grades' });
    }).catch(function (err) {
      modal.error = formatStaffPermissionError(err.message);
    }).finally(function () {
      modal.loading = false;
      render();
    });
  }

  function openStaffGradeModal(mode, gradeId) {
    var current = state();
    var modal = current.staffGradeModal;
    var data = staffOrgDetailData();
    var grades = data.access && Array.isArray(data.access.grades) ? data.access.grades : [];
    var grade = null;

    if (!canManageStaffGrades()) return;
    if (isStaffDetailOrgArchived(data)) return;

    if (mode === 'edit') {
      grade = grades.find(function (item) { return String(item.id) === String(gradeId); });
      if (!grade) return;
    }

    modal.open = true;
    modal.mode = mode === 'edit' ? 'edit' : 'create';
    modal.gradeId = grade ? grade.id : null;
    modal.code = grade ? (grade.code || '') : '';
    modal.name = grade ? (grade.name || '') : '';
    modal.level = grade ? String(grade.level || '') : '';
    modal.salary = grade ? String(grade.salary || 0) : '0';
    modal.priority = grade && grade.priority != null ? String(grade.priority) : (grade ? String(grade.level || '') : '');
    modal.inheritsLevel = grade && grade.inheritsLevel ? String(grade.inheritsLevel) : '';
    modal.reason = '';
    modal.loading = false;
    modal.message = null;
    modal.error = null;
    render();
  }

  function closeStaffGradeModal() {
    var modal = state().staffGradeModal;
    if (modal.loading) return;
    modal.open = false;
    modal.error = null;
    render();
  }

  function renderStaffGradeModal() {
    var current = state();
    var modal = current.staffGradeModal || {};
    if (!modal.open) return '';

    var data = staffOrgDetailData();
    var grades = data.access && Array.isArray(data.access.grades) ? data.access.grades : [];
    var isEdit = modal.mode === 'edit';
    var inheritanceOptions = '<option value="">Sem heranca</option>' + grades.filter(function (grade) {
      if (grade.active === false) return false;
      return !isEdit || String(grade.id) !== String(modal.gradeId);
    }).map(function (grade) {
      var value = String(grade.level || '');
      return '<option value="' + ui().escapeHtml(value) + '"' + (String(modal.inheritsLevel || '') === value ? ' selected' : '') + '>Nivel ' + ui().safeText(grade.level) + ' - ' + ui().safeText(grade.name || grade.code) + '</option>';
    }).join('');

    var error = modal.error ? '<div class="staff-org-modal-error">' + ui().safeText(formatStaffGradeError(modal.error)) + '</div>' : '';
    return '<div class="staff-org-modal-backdrop" role="presentation">' +
      '<section class="staff-org-modal" role="dialog" aria-modal="true" aria-label="' + ui().safeText(isEdit ? 'Editar cargo' : 'Criar cargo') + '">' +
        '<div class="staff-org-modal-header"><div><span>Staff</span><h3>' + ui().safeText(isEdit ? 'Editar cargo' : 'Criar cargo') + '</h3><p>Permissoes continuam apenas leitura nesta fase.</p></div><button class="modal-close" data-action="close-staff-grade-modal" aria-label="Cancelar">x</button></div>' +
        '<div class="staff-org-modal-body">' +
          (isEdit ? '<label><span>Codigo</span><input value="' + ui().safeText(modal.code) + '" disabled /></label>' : '<label><span>Codigo</span><input data-staff-grade-field="code" maxlength="48" value="' + ui().safeText(modal.code) + '" placeholder="Ex: sub_lider" ' + (modal.loading ? 'disabled' : '') + ' /></label>') +
          '<label><span>Nome</span><input data-staff-grade-field="name" maxlength="120" value="' + ui().safeText(modal.name) + '" placeholder="Nome do cargo" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Nivel</span><input data-staff-grade-field="level" type="number" min="1" max="1000" value="' + ui().safeText(modal.level) + '" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Salario</span><input data-staff-grade-field="salary" type="number" min="0" max="100000000" value="' + ui().safeText(modal.salary) + '" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Prioridade</span><input data-staff-grade-field="priority" type="number" min="0" max="1000" value="' + ui().safeText(modal.priority) + '" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Herda de</span><select data-staff-grade-field="inheritsLevel" ' + (modal.loading ? 'disabled' : '') + '>' + inheritanceOptions + '</select></label>' +
          '<label class="staff-org-modal-wide"><span>Motivo opcional</span><textarea data-staff-grade-field="reason" maxlength="255" rows="3" placeholder="Motivo para auditoria" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.reason) + '</textarea></label>' +
          '<small class="soft-note staff-org-modal-wide">Criar ou mover cargo acima da lideranca atual pode exigir staff.orgs.set_leader. Permissoes nao sao editadas aqui.</small>' +
          error +
        '</div>' +
        '<div class="staff-org-modal-actions">' +
          '<button class="btn btn-ghost" data-action="close-staff-grade-modal" ' + (modal.loading ? 'disabled' : '') + '>Cancelar</button>' +
          '<button class="btn btn-primary" data-action="submit-staff-grade-modal" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.loading ? 'Salvando...' : 'Salvar') + '</button>' +
        '</div>' +
      '</section>' +
    '</div>';
  }

  function formatStaffGradeError(error) {
    var key = String(error || '').toLowerCase();
    if (key.indexOf('org_archived') !== -1 || key.indexOf('arquivada') !== -1) return 'Organizacao arquivada. Reative antes de gerenciar cargos.';
    if (key.indexOf('invalid_org') !== -1 || key.indexOf('organizacao invalida') !== -1) return 'Organizacao invalida.';
    if (key.indexOf('org_not_found') !== -1 || key.indexOf('nao encontrada') !== -1) return 'Organizacao nao encontrada.';
    if (key.indexOf('invalid_grade') !== -1) return 'Cargo invalido.';
    if (key.indexOf('grade_not_found') !== -1) return 'Cargo nao encontrado.';
    if (key.indexOf('invalid_code') !== -1 || key.indexOf('codigo') !== -1) return 'Informe um codigo valido para o cargo.';
    if (key.indexOf('invalid_name') !== -1 || key.indexOf('nome') !== -1) return 'Informe um nome valido para o cargo.';
    if (key.indexOf('invalid_level') !== -1 || key.indexOf('nivel') !== -1) return 'Informe um nivel valido.';
    if (key.indexOf('grade_code_conflict') !== -1 || key.indexOf('codigo') !== -1 && key.indexOf('existe') !== -1) return 'Ja existe um cargo com esse codigo.';
    if (key.indexOf('grade_level_conflict') !== -1 || key.indexOf('nivel') !== -1 && key.indexOf('existe') !== -1) return 'Ja existe um cargo nesse nivel.';
    if (key.indexOf('invalid_salary') !== -1 || key.indexOf('salario') !== -1) return 'Informe um salario valido.';
    if (key.indexOf('invalid_inheritance') !== -1 || key.indexOf('heranca') !== -1) return 'Heranca de cargo invalida.';
    if (key.indexOf('inheritance_cycle') !== -1 || key.indexOf('ciclo') !== -1) return 'A heranca criaria um ciclo invalido.';
    if (key.indexOf('forbidden') !== -1 || key.indexOf('permiss') !== -1) return 'Voce nao tem permissao para gerenciar cargos.';
    if (key.indexOf('leader_permission_required') !== -1 || key.indexOf('lideranca') !== -1) return 'Alterar cargo maximo exige permissao de lideranca.';
    if (key.indexOf('grade_in_use') !== -1) return 'Este cargo possui membros e nao pode ser desativado.';
    if (key.indexOf('top_grade_protected') !== -1) return 'Cargo maximo protegido.';
    if (key.indexOf('grade_already_disabled') !== -1 || key.indexOf('ja esta desativado') !== -1) return 'Cargo ja esta desativado.';
    if (key.indexOf('grade_already_active') !== -1 || key.indexOf('ja esta ativo') !== -1) return 'Cargo ja esta ativo.';
    if (key.indexOf('create_grade_failed') !== -1) return 'Nao foi possivel criar o cargo.';
    if (key.indexOf('update_grade_failed') !== -1) return 'Nao foi possivel atualizar o cargo.';
    if (key.indexOf('rate_limited') !== -1 || key.indexOf('aguarde') !== -1) return 'Aguarde alguns segundos e tente novamente.';
    return error || 'Nao foi possivel salvar o cargo.';
  }

  function submitStaffGradeModal() {
    var current = state();
    var modal = current.staffGradeModal;
    var details = current.staffOrgDetails || {};
    var orgCode = String(details.orgCode || '').replace(/^\s+|\s+$/g, '');
    var detailData = staffOrgDetailData();
    var app = document.getElementById('app');

    function field(name) {
      var input = app && app.querySelector('[data-staff-grade-field="' + name + '"]');
      return input ? input.value.replace(/^\s+|\s+$/g, '') : (modal[name] || '');
    }

    modal.code = modal.mode === 'edit' ? modal.code : field('code');
    modal.name = field('name');
    modal.level = field('level');
    modal.salary = field('salary') || '0';
    modal.priority = field('priority');
    modal.inheritsLevel = field('inheritsLevel');
    modal.reason = field('reason');
    modal.error = null;

    if (!orgCode) { modal.error = 'Organizacao invalida.'; render(); return; }
    if (isStaffDetailOrgArchived(detailData)) { modal.error = 'Organizacao arquivada. Reative antes de gerenciar cargos.'; render(); return; }
    if (modal.mode !== 'edit' && !modal.code) { modal.error = 'Informe um codigo valido para o cargo.'; render(); return; }
    if (!modal.name) { modal.error = 'Informe um nome valido para o cargo.'; render(); return; }
    if (!modal.level) { modal.error = 'Informe um nivel valido.'; render(); return; }

    modal.loading = true;
    render();

    var payload = {
      code: modal.code,
      name: modal.name,
      level: Number(modal.level),
      salary: Number(modal.salary || 0),
      priority: modal.priority === '' ? undefined : Number(modal.priority),
      inheritsLevel: modal.inheritsLevel === '' ? undefined : Number(modal.inheritsLevel),
      reason: modal.reason
    };

    var request = modal.mode === 'edit'
      ? window.MZOrgService.updateOrgGradeBasic(orgCode, modal.gradeId, payload)
      : window.MZOrgService.createOrgGrade(orgCode, payload);

    request.then(function () {
      modal.message = modal.mode === 'edit' ? 'Cargo atualizado.' : 'Cargo criado.';
      modal.open = false;
      modal.error = null;
      openStaffOrgDetails(orgCode, { tab: 'grades' });
    }).catch(function (err) {
      modal.error = formatStaffGradeError(err.message);
    }).finally(function () {
      modal.loading = false;
      render();
    });
  }

  function renderStaffOrgDetailMembers(data) {
    var members = Array.isArray(data.members) ? data.members : [];
    var body = !members.length
      ? ui().empty('Nenhum membro retornado', 'Gestao administrativa de membros fica para fase futura.')
      : '<div class="staff-org-detail-table"><table><thead><tr><th>Membro</th><th>CitizenID</th><th>Cargo</th><th>Status</th><th>Entrada</th></tr></thead><tbody>' + members.map(function (member) {
        return '<tr><td class="cell-strong">' + ui().safeText(member.name || 'Membro') + '</td><td>' + ui().safeText(fmt().maskCitizenId(member.citizenid)) + '</td><td>' + ui().safeText(fmt().formatGradeName(member)) + '</td><td>' + ui().badge(member.isDuty ? 'Em servico' : fmt().formatStatusLabel(member.status || 'active'), member.isDuty ? 'success' : 'muted') + '</td><td>' + ui().safeText(fmt().formatDate(member.joinedAt)) + '</td></tr>';
      }).join('') + '</tbody></table></div>';
    return ui().card('Membros', 'Lista read-only. Sem promover, rebaixar, remover ou adicionar pelo Staff nesta fase.', renderDetailBlockError(data, 'members') + body, 'staff-org-detail-card');
  }

  function renderStaffOrgDetailBank(data) {
    var transactions = Array.isArray(data.transactions) ? data.transactions : [];
    var account = data.bank;
    var summary = account
      ? '<article class="bank-summary-card"><span>Saldo atual</span><strong>' + fmt().formatMoney(account.balance, account.currency) + '</strong><small>Consulta read-only pelo Staff.</small></article>'
      : ui().empty('Banco indisponivel', 'Esta org pode nao ter conta compartilhada ou sua sessao nao pode consultar.');
    var txBody = !transactions.length
      ? ui().empty('Sem movimentos recentes', 'Nenhuma transacao retornada para esta org.')
      : '<div class="staff-org-detail-table"><table><thead><tr><th>Data</th><th>Tipo</th><th>Valor</th><th>Ator</th><th>Motivo</th></tr></thead><tbody>' + transactions.map(function (tx) {
        return '<tr><td>' + ui().safeText(fmt().formatDate(tx.createdAt)) + '</td><td>' + ui().badge(fmt().formatStatusLabel(tx.type), tx.type === 'withdraw' ? 'warning' : 'success') + '</td><td>' + ui().safeText(fmt().formatMoney(tx.amount, tx.currency)) + '</td><td>' + ui().safeText(tx.actorName || fmt().maskCitizenId(tx.actorCitizenId)) + '</td><td>' + ui().safeText(tx.reason || '-') + '</td></tr>';
      }).join('') + '</tbody></table></div>';
    return ui().card('Banco', 'Consulta de saldo e ultimos movimentos. Staff nao deposita nem saca por aqui.', renderDetailBlockError(data, 'bank') + renderDetailBlockError(data, 'transactions') + summary + txBody, 'staff-org-detail-card');
  }

  function renderStaffOrgDetailGoals(data) {
    var goals = Array.isArray(data.goals) ? data.goals : [];
    var body = !goals.length
      ? ui().empty('Nenhuma meta retornada', 'Progresso/conclusao real de metas sera implementado em fase futura.')
      : '<div class="staff-org-detail-table"><table><thead><tr><th>Meta</th><th>Status</th><th>Tipo</th><th>Progresso</th><th>Criador</th></tr></thead><tbody>' + goals.map(function (goal) {
        return '<tr><td class="cell-strong">' + ui().safeText(goal.title || 'Meta') + '</td><td>' + ui().badge(fmt().formatStatusLabel(goal.status || 'active'), goalStatusVariant(goal.status)) + '</td><td>' + ui().safeText(fmt().formatGoalType(goal.type)) + '</td><td>' + renderGoalProgress(goal) + '</td><td>' + ui().safeText(goal.createdByName || fmt().maskCitizenId(goal.createdByCitizenId)) + '</td></tr>';
      }).join('') + '</tbody></table></div>';
    return ui().card('Metas', 'Read-only. Criacao, edicao e progresso administrativo nao existem nesta tela.', renderDetailBlockError(data, 'goals') + body + '<p class="soft-note">Progresso/conclusao real de metas permanece pendente para fase futura.</p>', 'staff-org-detail-card');
  }

  function renderStaffOrgDetailRecruitment(data) {
    var items = Array.isArray(data.recruitment) ? data.recruitment : [];
    var counts = recruitmentSummary(items);
    var body = !items.length
      ? ui().empty('Nenhuma candidatura retornada', 'Acoes de aprovar/recusar permanecem no contexto /org ou /gang.')
      : '<div class="staff-org-detail-table"><table><thead><tr><th>Candidato</th><th>CitizenID</th><th>Status</th><th>Cargo</th><th>Data</th></tr></thead><tbody>' + items.map(function (item) {
        var grade = item.desiredGradeLevel ? 'Nivel ' + item.desiredGradeLevel : (item.desiredGradeCode || '-');
        return '<tr><td class="cell-strong">' + ui().safeText(item.candidateName || item.targetName || 'Candidato') + '</td><td>' + ui().safeText(fmt().maskCitizenId(item.candidateCitizenId || item.targetCitizenId)) + '</td><td>' + ui().badge(fmt().formatStatusLabel(item.status), recruitmentStatusVariant(item.status)) + '</td><td>' + ui().safeText(grade) + '</td><td>' + ui().safeText(fmt().formatDate(item.createdAt)) + '</td></tr>';
      }).join('') + '</tbody></table></div>';
    return ui().card('Recrutamento', 'Consulta read-only por organizacao. Staff nao aprova nem recusa por aqui nesta fase.', renderDetailBlockError(data, 'recruitment') + '<div class="staff-org-detail-grid compact">' + renderRecruitmentSummaryCard('Pendentes', counts.pending, 'Aguardando decisao.') + renderRecruitmentSummaryCard('Aprovados', counts.approved, 'Viraram membros.') + renderRecruitmentSummaryCard('Recusados', counts.rejected, 'Recusadas recentemente.') + '</div>' + body, 'staff-org-detail-card');
  }

  function renderStaffOrgDetailLogs(data) {
    var logs = Array.isArray(data.logs) ? data.logs : [];
    return ui().card('Logs recentes', 'Eventos filtrados pela org, sem payload tecnico bruto.', renderDetailBlockError(data, 'logs') + renderStaffLogList(logs, 'Nenhum log recente retornado para esta org.'), 'staff-org-detail-card');
  }

  function renderStaffOrgDetailActions(data) {
    return '<section class="staff-org-actions">' +
      renderStaffDetailLeaderCard(data) +
      '<div class="staff-org-action-grid">' +
        renderStaffEditOrgBasicCard(data) +
        renderDisabledStaffOrgAction('Gerenciar cargos', 'Use a aba Cargos para criar, editar, desativar ou reativar grades.') +
        renderDisabledStaffOrgAction('Gerenciar permissoes', 'Editor de capabilities nao faz parte desta fase.') +
        renderStaffArchiveOrgCard(data) +
        renderDisabledStaffOrgAction('Excluir organizacao', 'Exclusao de org nao faz parte desta fase.') +
      '</div>' +
      renderStaffEditOrgBasicModal() +
      renderStaffArchiveModal() +
    '</section>';
  }

  function renderDisabledStaffOrgAction(title, description) {
    return '<section class="staff-org-action-card is-disabled">' +
      '<div class="badge-row">' + ui().badge('Em fase futura', 'muted') + '</div>' +
      '<span><strong>' + ui().safeText(title) + '</strong><small>' + ui().safeText(description) + '</small></span>' +
    '</section>';
  }

  function canUpdateStaffOrgBasic() {
    var current = state();
    if (!current.session) return false;
    if (current.session.user && current.session.user.isOwner) return true;
    return perms().hasGlobalPermission(current.session, 'staff.orgs.manage');
  }

  function renderStaffArchiveOrgCard(data) {
    var archived = isStaffDetailOrgArchived(data);
    var title = archived ? 'Reativar organizacao' : 'Arquivar organizacao';
    var description = archived
      ? 'Reativa a organizacao sem alterar historico, membros, banco, metas ou logs.'
      : 'Arquiva sem apagar historico, membros, banco, metas, recrutamento ou logs.';

    if (!canUpdateStaffOrgBasic()) {
      return '<section class="staff-org-action-card is-disabled">' +
        '<div class="badge-row">' + ui().badge('Bloqueado', 'warning') + '</div>' +
        '<span><strong>' + ui().safeText(title) + '</strong><small>Voce nao tem permissao para arquivar ou reativar.</small></span>' +
      '</section>';
    }

    return '<button class="staff-org-action-card" data-action="open-staff-archive-modal" data-staff-archive-action="' + (archived ? 'reactivate-org' : 'archive-org') + '">' +
      '<div class="badge-row">' + ui().badge(archived ? 'Reativar' : 'Soft archive', archived ? 'success' : 'warning') + '</div>' +
      '<span><strong>' + ui().safeText(title) + '</strong><small>' + ui().safeText(description) + '</small></span>' +
    '</button>';
  }

  function openStaffArchiveModal(action, gradeId) {
    var current = state();
    var details = current.staffOrgDetails || {};
    var data = staffOrgDetailData();
    var modal = current.staffArchiveModal;
    var org = (data && data.org) || {};
    var grades = data.access && Array.isArray(data.access.grades) ? data.access.grades : [];
    var grade = gradeId ? grades.find(function (item) { return String(item.id) === String(gradeId); }) : null;

    if (!details.orgCode || !canUpdateStaffOrgBasic()) return;

    modal.open = true;
    modal.action = action;
    modal.orgCode = details.orgCode;
    modal.gradeId = grade ? grade.id : null;
    modal.reason = '';
    modal.loading = false;
    modal.error = null;

    if (action === 'archive-org') {
      modal.title = 'Arquivar organizacao';
      modal.description = 'Arquivar nao apaga historico, membros, banco, logs, metas ou recrutamento. A org ficara somente consulta ate ser reativada.';
    } else if (action === 'reactivate-org') {
      modal.title = 'Reativar organizacao';
      modal.description = 'A organizacao voltara a aceitar operacoes normais. Historico e dados existentes permanecem preservados.';
    } else if (action === 'disable-grade') {
      if (!grade) return;
      modal.title = 'Desativar cargo';
      modal.description = 'O cargo "' + (grade.name || grade.code || '-') + '" sera ocultado de novas operacoes. Nada sera apagado.';
    } else if (action === 'reactivate-grade') {
      if (!grade) return;
      modal.title = 'Reativar cargo';
      modal.description = 'O cargo "' + (grade.name || grade.code || '-') + '" voltara a ficar disponivel.';
    } else {
      modal.open = false;
      return;
    }

    if (org.name && (action === 'archive-org' || action === 'reactivate-org')) {
      modal.description += ' Organizacao: ' + org.name + ' (' + details.orgCode + ').';
    }

    render();
  }

  function closeStaffArchiveModal() {
    var modal = state().staffArchiveModal;
    if (modal.loading) return;
    modal.open = false;
    modal.error = null;
    render();
  }

  function renderStaffArchiveModal() {
    var modal = state().staffArchiveModal || {};
    if (!modal.open) return '';

    var error = modal.error ? '<div class="staff-org-modal-error">' + ui().safeText(formatStaffArchiveError(modal.error)) + '</div>' : '';
    return '<div class="staff-org-modal-backdrop" role="presentation">' +
      '<section class="staff-org-modal" role="dialog" aria-modal="true" aria-label="' + ui().safeText(modal.title || 'Confirmar acao') + '">' +
        '<div class="staff-org-modal-header"><div><span>Staff</span><h3>' + ui().safeText(modal.title || 'Confirmar acao') + '</h3><p>' + ui().safeText(modal.description || 'Confirme a acao administrativa.') + '</p></div><button class="modal-close" data-action="close-staff-archive-modal" aria-label="Cancelar">x</button></div>' +
        '<div class="staff-org-modal-body">' +
          '<label class="staff-org-modal-wide"><span>Motivo opcional</span><textarea data-staff-archive-field="reason" maxlength="255" rows="3" placeholder="Motivo para auditoria" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.reason) + '</textarea></label>' +
          '<small class="soft-note staff-org-modal-wide">Esta acao usa arquivamento/desativacao segura. Nao ha DELETE fisico.</small>' +
          error +
        '</div>' +
        '<div class="staff-org-modal-actions">' +
          '<button class="btn btn-ghost" data-action="close-staff-archive-modal" ' + (modal.loading ? 'disabled' : '') + '>Cancelar</button>' +
          '<button class="btn btn-primary" data-action="submit-staff-archive-modal" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.loading ? 'Aplicando...' : 'Confirmar') + '</button>' +
        '</div>' +
      '</section>' +
    '</div>';
  }

  function formatStaffArchiveError(error) {
    var key = String(error || '').toLowerCase();
    if (key.indexOf('invalid_org') !== -1 || key.indexOf('organizacao invalida') !== -1) return 'Organizacao invalida.';
    if (key.indexOf('org_not_found') !== -1 || key.indexOf('nao encontrada') !== -1) return 'Organizacao nao encontrada.';
    if (key.indexOf('forbidden') !== -1 || key.indexOf('permiss') !== -1) return 'Voce nao tem permissao para esta acao.';
    if (key.indexOf('org_already_archived') !== -1 || key.indexOf('ja esta arquivada') !== -1) return 'Organizacao ja esta arquivada.';
    if (key.indexOf('org_already_active') !== -1 || key.indexOf('ja esta ativa') !== -1) return 'Organizacao ja esta ativa.';
    if (key.indexOf('protected_org') !== -1) return 'Esta organizacao nao pode ser arquivada nesta fase.';
    if (key.indexOf('archive_org_failed') !== -1) return 'Nao foi possivel arquivar a organizacao.';
    if (key.indexOf('reactivate_org_failed') !== -1) return 'Nao foi possivel reativar a organizacao.';
    if (key.indexOf('grade_in_use') !== -1) return 'Este cargo possui membros e nao pode ser desativado.';
    if (key.indexOf('top_grade_protected') !== -1) return 'Cargo maximo protegido.';
    if (key.indexOf('grade_already_disabled') !== -1 || key.indexOf('ja esta desativado') !== -1) return 'Cargo ja esta desativado.';
    if (key.indexOf('grade_already_active') !== -1 || key.indexOf('ja esta ativo') !== -1) return 'Cargo ja esta ativo.';
    if (key.indexOf('disable_grade_failed') !== -1) return 'Nao foi possivel desativar o cargo.';
    if (key.indexOf('reactivate_grade_failed') !== -1) return 'Nao foi possivel reativar o cargo.';
    if (key.indexOf('rate_limited') !== -1 || key.indexOf('aguarde') !== -1) return 'Aguarde alguns segundos e tente novamente.';
    return error || 'Nao foi possivel aplicar a acao.';
  }

  function submitStaffArchiveModal() {
    var current = state();
    var modal = current.staffArchiveModal;
    var app = document.getElementById('app');
    var reasonInput = app && app.querySelector('[data-staff-archive-field="reason"]');
    var orgCode = String(modal.orgCode || (current.staffOrgDetails && current.staffOrgDetails.orgCode) || '').replace(/^\s+|\s+$/g, '');

    modal.reason = reasonInput ? reasonInput.value.replace(/^\s+|\s+$/g, '') : (modal.reason || '');
    modal.error = null;

    if (!orgCode) { modal.error = 'Organizacao invalida.'; render(); return; }

    modal.loading = true;
    render();

    var request;
    if (modal.action === 'archive-org') {
      request = window.MZOrgService.archiveOrg(orgCode, modal.reason);
    } else if (modal.action === 'reactivate-org') {
      request = window.MZOrgService.reactivateOrg(orgCode, modal.reason);
    } else if (modal.action === 'disable-grade') {
      request = window.MZOrgService.disableOrgGrade(orgCode, modal.gradeId, modal.reason);
    } else if (modal.action === 'reactivate-grade') {
      request = window.MZOrgService.reactivateOrgGrade(orgCode, modal.gradeId, modal.reason);
    } else {
      modal.loading = false;
      modal.error = 'Acao invalida.';
      render();
      return;
    }

    request.then(function () {
      var tab = modal.action.indexOf('grade') !== -1 ? 'grades' : 'actions';
      modal.open = false;
      modal.error = null;
      return Promise.all([
        loadOrgs(),
        openStaffOrgDetails(orgCode, { tab: tab })
      ]);
    }).catch(function (err) {
      modal.error = formatStaffArchiveError(err.message);
    }).finally(function () {
      modal.loading = false;
      render();
    });
  }

  function orgStatusFromOrg(org) {
    if (org && org.status) return String(org.status).toLowerCase();
    if (org && org.active === false) return 'inactive';
    return org && (org.is_public || org.isPublic) ? 'public' : 'private';
  }

  function renderStaffEditOrgBasicCard(data) {
    var current = state();
    var form = current.staffEditOrgBasic || {};
    var archived = isStaffDetailOrgArchived(data);
    var message = form.message ? '<div class="inline-message success">' + ui().safeText(form.message) + '</div>' : '';
    var error = form.error && !form.open ? '<div class="inline-message error-inline">' + ui().safeText(formatStaffEditOrgBasicError(form.error)) + '</div>' : '';

    if (archived) {
      return '<section class="staff-org-action-card is-disabled">' +
        '<div class="badge-row">' + ui().badge('Somente consulta', 'muted') + '</div>' +
        '<span><strong>Editar dados basicos</strong><small>Reative a organizacao antes de editar.</small></span>' +
      '</section>';
    }

    if (!canUpdateStaffOrgBasic()) {
      return '<section class="staff-org-action-card is-disabled">' +
        '<div class="badge-row">' + ui().badge('Bloqueado', 'warning') + '</div>' +
        '<span><strong>Editar dados basicos</strong><small>Voce nao tem permissao para editar dados basicos.</small></span>' +
      '</section>';
    }

    return '<button class="staff-org-action-card" data-action="open-staff-edit-org-basic-modal">' +
      '<div class="badge-row">' + ui().badge('staff.orgs.manage', 'info') + '</div>' +
      '<span><strong>Editar dados basicos</strong><small>Nome, status publico/privado e flags operacionais.</small></span>' +
      message + error +
    '</button>';
  }

  function renderStaffDetailLeaderCard(data) {
    var current = state();
    var form = current.staffLeader || {};
    var org = (data && data.org) || findStaffOrgByCode(current.staffOrgDetails.orgCode) || {};
    var orgCode = current.staffOrgDetails.orgCode || org.code || '';
    var message = form.message ? '<div class="inline-message success">' + ui().safeText(form.message) + '</div>' : '';
    var error = form.error ? '<div class="inline-message error-inline">' + ui().safeText(formatStaffLeaderError(form.error)) + '</div>' : '';

    if (isStaffDetailOrgArchived(data)) {
      return ui().card('Definir lider', 'Acao administrativa restrita a esta organizacao.', '<div class="badge-row">' + ui().badge('Somente consulta', 'muted') + '</div><p class="soft-note">Reative a organizacao antes de definir lideranca.</p>', 'staff-org-detail-card');
    }

    if (!canShowStaffLeaderCard()) {
      return ui().card('Definir lider', 'Acao administrativa restrita a esta organizacao.', '<div class="badge-row">' + ui().badge('Bloqueado', 'warning') + '</div><p class="soft-note">Voce nao tem permissao para definir lideranca.</p>', 'staff-org-detail-card');
    }

    return ui().card('Definir lider', 'Coloca um player na maior grade desta organizacao.', '<div class="staff-set-leader-form">' +
      '<div class="staff-set-leader-hint staff-leader-wide"><span>Organizacao selecionada</span><strong>' + ui().safeText(org.name || orgCode || '-') + '</strong><small>' + ui().safeText(orgCode || '-') + '</small></div>' +
      '<label><span>CitizenID</span><input data-staff-leader-field="citizenid" maxlength="64" value="' + ui().safeText(form.citizenid) + '" placeholder="CitizenID ou passaporte" ' + (form.loading ? 'disabled' : '') + ' /></label>' +
      '<label><span>Motivo opcional</span><textarea data-staff-leader-field="reason" maxlength="255" rows="3" placeholder="Motivo para auditoria" ' + (form.loading ? 'disabled' : '') + '>' + ui().safeText(form.reason) + '</textarea></label>' +
      '<p class="soft-note staff-leader-wide">O codigo da organizacao vem do detalhe selecionado. A NUI nao envia cargo, source, permissao ou grade.</p>' +
      '<div class="staff-leader-actions"><button class="btn btn-primary" data-action="staff-set-leader" ' + (form.loading ? 'disabled' : '') + '>' + ui().safeText(form.loading ? 'Definindo...' : 'Definir lider') + '</button></div>' +
      message + error +
    '</div>', 'staff-org-detail-card');
  }

  function openStaffEditOrgBasicModal() {
    var current = state();
    var details = current.staffOrgDetails || {};
    var data = details.data || {};
    var org = data.org || findStaffOrgByCode(details.orgCode) || {};
    var modal = current.staffEditOrgBasic;

    if (!details.orgCode || !canUpdateStaffOrgBasic()) return;
    if (isStaffDetailOrgArchived(data)) return;

    modal.open = true;
    modal.orgCode = details.orgCode;
    modal.name = org.name || '';
    modal.status = orgStatusFromOrg(org);
    modal.hasSalary = org.hasSalary === true || org.has_salary === true;
    modal.hasSharedAccount = org.hasSharedAccount === true || org.has_shared_account === true;
    modal.hasStorage = org.hasStorage === true || org.has_storage === true;
    modal.reason = '';
    modal.loading = false;
    modal.error = null;
    modal.message = null;
    render();
  }

  function closeStaffEditOrgBasicModal() {
    var modal = state().staffEditOrgBasic;
    if (modal.loading) return;
    modal.open = false;
    modal.error = null;
    render();
  }

  function renderStaffEditOrgBasicModal() {
    var modal = state().staffEditOrgBasic || {};
    if (!modal.open) return '';

    var error = modal.error ? '<div class="staff-org-modal-error">' + ui().safeText(formatStaffEditOrgBasicError(modal.error)) + '</div>' : '';
    return '<div class="staff-org-modal-backdrop" role="presentation">' +
      '<section class="staff-org-modal" role="dialog" aria-modal="true" aria-label="Editar dados basicos">' +
        '<div class="staff-org-modal-header"><div><span>Staff</span><h3>Editar dados basicos</h3><p>Somente nome, status e flags da organizacao selecionada.</p></div><button class="modal-close" data-action="close-staff-edit-org-basic-modal" aria-label="Cancelar">x</button></div>' +
        '<div class="staff-org-modal-body">' +
          '<label><span>Nome</span><input data-staff-edit-org-basic-field="name" maxlength="120" value="' + ui().safeText(modal.name) + '" placeholder="Nome da organizacao" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Status</span><select data-staff-edit-org-basic-field="status" ' + (modal.loading ? 'disabled' : '') + '>' +
            '<option value="private"' + (modal.status === 'private' ? ' selected' : '') + '>Privada</option>' +
            '<option value="public"' + (modal.status === 'public' ? ' selected' : '') + '>Publica</option>' +
          '</select></label>' +
          '<label class="toggle-line"><input data-staff-edit-org-basic-field="hasSharedAccount" type="checkbox" ' + (modal.hasSharedAccount ? 'checked' : '') + ' ' + (modal.loading ? 'disabled' : '') + ' /> <span>Conta compartilhada</span></label>' +
          '<label class="toggle-line"><input data-staff-edit-org-basic-field="hasStorage" type="checkbox" ' + (modal.hasStorage ? 'checked' : '') + ' ' + (modal.loading ? 'disabled' : '') + ' /> <span>Bau/storage</span></label>' +
          '<label class="toggle-line"><input data-staff-edit-org-basic-field="hasSalary" type="checkbox" ' + (modal.hasSalary ? 'checked' : '') + ' ' + (modal.loading ? 'disabled' : '') + ' /> <span>Salario</span></label>' +
          '<label class="staff-org-modal-wide"><span>Motivo opcional</span><textarea data-staff-edit-org-basic-field="reason" maxlength="255" rows="3" placeholder="Motivo para auditoria" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.reason) + '</textarea></label>' +
          '<small class="soft-note staff-org-modal-wide">Nao e possivel alterar codigo, tipo, cargos, permissoes, membros ou banco por este modal.</small>' +
          error +
        '</div>' +
        '<div class="staff-org-modal-actions">' +
          '<button class="btn btn-ghost" data-action="close-staff-edit-org-basic-modal" ' + (modal.loading ? 'disabled' : '') + '>Cancelar</button>' +
          '<button class="btn btn-primary" data-action="submit-staff-edit-org-basic-modal" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.loading ? 'Salvando...' : 'Salvar') + '</button>' +
        '</div>' +
      '</section>' +
    '</div>';
  }

  function formatStaffEditOrgBasicError(error) {
    var key = String(error || '').toLowerCase();
    if (key.indexOf('invalid_org') !== -1 || key.indexOf('organizacao invalida') !== -1) return 'Organizacao invalida.';
    if (key.indexOf('org_not_found') !== -1 || key.indexOf('nao encontrada') !== -1) return 'Organizacao nao encontrada.';
    if (key.indexOf('invalid_name') !== -1 || key.indexOf('nome') !== -1) return 'Informe um nome valido.';
    if (key.indexOf('invalid_status') !== -1 || key.indexOf('status') !== -1) return 'Status invalido.';
    if (key.indexOf('forbidden') !== -1 || key.indexOf('permiss') !== -1) return 'Voce nao tem permissao para editar esta organizacao.';
    if (key.indexOf('rate_limited') !== -1 || key.indexOf('aguarde') !== -1) return 'Aguarde alguns segundos e tente novamente.';
    return error || 'Nao foi possivel atualizar a organizacao.';
  }

  function submitStaffEditOrgBasicModal() {
    var current = state();
    var modal = current.staffEditOrgBasic;
    var details = current.staffOrgDetails || {};
    var orgCode = String(details.orgCode || modal.orgCode || '').replace(/^\s+|\s+$/g, '');
    var app = document.getElementById('app');

    function field(name) {
      var input = app && app.querySelector('[data-staff-edit-org-basic-field="' + name + '"]');
      if (!input) return modal[name] || '';
      if (input.type === 'checkbox') return input.checked;
      return input.value.replace(/^\s+|\s+$/g, '');
    }

    modal.name = field('name');
    modal.status = field('status') || 'private';
    modal.hasSalary = field('hasSalary') === true;
    modal.hasSharedAccount = field('hasSharedAccount') === true;
    modal.hasStorage = field('hasStorage') === true;
    modal.reason = field('reason');
    modal.error = null;
    modal.message = null;

    if (!orgCode) {
      modal.error = 'Organizacao invalida.';
      render();
      return;
    }

    if (!modal.name) {
      modal.error = 'Informe um nome valido.';
      render();
      return;
    }

    modal.loading = true;
    render();

    window.MZOrgService.updateOrgBasic(orgCode, {
      name: modal.name,
      status: modal.status,
      hasSalary: modal.hasSalary,
      hasSharedAccount: modal.hasSharedAccount,
      hasStorage: modal.hasStorage,
      reason: modal.reason
    }).then(function (data) {
      var org = data && data.org ? data.org : {};
      modal.message = 'Dados basicos atualizados para ' + (org.name || modal.name) + '.';
      modal.open = false;
      modal.error = null;
      current.orgs.loaded = false;
      current.orgs.loadedKey = '';
      current.orgs.data = [];
      loadOrgs();
      openStaffOrgDetails(orgCode, { tab: 'actions' });
    }).catch(function (err) {
      modal.error = formatStaffEditOrgBasicError(err.message);
    }).finally(function () {
      modal.loading = false;
      render();
    });
  }

  function canCreateStaffOrg() {
    var current = state();
    if (!current.session) return false;
    if (current.session.user && current.session.user.isOwner) return true;
    return perms().hasGlobalPermission(current.session, 'staff.orgs.create');
  }

  function renderStaffCreateOrgPanel() {
    var current = state();
    var form = current.staffCreateOrg || {};
    var message = form.message ? '<div class="inline-message success">' + ui().safeText(form.message) + '</div>' : '';
    var error = form.error && !form.open ? '<div class="inline-message error-inline">' + ui().safeText(formatStaffCreateOrgError(form.error)) + '</div>' : '';

    if (!canCreateStaffOrg()) {
      return ui().card('Criar organizacao', 'Criacao por template seguro.', '<div class="badge-row">' + ui().badge('Bloqueado', 'warning') + '</div><p class="soft-note">Requer staff.orgs.create ou owner.</p>', 'staff-list-card');
    }

    return ui().card('Criar organizacao', 'Templates seguros criam cargos, permissoes e conta quando aplicavel.', '<div class="staff-action-grid compact">' +
      '<button class="staff-action-card" data-action="open-staff-create-org-modal">' +
        ui().renderIcon('assets/icons/orgs.svg', 'O', 'inline-icon-box') +
        '<span><strong>Criar organizacao</strong><small>Job, faccao, empresa, governo, VIP ou evento.</small></span>' +
      '</button>' +
    '</div><p class="soft-note">A criacao usa templates do servidor. Editor avancado de cargos/permissoes fica para fase futura.</p>' + message + error, 'staff-list-card');
  }

  function openStaffCreateOrgModal() {
    var modal = state().staffCreateOrg;
    modal.open = true;
    modal.type = modal.type || 'gang';
    modal.code = modal.code || '';
    modal.name = modal.name || '';
    modal.hasSalary = modal.hasSalary === true;
    modal.hasSharedAccount = modal.hasSharedAccount !== false;
    modal.hasStorage = modal.hasStorage !== false;
    modal.reason = modal.reason || '';
    modal.loading = false;
    modal.error = null;
    modal.message = null;
    render();
  }

  function closeStaffCreateOrgModal() {
    var modal = state().staffCreateOrg;
    if (modal.loading) return;
    modal.open = false;
    modal.error = null;
    render();
  }

  function renderStaffCreateOrgModal() {
    var modal = state().staffCreateOrg || {};
    if (!modal.open) return '';

    var options = staffOrgCreateTypes.map(function (item) {
      return '<option value="' + ui().escapeHtml(item.id) + '"' + (modal.type === item.id ? ' selected' : '') + '>' + ui().safeText(item.label) + '</option>';
    }).join('');

    var error = modal.error ? '<div class="staff-org-modal-error">' + ui().safeText(formatStaffCreateOrgError(modal.error)) + '</div>' : '';
    return '<div class="staff-org-modal-backdrop" role="presentation">' +
      '<section class="staff-org-modal" role="dialog" aria-modal="true" aria-label="Criar organizacao">' +
        '<div class="staff-org-modal-header"><div><span>Staff</span><h3>Criar organizacao</h3><p>Template seguro, sem editor livre nesta fase.</p></div><button class="modal-close" data-action="close-staff-create-org-modal" aria-label="Cancelar">x</button></div>' +
        '<div class="staff-org-modal-body">' +
          '<label><span>Tipo</span><select data-staff-create-org-field="type" ' + (modal.loading ? 'disabled' : '') + '>' + options + '</select></label>' +
          '<label><span>Codigo</span><input data-staff-create-org-field="code" maxlength="48" value="' + ui().safeText(modal.code) + '" placeholder="Ex: mafia_norte" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Nome</span><input data-staff-create-org-field="name" maxlength="120" value="' + ui().safeText(modal.name) + '" placeholder="Ex: Mafia Norte" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label class="toggle-line"><input data-staff-create-org-field="hasSharedAccount" type="checkbox" ' + (modal.hasSharedAccount ? 'checked' : '') + ' ' + (modal.loading ? 'disabled' : '') + ' /> <span>Conta compartilhada</span></label>' +
          '<label class="toggle-line"><input data-staff-create-org-field="hasStorage" type="checkbox" ' + (modal.hasStorage ? 'checked' : '') + ' ' + (modal.loading ? 'disabled' : '') + ' /> <span>Bau/storage</span></label>' +
          '<label class="toggle-line"><input data-staff-create-org-field="hasSalary" type="checkbox" ' + (modal.hasSalary ? 'checked' : '') + ' ' + (modal.loading ? 'disabled' : '') + ' /> <span>Salario</span></label>' +
          '<label class="staff-org-modal-wide"><span>Motivo opcional</span><textarea data-staff-create-org-field="reason" maxlength="255" rows="3" placeholder="Motivo para auditoria" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.reason) + '</textarea></label>' +
          '<small class="soft-note staff-org-modal-wide">A NUI envia somente tipo, codigo, nome, opcoes basicas e motivo. Cargos e permissoes sao calculados pelo servidor.</small>' +
          error +
        '</div>' +
        '<div class="staff-org-modal-actions">' +
          '<button class="btn btn-ghost" data-action="close-staff-create-org-modal" ' + (modal.loading ? 'disabled' : '') + '>Cancelar</button>' +
          '<button class="btn btn-primary" data-action="submit-staff-create-org-modal" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.loading ? 'Criando...' : 'Criar organizacao') + '</button>' +
        '</div>' +
      '</section>' +
    '</div>';
  }

  function formatStaffCreateOrgError(error) {
    var key = String(error || '').toLowerCase();
    if (key.indexOf('invalid_type') !== -1 || key.indexOf('tipo') !== -1) return 'Tipo de organizacao invalido.';
    if (key.indexOf('invalid_code') !== -1 || key.indexOf('codigo') !== -1) return 'Informe um codigo valido.';
    if (key.indexOf('invalid_name') !== -1 || key.indexOf('nome') !== -1) return 'Informe um nome valido.';
    if (key.indexOf('org_already_exists') !== -1 || key.indexOf('ja existe') !== -1) return 'Ja existe uma organizacao com esse codigo.';
    if (key.indexOf('forbidden') !== -1 || key.indexOf('permiss') !== -1) return 'Voce nao tem permissao para criar organizacoes.';
    if (key.indexOf('template_not_found') !== -1 || key.indexOf('template') !== -1) return 'Template nao encontrado.';
    if (key.indexOf('create_grade_failed') !== -1) return 'Nao foi possivel criar os cargos padrao.';
    if (key.indexOf('create_permission_failed') !== -1) return 'Nao foi possivel criar as permissoes padrao.';
    if (key.indexOf('create_account_failed') !== -1) return 'Nao foi possivel criar a conta compartilhada.';
    if (key.indexOf('rate_limited') !== -1 || key.indexOf('aguarde') !== -1) return 'Aguarde alguns segundos e tente novamente.';
    return error || 'Nao foi possivel criar a organizacao.';
  }

  function submitStaffCreateOrgModal() {
    var current = state();
    var modal = current.staffCreateOrg;
    var app = document.getElementById('app');

    function field(name) {
      var input = app && app.querySelector('[data-staff-create-org-field="' + name + '"]');
      if (!input) return modal[name] || '';
      if (input.type === 'checkbox') return input.checked;
      return input.value.replace(/^\s+|\s+$/g, '');
    }

    modal.type = field('type') || 'gang';
    modal.code = field('code');
    modal.name = field('name');
    modal.hasSalary = field('hasSalary') === true;
    modal.hasSharedAccount = field('hasSharedAccount') === true;
    modal.hasStorage = field('hasStorage') === true;
    modal.reason = field('reason');
    modal.error = null;
    modal.message = null;

    if (!modal.code) {
      modal.error = 'Informe um codigo valido.';
      render();
      return;
    }

    if (!modal.name) {
      modal.error = 'Informe um nome valido.';
      render();
      return;
    }

    modal.loading = true;
    render();

    window.MZOrgService.createOrgFromTemplate({
      type: modal.type,
      code: modal.code,
      name: modal.name,
      hasSalary: modal.hasSalary,
      hasSharedAccount: modal.hasSharedAccount,
      hasStorage: modal.hasStorage,
      reason: modal.reason
    }).then(function (data) {
      var org = data && data.org ? data.org : {};
      modal.message = 'Organizacao criada: ' + (org.name || modal.name) + '.';
      modal.open = false;
      modal.type = 'gang';
      modal.code = '';
      modal.name = '';
      modal.hasSalary = false;
      modal.hasSharedAccount = true;
      modal.hasStorage = true;
      modal.reason = '';
      current.orgs.loaded = false;
      current.orgs.loadedKey = '';
      current.orgs.data = [];
      current.logs.loaded = false;
      current.logs.loadedKey = '';
      loadOrgs();
      if (canLoadStaffGlobalLogs()) loadLogs({ limit: 100 });
    }).catch(function (err) {
      modal.error = formatStaffCreateOrgError(err.message);
    }).finally(function () {
      modal.loading = false;
      render();
    });
  }

  function staffOrgVariant(type) {
    type = String(type || '').toLowerCase();
    if (type === 'gang' || type === 'illegal') return 'danger';
    if (type === 'staff') return 'owner';
    if (type === 'business') return 'success';
    return 'info';
  }

  function renderStaffLogsSection() {
    var current = state();
    var logs = filteredLogs();
    var categoryOptions = unique(current.logs.data.map(function (log) { return log.category; }));
    var severityOptions = unique(current.logs.data.map(function (log) { return log.severity; }));
    var orgOptions = unique(current.logs.data.map(function (log) { return log.orgCode; }));
    var body = current.logs.loading
      ? ui().loading('Carregando logs')
      : current.logs.error
        ? ui().errorBox(current.logs.error)
        : renderStaffLogList(logs, 'Nenhum log visivel com os filtros atuais.');

    return ui().card('Filtros', 'Filtros locais sobre os logs ja autorizados pelo servidor.', renderLogFilters(categoryOptions, severityOptions, orgOptions), 'staff-list-card') +
      ui().card('Logs recentes', 'Lista legivel, sem payload tecnico bruto.', body, 'staff-list-card');
  }

  function renderStaffAuditSection() {
    var current = state();
    var logs = sensitiveStaffLogs();
    var body = current.logs.loading
      ? ui().loading('Carregando auditoria')
      : current.logs.error
        ? ui().errorBox(current.logs.error)
        : renderStaffLogList(logs, 'Nenhum evento sensivel recente encontrado.');

    return ui().card('Auditoria sensivel', 'Eventos de lideranca, membros, banco, recrutamento e metas dentro dos logs recentes.', body, 'staff-list-card');
  }

  function sensitiveStaffLogs() {
    return (state().logs.data || []).filter(function (log) {
      var action = String(log.action || '').toLowerCase();
      return sensitiveAuditActions.some(function (item) {
        return action.indexOf(item) !== -1;
      });
    });
  }

  function renderStaffLogList(logs, emptyMessage) {
    logs = Array.isArray(logs) ? logs : [];
    if (!logs.length) return ui().empty(emptyMessage || 'Nenhum evento encontrado.', 'Os dados aparecem aqui quando o servidor retornar logs permitidos.');

    return '<div class="staff-log-list">' + logs.map(function (log) {
      return '<article class="staff-log-item">' +
        '<div><strong>' + ui().safeText(formatLogAction(log)) + '</strong><span>' + ui().safeText(fmt().formatDate(log.createdAt)) + '</span></div>' +
        '<div class="badge-row">' + ui().badge(fmt().formatStatusLabel(log.severity || 'info'), severityVariant(log.severity)) + (log.orgCode ? ui().badge(log.orgCode, 'muted') : '') + '</div>' +
        '<p>' + ui().safeText(log.message || log.reason || 'Evento registrado pelo servidor.') + '</p>' +
        '<small>Autor: ' + ui().safeText(log.actorName || fmt().maskCitizenId(log.actorCitizenId)) + ' | Alvo: ' + ui().safeText(log.targetName || fmt().maskCitizenId(log.targetCitizenId)) + '</small>' +
      '</article>';
    }).join('') + '</div>';
  }

  function formatLogAction(log) {
    var action = log && log.action ? log.action : (log && log.category);
    if (fmt().formatActionLabel) return fmt().formatActionLabel(action);
    return fmt().formatStatusLabel(action);
  }

  function renderStaffActionsSection() {
    return '<div class="staff-action-grid">' +
      ui().card('Definir lider', 'A acao agora fica dentro da organizacao selecionada.', '<p class="soft-note">Use Organizacoes > Ver detalhes > Acoes para definir o lider de uma org/faccao. Assim o codigo da org vem do detalhe selecionado e nao de um campo manual.</p>', 'staff-leader-card') +
      renderDisabledStaffAction('Adicionar membro global', 'Criar membro em qualquer org sera uma fase propria com permissao forte.') +
      renderDisabledStaffAction('Remover membro global', 'Remocao administrativa global continua bloqueada nesta fase.') +
      renderDisabledStaffAction('Gerenciar staff', 'Hierarquia e gestao de staff permanecem fase futura.') +
      renderDisabledStaffAction('Editar cargos/permissoes', 'Editor de grades e capabilities nao faz parte desta fase.') +
    '</div>';
  }

  function renderDisabledStaffAction(title, description) {
    return '<section class="staff-action-card is-disabled">' +
      '<div class="badge-row">' + ui().badge('Em fase futura', 'muted') + '</div>' +
      '<span><strong>' + ui().safeText(title) + '</strong><small>' + ui().safeText(description) + '</small></span>' +
    '</section>';
  }

  function canShowStaffLeaderCard() {
    var current = state();
    if (!current.session) return false;
    if (current.session.user && current.session.user.isOwner) return true;
    return perms().hasGlobalPermission(current.session, 'staff.orgs.set_leader');
  }

  function formatStaffLeaderError(error) {
    var key = String(error || '').toLowerCase();
    if (key.indexOf('invalid_org') !== -1 || key.indexOf('organizacao invalida') !== -1) return 'Organizacao invalida.';
    if (key.indexOf('invalid_target') !== -1 || key.indexOf('citizenid') !== -1) return 'Informe um CitizenID valido.';
    if (key.indexOf('target_not_found') !== -1 || key.indexOf('player nao encontrado') !== -1) return 'Player nao encontrado.';
    if (key.indexOf('forbidden') !== -1 || key.indexOf('permiss') !== -1) return 'Voce nao tem permissao para definir lideranca.';
    if (key.indexOf('top_grade_not_found') !== -1 || key.indexOf('cargo maximo') !== -1) return 'Cargo maximo da organizacao nao encontrado.';
    if (key.indexOf('rate_limited') !== -1 || key.indexOf('aguarde') !== -1) return 'Aguarde alguns segundos e tente novamente.';
    return error || 'Nao foi possivel definir o lider.';
  }

  function submitStaffLeader() {
    var current = state();
    var form = current.staffLeader;
    var app = document.getElementById('app');
    var details = current.staffOrgDetails || {};
    var detailData = details.data || {};
    var detailOrg = detailData.org || {};

    function field(name) {
      var input = app && app.querySelector('[data-staff-leader-field="' + name + '"]');
      return input ? input.value.replace(/^\s+|\s+$/g, '') : (form[name] || '');
    }

    var orgCode = String(details.orgCode || detailOrg.code || '').replace(/^\s+|\s+$/g, '');
    var citizenid = field('citizenid');
    var reason = field('reason');

    form.orgCode = '';
    form.citizenid = citizenid;
    form.reason = reason;
    form.message = null;
    form.error = null;

    if (!orgCode) {
      form.error = 'Organizacao invalida.';
      render();
      return;
    }

    if (!citizenid) {
      form.error = 'Informe um CitizenID valido.';
      render();
      return;
    }

    form.loading = true;
    render();

    window.MZOrgMemberService.setOrgLeader(orgCode, citizenid, reason).then(function (data) {
      form.message = 'Lider definido em ' + (data.orgName || data.orgCode || orgCode) + ' na grade ' + (data.gradeName || data.gradeCode || data.gradeLevel || 'maxima') + '.';
      form.citizenid = '';
      form.reason = '';
      openStaffOrgDetails(orgCode, { tab: 'actions' });
    }).catch(function (err) {
      form.error = formatStaffLeaderError(err.message);
    }).finally(function () {
      form.loading = false;
      render();
    });
  }

  function renderLogsPage() {
    var current = state();
    var logs = filteredLogs();
    var categoryOptions = unique(current.logs.data.map(function (log) { return log.category; }));
    var severityOptions = unique(current.logs.data.map(function (log) { return log.severity; }));
    var orgOptions = unique(current.logs.data.map(function (log) { return log.orgCode; }));
    var listBody = current.logs.loading ? ui().loading('Carregando logs') : current.logs.error ? ui().errorBox(current.logs.error) : !logs.length ? ui().empty('Nenhum log visivel', 'Nao ha logs permitidos para esta sessao ou os filtros removeram todos.') : renderLogsTable(logs);

    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Auditoria</span><h2>Logs</h2><p>Eventos importantes retornados pelo servidor para acompanhamento.</p></div>' + ui().badge(logs.length + ' visiveis', 'info') + '</div>' +
      '<div class="metric-grid">' + ui().metricCard('assets/icons/logs.svg', current.logs.data.length, 'Total retornado', 'L') + ui().metricCard('assets/icons/warning.svg', current.logs.data.filter(function (l) { return l.severity === 'warning' || l.severity === 'warn'; }).length, 'Avisos', 'W') + ui().metricCard('assets/icons/alert.svg', current.logs.data.filter(function (l) { return l.severity === 'danger' || l.severity === 'error'; }).length, 'Criticos', 'A') + '</div>' +
      ui().card('Filtros locais', 'Refinam somente a lista ja permitida pelo servidor.', renderLogFilters(categoryOptions, severityOptions, orgOptions)) +
      ui().card('Eventos', 'Nenhum dado sensivel bruto e exibido nesta tabela.', listBody) +
    '</div>';
  }

  function canManageRecruitment(contextOrg) {
    var current = state();
    if (!current.session) return false;
    if (current.session.user && current.session.user.isOwner) return true;

    var caps = [];
    if (contextOrg && Array.isArray(contextOrg.capabilities)) caps = caps.concat(contextOrg.capabilities);
    if (current.orgView.detail && Array.isArray(current.orgView.detail.capabilities)) caps = caps.concat(current.orgView.detail.capabilities);

    return caps.indexOf('recruitment.manage') !== -1
      || caps.indexOf('members.invite') !== -1
      || caps.indexOf('manage.members') !== -1;
  }

  function recruitmentSummary(items) {
    items = Array.isArray(items) ? items : [];
    return {
      pending: items.filter(function (item) { return String(item.status || 'pending').toLowerCase() === 'pending'; }).length,
      approved: items.filter(function (item) { return String(item.status || '').toLowerCase() === 'approved'; }).length,
      rejected: items.filter(function (item) { return String(item.status || '').toLowerCase() === 'rejected'; }).length
    };
  }

  function renderRecruitmentSummaryCard(label, value, description) {
    return '<article class="recruitment-summary-card"><span>' + ui().safeText(label) + '</span><strong>' + ui().safeText(value) + '</strong><small>' + ui().safeText(description) + '</small></article>';
  }

  function renderRecruitmentActionCard(contextOrg) {
    var current = state();
    var allowed = canManageRecruitment(contextOrg);
    var text = allowed ? 'Registrar candidato por CitizenID.' : 'Seu cargo atual nao gerencia candidaturas.';
    return '<button class="recruitment-action-card" data-action="open-recruitment-modal" data-recruitment-mode="create" ' + (!allowed || current.recruitmentModal.loading ? 'disabled' : '') + '><strong>Novo candidato</strong><span>' + ui().safeText(text) + '</span></button>';
  }

  function renderRecruitmentMessages() {
    var current = state();
    var message = current.recruitment.actionMessage ? '<div class="inline-message success">' + ui().safeText(current.recruitment.actionMessage) + '</div>' : '';
    var error = current.recruitment.actionError ? '<div class="inline-message error-inline">' + ui().safeText(formatRecruitmentError(current.recruitment.actionError)) + '</div>' : '';
    return message + error;
  }

  function renderRecruitmentLayout(contextOrg, listBody) {
    var current = state();
    var summary = recruitmentSummary(current.recruitment.data || []);
    var title = current.activeShell === 'illegal' || current.activePanel === 'illegal' ? 'Candidaturas da faccao' : 'Candidaturas';

    return '<section class="recruitment-section">' +
      '<div class="recruitment-top-grid">' +
        renderRecruitmentSummaryCard('Pendentes', summary.pending, 'Aguardando decisao nesta org.') +
        renderRecruitmentSummaryCard('Aprovados', summary.approved, 'Viraram membros reais.') +
        renderRecruitmentActionCard(contextOrg) +
      '</div>' +
      renderRecruitmentMessages() +
      ui().card(title, 'Candidatos filtrados pela organizacao ativa.', listBody, 'recruitment-list-card') +
      renderRecruitmentModal() +
    '</section>';
  }

  function renderRecruitmentActionButtons(item) {
    if (!item || !item.id) return ui().safeText('-');
    var status = String(item.status || 'pending').toLowerCase();
    if (status !== 'pending') {
      if (status === 'approved') return ui().badge('Aprovada', 'success');
      if (status === 'rejected') return ui().badge('Recusada', 'danger');
      if (status === 'cancelled') return ui().badge('Arquivada', 'muted');
      return ui().badge(fmt().formatStatusLabel(status), recruitmentStatusVariant(status));
    }

    var id = ui().escapeHtml(item.id);
    return '<div class="action-row">' +
      '<button class="btn btn-ghost" data-action="open-recruitment-modal" data-recruitment-mode="approve" data-recruitment-id="' + id + '">Aprovar</button>' +
      '<button class="btn btn-ghost danger-btn" data-action="open-recruitment-modal" data-recruitment-mode="reject" data-recruitment-id="' + id + '">Recusar</button>' +
      '<button class="btn btn-ghost" data-action="open-recruitment-modal" data-recruitment-mode="cancel" data-recruitment-id="' + id + '">Arquivar</button>' +
    '</div>';
  }

  function recruitmentById(id) {
    id = String(id || '');
    return (state().recruitment.data || []).filter(function (item) {
      return String(item.id || '') === id;
    })[0] || null;
  }

  function openRecruitmentModal(mode, id) {
    var current = state();
    var item = recruitmentById(id);
    current.recruitment.actionMessage = null;
    current.recruitment.actionError = null;
    current.recruitmentModal.open = true;
    current.recruitmentModal.mode = mode || 'create';
    current.recruitmentModal.id = id || null;
    current.recruitmentModal.citizenid = '';
    current.recruitmentModal.gradeLevel = item && item.desiredGradeLevel ? String(item.desiredGradeLevel) : '';
    current.recruitmentModal.note = '';
    current.recruitmentModal.loading = false;
    current.recruitmentModal.error = null;
    render();
  }

  function closeRecruitmentModal() {
    var current = state();
    if (current.recruitmentModal.loading) return;
    current.recruitmentModal.open = false;
    current.recruitmentModal.error = null;
    render();
  }

  function recruitmentGradeSelect(contextOrg, value) {
    var grades = inviteGradeOptions(contextOrg);
    var selectedValue = String(value || '');
    if (!grades.length) {
      return '<label><span>Grade inicial</span><select data-recruitment-modal-field="gradeLevel" disabled><option value="">Cargo inicial automatico</option></select></label>';
    }

    return '<label><span>Grade inicial</span><select data-recruitment-modal-field="gradeLevel">' +
      '<option value="">Cargo inicial automatico</option>' +
      grades.map(function (grade) {
        var selected = selectedValue === String(grade.level || '') ? ' selected' : '';
        return '<option value="' + ui().escapeHtml(grade.level) + '"' + selected + '>' + ui().safeText(grade.name || grade.code) + ' (nivel ' + ui().safeText(grade.level) + ')</option>';
      }).join('') +
    '</select></label>';
  }

  function renderRecruitmentModal() {
    var current = state();
    var modal = current.recruitmentModal || {};
    if (!modal.open) return '';

    var mode = modal.mode || 'create';
    var item = recruitmentById(modal.id);
    var org = getActiveOrg() || current.orgView.detail || {};
    var contextOrg = perms().contextOrgsForActiveModule().filter(function (candidate) { return candidate.code === selectedOrgCode(); })[0] || null;
    var title = mode === 'approve' ? 'Aprovar candidatura' : mode === 'reject' ? 'Recusar candidatura' : mode === 'cancel' ? 'Arquivar candidatura' : 'Novo candidato';
    var confirmLabel = mode === 'approve' ? 'Confirmar aprovacao' : mode === 'reject' ? 'Confirmar recusa' : mode === 'cancel' ? 'Arquivar' : 'Criar candidatura';
    var body = '';

    if (mode === 'create') {
      body =
        '<label><span>CitizenID</span><input data-recruitment-modal-field="citizenid" maxlength="64" value="' + ui().safeText(modal.citizenid) + '" placeholder="CitizenID ou passaporte" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
        recruitmentGradeSelect(contextOrg, modal.gradeLevel) +
        '<label class="recruitment-modal-wide"><span>Observacao</span><textarea data-recruitment-modal-field="note" maxlength="1000" rows="3" placeholder="Resumo da triagem" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.note) + '</textarea></label>';
    } else {
      body =
        '<div class="recruitment-decision-summary"><strong>' + ui().safeText(item && (item.candidateName || item.targetName) || 'Candidato') + '</strong><span>CID ' + ui().safeText(fmt().maskCitizenId(item && (item.candidateCitizenId || item.targetCitizenId))) + '</span></div>' +
        (mode === 'approve' ? recruitmentGradeSelect(contextOrg, modal.gradeLevel) : '') +
        '<label class="recruitment-modal-wide"><span>' + ui().safeText(mode === 'approve' ? 'Nota opcional' : 'Motivo opcional') + '</span><textarea data-recruitment-modal-field="note" maxlength="1000" rows="3" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.note) + '</textarea></label>';
    }

    var error = modal.error ? '<div class="recruitment-modal-error">' + ui().safeText(formatRecruitmentError(modal.error)) + '</div>' : '';
    return '<div class="recruitment-modal-backdrop" role="presentation">' +
      '<section class="recruitment-modal" role="dialog" aria-modal="true" aria-label="' + ui().safeText(title) + '">' +
        '<div class="recruitment-modal-header"><div><span>Recrutamento</span><h3>' + ui().safeText(title) + '</h3><p>' + ui().safeText(org.name || selectedOrgCode() || 'Organizacao ativa') + '</p></div><button class="modal-close" data-action="close-recruitment-modal" aria-label="Cancelar">x</button></div>' +
        '<div class="recruitment-modal-body">' + body + '<small class="soft-note recruitment-modal-note">CitizenID, cargo e permissao sao validados pelo servidor.</small>' + error + '</div>' +
        '<div class="recruitment-modal-actions">' +
          '<button class="btn btn-ghost" data-action="close-recruitment-modal" ' + (modal.loading ? 'disabled' : '') + '>Cancelar</button>' +
          '<button class="recruitment-confirm-btn" data-action="submit-recruitment-modal" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.loading ? 'Processando...' : confirmLabel) + '</button>' +
        '</div>' +
      '</section>' +
    '</div>';
  }

  function formatRecruitmentError(error) {
    var key = String(error || '').toLowerCase();
    if (key.indexOf('player nao encontrado') !== -1 || key.indexOf('target_not_found') !== -1) return 'Player nao encontrado.';
    if (key.indexOf('ja existe') !== -1 || key.indexOf('already_pending') !== -1) return 'Ja existe uma candidatura pendente para esse CitizenID.';
    if (key.indexOf('ja e membro') !== -1 || key.indexOf('already_member') !== -1) return 'Esse player ja e membro da organizacao.';
    if (key.indexOf('sem permissao') !== -1 || key.indexOf('forbidden') !== -1) return 'Voce nao tem permissao para gerenciar recrutamento.';
    if (key.indexOf('cargo') !== -1 || key.indexOf('grade') !== -1 || key.indexOf('lideranca') !== -1) return 'Cargo inicial invalido ou protegido.';
    if (key.indexOf('pendente') !== -1 || key.indexOf('invalid_status') !== -1) return 'Esta candidatura nao esta pendente.';
    if (key.indexOf('aguarde') !== -1 || key.indexOf('rate_limited') !== -1) return 'Aguarde alguns segundos e tente novamente.';
    return error || 'Nao foi possivel concluir a acao.';
  }

  function submitRecruitmentModal() {
    var current = state();
    var modal = current.recruitmentModal || {};
    var app = document.getElementById('app');
    var code = selectedOrgCode();
    var mode = modal.mode || 'create';

    function field(name) {
      var input = app && app.querySelector('[data-recruitment-modal-field="' + name + '"]');
      return input ? input.value : (modal[name] || '');
    }

    current.recruitment.actionMessage = null;
    current.recruitment.actionError = null;
    modal.error = null;

    if (!code) {
      modal.error = 'Organizacao invalida.';
      render();
      return;
    }

    var note = field('note');
    var gradeLevel = field('gradeLevel');
    modal.note = note || '';
    modal.gradeLevel = gradeLevel || '';
    modal.loading = true;
    current.recruitment.actionLoading = true;
    render();

    var promise;
    if (mode === 'create') {
      var citizenid = field('citizenid').replace(/^\s+|\s+$/g, '');
      modal.citizenid = citizenid;
      if (!citizenid) {
        modal.loading = false;
        current.recruitment.actionLoading = false;
        modal.error = 'Informe o CitizenID do candidato.';
        render();
        return;
      }
      promise = window.MZOrgRecruitmentService.createRecruitment(code, { citizenid: citizenid, desiredGradeLevel: gradeLevel, note: note });
    } else if (mode === 'approve') {
      promise = window.MZOrgRecruitmentService.approveRecruitment(modal.id, { gradeLevel: gradeLevel, note: note });
    } else if (mode === 'reject') {
      promise = window.MZOrgRecruitmentService.rejectRecruitment(modal.id, note);
    } else {
      promise = window.MZOrgRecruitmentService.cancelRecruitment(modal.id, note);
    }

    promise.then(function () {
      current.recruitment.actionMessage = mode === 'create'
        ? 'Candidatura criada.'
        : mode === 'approve'
          ? 'Candidatura aprovada e membro adicionado.'
          : mode === 'reject'
            ? 'Candidatura recusada.'
            : 'Candidatura arquivada.';
      modal.open = false;
      modal.error = null;
      return reloadRecruitment();
    }).catch(function (err) {
      modal.error = formatRecruitmentError(err.message);
    }).finally(function () {
      modal.loading = false;
      current.recruitment.actionLoading = false;
      render();
    });
  }

  function renderRecruitmentPage() {
    var current = state();
    var panel = getPanel(current.activePanel);
    var available = perms().contextOrgsForActiveModule();
    var code = selectedOrgCode();
    var contextOrg = available.filter(function (org) { return org.code === code; })[0] || null;
    var isIllegal = current.activePanel === 'illegal';
    var title = isIllegal ? 'Recrutamento da faccao' : 'Recrutamento';

    if (code && current.recruitment.loadedKey !== current.activePanel + ':' + code && !current.recruitment.loading) {
      window.setTimeout(loadRecruitment, 0);
    }

    var body = current.recruitment.loading
      ? ui().loading('Carregando recrutamento')
      : current.recruitment.error
        ? ui().errorBox(current.recruitment.error)
        : renderRecruitmentList(current.recruitment.data || [], isIllegal);

    var emptyHub = !available.length && current.activePanel === 'hub';
    var hint = emptyHub
      ? 'Quando houver candidaturas para voce, elas aparecem aqui.'
      : 'Candidaturas e convites retornados para a organizacao selecionada.';

    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">' + ui().safeText(panel.title || 'Painel') + '</span><h2>' + ui().safeText(title) + '</h2><p>' + ui().safeText(hint) + '</p></div>' + ui().badge('Triagem', 'info') + '</div>' +
      (available.length > 1 ? renderOrgSelector(available, code) : '') +
      (emptyHub ? ui().empty('Nenhuma organizacao ativa', 'Abra /org ou /gang para operar o recrutamento contextual.') : renderRecruitmentLayout(contextOrg, body)) +
    '</div>';
  }

  function renderRecruitmentList(items, isIllegal) {
    if (!items.length) {
      return ui().empty('Nenhuma candidatura', isIllegal ? 'Nenhum candidato foi registrado para esta faccao.' : 'Sem candidatos registrados para esta organizacao.');
    }

    return '<div class="recruitment-scroll"><table class="recruitment-table"><thead><tr><th>Candidato</th><th>CitizenID</th><th>Status</th><th>Cargo</th><th>Data</th><th>Acoes</th></tr></thead><tbody>' + items.map(function (item) {
      var status = String(item.status || 'pending').toLowerCase();
      var grade = item.desiredGradeLevel ? ('Nivel ' + item.desiredGradeLevel) : 'Inicial segura';
      if (item.desiredGradeCode) grade += ' - ' + item.desiredGradeCode;
      return '<tr><td class="cell-strong">' + ui().safeText(item.candidateName || item.targetName || 'Candidato') + (item.note ? '<span class="cell-subtitle">' + ui().safeText(item.note) + '</span>' : '') + '</td><td>' + ui().safeText(fmt().maskCitizenId(item.candidateCitizenId || item.targetCitizenId)) + '</td><td>' + ui().badge(fmt().formatStatusLabel(status), recruitmentStatusVariant(status)) + '</td><td>' + ui().safeText(grade) + '</td><td>' + ui().safeText(fmt().formatDate(item.createdAt)) + '</td><td>' + renderRecruitmentActionButtons(item) + '</td></tr>';
    }).join('') + '</tbody></table></div>';
  }

  function renderGoalsPage() {
    var current = state();
    var panel = getPanel(current.activePanel);
    var available = perms().contextOrgsForActiveModule();
    var code = selectedOrgCode();
    var contextOrg = available.filter(function (org) { return org.code === code; })[0] || null;
    var isIllegal = current.activePanel === 'illegal';
    var title = goalPanelTitle(current.activePanel);

    if (code && current.goals.loadedKey !== current.activePanel + ':' + code && !current.goals.loading) {
      window.setTimeout(loadGoals, 0);
    }

    var body = current.goals.loading
      ? ui().loading('Carregando metas')
      : current.goals.error
        ? ui().errorBox(current.goals.error)
        : renderGoalList(current.goals.data || [], current.activePanel);

    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">' + ui().safeText(panel.title || 'Painel') + '</span><h2>' + ui().safeText(title) + '</h2><p>Metas ativas, progresso e criacao quando seu cargo permitir.</p></div>' + ui().badge((current.goals.data || []).length + ' metas', 'info') + '</div>' +
      (available.length > 1 ? renderOrgSelector(available, code) : '') +
      renderGoalsLayout(contextOrg, body) +
    '</div>';
  }

  function canCreateGoals(contextOrg) {
    var current = state();
    if (!current.session) return false;
    if (current.session.user && current.session.user.isOwner) return true;
    if (perms().isStaffAccess(current.session)) return true;

    var caps = [];
    if (contextOrg && Array.isArray(contextOrg.capabilities)) caps = caps.concat(contextOrg.capabilities);

    return caps.indexOf('goals.manage') !== -1 || caps.indexOf('manage.goals') !== -1;
  }

  function renderCreateGoalCard(contextOrg) {
    var current = state();
    var message = current.goals.createMessage ? '<div class="inline-message success">' + ui().safeText(current.goals.createMessage) + '</div>' : '';
    var error = current.goals.createError ? '<div class="inline-message error-inline">' + ui().safeText(current.goals.createError) + '</div>' : '';

    if (!canCreateGoals(contextOrg)) {
      return ui().card('Criar meta', 'Disponivel para cargos autorizados.', '<div class="invite-box invite-box-muted">' + ui().badge('Sem permissao', 'warning') + '<span>Seu cargo atual nao pode criar metas.</span></div>');
    }

    return ui().card('Criar meta', 'Formulario compacto para uma meta ativa.', '<details class="create-details" open><summary>Nova meta</summary><div class="goal-form">' +
      '<label><span>Titulo</span><input data-goal-field="title" maxlength="120" placeholder="Ex: Patrulhamento semanal" /></label>' +
      '<label><span>Tipo</span><select data-goal-field="type"><option value="manual">Manual</option><option value="weekly">Semanal</option><option value="monthly">Mensal</option><option value="collective">Coletiva</option><option value="individual">Individual</option></select></label>' +
      '<label><span>Objetivo</span><input data-goal-field="target" type="number" min="1" max="100000" step="1" value="1" /></label>' +
      '<label><span>Inicio opcional</span><input data-goal-field="startsAt" type="date" /></label>' +
      '<label><span>Fim opcional</span><input data-goal-field="endsAt" type="date" /></label>' +
      '<label class="goal-form-wide"><span>Descricao</span><textarea data-goal-field="description" maxlength="1000" rows="3" placeholder="Detalhe o objetivo sem dados sensiveis."></textarea></label>' +
      '<div class="goal-form-actions"><button class="btn btn-primary" data-action="create-goal" ' + (current.goals.createLoading ? 'disabled' : '') + '>' + (current.goals.createLoading ? 'Criando...' : 'Criar meta') + '</button></div>' +
      message + error +
    '</div></details>');
  }

  function goalSummary(items) {
    items = Array.isArray(items) ? items : [];
    var active = items.filter(function (goal) {
      var status = String(goal.status || 'active').toLowerCase();
      return status === 'active' || status === 'ativa';
    });
    var completed = items.filter(function (goal) {
      var status = String(goal.status || '').toLowerCase();
      return status === 'completed' || status === 'concluida';
    });
    var progressTotal = active.reduce(function (sum, goal) {
      var percent = fmt().asNumber(goal.progressPercent, 0);
      if (!percent && goal.target) percent = (fmt().asNumber(goal.progress, 0) / Math.max(fmt().asNumber(goal.target, 1), 1)) * 100;
      if (percent < 0) percent = 0;
      if (percent > 100) percent = 100;
      return sum + percent;
    }, 0);

    return {
      active: active.length,
      completed: completed.length,
      average: active.length ? Math.round(progressTotal / active.length) : 0
    };
  }

  function renderGoalSummaryCard(label, value, description) {
    return '<article class="goal-summary-card"><span>' + ui().safeText(label) + '</span><strong>' + ui().safeText(value) + '</strong><small>' + ui().safeText(description) + '</small></article>';
  }

  function renderGoalActionCard(contextOrg) {
    var current = state();
    var canCreate = canCreateGoals(contextOrg);
    var text = canCreate ? 'Defina uma nova meta para a organizacao.' : 'Seu cargo atual nao pode criar metas.';
    return '<button class="goal-action-card create" data-action="open-goal-modal" ' + (!canCreate || current.goalModal.loading ? 'disabled' : '') + '><strong>Criar meta</strong><span>' + ui().safeText(text) + '</span></button>';
  }

  function renderGoalsLayout(contextOrg, listBody) {
    var current = state();
    var summary = goalSummary(current.goals.data || []);
    var message = current.goals.createMessage ? '<div class="inline-message success">' + ui().safeText(current.goals.createMessage) + '</div>' : '';
    var error = current.goals.createError ? '<div class="inline-message error-inline">' + ui().safeText(formatGoalError(current.goals.createError)) + '</div>' : '';

    return '<section class="goals-section">' +
      '<div class="goals-top-grid">' +
        renderGoalSummaryCard('Metas ativas', summary.active, 'Metas em andamento nesta organizacao.') +
        renderGoalSummaryCard('Progresso geral', summary.average + '%', 'Media das metas ativas.') +
        renderGoalActionCard(contextOrg) +
      '</div>' +
      message + error +
      ui().card(goalPanelTitle(state().activePanel), goalCardDescription(state().activePanel), listBody, 'goals-list-card') +
    '</section>';
  }

  function formatGoalError(error) {
    var raw = String(error || '');
    var key = raw.toLowerCase();
    var messages = {
      invalid_title: 'Informe um titulo para a meta.',
      invalid_target: 'Informe um objetivo valido.',
      invalid_dates: 'Verifique as datas da meta.',
      forbidden: 'Voce nao tem permissao para criar metas.'
    };

    if (messages[key]) return messages[key];
    if (key.indexOf('titulo') !== -1 || key.indexOf('title') !== -1) return 'Informe um titulo para a meta.';
    if (key.indexOf('objetivo') !== -1 || key.indexOf('target') !== -1) return 'Informe um objetivo valido.';
    if (key.indexOf('data') !== -1 || key.indexOf('date') !== -1) return 'Verifique as datas da meta.';
    if (key.indexOf('permiss') !== -1 || key === 'forbidden') return 'Voce nao tem permissao para criar metas.';
    return raw || 'Nao foi possivel criar a meta.';
  }

  function openGoalModal() {
    var current = state();
    current.goalModal.open = true;
    current.goalModal.title = '';
    current.goalModal.type = 'manual';
    current.goalModal.target = 1;
    current.goalModal.startsAt = '';
    current.goalModal.endsAt = '';
    current.goalModal.description = '';
    current.goalModal.loading = false;
    current.goalModal.error = null;
    current.goals.createError = null;
    render();
  }

  function closeGoalModal() {
    var current = state();
    if (current.goalModal.loading) return;
    current.goalModal.open = false;
    current.goalModal.error = null;
    render();
  }

  function submitGoalModal() {
    var current = state();
    var app = document.getElementById('app');
    var code = selectedOrgCode();

    function field(name) {
      var input = app && app.querySelector('[data-goal-modal-field="' + name + '"]');
      return input ? input.value : (current.goalModal[name] || '');
    }

    current.goals.createMessage = null;
    current.goals.createError = null;
    current.goalModal.error = null;

    if (!code) {
      current.goalModal.error = 'Organizacao invalida.';
      render();
      return;
    }

    var payload = {
      title: field('title'),
      description: field('description'),
      type: field('type'),
      target: field('target'),
      startsAt: field('startsAt'),
      endsAt: field('endsAt')
    };

    if (!String(payload.title || '').trim()) {
      current.goalModal.error = 'Informe um titulo para a meta.';
      render();
      return;
    }

    if (fmt().asNumber(payload.target, 0) <= 0) {
      current.goalModal.error = 'Informe um objetivo valido.';
      render();
      return;
    }

    current.goalModal.title = payload.title;
    current.goalModal.type = payload.type || 'manual';
    current.goalModal.target = payload.target || 1;
    current.goalModal.startsAt = payload.startsAt || '';
    current.goalModal.endsAt = payload.endsAt || '';
    current.goalModal.description = payload.description || '';
    current.goalModal.loading = true;
    render();

    window.MZOrgGoalService.createGoal(code, payload).then(function (data) {
      current.goals.createMessage = 'Meta criada: ' + (data.title || payload.title) + '.';
      current.goalModal.open = false;
      current.goalModal.title = '';
      current.goalModal.type = 'manual';
      current.goalModal.target = 1;
      current.goalModal.startsAt = '';
      current.goalModal.endsAt = '';
      current.goalModal.description = '';
      current.goalModal.error = null;
      current.goals.loaded = false;
      current.goals.loadedKey = '';
      current.goals.data = [];
      loadGoals();
    }).catch(function (err) {
      current.goalModal.error = formatGoalError(err.message);
    }).finally(function () {
      current.goalModal.loading = false;
      render();
    });
  }

  function createGoal() {
    submitGoalModal();
  }

  function renderGoalModal() {
    var current = state();
    var modal = current.goalModal || {};
    if (!modal.open) return '';

    var org = getActiveOrg() || current.orgView.detail || {};
    var subtitle = org.name || selectedOrgCode() || 'Organizacao ativa';
    var error = modal.error ? '<div class="goal-modal-error">' + ui().safeText(formatGoalError(modal.error)) + '</div>' : '';

    return '<div class="goal-modal-backdrop" role="presentation">' +
      '<section class="goal-modal" role="dialog" aria-modal="true" aria-label="Criar meta">' +
        '<div class="goal-modal-header"><div><span>Metas</span><h3>Criar meta</h3><p>' + ui().safeText(subtitle) + '</p></div><button class="modal-close" data-action="close-goal-modal" aria-label="Cancelar">x</button></div>' +
        '<div class="goal-modal-body">' +
          '<label><span>Titulo</span><input data-goal-modal-field="title" maxlength="120" value="' + ui().safeText(modal.title) + '" placeholder="Ex: Patrulhamento semanal" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Tipo</span><select data-goal-modal-field="type" ' + (modal.loading ? 'disabled' : '') + '>' +
            '<option value="manual" ' + (modal.type === 'manual' ? 'selected' : '') + '>Manual</option>' +
            '<option value="weekly" ' + (modal.type === 'weekly' ? 'selected' : '') + '>Semanal</option>' +
            '<option value="monthly" ' + (modal.type === 'monthly' ? 'selected' : '') + '>Mensal</option>' +
            '<option value="collective" ' + (modal.type === 'collective' ? 'selected' : '') + '>Coletiva</option>' +
            '<option value="individual" ' + (modal.type === 'individual' ? 'selected' : '') + '>Individual</option>' +
          '</select></label>' +
          '<label><span>Objetivo</span><input data-goal-modal-field="target" type="number" min="1" max="100000" step="1" value="' + ui().safeText(modal.target || 1) + '" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Inicio opcional</span><input data-goal-modal-field="startsAt" type="date" value="' + ui().safeText(modal.startsAt) + '" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label><span>Fim opcional</span><input data-goal-modal-field="endsAt" type="date" value="' + ui().safeText(modal.endsAt) + '" ' + (modal.loading ? 'disabled' : '') + ' /></label>' +
          '<label class="goal-modal-wide"><span>Descricao</span><textarea data-goal-modal-field="description" maxlength="1000" rows="3" placeholder="Detalhe o objetivo sem dados sensiveis." ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.description) + '</textarea></label>' +
          error +
        '</div>' +
        '<div class="goal-modal-actions">' +
          '<button class="btn btn-ghost" data-action="close-goal-modal" ' + (modal.loading ? 'disabled' : '') + '>Cancelar</button>' +
          '<button class="goal-confirm-btn create" data-action="submit-goal-modal" ' + (modal.loading ? 'disabled' : '') + '>' + ui().safeText(modal.loading ? 'Criando...' : 'Confirmar meta') + '</button>' +
        '</div>' +
      '</section>' +
    '</div>';
  }

  function goalPanelTitle(panelId) {
    if (panelId === 'illegal') return 'Metas da faccao';
    if (panelId === 'business') return 'Metas da empresa';
    if (panelId === 'government') return 'Metas do governo';
    return 'Metas';
  }

  function goalCardDescription(panelId) {
    if (panelId === 'business') return 'Servicos, faturamento e objetivos da empresa.';
    if (panelId === 'government') return 'Objetivos publicos e operacionais.';
    if (panelId === 'illegal') return 'Lista privada retornada pelo servidor.';
    return 'Metas semanais, mensais, individuais e coletivas retornadas pelo servidor.';
  }

  function renderGoalList(items, panelId) {
    if (!items.length) {
      return ui().empty('Nenhuma meta ativa', panelId === 'business' || panelId === 'government' ? 'Crie uma meta quando o cargo tiver permissao.' : 'Quando houver metas, elas aparecem aqui.');
    }

    return '<div class="goals-scroll"><table class="goals-table"><thead><tr><th>Meta</th><th>Status</th><th>Tipo</th><th>Progresso</th><th>Periodo</th><th>Criada por</th></tr></thead><tbody>' + items.map(function (goal) {
      var period = goal.startsAt || goal.endsAt
        ? ui().safeText(fmt().formatDate(goal.startsAt)) + ' - ' + ui().safeText(fmt().formatDate(goal.endsAt))
        : 'Sem prazo';
      return '<tr><td class="cell-strong">' + ui().safeText(goal.title) + (goal.description ? '<span class="cell-subtitle">' + ui().safeText(goal.description) + '</span>' : '') + '</td><td>' + ui().badge(fmt().formatStatusLabel(goal.status || 'ativa'), goalStatusVariant(goal.status)) + '</td><td>' + ui().safeText(fmt().formatGoalType(goal.type)) + '</td><td>' + renderGoalProgress(goal) + '</td><td>' + period + '</td><td>' + ui().safeText(goal.createdByName || 'Sistema') + '</td></tr>';
    }).join('') + '</tbody></table></div>';
  }

  function renderGoalProgress(goal) {
    var percent = fmt().asNumber(goal.progressPercent, 0);
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;

    return '<div class="goal-progress"><div class="goal-progress-top"><span>' + ui().safeText(goal.progress || 0) + ' / ' + ui().safeText(goal.target || 0) + '</span><strong>' + ui().safeText(percent) + '%</strong></div><div class="progress-track"><span class="progress-fill" style="width:' + ui().escapeHtml(percent) + '%"></span></div></div>';
  }

  function goalStatusVariant(status) {
    status = String(status || '').toLowerCase();
    if (status === 'active' || status === 'ativa') return 'success';
    if (status === 'paused' || status === 'pausada') return 'warning';
    if (status === 'completed' || status === 'concluida') return 'info';
    if (status === 'expired' || status === 'expirada') return 'danger';
    return 'muted';
  }

  function recruitmentStatusVariant(status) {
    status = String(status || '').toLowerCase();
    if (status === 'approved' || status === 'aprovado') return 'success';
    if (status === 'rejected' || status === 'recusado') return 'danger';
    if (status === 'pending' || status === 'pendente') return 'warning';
    return 'muted';
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
    var filters = state().logs.filters;
    var query = String(filters.search || '').toLowerCase().trim();
    return state().logs.data.filter(function (log) {
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
      '<label class="search-field"><span>Busca</span><input data-log-filter="search" maxlength="80" value="' + ui().safeText(state().logs.filters.search) + '" placeholder="acao, autor, org..." /></label>' +
    '</div>';
  }

  function selectFilter(key, label, options) {
    return '<label><span>' + ui().safeText(label) + '</span><select data-log-filter="' + ui().escapeHtml(key) + '"><option value="all">Todas</option>' + options.map(function (option) {
      return '<option value="' + ui().safeText(option) + '" ' + (state().logs.filters[key] === option ? 'selected' : '') + '>' + ui().safeText(option) + '</option>';
    }).join('') + '</select></label>';
  }

  function renderLogsTable(logs) {
    return '<div class="table-scroll logs-scroll"><table><thead><tr><th>Data</th><th>Status</th><th>Acao</th><th>Autor</th><th>Alvo</th><th>Mensagem</th></tr></thead><tbody>' + logs.map(function (log) {
      return '<tr><td>' + ui().safeText(fmt().formatDate(log.createdAt)) + '</td><td>' + ui().badge(fmt().formatStatusLabel(log.severity || 'info'), severityVariant(log.severity)) + '</td><td class="cell-strong">' + ui().safeText(formatLogAction(log)) + '<span class="cell-subtitle">' + ui().safeText(fmt().formatStatusLabel(log.category)) + '</span></td><td>' + ui().safeText(log.actorName || fmt().maskCitizenId(log.actorCitizenId)) + '</td><td>' + ui().safeText(log.targetName || fmt().maskCitizenId(log.targetCitizenId)) + '</td><td>' + ui().safeText(log.message || log.reason) + '</td></tr>';
    }).join('') + '</tbody></table></div>';
  }

  function severityVariant(severity) {
    severity = fmt().formatSeverity(severity);
    if (severity === 'success') return 'success';
    if (severity === 'warning') return 'warning';
    if (severity === 'danger') return 'danger';
    return 'info';
  }

  function renderPlaceholder(title, description, icon, fallback) {
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Reservado</span><h2>' + ui().safeText(title) + '</h2><p>' + ui().safeText(description) + '</p></div>' + ui().badge('Consulta', 'info') + '</div>' +
      ui().card(title, 'Espaco reservado para quando houver dados deste modulo.', '<div class="empty">' + ui().renderIcon(icon, fallback || '*', 'empty-icon') + '<span>Nada para mostrar agora.</span></div>') +
    '</div>';
  }

  function bindEvents() {
    var app = document.getElementById('app');
    if (!app) return;

    app.querySelectorAll('[data-action="close"]').forEach(function (button) { button.addEventListener('click', window.MZOrgNui.closePanel); });
    app.querySelectorAll('[data-shell]').forEach(function (button) { button.addEventListener('click', function () { setActiveShell(button.getAttribute('data-shell')); }); });
    app.querySelectorAll('[data-section]').forEach(function (button) { button.addEventListener('click', function () { setActiveSection(button.getAttribute('data-section')); }); });
    app.querySelectorAll('[data-module]').forEach(function (button) { button.addEventListener('click', function () { setActiveModule(button.getAttribute('data-module')); }); });

    var sidebarToggle = app.querySelector('[data-action="toggle-sidebar"]');
    if (sidebarToggle) {
      sidebarToggle.addEventListener('click', function () {
        state().sidebarCollapsed = !state().sidebarCollapsed;
        render();
      });
    }

    var orgSelect = app.querySelector('[data-action="select-org"]');
    if (orgSelect) {
      orgSelect.addEventListener('change', function (event) {
        var type = perms().moduleType(state().activeModule) || 'all';
        var selected = orgSelect.options[orgSelect.selectedIndex];
        var orgType = selected ? selected.getAttribute('data-org-type') : '';
        state().orgView.selectedByPanel[type] = event.target.value;
        if (state().activeShell === 'legal' || state().activeShell === 'illegal') {
          state().activeOrgCode = event.target.value;
          state().activeOrgType = normalizeOrgType(orgType || type);
          state().activeSection = 'overview';
          window.MZOrgState.resetOrgPanelData();
          resetContextLoads();
        } else {
          if (state().activeModule === 'recruitment' || state().activeModule === 'goals') {
            var bucket = state().activeModule === 'recruitment' ? state().recruitment : state().goals;
            bucket.loaded = false;
            bucket.loadedKey = '';
            bucket.data = [];
          } else {
            window.MZOrgState.resetOrgPanelData();
          }
        }
        render();
        if (state().activeShell === 'legal' || state().activeShell === 'illegal') {
          loadActiveModule();
        } else if (state().activeModule === 'recruitment') {
          loadRecruitment();
        } else if (state().activeModule === 'goals') {
          loadGoals();
        } else {
          loadOrgPanel();
        }
      });
    }

    var inviteButton = app.querySelector('[data-action="invite-member"]');
    if (inviteButton) {
      inviteButton.addEventListener('click', inviteMember);
    }

    var openMemberButton = app.querySelector('[data-action="open-member-modal"]');
    if (openMemberButton) {
      openMemberButton.addEventListener('click', openMemberInviteModal);
    }

    app.querySelectorAll('[data-action="close-member-modal"]').forEach(function (button) {
      button.addEventListener('click', closeMemberInviteModal);
    });

    var submitMemberButton = app.querySelector('[data-action="submit-member-modal"]');
    if (submitMemberButton) {
      submitMemberButton.addEventListener('click', submitMemberInviteModal);
    }

    app.querySelectorAll('[data-action="remove-member"]').forEach(function (button) {
      button.addEventListener('click', function () {
        removeMember(button.getAttribute('data-citizenid'));
      });
    });

    app.querySelectorAll('[data-action="promote-member"]').forEach(function (button) {
      button.addEventListener('click', function () {
        changeMemberGrade(button.getAttribute('data-citizenid'), 'promote');
      });
    });

    app.querySelectorAll('[data-action="demote-member"]').forEach(function (button) {
      button.addEventListener('click', function () {
        changeMemberGrade(button.getAttribute('data-citizenid'), 'demote');
      });
    });

    var createGoalButton = app.querySelector('[data-action="create-goal"]');
    if (createGoalButton) {
      createGoalButton.addEventListener('click', createGoal);
    }

    var openGoalButton = app.querySelector('[data-action="open-goal-modal"]');
    if (openGoalButton) {
      openGoalButton.addEventListener('click', openGoalModal);
    }

    app.querySelectorAll('[data-action="close-goal-modal"]').forEach(function (button) {
      button.addEventListener('click', closeGoalModal);
    });

    var submitGoalButton = app.querySelector('[data-action="submit-goal-modal"]');
    if (submitGoalButton) {
      submitGoalButton.addEventListener('click', submitGoalModal);
    }

    app.querySelectorAll('[data-action="open-recruitment-modal"]').forEach(function (button) {
      button.addEventListener('click', function () {
        openRecruitmentModal(button.getAttribute('data-recruitment-mode') || 'create', button.getAttribute('data-recruitment-id'));
      });
    });

    app.querySelectorAll('[data-action="close-recruitment-modal"]').forEach(function (button) {
      button.addEventListener('click', closeRecruitmentModal);
    });

    var submitRecruitmentButton = app.querySelector('[data-action="submit-recruitment-modal"]');
    if (submitRecruitmentButton) {
      submitRecruitmentButton.addEventListener('click', submitRecruitmentModal);
    }

    app.querySelectorAll('[data-action="open-bank-modal"]').forEach(function (button) {
      button.addEventListener('click', function () {
        openBankModal(button.getAttribute('data-bank-type'));
      });
    });

    app.querySelectorAll('[data-action="close-bank-modal"]').forEach(function (button) {
      button.addEventListener('click', closeBankModal);
    });

    var submitBankButton = app.querySelector('[data-action="submit-bank-modal"]');
    if (submitBankButton) {
      submitBankButton.addEventListener('click', submitBankModal);
    }

    var staffSetLeaderButton = app.querySelector('[data-action="staff-set-leader"]');
    if (staffSetLeaderButton) {
      staffSetLeaderButton.addEventListener('click', submitStaffLeader);
    }

    var openStaffCreateOrgButton = app.querySelector('[data-action="open-staff-create-org-modal"]');
    if (openStaffCreateOrgButton) {
      openStaffCreateOrgButton.addEventListener('click', openStaffCreateOrgModal);
    }

    app.querySelectorAll('[data-action="close-staff-create-org-modal"]').forEach(function (button) {
      button.addEventListener('click', closeStaffCreateOrgModal);
    });

    var submitStaffCreateOrgButton = app.querySelector('[data-action="submit-staff-create-org-modal"]');
    if (submitStaffCreateOrgButton) {
      submitStaffCreateOrgButton.addEventListener('click', submitStaffCreateOrgModal);
    }

    var openStaffEditOrgBasicButton = app.querySelector('[data-action="open-staff-edit-org-basic-modal"]');
    if (openStaffEditOrgBasicButton) {
      openStaffEditOrgBasicButton.addEventListener('click', openStaffEditOrgBasicModal);
    }

    app.querySelectorAll('[data-action="close-staff-edit-org-basic-modal"]').forEach(function (button) {
      button.addEventListener('click', closeStaffEditOrgBasicModal);
    });

    var submitStaffEditOrgBasicButton = app.querySelector('[data-action="submit-staff-edit-org-basic-modal"]');
    if (submitStaffEditOrgBasicButton) {
      submitStaffEditOrgBasicButton.addEventListener('click', submitStaffEditOrgBasicModal);
    }

    app.querySelectorAll('[data-action="open-staff-grade-modal"]').forEach(function (button) {
      button.addEventListener('click', function () {
        openStaffGradeModal(button.getAttribute('data-grade-mode'), button.getAttribute('data-grade-id'));
      });
    });

    app.querySelectorAll('[data-action="close-staff-grade-modal"]').forEach(function (button) {
      button.addEventListener('click', closeStaffGradeModal);
    });

    var submitStaffGradeButton = app.querySelector('[data-action="submit-staff-grade-modal"]');
    if (submitStaffGradeButton) {
      submitStaffGradeButton.addEventListener('click', submitStaffGradeModal);
    }

    app.querySelectorAll('[data-action="open-staff-permission-modal"]').forEach(function (button) {
      button.addEventListener('click', function () {
        openStaffPermissionModal(button.getAttribute('data-grade-id'));
      });
    });

    app.querySelectorAll('[data-action="close-staff-permission-modal"]').forEach(function (button) {
      button.addEventListener('click', closeStaffPermissionModal);
    });

    var permissionSearch = app.querySelector('[data-staff-permission-field="search"]');
    if (permissionSearch) {
      permissionSearch.addEventListener('input', function () {
        updateStaffPermissionModalFields();
        render();
      });
    }

    app.querySelectorAll('[data-action="add-staff-grade-permission"]').forEach(function (button) {
      button.addEventListener('click', function () {
        changeStaffGradePermission('add', button.getAttribute('data-permission'));
      });
    });

    app.querySelectorAll('[data-action="remove-staff-grade-permission"]').forEach(function (button) {
      button.addEventListener('click', function () {
        changeStaffGradePermission('remove', button.getAttribute('data-permission'));
      });
    });

    app.querySelectorAll('[data-action="open-staff-archive-modal"]').forEach(function (button) {
      button.addEventListener('click', function () {
        openStaffArchiveModal(button.getAttribute('data-staff-archive-action'), button.getAttribute('data-grade-id'));
      });
    });

    app.querySelectorAll('[data-action="close-staff-archive-modal"]').forEach(function (button) {
      button.addEventListener('click', closeStaffArchiveModal);
    });

    var submitStaffArchiveButton = app.querySelector('[data-action="submit-staff-archive-modal"]');
    if (submitStaffArchiveButton) {
      submitStaffArchiveButton.addEventListener('click', submitStaffArchiveModal);
    }

    app.querySelectorAll('[data-action="staff-view-org-details"]').forEach(function (button) {
      button.addEventListener('click', function () {
        openStaffOrgDetails(button.getAttribute('data-org-code'));
      });
    });

    app.querySelectorAll('[data-action="staff-close-org-details"]').forEach(function (button) {
      button.addEventListener('click', closeStaffOrgDetails);
    });

    app.querySelectorAll('[data-staff-org-detail-tab]').forEach(function (button) {
      button.addEventListener('click', function () {
        setStaffOrgDetailTab(button.getAttribute('data-staff-org-detail-tab'));
      });
    });

    app.querySelectorAll('[data-log-filter]').forEach(function (input) {
      input.addEventListener('input', function (event) {
        state().logs.filters[input.getAttribute('data-log-filter')] = event.target.value;
        render();
      });
      input.addEventListener('change', function (event) {
        state().logs.filters[input.getAttribute('data-log-filter')] = event.target.value;
        render();
      });
    });
  }

  window.MZOrgRouter = {
    registerPanels: registerPanels,
    getPanel: getPanel,
    firstAllowedModule: firstAllowedModule,
    applyInitialModule: applyInitialModule,
    setActivePanel: setActivePanel,
    setActiveShell: setActiveShell,
    setActiveModule: setActiveModule,
    setActiveOrg: setActiveOrg,
    setActiveSection: setActiveSection,
    getActiveOrg: getActiveOrg,
    getFirstOrgByType: getFirstOrgByType,
    selectedOrgCode: selectedOrgCode,
    loadActiveModule: loadActiveModule,
    loadOrgPanel: loadOrgPanel,
    loadOrgs: loadOrgs,
    loadLogs: loadLogs,
    loadRecruitment: loadRecruitment,
    reloadRecruitment: reloadRecruitment,
    loadGoals: loadGoals,
    reloadGoals: reloadGoals,
    render: render,
    renderDashboard: renderDashboard,
    renderOrgsPage: renderOrgsPage,
    renderOrgPanelPage: renderOrgPanelPage,
    renderStaffPage: renderStaffPage,
    renderLogsPage: renderLogsPage,
    renderRecruitmentPage: renderRecruitmentPage,
    renderGoalsPage: renderGoalsPage,
    createGoal: createGoal,
    renderAccessModelCard: renderAccessModelCard,
    inviteMember: inviteMember,
    removeMember: removeMember,
    changeMemberGrade: changeMemberGrade,
    renderPlaceholder: renderPlaceholder
  };
}());
