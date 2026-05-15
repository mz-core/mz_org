(function () {
  'use strict';

  window.MZOrgPanels = window.MZOrgPanels || {};
  window.MZOrgPanels.hub = {
    id: 'hub',
    title: 'Painel Geral',
    subtitle: 'Portal dos paineis liberados para seu personagem.',
    initialModule: 'dashboard',
    modules: ['dashboard', 'recruitment', 'goals', 'legal', 'gang', 'staff', 'vip', 'business', 'government', 'event', 'orgs', 'logs', 'settings'],
    render: function () {
      return window.MZOrgRouter.renderDashboard();
    }
  };
}());
