MZOrgSession = MZOrgSession or {}

local SessionRevision = {}
local CurrentRevision = {}
local SessionScopes = {}

local GLOBAL_PERMISSION_CANDIDATES = {
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
  'staff.roles.manage',
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
  'staff.logs.view'
}

local PLAYER_PERMISSION_CANDIDATES = {
  'staff.players.list',
  'staff.players.goto',
  'staff.players.bring',
  'staff.players.heal',
  'staff.players.revive',
  'staff.players.armor',
  'staff.players.godmode'
}

local function addUnique(values, seen, value)
  if not value or value == '' or seen[value] then return end
  seen[value] = true
  values[#values + 1] = value
end

local function hasValue(values, value)
  for _, item in ipairs(values or {}) do
    if item == value then return true end
  end
  return false
end

local function hasAnyValue(values, candidates)
  for _, candidate in ipairs(candidates or {}) do
    if hasValue(values, candidate) then return true end
  end
  return false
end

local function normalizeOrgType(value)
  return MZOrgMenuProfiles.NormalizeType(value)
end

local function nextRevision(source)
  source = tonumber(source) or 0
  SessionRevision[source] = (SessionRevision[source] or 0) + 1
  local revision = ('s2:%s:%s:%s'):format(source, os.time(), SessionRevision[source])
  CurrentRevision[source] = revision
  return revision
end

function MZOrgSession.IsRevisionCurrent(source, revision)
  source = tonumber(source)
  return source ~= nil and revision ~= nil and CurrentRevision[source] == revision
end

local function collectCapabilities(rawOrg)
  local capabilities, seen = {}, {}
  for _, field in ipairs({ 'capabilities', 'permissions' }) do
    local values = type(rawOrg) == 'table' and rawOrg[field] or nil
    if type(values) == 'table' then
      for key, value in pairs(values) do
        local permission = type(key) == 'number' and value or (value == true and key or nil)
        if type(permission) == 'string' and not MZOrgSecurity.IsStaffPermission(permission) then
          addUnique(capabilities, seen, permission)
        end
      end
    end
  end
  table.sort(capabilities)
  return capabilities
end

local function normalizeGrade(rawOrg)
  local grade = type(rawOrg.grade) == 'table' and rawOrg.grade or {}
  return {
    id = tonumber(grade.id or rawOrg.gradeId or rawOrg.grade_id),
    level = tonumber(grade.level or rawOrg.gradeLevel or rawOrg.grade_level or rawOrg.grade) or 0,
    code = tostring(grade.code or rawOrg.gradeCode or rawOrg.grade_code or ''),
    name = tostring(grade.name or rawOrg.gradeName or rawOrg.grade_name or grade.code or rawOrg.gradeCode or '')
  }
end

local function normalizeOrganization(source, rawOrg)
  if type(rawOrg) ~= 'table' then return nil end
  local code = MZOrgSecurity.NormalizeOrgCode(rawOrg.code or rawOrg.org_code)
  if not code then return nil end

  local status = tostring(rawOrg.status or ''):lower()
  local active = rawOrg.active == true or rawOrg.active == 1 or tostring(rawOrg.active):lower() == 'true'
  if status == '' then status = active and 'active' or 'archived' end
  if status == 'private' or status == 'public' then status = 'active' end
  local capabilities = collectCapabilities(rawOrg)
  local entryAllowed = status == 'active'
    and hasValue(capabilities, 'org.view')
    and MZOrgSecurity.CanOrg(source, code, 'org.view')

  if not entryAllowed then return nil end

  local grade = normalizeGrade(rawOrg)
  local orgType = normalizeOrgType(rawOrg.type or rawOrg.type_code or rawOrg.org_type)
  local config = type(rawOrg.config) == 'table' and rawOrg.config or {}
  local presentation = MZOrgMenuProfiles.Resolve(orgType, config.ui)
  local flags = {
    orgType = orgType,
    hasSalary = rawOrg.hasSalary == true or rawOrg.has_salary == true or rawOrg.has_salary == 1,
    hasSharedAccount = rawOrg.hasSharedAccount == true or rawOrg.has_shared_account == true or rawOrg.has_shared_account == 1,
    hasStorage = rawOrg.hasStorage == true or rawOrg.has_storage == true or rawOrg.has_storage == 1
  }
  local features = MZOrgMenuFeatures.Resolve(
    presentation.defaultFeatures,
    config.features,
    capabilities,
    flags,
    status
  )
  return {
    id = 'org:' .. code,
    kind = 'organization',
    code = code,
    name = tostring(rawOrg.name or rawOrg.org_name or code),
    type = orgType,
    status = status,
    grade = grade,
    membership = {
      citizenId = nil,
      grade = grade,
      isPrimary = rawOrg.isPrimary == true or rawOrg.is_primary == true or rawOrg.is_primary == 1,
      isDuty = rawOrg.duty == true or rawOrg.isDuty == true or rawOrg.is_duty == true,
      joinedAt = rawOrg.joinedAt or rawOrg.joined_at
    },
    capabilities = capabilities,
    features = features,
    presentation = presentation,
    supportsLeadership = rawOrg.supportsLeadership == true
      and MZOrgMenuProfiles.SupportsLeadership(orgType),
    entryAllowed = true,
    readOnly = false,
    flags = flags
  }
end

function MZOrgSession.ResolveOrganization(source, orgCode)
  source = MZOrgSecurity.NormalizeSource(source)
  orgCode = MZOrgSecurity.NormalizeOrgCode(orgCode)
  if not source or not orgCode then return nil, 'invalid_context' end

  local rawOrganizations, contextError = MZOrgSecurity.SafeExport('GetPlayerOrgContext', source)
  if rawOrganizations == nil then
    rawOrganizations, contextError = MZOrgSecurity.SafeExport('GetPlayerOrgs', source)
  end
  if type(rawOrganizations) ~= 'table' then return nil, contextError or 'session_unavailable' end

  for _, rawOrg in ipairs(rawOrganizations) do
    local organization = normalizeOrganization(source, rawOrg)
    if organization and organization.code == orgCode then return organization end
  end
  return nil, 'context_not_found'
end

local function collectGlobalPermissions(source, owner)
  local permissions, grants, seen = {}, {}, {}
  if owner then
    addUnique(permissions, seen, Config.OwnerAce or 'group.mz_owner')
    grants[#grants + 1] = { permission = Config.OwnerAce or 'group.mz_owner', source = 'owner' }
  end

  for _, permission in ipairs(GLOBAL_PERMISSION_CANDIDATES) do
    local allowed, provenance = MZOrgSecurity.GetGlobalPermissionGrant(source, permission)
    if allowed then
      addUnique(permissions, seen, permission)
      grants[#grants + 1] = { permission = permission, source = provenance }
    end
  end
  table.sort(permissions)
  return permissions, grants
end

local function buildStaffContext(owner, permissions)
  local features, seen = {}, {}
  local function feature(name) addUnique(features, seen, name) end
  if owner or hasValue(permissions, 'staff.panel.open') then feature('overview') end
  if owner or hasValue(permissions, 'staff.orgs.view') or hasValue(permissions, 'staff.orgs.manage')
    or hasValue(permissions, 'staff.orgs.create') or hasValue(permissions, 'staff.orgs.edit')
    or hasValue(permissions, 'staff.orgs.archive') or hasValue(permissions, 'staff.orgs.restore')
    or hasValue(permissions, 'staff.orgs.features') or hasValue(permissions, 'staff.orgs.appearance')
    or hasValue(permissions, 'staff.orgs.duty')
    or hasValue(permissions, 'staff.orgs.set_leader') then
    feature('organizations')
  end
  if owner or hasValue(permissions, 'staff.logs.view') then feature('logs') end
  if owner or hasValue(permissions, 'staff.members.invite') or hasValue(permissions, 'staff.members.remove')
    or hasValue(permissions, 'staff.members.promote') or hasValue(permissions, 'staff.members.demote') then
    feature('members')
  end
  if owner or hasAnyValue(permissions, PLAYER_PERMISSION_CANDIDATES) then feature('players') end
  if owner or hasValue(permissions, 'staff.roles.manage') then feature('staff') end
  if #features == 0 then return nil end
  return {
    id = 'staff',
    kind = 'staff',
    entryAllowed = true,
    permissions = permissions,
    capabilities = permissions,
    features = features,
    readOnly = not owner
      and not hasValue(permissions, 'staff.orgs.manage')
      and not hasValue(permissions, 'staff.orgs.create')
      and not hasValue(permissions, 'staff.orgs.edit')
      and not hasValue(permissions, 'staff.orgs.archive')
      and not hasValue(permissions, 'staff.orgs.restore')
      and not hasValue(permissions, 'staff.orgs.features')
      and not hasValue(permissions, 'staff.orgs.appearance')
      and not hasValue(permissions, 'staff.orgs.duty')
      and not hasValue(permissions, 'staff.orgs.set_leader')
      and not hasValue(permissions, 'staff.members.invite')
      and not hasValue(permissions, 'staff.members.remove')
      and not hasValue(permissions, 'staff.members.promote')
      and not hasValue(permissions, 'staff.members.demote')
  }
end

local function normalizeRequest(requested)
  requested = type(requested) == 'table' and requested or {}
  local nested = type(requested.requestedEntry) == 'table' and requested.requestedEntry or {}
  local entry = type(requested.requestedEntry) == 'string' and requested.requestedEntry or nested.id
  entry = tostring(entry or requested.entry or requested.kind or 'hub'):lower()
  if entry ~= 'staff' and entry ~= 'organization' and entry ~= 'hub' then
    if entry == 'legal' or entry == 'gang' or entry == 'illegal' or entry == 'business'
      or entry == 'government' or entry == 'vip' or entry == 'event' then
      requested.requestedType = entry
      entry = 'organization'
    else
      entry = 'hub'
    end
  end
  local requestedType = requested.requestedType or nested.requestedType or requested.mode
  return {
    id = entry,
    command = tostring(requested.command or nested.command or '') ~= '' and tostring(requested.command or nested.command) or nil,
    requestedOrgCode = MZOrgSecurity.NormalizeOrgCode(requested.requestedOrgCode or nested.requestedOrgCode),
    requestedType = requestedType and normalizeOrgType(requestedType) or nil
  }
end

function MZOrgSession.InvalidateOrganization(orgCode, action, actorSource)
  orgCode = MZOrgSecurity.NormalizeOrgCode(orgCode)
  if not orgCode then return end
  actorSource = tonumber(actorSource)
  for sourceId, scope in pairs(SessionScopes) do
    if scope.staff == true or (type(scope.organizations) == 'table' and scope.organizations[orgCode] == true) then
      CurrentRevision[sourceId] = nil
      SessionScopes[sourceId] = nil
      if sourceId ~= actorSource then
        TriggerClientEvent('mz_org:client:organizationInvalidated', sourceId, {
          orgCode = orgCode,
          action = action or 'org.changed'
        })
      end
    end
  end
end

AddEventHandler('mz_core:internal:organizationChanged', function(change)
  if type(change) ~= 'table' then return end
  MZOrgSession.InvalidateOrganization(change.orgCode, change.action, change.actorSource)
end)

local function resolveEntry(requested, organizations, staff)
  if requested.id == 'hub' then
    for _, organization in ipairs(organizations) do
      if organization.membership and organization.membership.isPrimary then
        return true, nil, organization.id
      end
    end
    return true, nil, organizations[1] and organizations[1].id or nil
  end
  if requested.id == 'staff' then
    if staff and staff.entryAllowed then return true, nil, 'staff' end
    return false, 'entry_not_allowed', nil
  end

  if requested.requestedOrgCode then
    for _, organization in ipairs(organizations) do
      if organization.code == requested.requestedOrgCode and organization.entryAllowed then
        return true, nil, organization.id
      end
    end
    return false, 'context_not_found', nil
  end

  for _, organization in ipairs(organizations) do
    if not requested.requestedType or organization.type == requested.requestedType then
      return true, nil, organization.id
    end
  end
  return false, 'entry_not_allowed', nil
end

local function buildLegacyModules(owner, organizations, staff)
  local modules, seen = {}, {}
  addUnique(modules, seen, 'dashboard')
  for _, organization in ipairs(organizations) do
    local legacyType = organization.type == 'job' and 'legal' or organization.type
    addUnique(modules, seen, legacyType)
    if hasValue(organization.features, 'recruitment') then addUnique(modules, seen, 'recruitment') end
    if hasValue(organization.features, 'goals') then addUnique(modules, seen, 'goals') end
    if hasValue(organization.features, 'logs') and hasValue(organization.capabilities, 'logs.view') then
      addUnique(modules, seen, 'logs')
    end
  end
  if staff then
    addUnique(modules, seen, 'staff')
    if hasValue(staff.features, 'organizations') then addUnique(modules, seen, 'orgs') end
    if hasValue(staff.features, 'logs') then addUnique(modules, seen, 'logs') end
  end
  if owner then addUnique(modules, seen, 'settings') end
  return modules
end

local function displayName(source, player)
  local name = GetPlayerName(source)
  if name and name ~= '' then return name end
  local charinfo = type(player) == 'table' and player.charinfo or nil
  if type(charinfo) == 'table' then
    local full = (tostring(charinfo.firstname or '') .. ' ' .. tostring(charinfo.lastname or ''))
      :gsub('^%s+', ''):gsub('%s+$', '')
    if full ~= '' then return full end
  end
  return 'ID ' .. tostring(source)
end

function MZOrgSession.Build(source, requestedContext)
  source = MZOrgSecurity.NormalizeSource(source)
  if not source then return nil, 'invalid_source' end
  local owner = MZOrgSecurity.IsOwner(source)
  local player = MZOrgSecurity.SafeExport('GetPlayer', source)
  if type(player) ~= 'table' or not player.citizenid then return nil, 'session_unavailable' end
  local rawOrganizations = MZOrgSecurity.SafeExport('GetPlayerOrgContext', source)
  if rawOrganizations == nil then rawOrganizations = MZOrgSecurity.SafeExport('GetPlayerOrgs', source) end
  if type(rawOrganizations) ~= 'table' then return nil, 'session_unavailable' end

  local organizations = {}
  for _, rawOrg in ipairs(rawOrganizations) do
    local organization = normalizeOrganization(source, rawOrg)
    if organization then
      organization.membership.citizenId = player and player.citizenid and tostring(player.citizenid) or nil
      organizations[#organizations + 1] = organization
    end
  end

  local permissions, grants = collectGlobalPermissions(source, owner)
  local staff = buildStaffContext(owner, permissions)
  local requested = normalizeRequest(requestedContext)
  local entryAllowed, denialReason, defaultContextId = resolveEntry(requested, organizations, staff)
  local revision = nextRevision(source)
  local modules = buildLegacyModules(owner, organizations, staff)

  local user = {
    source = source,
    serverId = source,
    name = displayName(source, player),
    citizenid = player and player.citizenid and tostring(player.citizenid) or nil,
    citizenId = player and player.citizenid and tostring(player.citizenid) or nil,
    isOwner = owner,
    globalPermissions = permissions
  }

  local legacyOrgs = {}
  for _, organization in ipairs(organizations) do
    legacyOrgs[#legacyOrgs + 1] = {
      code = organization.code,
      name = organization.name,
      type = organization.type == 'job' and 'legal' or organization.type,
      status = organization.status,
      grade = organization.grade.level,
      gradeCode = organization.grade.code,
      gradeName = organization.grade.name,
      capabilities = organization.capabilities,
      features = organization.features,
      entryAllowed = organization.entryAllowed,
      readOnly = organization.readOnly
    }
  end

  local scopeOrganizations = {}
  for _, organization in ipairs(organizations) do scopeOrganizations[organization.code] = true end
  SessionScopes[source] = { staff = staff ~= nil, organizations = scopeOrganizations }

  return {
    version = 2,
    contractVersion = 2,
    revision = revision,
    sessionId = revision,
    generatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    user = user,
    requestedEntry = requested,
    entryAllowed = entryAllowed,
    denialReason = denialReason,
    defaultContextId = defaultContextId,
    entrypoints = {
      hub = true,
      staffWorkspace = staff ~= nil,
      organizationWorkspaces = (function()
        local codes = {}
        for _, organization in ipairs(organizations) do codes[#codes + 1] = organization.code end
        return codes
      end)()
    },
    global = {
      permissions = permissions,
      permissionGrants = grants,
      features = {}
    },
    organizations = organizations,
    contexts = organizations,
    staff = staff,
    staffContext = staff,
    compatibility = { modules = modules },
    orgs = legacyOrgs,
    modules = modules
  }
end

function MZOrgSession.ResolvePanelEntry(source, requestedContext)
  local session, err = MZOrgSession.Build(source, requestedContext)
  if not session then return false, err or 'session_unavailable' end
  return session.entryAllowed == true, {
    entryAllowed = session.entryAllowed,
    denialReason = session.denialReason,
    defaultContextId = session.defaultContextId,
    revision = session.revision,
    session = session
  }
end

RegisterNetEvent('mz_org:server:requestSession', function(requestId, payload)
  local sourceId = source
  if type(requestId) ~= 'number' then
    payload = type(requestId) == 'table' and requestId or payload
    requestId = nil
  end
  local session, err = MZOrgSession.Build(sourceId, payload)
  if not session then
    if requestId then
      TriggerClientEvent('mz_org:client:serverResponse', sourceId, requestId, {
        ok = false,
        error = err or 'Sessao indisponivel.'
      })
    end
    return
  end
  if requestId then
    TriggerClientEvent('mz_org:client:serverResponse', sourceId, requestId, { ok = true, data = session })
  end
  TriggerClientEvent('mz_org:client:receiveSession', sourceId, session)
end)

AddEventHandler('playerDropped', function()
  SessionRevision[source] = nil
  CurrentRevision[source] = nil
  SessionScopes[source] = nil
end)
