(function () {
  'use strict';

  window.MZOrgPanels = window.MZOrgPanels || {};
  window.MZOrgPanels.event = {
    id: 'event',
    title: 'Eventos',
    subtitle: 'Painel reservado para eventos.',
    initialModule: 'event',
    orgTypes: ['event'],
    modules: ['event', 'logs'],
    render: function () {
      return window.MZOrgRouter.renderOrgPanelPage();
    }
  };
}());
