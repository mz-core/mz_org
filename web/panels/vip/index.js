(function () {
  'use strict';

  window.MZOrgPanels = window.MZOrgPanels || {};
  window.MZOrgPanels.vip = {
    id: 'vip',
    title: 'VIP',
    subtitle: 'Painel reservado para beneficios e vinculo VIP.',
    initialModule: 'vip',
    orgTypes: ['vip'],
    modules: ['vip', 'logs'],
    render: function () {
      return window.MZOrgRouter.renderOrgPanelPage();
    }
  };
}());
