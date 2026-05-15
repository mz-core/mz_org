(function () {
  'use strict';

  window.MZOrgPanels = window.MZOrgPanels || {};
  window.MZOrgPanels.government = {
    id: 'government',
    title: 'Governo',
    subtitle: 'Gestao publica e auditoria operacional.',
    initialModule: 'government',
    orgTypes: ['government'],
    modules: ['government', 'recruitment', 'goals', 'logs'],
    render: function () {
      return window.MZOrgRouter.renderOrgPanelPage();
    }
  };
}());
