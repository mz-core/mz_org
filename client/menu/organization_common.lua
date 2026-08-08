MZOrgOrganizationCommon = MZOrgOrganizationCommon or {}

function MZOrgOrganizationCommon.RootId(organization)
  return 'mz_org:org:' .. tostring(organization.code) .. ':root'
end

function MZOrgOrganizationCommon.Visual(context)
  local visual = MZOrgMenuCommon.VisualFields(context.organization)
  for key, value in pairs(visual) do context[key] = value end
  return context
end

function MZOrgOrganizationCommon.Request(context, moduleName, eventName, payload, callback)
  payload = type(payload) == 'table' and payload or {}
  payload.orgCode = context.organization.code
  MZOrgMenuRequest.BeginOrganizationModule(moduleName)
  return MZOrgMenuRequest.RequestContextual(eventName, payload, callback)
end

function MZOrgOrganizationCommon.Mutate(context, eventName, payload)
  local organization = context.organization
  payload = type(payload) == 'table' and payload or {}
  payload.orgCode = organization.code
  payload.organizationRevision = organization.organizationRevision
  MZOrgMenuRequest.RequestMutation(eventName, payload, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Operacao organizacional recusada.', 'error')
      return
    end
    local auditId = response.data.auditId
    MZOrgMenuCommon.Notify(('Operacao confirmada%s.'):format(
      auditId and (' / auditId ' .. tostring(auditId)) or ''
    ), 'success')
    MZOrgOrganizationMenu.Open(organization.code)
  end)
end

function MZOrgOrganizationCommon.Open(context, moduleName, title, subtitle, options)
  local organization = context.organization
  MZOrgMenuCommon.OpenContext(MZOrgOrganizationCommon.Visual({
    id = ('mz_org:org:%s:%s'):format(organization.code, moduleName),
    title = title,
    subtitle = subtitle or (organization.name .. ' / somente leitura'),
    menu = MZOrgOrganizationCommon.RootId(organization),
    onExit = function() MZOrgMenuRequest.ClearContext('organization') end,
    options = options
  }))
end

function MZOrgOrganizationCommon.Empty(options, title, icon)
  if #options == 0 then
    options[1] = { title = title, icon = icon or 'info', readOnly = true }
  end
  return options
end

function MZOrgOrganizationCommon.AddPagination(options, pagination, openPage)
  pagination = type(pagination) == 'table' and pagination or {}
  local offset = tonumber(pagination.offset) or 0
  local limit = tonumber(pagination.limit) or 25
  local returned = tonumber(pagination.returned) or 0
  if offset > 0 then
    options[#options + 1] = {
      title = 'Pagina anterior',
      icon = 'arrow-left',
      onSelect = function() openPage(math.max(0, offset - limit)) end
    }
  end
  if returned == limit then
    options[#options + 1] = {
      title = 'Proxima pagina',
      icon = 'arrow-right',
      onSelect = function() openPage(offset + limit) end
    }
  end
end
