(function () {
  'use strict';

  window.MZOrgPanels = window.MZOrgPanels || {};
  window.MZOrgPanels.business = {
    id: 'business',
    title: 'Empresa',
    subtitle: 'Operacao e equipe da empresa.',
    initialModule: 'business',
    orgTypes: ['business'],
    modules: ['business', 'recruitment', 'goals', 'logs'],
    render: function () {
      return window.MZOrgRouter.renderOrgPanelPage();
    }
  };
}());
