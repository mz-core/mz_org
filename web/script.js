(function () {
  'use strict';

  window.MZOrgRouter.registerPanels();
  window.MZOrgNui.init();

  if (!window.MZOrgNui.inFiveM()) {
    window.MZOrgNui.openPanel('dashboard', 'hub');
  }
}());
