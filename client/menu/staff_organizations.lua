MZOrgStaffOrganizations = MZOrgStaffOrganizations or {}

local ORG_TYPES = { 'job', 'gang', 'business', 'government', 'vip', 'event' }

local function contains(values, expected)
  for _, value in ipairs(values or {}) do if value == expected then return true end end
  return false
end

local function statusLabel(status)
  return status == 'archived' and 'Arquivada' or 'Ativa'
end

local function boolLabel(value)
  return value == true and 'Habilitado' or 'Desabilitado'
end

local function registerInspectionContexts(data, parentMenu)
  local org = data.organization
  local rootId = 'mz_org:staff:org:' .. org.code .. ':root'
  local parent = rootId
  local supportsLeadership = org.supportsLeadership == true
  local leader = type(data.leader) == 'table' and data.leader or nil
  local effectiveFeatures = {}
  for _, feature in ipairs(data.features or {}) do if feature.effective then effectiveFeatures[#effectiveFeatures + 1] = feature.name end end
  local effectiveTheme = data.appearance and data.appearance.theme or {}

  MZOrgMenuCommon.RegisterContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. org.code .. ':summary',
    title = 'Resumo', subtitle = org.name, menu = parent,
    options = {
      { title = 'Codigo', description = tostring(org.code), icon = 'info', readOnly = true },
      { title = 'Nome', description = tostring(org.name), icon = 'building', readOnly = true },
      { title = 'Tipo', description = tostring(org.type), icon = 'layers', readOnly = true },
      { title = 'Estado', description = statusLabel(org.status), icon = org.status == 'archived' and 'archive' or 'check', readOnly = true },
      { title = 'Criada em', description = MZOrgMenuCommon.FormatDateTime(org.createdAt), icon = 'calendar', readOnly = true },
      {
        title = supportsLeadership and 'Lideranca' or 'Modelo VIP',
        description = supportsLeadership
          and (leader and tostring(leader.name or leader.citizenid) or 'Nao identificada')
          or 'Niveis de privilegio sem lider',
        icon = supportsLeadership and 'crown' or 'layers',
        readOnly = true
      },
      { title = 'Total de membros', description = tostring(#(data.members or {})), icon = 'users', readOnly = true },
      { title = 'Total de cargos', description = tostring(#(data.grades or {})), icon = 'shield', readOnly = true },
      { title = 'Features efetivas', description = #effectiveFeatures > 0 and table.concat(effectiveFeatures, ', ') or 'Nenhuma', icon = 'layers', readOnly = true },
      { title = 'Tema efetivo', description = tostring(effectiveTheme.accent or '') .. ' / ' .. tostring(effectiveTheme.accent2 or ''), icon = 'eye', readOnly = true },
      {
        title = 'Ponto de servico',
        description = org.supportsDuty ~= true
          and 'Nao aplicavel a este tipo'
          or (type(org.dutyPoint) == 'table' and org.dutyPoint.enabled == true
            and tostring(org.dutyPoint.label or 'Configurado')
            or 'Nao configurado'),
        icon = type(org.dutyPoint) == 'table' and org.dutyPoint.enabled == true and 'check' or 'info',
        metadata = type(org.dutyPoint) == 'table' and org.dutyPoint.enabled == true and {
          {
            label = 'Coordenadas',
            value = ('%.2f, %.2f, %.2f'):format(
              tonumber(org.dutyPoint.coords and org.dutyPoint.coords.x) or 0.0,
              tonumber(org.dutyPoint.coords and org.dutyPoint.coords.y) or 0.0,
              tonumber(org.dutyPoint.coords and org.dutyPoint.coords.z) or 0.0
            )
          }
        } or nil,
        readOnly = true
      },
      { title = 'Revisao', description = tostring(org.organizationRevision or 1), icon = 'refresh', readOnly = true },
      { title = 'Nome de exibicao', description = tostring(org.public and org.public.displayName or '-'), icon = 'info', readOnly = true },
      { title = 'Descricao', description = tostring(org.public and org.public.description or '-'), icon = 'info', readOnly = true },
      { title = 'Modo', description = data.readOnly and 'Somente leitura' or 'Operacional seguro', icon = 'eye', readOnly = true }
    }
  }))

  if supportsLeadership then
    MZOrgMenuCommon.RegisterContext(MZOrgStaffMenu.Visual({
      id = 'mz_org:staff:org:' .. org.code .. ':leader',
      title = 'Lideranca', subtitle = org.name, menu = parent,
      options = leader and {
        { title = tostring(leader.name or leader.citizenid), description = tostring(leader.gradeName or leader.gradeCode or ''), icon = 'crown', metadata = {
          { label = 'CitizenID', value = leader.citizenid }, { label = 'Grade', value = leader.gradeLevel }
        }, readOnly = true }
      } or { { title = 'Lideranca nao identificada', icon = 'warning', readOnly = true } }
    }))
  end

  local memberOptions = {}
  for _, member in ipairs(data.members or {}) do
    memberOptions[#memberOptions + 1] = {
      title = tostring(member.name or member.citizenid),
      description = tostring(member.gradeName or member.gradeCode or 'Sem cargo'),
      icon = member.isLeader and 'crown' or 'users',
      metadata = {
        { label = 'CitizenID', value = member.citizenid },
        { label = 'Grade', value = member.gradeLevel },
        { label = 'Estado', value = member.status },
        { label = 'Entrada', value = MZOrgMenuCommon.FormatDateTime(member.joinedAt) }
      },
      readOnly = true
    }
  end
  if #memberOptions == 0 then memberOptions[1] = { title = 'Nenhum membro', icon = 'users', readOnly = true } end
  MZOrgMenuCommon.RegisterContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. org.code .. ':members', title = 'Membros', subtitle = org.name .. ' / somente leitura', menu = parent, options = memberOptions
  }))

  local gradeOptions = {}
  for _, grade in ipairs(data.grades or {}) do
    local legacy = {}
    for _, permission in ipairs(data.legacyStaffCapabilities or {}) do
      if tonumber(permission.gradeId) == tonumber(grade.id) then legacy[#legacy + 1] = permission.permission end
    end
    local capabilities = table.concat(grade.capabilities or {}, ', ')
    if capabilities == '' then capabilities = 'Nenhuma capability organizacional' end
    gradeOptions[#gradeOptions + 1] = {
      title = ('%s - %s'):format(tostring(grade.level), tostring(grade.name or grade.code)),
      description = capabilities,
      icon = 'shield',
      metadata = {
        { label = 'Codigo', value = grade.code },
        { label = 'Membros', value = grade.memberCount },
        { label = 'Estado', value = grade.active and 'Ativo' or 'Inativo' },
        { label = 'Legado ignorado', value = #legacy }
      },
      readOnly = true
    }
    for _, permission in ipairs(legacy) do
      gradeOptions[#gradeOptions + 1] = {
        title = 'Legado ignorado', description = permission, icon = 'warning', readOnly = true
      }
    end
  end
  for _, permission in ipairs(data.legacyStaffCapabilities or {}) do
    if permission.gradeId == nil then
      gradeOptions[#gradeOptions + 1] = {
        title = 'Legado ignorado (base)', description = permission.permission, icon = 'warning', readOnly = true
      }
    end
  end
  if #gradeOptions == 0 then gradeOptions[1] = { title = 'Nenhum cargo disponivel', icon = 'shield', readOnly = true } end
  MZOrgMenuCommon.RegisterContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. org.code .. ':grades', title = 'Cargos', subtitle = org.name .. ' / somente leitura', menu = parent, options = gradeOptions
  }))

  local featureOptions = {}
  for _, feature in ipairs(data.features or {}) do
    local override = feature.override == nil and 'sem override' or tostring(feature.override)
    featureOptions[#featureOptions + 1] = {
      title = feature.name,
      description = ('%s / origem: %s'):format(boolLabel(feature.effective), tostring(feature.origin)),
      icon = feature.effective and 'check' or 'x',
      metadata = {
        { label = 'Perfil', value = tostring(feature.profileEnabled) },
        { label = 'Override', value = override },
        { label = 'Dependencia', value = feature.dependency or 'nenhuma' }
      },
      readOnly = true
    }
  end
  MZOrgMenuCommon.RegisterContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. org.code .. ':features', title = 'Features', subtitle = org.name, menu = parent, options = featureOptions
  }))

  local appearance, sources = data.appearance or {}, data.appearance and data.appearance.sources or {}
  local theme = type(appearance.theme) == 'table' and appearance.theme or {}
  local appearanceOptions = {}
  local values = {
    { 'Perfil herdado', appearance.key, sources.profile },
    { 'Accent', theme.accent, sources.accent },
    { 'Accent 2', theme.accent2, sources.accent2 },
    { 'Brand', appearance.brand, sources.brand },
    { 'Header icon', appearance.icon, sources.icon },
    { 'Badge', appearance.badge, sources.badge },
    { 'Position', theme.position, sources.position },
    { 'Width', theme.width, sources.width }
  }
  for _, row in ipairs(values) do
    appearanceOptions[#appearanceOptions + 1] = { title = row[1], description = tostring(row[2] or ''), icon = 'eye', metadata = {
      { label = 'Origem', value = row[3] or 'desconhecida' }
    }, readOnly = true }
  end
  MZOrgMenuCommon.RegisterContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. org.code .. ':appearance', title = 'Aparencia efetiva', subtitle = org.name, menu = parent, options = appearanceOptions
  }))

  local rootOptions = {
    { title = 'Resumo', icon = 'info', menu = 'mz_org:staff:org:' .. org.code .. ':summary' }
  }
  if supportsLeadership then
    rootOptions[#rootOptions + 1] = {
      title = 'Lideranca',
      icon = 'crown',
      onSelect = function() MZOrgStaffOperations.OpenLeadership(data) end
    }
  end
  local structuralOptions = {
    { title = 'Membros', description = tostring(#(data.members or {})), icon = 'users', onSelect = function() MZOrgStaffOperations.OpenMembers(data) end },
    { title = 'Cargos', description = tostring(#(data.grades or {})), icon = 'shield', onSelect = function() MZOrgStaffOperations.OpenGrades(data) end },
    { title = 'Features', icon = 'layers', onSelect = function() MZOrgStaffFeatures.Open(data) end },
    { title = 'Aparencia', icon = 'eye', onSelect = function() MZOrgStaffAppearance.Open(data) end }
  }
  for _, option in ipairs(structuralOptions) do rootOptions[#rootOptions + 1] = option end
  if org.supportsDuty == true then
    rootOptions[#rootOptions + 1] = {
      title = 'Ponto de servico',
      description = type(org.dutyPoint) == 'table' and org.dutyPoint.enabled == true
        and tostring(org.dutyPoint.label or 'Configurado')
        or 'Nao configurado',
      icon = type(org.dutyPoint) == 'table' and org.dutyPoint.enabled == true and 'check' or 'building',
      onSelect = function() MZOrgStaffDuty.Open(data) end
    }
  end
  if org.status == 'active' and contains(data.allowedActions, 'edit') then
    rootOptions[#rootOptions + 1] = { title = 'Editar dados basicos', icon = 'info', onSelect = function() MZOrgStaffMutations.EditBasic(data) end }
    rootOptions[#rootOptions + 1] = { title = 'Alterar tipo', description = 'Operacao sensivel com previa de impacto.', icon = 'layers', onSelect = function() MZOrgStaffMutations.ChangeType(data) end }
  end
  if org.status == 'active' and contains(data.allowedActions, 'archive') then
    rootOptions[#rootOptions + 1] = { title = 'Arquivar organizacao', description = 'Exige digitacao do codigo.', icon = 'archive', onSelect = function() MZOrgStaffMutations.Archive(data) end }
  end
  if org.status ~= 'active' and contains(data.allowedActions, 'restore') then
    rootOptions[#rootOptions + 1] = { title = 'Reativar organizacao', description = 'Valida integridade antes de reabrir.', icon = 'refresh', onSelect = function() MZOrgStaffMutations.Restore(data) end }
  end
  if contains(data.allowedModules, 'logs') then
    rootOptions[#rootOptions + 1] = { title = 'Logs', icon = 'eye', onSelect = function() MZOrgStaffLogs.OpenOrganization(org.code, false) end }
  end
  if contains(data.allowedModules, 'audit') then
    rootOptions[#rootOptions + 1] = { title = 'Auditoria', icon = 'shield', onSelect = function() MZOrgStaffLogs.OpenOrganization(org.code, true) end }
  end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = rootId,
    title = org.name,
    subtitle = statusLabel(org.status) .. (data.readOnly and ' / Staff somente leitura' or ' / Staff operacional'),
    menu = parentMenu or MZOrgStaffMenu.RootId(),
    options = rootOptions
  }))
end

function MZOrgStaffOrganizations.OpenInspection(orgCode, parentMenu)
  MZOrgMenuRequest.BeginStaffModule('organizations', orgCode)
  MZOrgMenuRequest.RequestContextual('mz_org:server:staffGetOrganization', { orgCode = orgCode }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Inspecao Staff indisponivel.', 'error')
      return
    end
    if not response.data.organization or response.data.organization.code ~= orgCode then return end
    registerInspectionContexts(response.data, parentMenu)
  end)
end

function MZOrgStaffOrganizations.List(filters, page)
  filters = type(filters) == 'table' and filters or {}
  page = tonumber(page) or 1
  MZOrgMenuRequest.BeginStaffModule('organizations')
  MZOrgMenuRequest.RequestContextual('mz_org:server:staffListOrganizations', {
    page = page, pageSize = (Config.MenuArchitecture or {}).pageSize or 20,
    status = filters.status, type = filters.type, query = filters.query
  }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Listagem Staff indisponivel.', 'error')
      return
    end
    local data, options = response.data, {}
    for _, org in ipairs(data.items or {}) do
      local selectedCode = org.code
      options[#options + 1] = {
        title = org.name,
        description = ('%s / %s / %s'):format(org.code, org.type, org.badge),
        icon = org.presentation and org.presentation.icon or 'building',
        iconColor = org.presentation and org.presentation.theme and org.presentation.theme.accent or nil,
        metadata = {
          { label = 'ID', value = org.id },
          { label = 'Estado', value = org.badge },
          {
            label = 'Lideranca',
            value = org.supportsLeadership == false
              and 'Nao aplicavel'
              or (org.leadershipAvailable and org.leader or 'Sob demanda')
          },
          { label = 'Membros', value = org.memberCountAvailable and org.memberCount or 'Sob demanda' }
        },
        onSelect = function() MZOrgStaffOrganizations.OpenInspection(selectedCode, 'mz_org:staff:organizations:list') end
      }
    end
    if #options == 0 then options[1] = { title = 'Nenhuma organizacao encontrada', icon = 'search', readOnly = true } end
    local pagination = data.pagination or {}
    if (pagination.page or 1) > 1 then
      options[#options + 1] = { title = 'Pagina anterior', icon = 'arrow-left', onSelect = function() MZOrgStaffOrganizations.List(filters, pagination.page - 1) end }
    end
    if (pagination.page or 1) < (pagination.totalPages or 1) then
      options[#options + 1] = { title = 'Proxima pagina', icon = 'refresh', onSelect = function() MZOrgStaffOrganizations.List(filters, pagination.page + 1) end }
    end
    options[#options + 1] = { title = 'Filtrar por tipo', icon = 'layers', onSelect = function() MZOrgStaffOrganizations.OpenTypeFilter(filters) end }
    MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
      id = 'mz_org:staff:organizations:list',
      title = 'Organizacoes',
      subtitle = ('Pagina %s/%s - %s resultados'):format(pagination.page or 1, pagination.totalPages or 1, pagination.total or 0),
      menu = MZOrgStaffMenu.RootId(), options = options
    }))
  end)
end

function MZOrgStaffOrganizations.Search()
  local result = MZOrgMenuCommon.InputDialog('Buscar organizacao', {
    { type = 'input', label = 'Nome, codigo ou ID estrutural', required = true }
  })
  if type(result) == 'table' and tostring(result[1] or '') ~= '' then
    MZOrgStaffOrganizations.List({ status = 'all', query = result[1] }, 1)
  end
end

function MZOrgStaffOrganizations.OpenTypeFilter(filters)
  local options = { { title = 'Todos os tipos', icon = 'layers', onSelect = function() local nextFilters = { status = filters.status, query = filters.query }; MZOrgStaffOrganizations.List(nextFilters, 1) end } }
  for _, orgType in ipairs(ORG_TYPES) do
    local selectedType = orgType
    options[#options + 1] = { title = selectedType, icon = MZOrgMenuProfiles.Resolve(selectedType, nil).icon, onSelect = function()
      local nextFilters = { status = filters.status, query = filters.query, type = selectedType }
      MZOrgStaffOrganizations.List(nextFilters, 1)
    end }
  end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:organizations:type', title = 'Filtrar por tipo', menu = 'mz_org:staff:organizations:list', options = options
  }))
end

function MZOrgStaffOrganizations.OpenLegacyDiagnostics(page)
  MZOrgMenuRequest.BeginStaffModule('legacy')
  MZOrgMenuRequest.RequestContextual('mz_org:server:staffListLegacyDiagnostics', { page = page, pageSize = 20 }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Diagnostico indisponivel.', 'error') return
    end
    local options = {}
    for _, item in ipairs(response.data.items or {}) do
      options[#options + 1] = {
        title = item.permission,
        description = ('%s / %s / Legado ignorado'):format(item.orgCode or '', item.gradeName or 'capability base'),
        icon = 'warning',
        metadata = {
          { label = 'Organizacao', value = item.orgName },
          { label = 'Cargo', value = item.gradeCode or 'base' },
          { label = 'Status', value = 'ignorada' },
          { label = 'Recomendacao', value = item.recommendation }
        }, readOnly = true
      }
    end
    if #options == 0 then options[1] = { title = 'Nenhuma capability staff.* legada', icon = 'check', readOnly = true } end
    local pagination = response.data.pagination or {}
    if (pagination.page or 1) > 1 then options[#options + 1] = { title = 'Pagina anterior', icon = 'arrow-left', onSelect = function() MZOrgStaffOrganizations.OpenLegacyDiagnostics(pagination.page - 1) end } end
    if (pagination.page or 1) < (pagination.totalPages or 1) then options[#options + 1] = { title = 'Proxima pagina', icon = 'refresh', onSelect = function() MZOrgStaffOrganizations.OpenLegacyDiagnostics(pagination.page + 1) end } end
    MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
      id = 'mz_org:staff:legacy', title = 'Diagnostico legado', subtitle = tostring(pagination.total or 0) .. ' registros ignorados', menu = MZOrgStaffMenu.RootId(), options = options
    }))
  end)
end
