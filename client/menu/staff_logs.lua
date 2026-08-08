MZOrgStaffLogs = MZOrgStaffLogs or {}

local function requestFilters(current)
  current = type(current) == 'table' and current or {}
  local values = MZOrgMenuCommon.InputDialog('Filtros estruturais', {
    { type = 'input', label = 'Escopo/categoria exata', default = current.category or '' },
    { type = 'input', label = 'Acao exata', default = current.action or '' },
    { type = 'input', label = 'Autor estrutural exato', default = current.actor or '' },
    { type = 'input', label = 'Data inicial', default = current.dateFrom or '' },
    { type = 'input', label = 'Data final', default = current.dateTo or '' },
    { type = 'input', label = 'Audit ID exato', default = current.auditId or '' }
  })
  if type(values) ~= 'table' then return nil end
  return { category = values[1], action = values[2], actor = values[3], dateFrom = values[4], dateTo = values[5], auditId = values[6] }
end

local function open(scopeKind, orgCode, auditOnly, filters, offset)
  filters = type(filters) == 'table' and filters or {}
  offset = tonumber(offset) or 0
  local moduleName = auditOnly and 'audit' or 'logs'
  MZOrgMenuRequest.BeginStaffModule(moduleName, orgCode)
  local eventName
  if scopeKind == 'org' then eventName = auditOnly and 'mz_org:server:staffListOrgAudit' or 'mz_org:server:staffListOrgLogs'
  else eventName = auditOnly and 'mz_org:server:staffListGlobalAudit' or 'mz_org:server:staffListGlobalLogs' end
  local payload = {
    orgCode = orgCode, category = filters.category, action = filters.action, actor = filters.actor,
    dateFrom = filters.dateFrom, dateTo = filters.dateTo, auditId = filters.auditId,
    limit = 25, offset = offset
  }
  MZOrgMenuRequest.RequestContextual(eventName, payload, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Logs Staff indisponiveis.', 'error') return
    end
    local options = {
      { title = 'Aplicar filtros', description = 'Acao, autor, periodo e auditId exatos.', icon = 'search', onSelect = function()
        local nextFilters = requestFilters(filters)
        if nextFilters then open(scopeKind, orgCode, auditOnly, nextFilters, 0) end
      end }
    }
    for _, item in ipairs(response.data.items or {}) do
      options[#options + 1] = {
        title = tostring(item.action or 'Evento'),
        description = MZOrgMenuCommon.FormatDateTime(item.createdAt, 'Data indisponivel') .. ' / ' .. tostring(item.actorName or item.actorCitizenId or 'system'),
        icon = auditOnly and 'shield' or 'eye',
        metadata = {
          { label = 'Escopo', value = item.scope },
          { label = 'Org', value = item.orgCode or 'global' },
          { label = 'Audit ID', value = item.auditId or 'n/a' },
          { label = 'Alvo', value = item.targetName or item.targetCitizenId }
        }, readOnly = true
      }
    end
    local pagination = response.data.pagination or {}
    if offset > 0 then options[#options + 1] = { title = 'Pagina anterior', icon = 'arrow-left', onSelect = function() open(scopeKind, orgCode, auditOnly, filters, math.max(0, offset - 25)) end } end
    if (pagination.returned or 0) == 25 then options[#options + 1] = { title = 'Proxima pagina', icon = 'refresh', onSelect = function() open(scopeKind, orgCode, auditOnly, filters, offset + 25) end } end
    local parent = scopeKind == 'org' and ('mz_org:staff:org:' .. orgCode .. ':root') or MZOrgStaffMenu.RootId()
    MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
      id = scopeKind == 'org' and ('mz_org:staff:' .. moduleName .. ':org:' .. orgCode) or ('mz_org:staff:' .. moduleName .. ':global'),
      title = auditOnly and 'Auditoria' or 'Logs',
      subtitle = scopeKind == 'org' and ('Organizacao ' .. orgCode) or 'Escopo global',
      menu = parent, options = options
    }))
  end)
end

function MZOrgStaffLogs.OpenGlobal(auditOnly)
  open('global', nil, auditOnly == true, {}, 0)
end

function MZOrgStaffLogs.OpenOrganization(orgCode, auditOnly)
  open('org', orgCode, auditOnly == true, {}, 0)
end
