local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org:orgs]', ...)
end

local function ok(data)
  return {
    ok = true,
    data = data
  }
end

local function fail(errorMessage)
  return {
    ok = false,
    error = errorMessage or 'Erro desconhecido.'
  }
end

local function sendResponse(src, requestId, response)
  TriggerClientEvent('mz_org:client:serverResponse', src, requestId, response)
end

local function safeExport(resourceName, exportName, ...)
  if GetResourceState(resourceName) ~= 'started' then
    debugPrint(('export skipped: resource %s is not started'):format(resourceName))
    return nil
  end

  local args = { ... }
  local success, result, extra = pcall(function()
    local resourceExports = exports[resourceName]
    return resourceExports[exportName](resourceExports, table.unpack(args))
  end)

  if not success then
    debugPrint(('export failed: %s:%s - %s'):format(resourceName, exportName, tostring(result)))
    return nil
  end

  return result, extra
end

local function normalizeOrgType(rawType)
  rawType = tostring(rawType or '')

  if rawType == 'job' then return 'legal' end
  if rawType == 'gang' then return 'gang' end
  if rawType == 'staff' then return 'staff' end
  if rawType == 'business' then return 'business' end
  if rawType == 'government' then return 'government' end
  if rawType == 'vip' then return 'vip' end

  return rawType ~= '' and rawType or 'legal'
end

local function asBool(value)
  if value == true then return true end
  if value == false or value == nil then return false end
  if type(value) == 'number' then return value == 1 end
  if type(value) == 'string' then
    value = value:lower()
    return value == '1' or value == 'true'
  end

  return false
end

local function normalizeOrgCode(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end

  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' then return nil end

  return value
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

local function mapContextByCode(context)
  local out = {}

  for _, org in ipairs(context or {}) do
    if org.code then
      out[tostring(org.code)] = org
    end
  end

  return out
end

local function normalizeOrg(row, playerContext)
  if type(row) ~= 'table' then return nil end

  local code = normalizeOrgCode(row.code or row.org_code)
  if not code then return nil end

  local context = playerContext and playerContext[code] or nil
  local grade = type(context and context.grade) == 'table' and context.grade or nil

  return {
    code = code,
    name = tostring(row.name or row.org_name or code),
    type = normalizeOrgType(row.type or row.type_code or row.org_type),
    is_public = asBool(row.is_public),
    locked = asBool(row.locked or row.is_locked),
    protected = asBool(row.protected or row.is_protected),
    memberCount = tonumber(row.memberCount or row.member_count),
    playerRole = context and (context.gradeCode or context.grade_code or (grade and grade.code)) or nil,
    grade = context and (tonumber(context.grade) or tonumber(context.grade_level) or (grade and tonumber(grade.level))) or nil,
    gradeCode = context and tostring(context.gradeCode or context.grade_code or (grade and grade.code) or '') or nil
  }
end

local function isOwner(src)
  return isAceAllowed(src, Config.OwnerAce)
end

local function canManageOrgs(src)
  if isOwner(src) then return true end

  return safeExport('mz_core', 'HasGlobalPermission', src, 'staff.orgs.manage') == true
    or safeExport('mz_core', 'HasGlobalPermission', src, 'staff.panel.open') == true
end

local function getPlayerContext(src)
  local context = safeExport('mz_core', 'GetPlayerOrgContext', src)
  if type(context) == 'table' then return context end

  context = safeExport('mz_core', 'GetPlayerOrgs', src)
  if type(context) == 'table' then return context end

  return {}
end

local function listVisibleOrgs(src)
  local context = getPlayerContext(src)
  local contextByCode = mapContextByCode(context)
  local canSeeAll = canManageOrgs(src)
  local rows = nil

  if canSeeAll then
    rows = safeExport('mz_core', 'ListOrgs')
  else
    rows = context
  end

  local out = {}
  for _, row in ipairs(type(rows) == 'table' and rows or {}) do
    local org = normalizeOrg(row, contextByCode)
    if org then
      out[#out + 1] = org
    end
  end

  return out
end

local function canViewOrg(src, orgCode)
  if isOwner(src) or canManageOrgs(src) then return true end
  return safeExport('mz_core', 'CanOrg', src, orgCode, 'org.view') == true
end

RegisterNetEvent('mz_org:server:listOrgs', function(requestId)
  local src = source
  sendResponse(src, requestId, ok(listVisibleOrgs(src)))
end)

RegisterNetEvent('mz_org:server:getOrg', function(requestId, payload)
  local src = source
  local orgCode = normalizeOrgCode(type(payload) == 'table' and payload.orgCode or nil)

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  if not canViewOrg(src, orgCode) then
    sendResponse(src, requestId, fail('Sem permissao.'))
    return
  end

  local row = safeExport('mz_core', 'GetOrgByCode', orgCode)
  if not row then
    sendResponse(src, requestId, fail('Organizacao nao encontrada.'))
    return
  end

  local contextByCode = mapContextByCode(getPlayerContext(src))
  sendResponse(src, requestId, ok(normalizeOrg(row, contextByCode)))
end)
