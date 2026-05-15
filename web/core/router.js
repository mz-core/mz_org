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

  function loadRecruitment() {
    var current = state();
    var code = selectedOrgCode();
    var key = current.activePanel + ':' + (code || 'self');
    if (current.recruitment.loading || (current.recruitment.loaded && current.recruitment.loadedKey === key)) return;

    current.recruitment.loading = true;
    current.recruitment.error = null;
    current.recruitment.loadedKey = key;
    render();

    var filters = { limit: 50 };
    if (code) filters.orgCode = code;

    window.MZOrgRecruitmentService.listRecruitment(filters).then(function (items) {
      current.recruitment.data = Array.isArray(items) ? items : [];
      current.recruitment.loaded = true;
    }).catch(function (err) {
      current.recruitment.error = err.message;
    }).finally(function () {
      current.recruitment.loading = false;
      render();
    });
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
    return '<div class="table-scroll"><table><thead><tr><th>Nome</th><th>Tipo</th><th>Cargo</th><th>Status</th><th>Avancado</th></tr></thead><tbody>' + items.map(function (org) {
      return '<tr><td class="cell-strong">' + ui().safeText(org.name || org.code) + '</td><td>' + ui().badge(fmt().formatOrgType(org.type || 'legal'), org.type === 'gang' ? 'danger' : 'info') + '</td><td>' + ui().safeText(fmt().formatGradeName(org)) + '</td><td>' + ui().badge(org.is_public ? 'Publica' : 'Privada', org.is_public ? 'success' : 'muted') + '</td><td>' + ui().technicalDetails('Detalhes', [{ label: 'Codigo', value: org.code }, { label: 'Tipo tecnico', value: org.type }]) + '</td></tr>';
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

    return '<div class="two-col">' + renderCreateGoalCard(contextOrg) + ui().card(goalPanelTitle(current.activePanel), goalCardDescription(current.activePanel), body) + '</div>';
  }

  function renderRecruitmentSection(contextOrg) {
    var current = state();
    var isIllegal = current.activeShell === 'illegal';
    var title = isIllegal ? 'Recrutamento da faccao' : 'Recrutamento';
    var body = current.recruitment.loading
      ? ui().loading('Carregando recrutamento')
      : current.recruitment.error
        ? ui().errorBox(current.recruitment.error)
        : renderRecruitmentList(current.recruitment.data || [], isIllegal);

    return ui().card(title, 'Candidaturas e convites da organizacao ativa.', body + ui().technicalDetails('Contexto', [{ label: 'Org', value: contextOrg && contextOrg.code }, { label: 'Tipo', value: contextOrg && contextOrg.type }]));
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
    return ui().card('Resumo', 'O que importa para operar a organizacao.', '<div class="detail-grid"><span>Nome</span><strong>' + ui().safeText(org.name) + '</strong><span>Tipo</span><strong>' + ui().safeText(fmt().formatOrgType(org.type)) + '</strong><span>Status</span><strong>' + ui().safeText(org.is_public ? 'Publica' : 'Privada') + '</strong></div>' + ui().technicalDetails('Detalhes tecnicos', [{ label: 'Codigo da org', value: org.code }, { label: 'Tipo interno', value: org.type }, { label: 'ID interno', value: org.id }]));
  }

  function renderOrgAccess(org) {
    org = org || {};
    var detail = state().orgView.detail || {};
    var caps = Array.isArray(detail.capabilities) && detail.capabilities.length ? detail.capabilities : (org.capabilities || []);
    return ui().card('Meu acesso', 'Cargo, permissoes e acoes disponiveis.', '<div class="detail-grid"><span>Cargo</span><strong>' + ui().safeText(fmt().formatGradeName(org)) + '</strong><span>Permissoes</span><strong>' + ui().safeText(caps.length) + '</strong></div>' + capabilityBadges(caps, 8) + ui().technicalDetails('Detalhes tecnicos', [{ label: 'Codigo do cargo', value: org.gradeCode }, { label: 'Nivel', value: org.grade }, { label: 'Capabilities cruas', value: caps.join(', ') }]));
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
      ? '<div class="badge-row">' + model.playerOverrides.map(function (override) { return ui().permissionBadge(override.permission || '-', override.allow === false ? 'danger' : 'info'); }).join('') + '</div>' + ui().technicalDetails('Overrides tecnicos', model.playerOverrides.map(function (override) { return { label: override.allow === false ? 'Negado' : 'Permitido', value: override.permission || '-' }; }))
      : ui().empty('Sem ajustes individuais', 'Nenhuma permissao individual foi retornada para sua sessao.');

    return ui().card('Cargos e permissoes', 'Hierarquia, salario e permissoes em linguagem de uso.', '<div class="access-section"><h4>Permissoes base</h4>' + base + '</div><div class="access-section"><h4>Hierarquia</h4>' + gradesBody + '</div><div class="access-section"><h4>Ajustes da sua sessao</h4>' + overrides + '</div>');
  }

  function renderGradesTable(grades) {
    return '<div class="table-scroll"><table><thead><tr><th>Nivel</th><th>Cargo</th><th>Salario</th><th>Heranca</th><th>Permissoes</th><th>Avancado</th></tr></thead><tbody>' + grades.map(function (grade) {
      var caps = Array.isArray(grade.capabilities) && grade.capabilities.length
        ? capabilityBadges(grade.capabilities, 5)
        : ui().safeText('-');
      var inheritance = grade.inheritsLevel ? 'Herda do nivel ' + grade.inheritsLevel : 'Sem heranca';
      return '<tr><td>' + ui().badge('Nivel ' + grade.level, 'info') + '</td><td class="cell-strong">' + ui().safeText(grade.name || grade.code) + '</td><td>' + ui().safeText(fmt().formatMoney(grade.salary || 0)) + '</td><td>' + ui().safeText(inheritance) + '</td><td>' + caps + '</td><td>' + ui().technicalDetails('Tecnico', [{ label: 'Codigo', value: grade.code }, { label: 'Herda codigo', value: grade.inheritsCode }, { label: 'Capabilities cruas', value: (grade.capabilities || []).join(', ') }]) + '</td></tr>';
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
    return caps.indexOf('account.manage') !== -1 || caps.indexOf(action) !== -1;
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
    var inviteBox = renderInviteMemberBox(contextOrg);
    var actionMessages = renderMemberActionMessages();

    if (current.orgView.membersLoading) return ui().card('Membros', 'Equipe e acoes disponiveis.', ui().loading('Carregando membros'));
    if (current.orgView.membersError) return ui().card('Membros', 'Equipe e acoes disponiveis.', ui().errorBox(current.orgView.membersError));
    var items = current.orgView.members || [];
    if (!items.length) return ui().card('Membros', 'Equipe e acoes disponiveis.', inviteBox + actionMessages + ui().empty('Nenhum membro encontrado', 'Quando houver membros visiveis para sua sessao, eles aparecem aqui.'));
    return ui().card('Membros', 'Equipe, cargos e acoes permitidas.', inviteBox + actionMessages + '<div class="table-scroll members-scroll"><table><thead><tr><th>Nome</th><th>Cargo</th><th>Status</th><th>Entrada</th><th>Ultima atividade</th><th>Acoes</th><th>Avancado</th></tr></thead><tbody>' + items.map(function (member) {
      return '<tr><td class="cell-strong">' + ui().safeText(member.name || 'Membro') + '<span class="cell-subtitle">CID ' + ui().safeText(fmt().maskCitizenId(member.citizenid)) + '</span></td><td>' + ui().safeText(fmt().formatGradeName(member)) + '</td><td><div class="badge-row">' + (member.isLeader ? ui().badge('Lider', 'owner') : '') + (member.isDuty ? ui().badge('Em servico', 'success') : ui().badge('Fora de servico', 'muted')) + ui().badge(fmt().formatStatusLabel(member.status || 'ativo'), 'info') + '</div></td><td>' + ui().safeText(fmt().formatDate(member.joinedAt)) + '</td><td>' + ui().safeText(fmt().formatDate(member.lastSeen)) + '</td><td>' + renderMemberActionButtons(member, contextOrg) + '</td><td>' + ui().technicalDetails('Detalhes', [{ label: 'CitizenID', value: member.citizenid }, { label: 'Grade code', value: member.gradeCode }, { label: 'Grade', value: member.grade }]) + '</td></tr>';
    }).join('') + '</tbody></table></div>');
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
    var message = current.orgView.removeMessage ? '<div class="inline-message success">' + ui().safeText(current.orgView.removeMessage) + '</div>' : '';
    var error = current.orgView.removeError ? '<div class="inline-message error-inline">' + ui().safeText(current.orgView.removeError) + '</div>' : '';
    var gradeMessage = current.orgView.gradeMessage ? '<div class="inline-message success">' + ui().safeText(current.orgView.gradeMessage) + '</div>' : '';
    var gradeError = current.orgView.gradeError ? '<div class="inline-message error-inline">' + ui().safeText(current.orgView.gradeError) + '</div>' : '';
    return message + error + gradeMessage + gradeError;
  }

  function renderInviteMemberBox(contextOrg) {
    var current = state();
    var message = current.orgView.inviteMessage ? '<div class="inline-message success">' + ui().safeText(current.orgView.inviteMessage) + '</div>' : '';
    var error = current.orgView.inviteError ? '<div class="inline-message error-inline">' + ui().safeText(current.orgView.inviteError) + '</div>' : '';
    var gradeSelect = renderInviteGradeSelect(contextOrg);

    if (!canInviteMembers(contextOrg)) {
      return '<div class="invite-box invite-box-muted">' + ui().badge('Sem permissao', 'warning') + '<span>Seu cargo atual nao pode convidar novos membros.</span></div>';
    }

    return '<div class="invite-box">' +
      '<div><strong>Convidar membro</strong><span>Informe o ID online e escolha a grade inicial.</span><small>A grade e validada pelo servidor.</small></div>' +
      '<label><span>ID do player online</span><input data-member-invite-target type="number" min="1" step="1" placeholder="Ex: 12" /></label>' +
      gradeSelect +
      '<button class="btn btn-primary" data-action="invite-member" ' + (current.orgView.inviteLoading ? 'disabled' : '') + '>' + (current.orgView.inviteLoading ? 'Convidando...' : 'Convidar membro') + '</button>' +
      message + error +
    '</div>';
  }

  function inviteGradeOptions(contextOrg) {
    var current = state();
    var model = current.orgView.access || {};
    var grades = Array.isArray(model.grades) ? model.grades.slice() : [];

    if (!grades.length) return [];
    if (current.session && current.session.user && current.session.user.isOwner) return grades;
    if (perms().isStaffAccess(current.session)) return grades;

    var actorLevel = fmt().asNumber(contextOrg && contextOrg.grade, 0);
    return grades.filter(function (grade) {
      return fmt().asNumber(grade.level, 0) > 0 && fmt().asNumber(grade.level, 0) < actorLevel;
    });
  }

  function renderInviteGradeSelect(contextOrg) {
    var current = state();
    var grades = inviteGradeOptions(contextOrg);
    var loading = current.orgView.accessLoading;
    var helper = loading ? 'Carregando cargos...' : 'Se nada for escolhido, o core usa a menor grade segura.';

    if (!grades.length) {
      return '<label><span>Grade inicial</span><select data-member-invite-grade disabled><option value="">Cargo inicial automatico</option></select><small>' + ui().safeText(helper) + '</small></label>';
    }

    return '<label><span>Grade inicial</span><select data-member-invite-grade>' +
      '<option value="">Cargo inicial automatico</option>' +
      grades.map(function (grade) {
        return '<option value="' + ui().escapeHtml(grade.level) + '" data-grade-code="' + ui().escapeHtml(grade.code || '') + '">' + ui().safeText(grade.name || grade.code) + ' (nivel ' + ui().safeText(grade.level) + ')</option>';
      }).join('') +
      '</select><small>' + ui().safeText(helper) + '</small></label>';
  }

  function inviteMember() {
    var current = state();
    var app = document.getElementById('app');
    var code = selectedOrgCode();
    var input = app && app.querySelector('[data-member-invite-target]');
    var gradeSelect = app && app.querySelector('[data-member-invite-grade]');
    var targetId = input ? input.value : '';
    var grade = null;

    current.orgView.inviteMessage = null;
    current.orgView.inviteError = null;

    if (!code) {
      current.orgView.inviteError = 'Organizacao invalida.';
      render();
      return;
    }

    if (!targetId) {
      current.orgView.inviteError = 'Informe o ID do player online.';
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

    current.orgView.inviteLoading = true;
    render();

    window.MZOrgMemberService.inviteMember(code, targetId, grade).then(function (data) {
      current.orgView.inviteMessage = 'Membro convidado na grade ' + (data.gradeCode || data.grade || 'inicial') + '.';
      return reloadMembers(code);
    }).catch(function (err) {
      current.orgView.inviteError = err.message || 'Nao foi possivel convidar membro.';
    }).finally(function () {
      current.orgView.inviteLoading = false;
      render();
    });
  }

  function renderMemberActionButtons(member, contextOrg) {
    if (!member || !member.citizenid) return ui().safeText('-');

    var current = state();
    var safeCitizen = ui().escapeHtml(member.citizenid);
    var removeLoading = current.orgView.removeLoading && current.orgView.removeCitizenId === member.citizenid;
    var promoteLoading = current.orgView.gradeLoading && current.orgView.gradeAction === 'promote' && current.orgView.gradeCitizenId === member.citizenid;
    var demoteLoading = current.orgView.gradeLoading && current.orgView.gradeAction === 'demote' && current.orgView.gradeCitizenId === member.citizenid;
    var buttons = [];

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

    if (!window.confirm('Remover este membro da organizacao?')) return;

    current.orgView.removeLoading = true;
    current.orgView.removeCitizenId = citizenid;
    render();

    window.MZOrgMemberService.removeMember(code, citizenid).then(function () {
      current.orgView.removeMessage = 'Membro removido da organizacao.';
      return reloadMembers(code);
    }).catch(function (err) {
      current.orgView.removeError = err.message || 'Nao foi possivel remover membro.';
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

    var confirmMessage = action === 'demote' ? 'Rebaixar este membro?' : 'Promover este membro?';
    if (!window.confirm(confirmMessage)) return;

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
      return reloadMembers(code);
    }).catch(function (err) {
      current.orgView.gradeError = err.message || 'Nao foi possivel alterar cargo.';
    }).finally(function () {
      current.orgView.gradeLoading = false;
      current.orgView.gradeAction = null;
      current.orgView.gradeCitizenId = null;
      render();
    });
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
    return '<div class="screen">' +
      '<div class="page-heading"><div><span class="module-kicker">Staff</span><h2>Area administrativa</h2><p>Visao organizada para auditoria e consulta. Acoes criticas continuam bloqueadas no servidor.</p></div>' + ui().badge(perms().getAccessLabel(), perms().getAccessVariant()) + '</div>' +
      '<div class="metric-grid">' + ui().metricCard('assets/icons/staff.svg', 'Liberado', 'Acesso staff/owner', 'S') + ui().metricCard('assets/icons/logs.svg', perms().canViewModule(state().session, 'logs') ? 'Disponivel' : 'Oculto', 'Auditoria') + ui().metricCard('assets/icons/lock.svg', 'Protegidas', 'Acoes sensiveis', 'B') + '</div>' +
      '<div class="two-col">' +
        ui().card('Visao administrativa', 'Atalhos seguros para consulta.', '<div class="module-card-grid"><button class="module-card" data-module="orgs">' + ui().renderIcon('assets/icons/orgs.svg', 'O', 'inline-icon-box') + '<span><strong>Organizacoes</strong><small>Consultar orgs visiveis</small></span></button><button class="module-card" data-module="logs">' + ui().renderIcon('assets/icons/logs.svg', 'L', 'inline-icon-box') + '<span><strong>Logs</strong><small>Acompanhar auditoria</small></span></button></div>') +
        ui().card('Avisos', 'Sem novas acoes nesta etapa.', '<div class="badge-row">' + ui().badge('Consulta', 'info') + ui().badge('Auditoria', 'success') + ui().badge('Edicao bloqueada', 'warning') + '</div>' + ui().technicalDetails('Detalhes tecnicos', [{ label: 'Modulo', value: 'staff' }, { label: 'Acoes novas', value: 'nenhuma' }])) +
      '</div>' +
    '</div>';
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
      '<div class="two-col">' +
        ui().card('Contexto', 'Escopo do recrutamento.', '<div class="detail-grid"><span>Organizacao</span><strong>' + ui().safeText(contextOrg && contextOrg.name || (emptyHub ? 'Candidaturas' : code)) + '</strong><span>Tipo</span><strong>' + ui().safeText(fmt().formatOrgType(contextOrg && contextOrg.type)) + '</strong><span>Modo</span><strong>' + ui().safeText(isIllegal ? 'Privado' : 'Gestao') + '</strong></div>' + ui().technicalDetails('Detalhes tecnicos', [{ label: 'Codigo da org', value: code }, { label: 'Tipo interno', value: contextOrg && contextOrg.type }])) +
        ui().card('Resumo', 'Triagem sem acoes novas.', '<div class="stat-grid compact">' + ui().statCard('Registros', (current.recruitment.data || []).length, 'Retornados pelo servidor') + ui().statCard('Status', 'Consulta', 'Sem aprovar/recusar nesta tela') + '</div>') +
      '</div>' +
      ui().card(title, isIllegal ? 'Lista discreta e privada, filtrada pelo servidor.' : 'Candidaturas e convites da organizacao.', body) +
    '</div>';
  }

  function renderRecruitmentList(items, isIllegal) {
    if (!items.length) {
      return ui().empty('Nenhum registro de recrutamento', isIllegal ? 'Nenhuma candidatura ou convite privado foi retornado.' : 'Sem candidaturas ou convites no momento.');
    }

    return '<div class="table-scroll"><table><thead><tr><th>Data</th><th>Status</th><th>Tipo</th><th>Candidato</th><th>Mensagem</th><th>Avancado</th></tr></thead><tbody>' + items.map(function (item) {
      return '<tr><td>' + ui().safeText(fmt().formatDate(item.createdAt)) + '</td><td>' + ui().badge(fmt().formatStatusLabel(item.status || 'pendente'), recruitmentStatusVariant(item.status)) + '</td><td>' + ui().safeText(fmt().formatStatusLabel(item.type || 'candidatura')) + '</td><td class="cell-strong">' + ui().safeText(item.candidateName || 'Candidato') + '<span class="cell-subtitle">CID ' + ui().safeText(fmt().maskCitizenId(item.candidateCitizenId)) + '</span></td><td>' + ui().safeText(item.message) + '</td><td>' + ui().technicalDetails('Detalhes', [{ label: 'CitizenID', value: item.candidateCitizenId }, { label: 'Org', value: item.orgCode }]) + '</td></tr>';
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
      '<div class="two-col">' +
        ui().card('Contexto', isIllegal ? 'Metas privadas da faccao.' : 'Escopo das metas da organizacao.', '<div class="detail-grid"><span>Organizacao</span><strong>' + ui().safeText(contextOrg && contextOrg.name || code) + '</strong><span>Tipo</span><strong>' + ui().safeText(fmt().formatOrgType(contextOrg && contextOrg.type)) + '</strong><span>Retornadas</span><strong>' + ui().safeText((current.goals.data || []).length) + '</strong></div>' + ui().technicalDetails('Detalhes tecnicos', [{ label: 'Codigo da org', value: code }, { label: 'Tipo interno', value: contextOrg && contextOrg.type }])) +
        renderCreateGoalCard(contextOrg) +
      '</div>' +
      ui().card(title, goalCardDescription(current.activePanel), body) +
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

  function createGoal() {
    var current = state();
    var app = document.getElementById('app');
    var code = selectedOrgCode();

    function field(name) {
      var input = app && app.querySelector('[data-goal-field="' + name + '"]');
      return input ? input.value : '';
    }

    current.goals.createMessage = null;
    current.goals.createError = null;

    if (!code) {
      current.goals.createError = 'Organizacao invalida.';
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
      current.goals.createError = 'Informe um titulo para a meta.';
      render();
      return;
    }

    current.goals.createLoading = true;
    render();

    window.MZOrgGoalService.createGoal(code, payload).then(function (data) {
      current.goals.createMessage = 'Meta criada: ' + (data.title || payload.title) + '.';
      current.goals.loaded = false;
      current.goals.loadedKey = '';
      current.goals.data = [];
      loadGoals();
    }).catch(function (err) {
      current.goals.createError = err.message || 'Nao foi possivel criar meta.';
    }).finally(function () {
      current.goals.createLoading = false;
      render();
    });
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

    return '<div class="table-scroll"><table><thead><tr><th>Meta</th><th>Status</th><th>Tipo</th><th>Progresso</th><th>Periodo</th><th>Criada por</th><th>Avancado</th></tr></thead><tbody>' + items.map(function (goal) {
      return '<tr><td class="cell-strong">' + ui().safeText(goal.title) + '<span class="cell-subtitle">' + ui().safeText(goal.description) + '</span></td><td>' + ui().badge(fmt().formatStatusLabel(goal.status || 'ativa'), goalStatusVariant(goal.status)) + '</td><td>' + ui().safeText(fmt().formatGoalType(goal.type)) + '</td><td>' + renderGoalProgress(goal) + '</td><td>' + ui().safeText(fmt().formatDate(goal.startsAt)) + ' - ' + ui().safeText(fmt().formatDate(goal.endsAt)) + '</td><td>' + ui().safeText(goal.createdByName || 'Sistema') + '</td><td>' + ui().technicalDetails('Detalhes', [{ label: 'ID', value: goal.id }, { label: 'Org', value: goal.orgCode }, { label: 'Tipo tecnico', value: goal.type }]) + '</td></tr>';
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
    return '<div class="table-scroll logs-scroll"><table><thead><tr><th>Data</th><th>Status</th><th>Acao</th><th>Autor</th><th>Alvo</th><th>Mensagem</th><th>Avancado</th></tr></thead><tbody>' + logs.map(function (log) {
      return '<tr><td>' + ui().safeText(fmt().formatDate(log.createdAt)) + '</td><td>' + ui().badge(fmt().formatStatusLabel(log.severity || 'info'), severityVariant(log.severity)) + '</td><td class="cell-strong">' + ui().safeText(fmt().formatStatusLabel(log.action || log.category)) + '<span class="cell-subtitle">' + ui().safeText(fmt().formatStatusLabel(log.category)) + '</span></td><td>' + ui().safeText(log.actorName || fmt().maskCitizenId(log.actorCitizenId)) + '</td><td>' + ui().safeText(log.targetName || fmt().maskCitizenId(log.targetCitizenId)) + '</td><td>' + ui().safeText(log.message || log.reason) + '</td><td>' + ui().technicalDetails('Detalhes', [{ label: 'Org', value: log.orgCode }, { label: 'Acao tecnica', value: log.action }, { label: 'Autor CID', value: log.actorCitizenId }, { label: 'Alvo CID', value: log.targetCitizenId }]) + '</td></tr>';
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
