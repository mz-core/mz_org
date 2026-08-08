MZOrgOrganizationLogs = MZOrgOrganizationLogs or {}

local function open(context, offset)
  MZOrgOrganizationCommon.Request(context, 'logs', 'mz_org:server:organizationListLogs', {
    offset = offset or 0
  }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Nao foi possivel consultar os logs.', 'error')
      return
    end

    local options = {}
    for _, item in ipairs(response.data.items or {}) do
      options[#options + 1] = {
        title = tostring(item.action or 'Evento'),
        description = MZOrgMenuCommon.FormatDateTime(item.createdAt) .. ' / ' .. tostring(item.actorName or item.actorCitizenId or 'Sistema'),
        icon = 'history',
        metadata = {
          { label = 'Categoria', value = item.category or '-' },
          { label = 'Severidade', value = item.severity or 'info' },
          { label = 'Alvo', value = item.targetName or item.targetCitizenId or '-' },
          { label = 'Mensagem', value = item.message or item.reason or 'Nao informada' },
          { label = 'Audit ID', value = item.auditId or '-' }
        },
        readOnly = true
      }
    end
    MZOrgOrganizationCommon.Empty(options, 'Nenhum log encontrado', 'history')
    MZOrgOrganizationCommon.AddPagination(options, response.data.pagination, function(nextOffset) open(context, nextOffset) end)
    MZOrgOrganizationCommon.Open(context, 'logs', 'Logs', nil, options)
  end)
end

function MZOrgOrganizationLogs.Open(context)
  open(context, 0)
end
