(function () {
  'use strict';

  var modules = [
    { id: 'dashboard', label: 'Dashboard', icon: 'assets/icons/dashboard.svg', fallback: 'D', description: 'Resumo do acesso atual.' },
    { id: 'legal', label: 'Organizacao', icon: 'assets/icons/legal.svg', fallback: 'O', description: 'Painel legal da sua org.' },
    { id: 'gang', label: 'Gang', icon: 'assets/icons/gang.svg', fallback: 'G', description: 'Painel ilegal privado.' },
    { id: 'staff', label: 'Staff', icon: 'assets/icons/staff.svg', fallback: 'S', description: 'Area administrativa.' },
    { id: 'vip', label: 'VIP', icon: 'assets/icons/vip.svg', fallback: 'V', description: 'Beneficios e vinculo VIP.' },
    { id: 'business', label: 'Empresa', icon: 'assets/icons/business.svg', fallback: 'B', description: 'Painel de empresas.' },
    { id: 'government', label: 'Governo', icon: 'assets/icons/government.svg', fallback: 'P', description: 'Prefeitura e governo.' },
    { id: 'event', label: 'Eventos', icon: 'assets/icons/event.svg', fallback: 'E', description: 'Painel de eventos.' },
    { id: 'orgs', label: 'Organizacoes', icon: 'assets/icons/orgs.svg', fallback: 'L', description: 'Consulta administrativa.' },
    { id: 'recruitment', label: 'Recrutamento', icon: 'assets/icons/recruitment.svg', fallback: 'R', description: 'Candidaturas e triagem.' },
    { id: 'goals', label: 'Metas', icon: 'assets/icons/goals.svg', fallback: 'M', description: 'Metas da organizacao.' },
    { id: 'logs', label: 'Logs', icon: 'assets/icons/logs.svg', fallback: 'A', description: 'Auditoria read-only.' },
    { id: 'settings', label: 'Configuracoes', icon: 'assets/icons/settings.svg', fallback: 'C', description: 'Configuracoes futuras.' }
  ];

  var moduleById = modules.reduce(function (acc, item) {
    acc[item.id] = item;
    return acc;
  }, {});

  var panelFallback = {
    id: 'hub',
    title: 'Painel Geral',
    subtitle: 'Entrada contextual para os modulos liberados.',
    initialModule: 'dashboard',
    modules: ['dashboard']
  };

  var state = {
    isOpen: false,
    loadingSession: false,
    sessionError: null,
    requestedPanel: 'hub',
    requestedInitialModule: 'dashboard',
    activeShell: 'hub',
    activeOrgCode: null,
    activeOrgType: null,
    activeSection: 'overview',
    activePanel: 'hub',
    activeModule: 'dashboard',
    currentContext: null,
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
      accessLoading: false,
      accessError: null,
      access: null,
      bankActionLoading: false,
      bankActionType: null,
      bankActionMessage: null,
      bankActionError: null,
      inviteLoading: false,
      inviteMessage: null,
      inviteError: null,
      removeLoading: false,
      removeCitizenId: null,
      removeMessage: null,
      removeError: null,
      gradeLoading: false,
      gradeAction: null,
      gradeCitizenId: null,
      gradeMessage: null,
      gradeError: null,
      loadedKey: ''
    },
    logs: { loading: false, loaded: false, loadedKey: '', error: null, data: [], filters: { category: 'all', severity: 'all', org: 'all', search: '' } },
    recruitment: { loading: false, loaded: false, loadedKey: '', error: null, data: [], detail: null, actionLoading: false, actionMessage: null, actionError: null },
    goals: { loading: false, loaded: false, loadedKey: '', error: null, data: [], detail: null, createLoading: false, createMessage: null, createError: null },
    recruitmentModal: { open: false, mode: 'create', id: null, citizenid: '', gradeLevel: '', note: '', loading: false, error: null },
    goalModal: { open: false, title: '', type: 'manual', target: 1, startsAt: '', endsAt: '', description: '', loading: false, error: null },
    bankModal: { open: false, type: null, amount: '', reason: '', loading: false, error: null },
    memberModal: { open: false, citizenid: '', gradeLevel: '', gradeCode: '', loading: false, error: null },
    staffLeader: { orgCode: '', citizenid: '', reason: '', loading: false, message: null, error: null },
    cache: { orgs: null, logs: null, bank: {}, accessByOrg: {} },
    sidebarCollapsed: false
  };

  function resetOrgPanelData() {
    state.orgView.detail = null;
    state.orgView.members = [];
    state.orgView.bank = null;
    state.orgView.transactions = [];
    state.orgView.access = null;
    state.orgView.accessLoading = false;
    state.orgView.bankActionLoading = false;
    state.orgView.bankActionType = null;
    state.orgView.bankActionMessage = null;
    state.orgView.bankActionError = null;
    state.bankModal.open = false;
    state.bankModal.type = null;
    state.bankModal.amount = '';
    state.bankModal.reason = '';
    state.bankModal.loading = false;
    state.bankModal.error = null;
    state.recruitmentModal.open = false;
    state.recruitmentModal.mode = 'create';
    state.recruitmentModal.id = null;
    state.recruitmentModal.citizenid = '';
    state.recruitmentModal.gradeLevel = '';
    state.recruitmentModal.note = '';
    state.recruitmentModal.loading = false;
    state.recruitmentModal.error = null;
    state.recruitment.actionLoading = false;
    state.recruitment.actionMessage = null;
    state.recruitment.actionError = null;
    state.memberModal.open = false;
    state.memberModal.citizenid = '';
    state.memberModal.gradeLevel = '';
    state.memberModal.gradeCode = '';
    state.memberModal.loading = false;
    state.memberModal.error = null;
    state.orgView.inviteLoading = false;
    state.orgView.inviteMessage = null;
    state.orgView.inviteError = null;
    state.orgView.removeLoading = false;
    state.orgView.removeCitizenId = null;
    state.orgView.removeMessage = null;
    state.orgView.removeError = null;
    state.orgView.gradeLoading = false;
    state.orgView.gradeAction = null;
    state.orgView.gradeCitizenId = null;
    state.orgView.gradeMessage = null;
    state.orgView.gradeError = null;
    state.orgView.detailError = null;
    state.orgView.membersError = null;
    state.orgView.bankError = null;
    state.orgView.transactionsError = null;
    state.orgView.accessError = null;
    state.orgView.loadedKey = '';
  }

  window.MZOrgState = {
    modules: modules,
    moduleById: moduleById,
    panelFallback: panelFallback,
    state: state,
    resetOrgPanelData: resetOrgPanelData
  };
}());
