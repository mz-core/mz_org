(function () {
  'use strict';

  window.MZOrgPanels = window.MZOrgPanels || {};
  window.MZOrgPanels.legal = {
    id: 'legal',
    title: 'Organizacao Legal',
    subtitle: 'Gestao da sua organizacao legal.',
    initialModule: 'legal',
    orgTypes: ['legal', 'job'],
    modules: ['legal', 'recruitment', 'goals', 'logs'],
    render: function () {
      return window.MZOrgRouter.renderOrgPanelPage();
    }
  };
}());
