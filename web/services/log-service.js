(function () {
  'use strict';

  function listLogs(filters) {
    return window.MZOrgNui.callNuiData('logs:list', filters || { limit: 100 }).then(function (items) {
      return Array.isArray(items) ? items : [];
    });
  }

  window.MZOrgLogService = {
    listLogs: listLogs
  };
}());
