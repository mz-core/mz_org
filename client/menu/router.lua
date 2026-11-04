MZOrgMenuRouter = MZOrgMenuRouter or {}

local function normalizedFilter(value)
  if value == nil then return nil end
  return MZOrgMenuProfiles.NormalizeType(value)
end

local function filteredOrganizations(session, typeFilter)
  local organizations = {}
  for _, organization in ipairs(type(session) == 'table' and session.organizations or {}) do
    if organization.entryAllowed == true
      and tostring(organization.status or ''):lower() == 'active'
      and (not typeFilter or organization.type == typeFilter)
    then
      organizations[#organizations + 1] = organization
    end
  end
  return organizations
end

local function openSelector(organizations, typeFilter)
  local options = {}
  for _, organization in ipairs(organizations) do
    local profile = MZOrgMenuTheme.Resolve(organization)
    options[#options + 1] = {
      title = organization.name,
      description = ('%s / %s'):format(profile.label or organization.type, organization.grade and organization.grade.name or ''),
      icon = profile.icon,
      onSelect = function() MZOrgOrganizationMenu.Open(organization.code) end
    }
  end

  local selector = {
    id = 'mz_org:organization:selector:' .. tostring(typeFilter or 'all'),
    title = 'Selecionar organizacao',
    subtitle = 'Escolha o contexto que deseja consultar',
    brand = 'MZ Organizations',
    headerIcon = 'building',
    badge = typeFilter and typeFilter:upper() or 'ORG',
    onExit = function() MZOrgMenuRequest.ClearContext('organization') end,
    options = options
  }
  if typeFilter then selector.theme = MZOrgMenuProfiles.Resolve(typeFilter, nil).theme end
  MZOrgMenuCommon.OpenContext(selector)
end

function MZOrgMenuRouter.ShouldUseOrganizationMenu()
  local interface = type(Config.Interface) == 'table' and Config.Interface or {}
  local mode = tostring(interface.mode or 'nui'):lower()
  return interface.organizationMenu == true and mode == 'menu'
end

function MZOrgMenuRouter.ShouldUseStaffMenu()
  local interface = type(Config.Interface) == 'table' and Config.Interface or {}
  local architecture = type(Config.MenuArchitecture) == 'table' and Config.MenuArchitecture or {}
  local mode = tostring(interface.mode or 'nui'):lower()
  return interface.staffMenu == true and architecture.enabled == true and architecture.staffMenuEnabled == true and mode == 'menu'
end

function MZOrgMenuRouter.CanUseNui()
  local interface = type(Config.Interface) == 'table' and Config.Interface or {}
  local mode = tostring(interface.mode or 'nui'):lower()
  return mode == 'nui' and interface.nuiPanel ~= false and interface.nuiCommands ~= false
end

function MZOrgMenuRouter.OpenOrganizations(typeFilter, commandName)
  typeFilter = normalizedFilter(typeFilter)
  MZOrgMenuRequest.BeginContext('selector:' .. tostring(typeFilter or 'all'))
  MZOrgMenuRequest.RequestContextual('mz_org:server:requestSession', {
    requestedEntry = 'organization',
    requestedType = typeFilter,
    command = commandName
  }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Sessao organizacional indisponivel.', 'error')
      return
    end

    local organizations = filteredOrganizations(response.data, typeFilter)
    if #organizations == 0 then
      MZOrgMenuCommon.Notify('Nenhuma organizacao ativa disponivel para este comando.', 'error')
    elseif #organizations == 1 then
      MZOrgOrganizationMenu.Open(organizations[1].code)
    else
      openSelector(organizations, typeFilter)
    end
  end)
end
