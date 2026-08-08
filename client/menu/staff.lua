MZOrgStaffMenu = MZOrgStaffMenu or { State = {} }

local function hasModule(entry, moduleName)
  for _, value in ipairs(type(entry) == 'table' and entry.modules or {}) do
    if value == moduleName then return true end
  end
  return false
end

function MZOrgStaffMenu.HasModule(moduleName)
  return hasModule(MZOrgStaffMenu.State.entry, moduleName)
end

function MZOrgStaffMenu.HasAction(actionName)
  for _, value in ipairs(type(MZOrgStaffMenu.State.entry) == 'table' and MZOrgStaffMenu.State.entry.actions or {}) do
    if value == actionName then return true end
  end
  return false
end

function MZOrgStaffMenu.RootId()
  return 'mz_org:staff:root'
end

function MZOrgStaffMenu.Visual(context)
  context = type(context) == 'table' and context or {}
  local presentation = MZOrgMenuProfiles.Resolve('staff', nil)
  context.theme = presentation.theme
  context.brand = presentation.brand
  context.headerIcon = presentation.icon
  context.badge = 'STAFF'
  context.onExit = context.onExit or function()
    MZOrgMenuRequest.ClearContext('staff')
    MZOrgStaffMenu.State = {}
  end
  return context
end

local function openOverview(entry)
  local permissions = table.concat(entry.permissions or {}, ', ')
  if permissions == '' then permissions = entry.user and entry.user.identity or 'Staff' end
  local modules = table.concat(entry.modules or {}, ', ')
  local counts = type(entry.counts) == 'table' and entry.counts or {}
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:overview',
    title = 'Visao geral Staff',
    subtitle = 'Contexto global / somente leitura',
    menu = MZOrgStaffMenu.RootId(),
    options = {
      { title = 'Usuario', description = entry.user and entry.user.name or 'Staff', icon = 'users', readOnly = true },
      { title = 'Identificacao', description = entry.user and entry.user.identity or 'Staff', icon = 'shield', readOnly = true },
      { title = 'Permissoes globais', description = permissions, icon = 'lock', readOnly = true },
      {
        title = 'Organizacoes ativas',
        description = counts.restricted and 'Restrito' or tostring(counts.activeOrganizations or 0),
        icon = 'building',
        readOnly = true
      },
      {
        title = 'Organizacoes arquivadas',
        description = counts.restricted and 'Restrito' or tostring(counts.archivedOrganizations or 0),
        icon = 'archive',
        readOnly = true
      },
      { title = 'Modulos liberados', description = modules, icon = 'layers', readOnly = true },
      { title = 'Modo', description = entry.readOnly and 'Somente leitura' or 'Operacional seguro - Lote 6A', icon = 'eye', readOnly = true }
    }
  }))
end

function MZOrgStaffMenu.OpenRoot(entry)
  MZOrgStaffMenu.State.entry = entry
  local options = {
    {
      title = 'Visao geral',
      description = 'Identidade, permissoes globais e contadores.',
      icon = 'info',
      onSelect = function() openOverview(entry) end
    }
  }

  if MZOrgStaffMenu.HasAction('create') then
    options[#options + 1] = {
      title = 'Criar organizacao',
      description = 'Criacao por template oficial com confirmacao e auditoria.',
      icon = 'building',
      onSelect = function() MZOrgStaffMutations.CreateOrganization() end
    }
  end

  if hasModule(entry, 'organizations') then
    options[#options + 1] = {
      title = 'Buscar organizacao',
      description = 'Busca estrutural por nome, codigo ou ID.',
      icon = 'search',
      onSelect = function() MZOrgStaffOrganizations.Search() end
    }
    options[#options + 1] = {
      title = 'Organizacoes ativas',
      description = tostring(entry.counts and entry.counts.activeOrganizations or 0),
      icon = 'building',
      onSelect = function() MZOrgStaffOrganizations.List({ status = 'active' }, 1) end
    }
    options[#options + 1] = {
      title = 'Organizacoes arquivadas',
      description = tostring(entry.counts and entry.counts.archivedOrganizations or 0),
      icon = 'archive',
      onSelect = function() MZOrgStaffOrganizations.List({ status = 'archived' }, 1) end
    }
    options[#options + 1] = {
      title = 'Todas as organizacoes',
      description = 'Listagem paginada e filtros por tipo.',
      icon = 'layers',
      onSelect = function() MZOrgStaffOrganizations.List({ status = 'all' }, 1) end
    }
  end

  if hasModule(entry, 'legacy') then
    options[#options + 1] = {
      title = 'Diagnostico de permissoes legadas',
      description = 'Capabilities staff.* armazenadas e ignoradas.',
      icon = 'warning',
      onSelect = function() MZOrgStaffOrganizations.OpenLegacyDiagnostics(1) end
    }
  end

  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = MZOrgStaffMenu.RootId(),
    title = 'Staff - Organizacoes',
    subtitle = (entry.user and entry.user.name or 'Staff') .. (entry.readOnly and ' / somente leitura' or ' / operacional'),
    options = options
  }))
end

function MZOrgStaffMenu.AfterMutation(result, orgCode)
  local auditId = type(result) == 'table' and result.auditId or nil
  MZOrgMenuCommon.Notify(('Operacao confirmada%s.'):format(auditId and (' / auditId ' .. auditId) or ''), 'success')
  MZOrgStaffMenu.Open({ orgCode = orgCode })
end

function MZOrgStaffMenu.Open(options)
  options = type(options) == 'table' and options or {}
  local architecture = type(Config.MenuArchitecture) == 'table' and Config.MenuArchitecture or {}
  if architecture.enabled ~= true or architecture.staffMenuEnabled ~= true or Config.Interface.staffMenu ~= true then
    MZOrgMenuCommon.Notify('Staff Menu desativado por configuracao.', 'error')
    return
  end

  MZOrgMenuRequest.BeginStaffContext('entry')
  MZOrgMenuRequest.RequestContextual('mz_org:server:resolveStaffMenuEntry', {}, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Acesso Staff negado.', 'error')
      MZOrgMenuRequest.ClearContext('staff')
      return
    end
    local entry = response.data
    MZOrgMenuRequest.SetStaffContext(entry.session or {}, 'root')
    MZOrgStaffMenu.OpenRoot(entry)
    if options.orgCode and hasModule(entry, 'organizations') then
      MZOrgStaffOrganizations.OpenInspection(options.orgCode)
    end
  end)
end
