(function () {
  'use strict';

  window.MZOrgPanels = window.MZOrgPanels || {};
  window.MZOrgPanels.illegal = {
    id: 'illegal',
    title: 'Organizacao Ilegal',
    subtitle: 'Gestao privada da sua faccao.',
    initialModule: 'gang',
    orgTypes: ['gang', 'illegal'],
    modules: ['gang', 'recruitment', 'goals', 'logs'],
    render: function () {
      return window.MZOrgRouter.renderOrgPanelPage();
    }
  };
}());
