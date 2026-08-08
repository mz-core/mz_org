MZOrgStaffMenuServer = MZOrgStaffMenuServer or {}

local STAFF_PERMISSION_CANDIDATES = {
  'staff.panel.open',
  'staff.orgs.view',
  'staff.orgs.manage',
  'staff.orgs.create',
  'staff.orgs.edit',
  'staff.orgs.archive',
  'staff.orgs.restore',
  'staff.orgs.features',
  'staff.orgs.appearance',
  'staff.orgs.duty',
  'staff.orgs.set_leader',
  'staff.logs.view',
  'staff.members.invite',
  'staff.members.remove',
  'staff.members.promote',
  'staff.members.demote',
  'staff.coords.copy',
  'staff.noclip',
  'staff.teleport',
  'staff.players.list',
  'staff.players.goto',
  'staff.players.bring',
  'staff.players.heal',
  'staff.players.revive',
  'staff.players.armor',
  'staff.players.godmode',
  'staff.roles.manage'
}

local ORG_TYPES = {
  job = true,
  gang = true,
  business = true,
  government = true,
  vip = true,
  event = true
}

local function respond(sourceId, requestId, ok, dataOrError)
  sourceId = tonumber(sourceId)
  if not sourceId or sourceId <= 0 then
    print(('[mz_org][staff] Resposta descartada: source invalido (requestId=%s).'):format(tostring(requestId)))
    return false
  end

  TriggerClientEvent('mz_org:client:serverResponse', sourceId, requestId, ok and {
    ok = true,
    data = dataOrError
  } or {
    ok = false,
    error = dataOrError or 'Leitura Staff negada.'
  })
  return true
end

local function respondRead(sourceId, requestId, payload, data)
  local context = type(payload) == 'table' and payload._context or nil
  if type(context) ~= 'table' or not MZOrgSession.IsRevisionCurrent(sourceId, context.sessionRevision) then
    respond(sourceId, requestId, false, 'Sessao Staff alterada durante a leitura.')
    return
  end
  respond(sourceId, requestId, true, data)
end

local function trim(value, maxLength)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' then return nil end
  if maxLength and #value > maxLength then value = value:sub(1, maxLength) end
  return value
end

local function bool(value)
  return value == true or value == 1 or tostring(value):lower() == 'true'
end

local function dutyPointDto(value, orgType)
  if not MZOrgMenuMutations.SupportsDutyType(orgType) or type(value) ~= 'table'
    or value.enabled ~= true or type(value.coords) ~= 'table' then
    return nil
  end
  local x, y, z = tonumber(value.coords.x), tonumber(value.coords.y), tonumber(value.coords.z)
  local radius, drawDistance = tonumber(value.radius), tonumber(value.drawDistance)
  local label = type(value.label) == 'string' and value.label or nil
  local function finite(number)
    return number ~= nil and number == number and number ~= math.huge and number ~= -math.huge
  end
  if not finite(x) or not finite(y) or not finite(z)
    or not finite(radius) or radius < 1.0 or radius > 5.0
    or not finite(drawDistance) or drawDistance < 5.0 or drawDistance > 50.0
    or drawDistance < radius or not label or #label < 2 or #label > 64 then
    return nil
  end
  return {
    enabled = true,
    coords = { x = x, y = y, z = z },
    radius = radius,
    drawDistance = drawDistance,
    label = label
  }
end

local function hasGlobal(sourceId, permission)
  return MZOrgSecurity.GetGlobalPermissionGrant(sourceId, permission) == true
end

local function architectureEnabled()
  local architecture = type(Config.MenuArchitecture) == 'table' and Config.MenuArchitecture or {}
  local interface = type(Config.Interface) == 'table' and Config.Interface or {}
  return architecture.enabled == true and architecture.staffMenuEnabled == true and interface.staffMenu == true
end

local function staffModules(sourceId)
  local owner = MZOrgSecurity.IsOwner(sourceId)
  local permissions, modules = {}, { overview = false, create = false, organizations = false, logs = false, audit = false, legacy = false }
  for _, permission in ipairs(STAFF_PERMISSION_CANDIDATES) do
    if hasGlobal(sourceId, permission) then permissions[#permissions + 1] = permission end
  end
  table.sort(permissions)

  modules.overview = owner or #permissions > 0
  modules.create = owner or hasGlobal(sourceId, 'staff.orgs.create')
  modules.organizations = owner or hasGlobal(sourceId, 'staff.orgs.view')
  modules.logs = owner or hasGlobal(sourceId, 'staff.logs.view')
  modules.audit = modules.logs
  modules.legacy = modules.organizations
  local actions = {
    create = modules.create,
    edit = owner or hasGlobal(sourceId, 'staff.orgs.edit'),
    archive = owner or hasGlobal(sourceId, 'staff.orgs.archive'),
    restore = owner or hasGlobal(sourceId, 'staff.orgs.restore'),
    features = owner or hasGlobal(sourceId, 'staff.orgs.features'),
    appearance = owner or hasGlobal(sourceId, 'staff.orgs.appearance'),
    dutyPoint = owner or hasGlobal(sourceId, 'staff.orgs.duty'),
    setLeader = owner or hasGlobal(sourceId, 'staff.orgs.set_leader'),
    membersInvite = owner or hasGlobal(sourceId, 'staff.members.invite'),
    membersRemove = owner or hasGlobal(sourceId, 'staff.members.remove'),
    membersPromote = owner or hasGlobal(sourceId, 'staff.members.promote'),
    membersDemote = owner or hasGlobal(sourceId, 'staff.members.demote'),
    grades = owner or hasGlobal(sourceId, 'staff.orgs.manage')
  }
  return owner, permissions, modules, actions
end

local function moduleList(modules)
  local list = {}
  for _, name in ipairs({ 'overview', 'create', 'organizations', 'logs', 'audit', 'legacy' }) do
    if modules[name] then list[#list + 1] = name end
  end
  return list
end

local function actionList(actions)
  local list = {}
  for _, name in ipairs({
    'create', 'edit', 'archive', 'restore', 'features', 'appearance', 'setLeader',
    'dutyPoint', 'membersInvite', 'membersRemove', 'membersPromote', 'membersDemote', 'grades'
  }) do
    if actions[name] then list[#list + 1] = name end
  end
  return list
end

local function organizationActionList(actions, active, supportsLeadership, supportsDuty)
  local list = {}
  if active then
    for _, name in ipairs({
      'edit', 'features', 'appearance', 'setLeader', 'membersInvite', 'membersRemove',
      'membersPromote', 'membersDemote', 'grades', 'dutyPoint', 'archive'
    }) do
      if actions[name]
        and (name ~= 'setLeader' or supportsLeadership == true)
        and (name ~= 'dutyPoint' or supportsDuty == true) then
        list[#list + 1] = name
      end
    end
  elseif actions.restore then
    list[1] = 'restore'
  end
  return list
end

local function requireModule(sourceId, payload, moduleName, orgCode)
  if not architectureEnabled() then return false, 'Staff Menu desativado.' end
  local _, _, modules = staffModules(sourceId)
  if not modules[moduleName] then return false, 'Sem permissao global para este modulo Staff.' end

  local context = type(payload) == 'table' and payload._context or nil
  if type(context) ~= 'table' then return false, 'Contexto Staff ausente.' end
  if context.module ~= moduleName then return false, 'Modulo Staff divergente.' end
  if orgCode and context.orgCode ~= orgCode then return false, 'Organizacao Staff divergente.' end
  local expectedKey = orgCode and ('staff:' .. moduleName .. ':org:' .. orgCode) or ('staff:' .. moduleName)
  if context.contextKey ~= expectedKey then return false, 'Chave de contexto Staff divergente.' end
  if context.sessionId ~= context.sessionRevision then return false, 'Identificador de sessao Staff divergente.' end
  if not MZOrgSession.IsRevisionCurrent(sourceId, context.sessionRevision) then
    return false, 'Sessao Staff obsoleta.'
  end
  return true, modules
end

function MZOrgStaffMenuServer.Respond(sourceId, requestId, ok, dataOrError)
  respond(sourceId, requestId, ok, dataOrError)
end

function MZOrgStaffMenuServer.AuthorizeMutation(sourceId, requestId, payload, moduleName, permission, orgCode)
  if type(requestId) ~= 'number' or type(payload) ~= 'table' or tonumber(payload.requestId) ~= requestId then
    return false, 'Envelope de mutacao invalido.'
  end
  local context = payload._context
  if type(context) ~= 'table' or tonumber(context.requestId) ~= requestId then
    return false, 'RequestId contextual divergente.'
  end
  local allowed, modulesOrError = requireModule(sourceId, payload, moduleName, orgCode)
  if not allowed then return false, modulesOrError end
  if not MZOrgSecurity.IsOwner(sourceId) and not hasGlobal(sourceId, permission) then
    return false, 'Sem permissao global especifica para esta mutacao.'
  end
  return true
end

function MZOrgStaffMenuServer.MutationContext(requestId, payload)
  local context = type(payload) == 'table' and payload._context or {}
  return {
    requestId = requestId,
    sessionId = context.sessionId,
    sessionRevision = context.sessionRevision,
    contextKey = context.contextKey,
    module = context.module,
    orgCode = context.orgCode
  }
end

local function listOfficialOrganizations()
  local rows, err = MZOrgSecurity.SafeExport('ListOrgs')
  if type(rows) ~= 'table' then return nil, err or 'org_read_unavailable' end
  local result = {}
  for _, org in ipairs(rows) do
    local orgType = MZOrgMenuProfiles.NormalizeType(org.type or org.typeCode)
    if ORG_TYPES[orgType] then result[#result + 1] = org end
  end
  return result
end

local function countOrganizations(rows)
  local active, archived = 0, 0
  for _, org in ipairs(rows or {}) do
    if bool(org.active) then active = active + 1 else archived = archived + 1 end
  end
  return active, archived
end

function MZOrgStaffMenuServer.ResolveStaffMenuEntry(sourceId)
  sourceId = MZOrgSecurity.NormalizeSource(sourceId)
  if not sourceId then return false, 'invalid_source' end
  if not architectureEnabled() then return false, 'staff_menu_disabled' end

  local owner, permissions, modules, actions = staffModules(sourceId)
  if not modules.overview then return false, 'entry_not_allowed' end

  local session, sessionError = MZOrgSession.Build(sourceId, {
    requestedEntry = 'staff',
    command = (Config.MenuArchitecture or {}).staffCommand or 'stafforg'
  })
  if not session then return false, sessionError or 'session_unavailable' end

  local activeCount, archivedCount
  if modules.organizations then
    local organizations, listError = listOfficialOrganizations()
    if not organizations then return false, listError end
    activeCount, archivedCount = countOrganizations(organizations)
  end

  local operational = actions.create or (modules.organizations and (
    actions.edit or actions.archive or actions.restore or actions.features or actions.appearance
    or actions.dutyPoint
    or actions.setLeader or actions.membersInvite or actions.membersRemove
    or actions.membersPromote or actions.membersDemote or actions.grades
  ))
  return true, {
    session = { sessionId = session.sessionId, revision = session.revision },
    contextKey = 'staff:root',
    user = {
      name = session.user and session.user.name or ('ID ' .. sourceId),
      serverId = sourceId,
      isOwner = owner,
      identity = owner and 'Owner' or 'Staff'
    },
    permissions = permissions,
    modules = moduleList(modules),
    actions = actionList(actions),
    counts = {
      activeOrganizations = activeCount,
      archivedOrganizations = archivedCount,
      restricted = not modules.organizations
    },
    readOnly = not operational,
    presentation = MZOrgMenuProfiles.Resolve('staff', nil)
  }
end

exports('ResolveStaffMenuEntry', function(sourceId)
  return MZOrgStaffMenuServer.ResolveStaffMenuEntry(sourceId)
end)

RegisterNetEvent('mz_org:server:resolveStaffMenuEntry', function(requestId)
  local sourceId = source
  local allowed, result = MZOrgStaffMenuServer.ResolveStaffMenuEntry(sourceId)
  respond(sourceId, requestId, allowed, result)
end)

RegisterNetEvent('mz_org:server:staffListOrganizations', function(requestId, payload)
  local sourceId = source
  local allowed, modulesOrError = requireModule(sourceId, payload, 'organizations')
  if not allowed then respond(sourceId, requestId, false, modulesOrError) return end

  local rows, listError = listOfficialOrganizations()
  if not rows then respond(sourceId, requestId, false, listError) return end
  payload = type(payload) == 'table' and payload or {}
  local pageSize = math.max(1, math.min(tonumber(payload.pageSize) or (Config.MenuArchitecture or {}).pageSize or 20, 25))
  local page = math.max(1, math.floor(tonumber(payload.page) or 1))
  local status = trim(payload.status, 16)
  local orgType = trim(payload.type, 24)
  if orgType then orgType = MZOrgMenuProfiles.NormalizeType(orgType) end
  local query = trim(payload.query, 96)
  local queryLower = query and query:lower() or nil
  local queryId = query and tonumber(query) or nil
  local filtered = {}

  for _, org in ipairs(rows) do
    local active = bool(org.active)
    local currentStatus = active and 'active' or 'archived'
    local currentType = MZOrgMenuProfiles.NormalizeType(org.type or org.typeCode)
    local statusMatch = not status or status == 'all' or status == currentStatus
    local typeMatch = not orgType or currentType == orgType
    local queryMatch = not queryLower
      or tostring(org.code or ''):lower():find(queryLower, 1, true) ~= nil
      or tostring(org.name or ''):lower():find(queryLower, 1, true) ~= nil
      or (queryId and tonumber(org.id) == queryId)
    if statusMatch and typeMatch and queryMatch then
      local presentation = MZOrgMenuProfiles.Resolve(currentType, type(org.config) == 'table' and org.config.ui or nil)
      filtered[#filtered + 1] = {
        id = tonumber(org.id) or org.id,
        code = org.code,
        name = org.name,
        type = currentType,
        status = currentStatus,
        badge = active and 'Ativa' or 'Arquivada',
        presentation = presentation,
        leader = nil,
        memberCount = nil,
        supportsLeadership = MZOrgMenuProfiles.SupportsLeadership(currentType),
        leadershipAvailable = false,
        memberCountAvailable = false
      }
    end
  end

  local total = #filtered
  local totalPages = math.max(1, math.ceil(total / pageSize))
  if page > totalPages then page = totalPages end
  local items, first = {}, ((page - 1) * pageSize) + 1
  for index = first, math.min(total, first + pageSize - 1) do items[#items + 1] = filtered[index] end
  respondRead(sourceId, requestId, payload, {
    items = items,
    pagination = { page = page, pageSize = pageSize, total = total, totalPages = totalPages },
    filters = { status = status or 'all', type = orgType, query = query }
  })
end)

RegisterNetEvent('mz_org:server:staffGetOrganization', function(requestId, payload)
  local sourceId = source
  local orgCode = MZOrgSecurity.NormalizeOrgCode(type(payload) == 'table' and payload.orgCode or nil)
  if not orgCode then respond(sourceId, requestId, false, 'Organizacao invalida.') return end
  local allowed, modulesOrError = requireModule(sourceId, payload, 'organizations', orgCode)
  if not allowed then respond(sourceId, requestId, false, modulesOrError) return end

  local inspection, inspectionError = MZOrgSecurity.SafeExport('GetStaffOrgInspection', sourceId, orgCode)
  if type(inspection) ~= 'table' then respond(sourceId, requestId, false, inspectionError or 'Inspecao indisponivel.') return end
  local org = inspection.organization or {}
  local config = type(org.config) == 'table' and org.config or {}
  local organizationDto = {
    id = org.id,
    code = org.code,
    name = org.name,
    type = MZOrgMenuProfiles.NormalizeType(org.type),
    typeName = org.typeName,
    active = org.active == true,
    status = org.status,
    isPublic = org.isPublic == true,
    requiresWhitelist = org.requiresWhitelist == true,
    hasSalary = org.hasSalary == true,
    hasSharedAccount = org.hasSharedAccount == true,
    hasStorage = org.hasStorage == true,
    supportsLeadership = org.supportsLeadership == true,
    createdAt = org.createdAt,
    updatedAt = org.updatedAt,
    organizationRevision = tonumber(org.organizationRevision) or 1,
    public = {
      displayName = type(config.public) == 'table' and config.public.displayName or nil,
      description = type(config.public) == 'table' and config.public.description or nil,
      metadata = type(config.public) == 'table' and type(config.public.metadata) == 'table' and config.public.metadata or {}
    },
    featureOverrides = type(config.features) == 'table' and config.features or {},
    appearanceOverrides = type(config.ui) == 'table' and config.ui or {},
    dutyPoint = dutyPointDto(config.dutyPoint, org.type),
    supportsDuty = MZOrgMenuProfiles.NormalizeType(org.type) ~= 'vip'
  }
  local presentation = MZOrgMenuProfiles.Resolve(org.type, config.ui)
  local flags = {
    orgType = MZOrgMenuProfiles.NormalizeType(org.type),
    hasSalary = org.hasSalary == true,
    hasSharedAccount = org.hasSharedAccount == true,
    hasStorage = org.hasStorage == true
  }
  local featureRows = MZOrgMenuFeatures.ExplainConfiguration(
    presentation.defaultFeatures,
    config.features,
    flags,
    org.status
  )
  local members = {}
  for _, member in ipairs(inspection.members or {}) do
    members[#members + 1] = {
      citizenid = member.citizenid,
      name = member.name,
      grade = member.grade,
      gradeLevel = member.gradeLevel,
      gradeCode = member.gradeCode,
      gradeName = member.gradeName,
      isLeader = org.supportsLeadership == true and member.isLeader == true,
      isDuty = member.isDuty == true,
      joinedAt = member.joinedAt,
      status = member.status
    }
  end
  local grades = {}
  for _, grade in ipairs(inspection.grades or {}) do
    grades[#grades + 1] = {
      id = grade.id,
      code = grade.code,
      name = grade.name,
      level = grade.level,
      active = grade.active == true,
      salary = tonumber(grade.salary) or 0,
      priority = tonumber(grade.priority) or tonumber(grade.level) or 0,
      inheritsGradeId = grade.inheritsGradeId,
      inheritsLevel = grade.inheritsLevel,
      inheritsCode = grade.inheritsCode,
      memberCount = grade.memberCount,
      capabilities = grade.capabilities or {},
      directCapabilities = grade.directCapabilities or {}
    }
  end
  local leader = nil
  if org.supportsLeadership == true and type(inspection.leader) == 'table' then
    leader = {
      citizenid = inspection.leader.citizenid,
      name = inspection.leader.name,
      gradeLevel = inspection.leader.gradeLevel,
      gradeCode = inspection.leader.gradeCode,
      gradeName = inspection.leader.gradeName,
      status = inspection.leader.status
    }
  end
  local _, _, currentModules, currentActions = staffModules(sourceId)
  local availableActions = organizationActionList(
    currentActions,
    org.active == true,
    org.supportsLeadership == true,
    organizationDto.supportsDuty == true
  )
  respondRead(sourceId, requestId, payload, {
    organization = organizationDto,
    leader = leader,
    members = members,
    grades = grades,
    baseCapabilities = inspection.baseCapabilities or {},
    legacyStaffCapabilities = inspection.legacyStaffCapabilities or {},
    features = featureRows,
    appearance = presentation,
    allowedModules = moduleList(currentModules),
    allowedActions = availableActions,
    readOnly = #availableActions == 0
  })
end)

local function normalizeLogFilters(payload, auditOnly)
  payload = type(payload) == 'table' and payload or {}
  return {
    category = trim(payload.category or payload.scope, 32),
    action = trim(payload.action, 96),
    actor = trim(payload.actor, 96),
    auditId = trim(payload.auditId, 96),
    dateFrom = trim(payload.dateFrom, 32),
    dateTo = trim(payload.dateTo, 32),
    auditOnly = auditOnly == true,
    limit = math.max(1, math.min(tonumber(payload.limit) or 25, 50)),
    offset = math.max(0, math.min(tonumber(payload.offset) or 0, 10000))
  }
end

local function listStaffLogs(sourceId, requestId, payload, scopeKind, auditOnly)
  local moduleName = auditOnly and 'audit' or 'logs'
  local orgCode = scopeKind == 'org' and MZOrgSecurity.NormalizeOrgCode(type(payload) == 'table' and payload.orgCode or nil) or nil
  if scopeKind == 'org' and not orgCode then respond(sourceId, requestId, false, 'Organizacao invalida.') return end
  local allowed, modulesOrError = requireModule(sourceId, payload, moduleName, orgCode)
  if not allowed then respond(sourceId, requestId, false, modulesOrError) return end
  if scopeKind == 'org' then
    local org = MZOrgSecurity.GetOrg(orgCode)
    if not org then respond(sourceId, requestId, false, 'Organizacao inexistente.') return end
  end

  local filters = normalizeLogFilters(payload, auditOnly)
  local rows, logsError
  if scopeKind == 'org' then
    rows, logsError = MZOrgSecurity.SafeExport('ListOrgLogsSecure', sourceId, orgCode, filters)
  else
    rows, logsError = MZOrgSecurity.SafeExport('ListGlobalLogsSecure', sourceId, filters)
  end
  if type(rows) ~= 'table' then respond(sourceId, requestId, false, logsError or 'Logs indisponiveis.') return end
  respondRead(sourceId, requestId, payload, {
    items = rows,
    scope = scopeKind,
    orgCode = orgCode,
    auditOnly = auditOnly == true,
    pagination = { limit = filters.limit, offset = filters.offset, returned = #rows }
  })
end

RegisterNetEvent('mz_org:server:staffListGlobalLogs', function(requestId, payload)
  local sourceId = source
  listStaffLogs(sourceId, requestId, payload, 'global', false)
end)

RegisterNetEvent('mz_org:server:staffListOrgLogs', function(requestId, payload)
  local sourceId = source
  listStaffLogs(sourceId, requestId, payload, 'org', false)
end)

RegisterNetEvent('mz_org:server:staffListGlobalAudit', function(requestId, payload)
  local sourceId = source
  listStaffLogs(sourceId, requestId, payload, 'global', true)
end)

RegisterNetEvent('mz_org:server:staffListOrgAudit', function(requestId, payload)
  local sourceId = source
  listStaffLogs(sourceId, requestId, payload, 'org', true)
end)

RegisterNetEvent('mz_org:server:staffListLegacyDiagnostics', function(requestId, payload)
  local sourceId = source
  local allowed, modulesOrError = requireModule(sourceId, payload, 'legacy')
  if not allowed then respond(sourceId, requestId, false, modulesOrError) return end
  local rows, diagnosticError = MZOrgSecurity.SafeExport('ListLegacyStaffOrgPermissions', sourceId)
  if type(rows) ~= 'table' then respond(sourceId, requestId, false, diagnosticError or 'Diagnostico indisponivel.') return end

  local pageSize = math.max(1, math.min(tonumber(payload.pageSize) or 20, 25))
  local page = math.max(1, math.floor(tonumber(payload.page) or 1))
  local total = #rows
  local totalPages = math.max(1, math.ceil(total / pageSize))
  if page > totalPages then page = totalPages end
  local items, first = {}, ((page - 1) * pageSize) + 1
  for index = first, math.min(total, first + pageSize - 1) do items[#items + 1] = rows[index] end
  respondRead(sourceId, requestId, payload, {
    items = items,
    pagination = { page = page, pageSize = pageSize, total = total, totalPages = totalPages }
  })
end)
