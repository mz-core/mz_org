(function () {
  'use strict';

  window.MZOrgPanels = window.MZOrgPanels || {};
  window.MZOrgPanels.staff = {
    id: 'staff',
    title: 'Staff',
    subtitle: 'Consulta administrativa, orgs e auditoria.',
    initialModule: 'staff',
    modules: ['staff', 'orgs', 'logs', 'settings'],
    render: function () {
      return window.MZOrgRouter.renderStaffPage();
    }
  };
}());
