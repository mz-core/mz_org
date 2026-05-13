local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org:members]', ...)
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

local function isOwner(src)
  return isAceAllowed(src, Config.OwnerAce)
end

local function canViewMembers(src, orgCode)
  if isOwner(src) then return true end

  if safeExport('mz_core', 'HasGlobalPermission', src, 'staff.orgs.manage') == true then
    return true
  end

  if safeExport('mz_core', 'HasGlobalPermission', src, 'staff.panel.open') == true then
    return true
  end

  return safeExport('mz_core', 'CanOrg', src, orgCode, 'org.view') == true
end

local function normalizeMember(row)
  if type(row) ~= 'table' then return nil end

  return {
    citizenid = row.citizenid and tostring(row.citizenid) or nil,
    name = tostring(row.name or row.fullName or row.full_name or row.citizenid or 'Membro'),
    orgCode = row.orgCode or row.org_code,
    grade = tonumber(row.grade or row.grade_level) or 0,
    gradeCode = tostring(row.gradeCode or row.grade_code or ''),
    gradeName = tostring(row.gradeName or row.grade_name or ''),
    isLeader = row.isLeader == true or row.is_leader == true or row.is_leader == 1,
    isDuty = row.isDuty == true or row.is_duty == true or row.duty == true or row.duty == 1,
    joinedAt = row.joinedAt or row.joined_at,
    lastSeen = row.lastSeen or row.last_seen_at,
    status = tostring(row.status or '')
  }
end

RegisterNetEvent('mz_org:server:listMembers', function(requestId, payload)
  local src = source
  local orgCode = normalizeOrgCode(type(payload) == 'table' and payload.orgCode or nil)

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  if not canViewMembers(src, orgCode) then
    sendResponse(src, requestId, fail('Sem permissao.'))
    return
  end

  local rows, err = safeExport('mz_core', 'ListOrgMembers', src, orgCode)
  if rows == false then
    sendResponse(src, requestId, fail(err == 'forbidden' and 'Sem permissao.' or 'Nao foi possivel listar membros.'))
    return
  end

  if type(rows) ~= 'table' then
    debugPrint('ListOrgMembers indisponivel ou falhou no mz_core; retornando lista vazia segura.')
    sendResponse(src, requestId, ok({}))
    return
  end

  local out = {}
  for _, row in ipairs(rows) do
    local member = normalizeMember(row)
    if member then
      out[#out + 1] = member
    end
  end

  sendResponse(src, requestId, ok(out))
end)
