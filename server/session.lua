local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org:session]', ...)
end

local function isAceAllowed(src, ace)
  local sourceId = tonumber(src)
  if not sourceId or sourceId <= 0 then return false end

  ace = tostring(ace or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if ace == '' then return false end

  local allowed = IsPlayerAceAllowed(sourceId, ace)
  local normalized = tostring(allowed):lower()
  return allowed == true or allowed == 1 or normalized == '1' or normalized == 'true'
end

local function isOwner(src)
  return isAceAllowed(src, Config.OwnerAce)
end

local function safeExport(resourceName, exportName, ...)
  if GetResourceState(resourceName) ~= 'started' then
    debugPrint(('export skipped: resource %s is not started'):format(resourceName))
    return nil
  end

  local args = { ... }
  local ok, result, extra = pcall(function()
    local resourceExports = exports[resourceName]
    return resourceExports[exportName](resourceExports, table.unpack(args))
  end)

  if not ok then
    debugPrint(('export failed: %s:%s - %s'):format(resourceName, exportName, tostring(result)))
    return nil
  end

  return result, extra
end

local function tableHasValue(values, value)
  for _, item in ipairs(values or {}) do
    if item == value then return true end
  end

  return false
end

local function addUnique(values, value)
  if not value or value == '' then return end
  if tableHasValue(values, value) then return end
  values[#values + 1] = value
end

local function collectCapabilities(rawOrg)
  local capabilities = {}

  -- Capabilities visuais vêm do contexto retornado pelo core. Ações críticas futuras
  -- ainda devem chamar CanOrg no server antes de executar qualquer mutação.
  local rawCapabilities = rawOrg and rawOrg.capabilities or nil
  if type(rawCapabilities) == 'table' then
    for key, value in pairs(rawCapabilities) do
      if type(key) == 'number' and type(value) == 'string' then
        addUnique(capabilities, value)
      elseif value == true and type(key) == 'string' then
        addUnique(capabilities, key)
      end
    end
  end

  local rawPermissions = rawOrg and rawOrg.permissions or nil
  if type(rawPermissions) == 'table' then
    for key, value in pairs(rawPermissions) do
      if type(key) == 'number' and type(value) == 'string' then
        addUnique(capabilities, value)
      elseif value == true and type(key) == 'string' then
        addUnique(capabilities, key)
      end
    end
  end

  addUnique(capabilities, 'org.view')

  return capabilities
end

local function normalizeOrgType(rawType)
  rawType = tostring(rawType or '')

  if rawType == 'job' then return 'legal' end
  if rawType == 'gang' then return 'gang' end
  if rawType == 'staff' then return 'staff' end
  if rawType == 'business' then return 'business' end
  if rawType == 'government' then return 'government' end
  if rawType == 'vip' then return 'vip' end
  if rawType == 'event' then return 'event' end

  return 'legal'
end

local function normalizeOrgContext(rawOrg)
  if type(rawOrg) ~= 'table' then return nil end

  local grade = rawOrg.grade
  local gradeLevel = 0
  local gradeCode = ''

  if type(grade) == 'table' then
    gradeLevel = tonumber(grade.level or grade.grade or grade.id) or 0
    gradeCode = tostring(grade.code or '')
  else
    gradeLevel = tonumber(rawOrg.grade or rawOrg.grade_level) or 0
    gradeCode = tostring(rawOrg.gradeCode or rawOrg.grade_code or '')
  end

  local code = rawOrg.code or rawOrg.org_code
  if not code or code == '' then return nil end

  return {
    code = tostring(code),
    name = tostring(rawOrg.name or rawOrg.org_name or code),
    type = normalizeOrgType(rawOrg.type or rawOrg.type_code or rawOrg.org_type),
    grade = gradeLevel,
    gradeCode = gradeCode,
    capabilities = collectCapabilities(rawOrg)
  }
end

local function hasCapability(orgs, capability)
  for _, org in ipairs(orgs or {}) do
    if tableHasValue(org.capabilities, capability) then
      return true
    end
  end

  return false
end

local function hasStaffOrg(orgs)
  for _, org in ipairs(orgs or {}) do
    if org.type == 'staff' then
      return true
    end
  end

  return false
end

local function buildGlobalPermissions(src, owner, orgs)
  local permissions = {}

  if owner then
    addUnique(permissions, Config.OwnerAce)
    addUnique(permissions, 'staff.orgs.manage')
    addUnique(permissions, 'staff.players.manage')
    addUnique(permissions, 'staff.logs.view')
    return permissions
  end

  local candidates = {
    'staff.panel.open',
    'staff.orgs.manage',
    'staff.players.manage',
    'staff.logs.view'
  }

  for _, permission in ipairs(candidates) do
    local allowedByAce = isAceAllowed(src, permission)
    local coreGlobalPermission = safeExport('mz_core', 'HasGlobalPermission', src, permission)
    local allowedByCore = coreGlobalPermission == true

    if coreGlobalPermission == nil then
      allowedByCore = safeExport('mz_core', 'HasPermission', src, permission) == true
    end

    if allowedByAce or allowedByCore then
      addUnique(permissions, permission)
    end
  end

  if hasStaffOrg(orgs) then
    addUnique(permissions, 'staff.panel.open')
  end

  return permissions
end

local function hasGlobalPermission(permissions, permission)
  return tableHasValue(permissions, permission)
end

local function hasOrgType(orgs, orgType)
  for _, org in ipairs(orgs or {}) do
    if org.type == orgType then
      return true
    end
  end

  return false
end

local function addOrgTypeModules(modules, orgs)
  if hasOrgType(orgs, 'legal') then addUnique(modules, 'legal') end
  if hasOrgType(orgs, 'gang') then addUnique(modules, 'gang') end
  if hasOrgType(orgs, 'vip') then addUnique(modules, 'vip') end
  if hasOrgType(orgs, 'business') then addUnique(modules, 'business') end
  if hasOrgType(orgs, 'government') then addUnique(modules, 'government') end
  if hasOrgType(orgs, 'event') then addUnique(modules, 'event') end
end

local function buildModules(owner, orgs, globalPermissions)
  local modules = {}
  local hasOrgs = #orgs > 0
  local staffAllowed = owner
    or hasGlobalPermission(globalPermissions, 'staff.panel.open')
    or hasGlobalPermission(globalPermissions, 'staff.orgs.manage')
    or hasGlobalPermission(globalPermissions, 'staff.logs.view')

  addUnique(modules, 'dashboard')

  if owner then
    addUnique(modules, 'legal')
    addUnique(modules, 'gang')
    addUnique(modules, 'staff')
    addUnique(modules, 'vip')
    addUnique(modules, 'business')
    addUnique(modules, 'government')
    addUnique(modules, 'event')
    addUnique(modules, 'orgs')
    addUnique(modules, 'recruitment')
    addUnique(modules, 'goals')
    addUnique(modules, 'logs')
    addUnique(modules, 'settings')
    return modules
  end

  if staffAllowed then
    addUnique(modules, 'staff')
    addUnique(modules, 'orgs')
    addUnique(modules, 'recruitment')
    addUnique(modules, 'logs')
  end

  if hasOrgs then
    addOrgTypeModules(modules, orgs)
    addUnique(modules, 'recruitment')
    addUnique(modules, 'goals')

    if hasCapability(orgs, 'logs.view') then
      addUnique(modules, 'logs')
    end
  else
    addUnique(modules, 'recruitment')
  end

  return modules
end

local function getPlayerDisplayName(src, player)
  local nuiName = GetPlayerName(src)
  if nuiName and nuiName ~= '' then return nuiName end

  local charinfo = type(player) == 'table' and player.charinfo or nil
  if type(charinfo) == 'table' then
    local firstName = tostring(charinfo.firstname or '')
    local lastName = tostring(charinfo.lastname or '')
    local fullName = (firstName .. ' ' .. lastName):gsub('^%s+', ''):gsub('%s+$', '')
    if fullName ~= '' then return fullName end
  end

  return ('ID ' .. tostring(src))
end

local function buildMockSession(src)
  local owner = isOwner(src)

  return {
    user = {
      source = src,
      name = GetPlayerName(src) or ('ID ' .. tostring(src)),
      isOwner = owner,
      globalPermissions = owner and {
        Config.OwnerAce,
        'staff.orgs.manage',
        'staff.players.manage',
        'staff.logs.view'
      } or {}
    },

    orgs = owner and {} or {
      {
        code = 'mafia',
        name = 'Mafia',
        type = 'gang',
        grade = 4,
        gradeCode = 'lider',
        capabilities = {
          'org.view',
          'members.invite',
          'members.kick',
          'storage.open',
          'storage.deposit',
          'storage.withdraw',
          'account.view',
          'goals.view',
          'goals.manage',
          'boss.actions'
        }
      }
    },

    modules = owner and {
      'dashboard',
      'legal',
      'gang',
      'orgs',
      'staff',
      'recruitment',
      'goals',
      'logs',
      'settings'
    } or {
      'dashboard',
      'gang',
      'recruitment',
      'goals'
    }
  }
end

local function buildRealSession(src)
  src = tonumber(src)
  if not src or src <= 0 then
    debugPrint('invalid source for real session', tostring(src))
    return {
      user = {
        source = src or 0,
        name = 'Unknown',
        isOwner = false,
        globalPermissions = {}
      },
      orgs = {},
      modules = { 'dashboard', 'recruitment' }
    }
  end

  local owner = isOwner(src)
  local player = safeExport('mz_core', 'GetPlayer', src)
  local coreSession = safeExport('mz_core', 'GetPlayerSession', src)
  local rawOrgs = safeExport('mz_core', 'GetPlayerOrgContext', src)
  if rawOrgs == nil then
    rawOrgs = safeExport('mz_core', 'GetPlayerOrgs', src)
  end

  if coreSession == nil then
    debugPrint('GetPlayerSession returned nil for source', src)
  end

  local orgs = {}
  if type(rawOrgs) == 'table' then
    for _, rawOrg in ipairs(rawOrgs) do
      local org = normalizeOrgContext(rawOrg)
      if org then
        orgs[#orgs + 1] = org
      end
    end
  elseif rawOrgs ~= nil then
    debugPrint('GetPlayerOrgs returned non-table for source', src)
  end

  local globalPermissions = buildGlobalPermissions(src, owner, orgs)

  return {
    user = {
      source = src,
      name = getPlayerDisplayName(src, player),
      isOwner = owner,
      globalPermissions = globalPermissions
    },
    orgs = orgs,
    modules = buildModules(owner, orgs, globalPermissions)
  }
end

local function buildPanelSession(src)
  if Config.UseMockSession == true then
    if Config.AllowDevMockSession ~= true then
      debugPrint('mock session requested but disabled outside debug mode')
      return buildRealSession(src)
    end

    return buildMockSession(src)
  end

  return buildRealSession(src)
end

RegisterNetEvent('mz_org:server:requestSession', function()
  local src = source
  local session = buildPanelSession(src)

  TriggerClientEvent('mz_org:client:receiveSession', src, session)
end)
