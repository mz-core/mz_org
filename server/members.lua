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

local InviteRateLimit = {}
local RemoveRateLimit = {}
local GradeRateLimit = {}

local function rateLimited(bucket, src)
  local now = GetGameTimer()
  local last = bucket[src] or 0
  if now - last < 2000 then
    return true
  end

  bucket[src] = now
  return false
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

local function normalizeTargetId(value)
  local targetId = tonumber(value)
  if not targetId or targetId <= 0 then return nil end
  return math.floor(targetId)
end

local function normalizeCitizenId(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end

  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' or #value > 64 then return nil end

  return value
end

local function normalizeGradeLevel(value)
  if value == nil or value == '' then return nil end
  local level = tonumber(value)
  if not level or level <= 0 then return false end
  return math.floor(level)
end

local function normalizeGradeCode(value)
  if value == nil or value == '' then return nil end
  if type(value) ~= 'string' and type(value) ~= 'number' then return false end

  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' then return nil end
  if #value > 64 then return false end

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

RegisterNetEvent('mz_org:server:inviteMember', function(requestId, payload)
  local src = source
  local orgCode = normalizeOrgCode(type(payload) == 'table' and payload.orgCode or nil)
  local targetId = normalizeTargetId(type(payload) == 'table' and (payload.targetId or payload.targetSource) or nil)
  local gradeLevel = normalizeGradeLevel(type(payload) == 'table' and payload.gradeLevel or nil)
  local gradeCode = normalizeGradeCode(type(payload) == 'table' and payload.gradeCode or nil)

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  if gradeLevel == false or gradeCode == false then
    sendResponse(src, requestId, fail('Cargo inicial invalido.'))
    return
  end

  if not targetId then
    sendResponse(src, requestId, fail('Player alvo invalido.'))
    return
  end

  if rateLimited(InviteRateLimit, src) then
    sendResponse(src, requestId, fail('Aguarde antes de convidar novamente.'))
    return
  end

  local options = nil
  if gradeLevel or gradeCode then
    options = {
      gradeLevel = gradeLevel,
      gradeCode = gradeCode
    }
  end

  local result, dataOrErr = safeExport('mz_core', 'InviteOrgMember', src, orgCode, targetId, options)
  if result ~= true then
    local message = 'Nao foi possivel convidar o membro.'
    if dataOrErr == 'invalid_target' then message = 'Player alvo invalido ou offline.' end
    if dataOrErr == 'invalid_org' or dataOrErr == 'org_not_found' then message = 'Organizacao invalida.' end
    if dataOrErr == 'already_member' then message = 'O player ja e membro desta organizacao.' end
    if dataOrErr == 'forbidden' then message = 'Sem permissao para convidar membros.' end
    if dataOrErr == 'self_target' then message = 'Voce nao pode convidar a si mesmo.' end
    if dataOrErr == 'invalid_grade' then message = 'Cargo inicial invalido para esta organizacao.' end
    if dataOrErr == 'grade_not_allowed' then message = 'Voce nao pode convidar para este cargo.' end
    if dataOrErr == 'grade_not_found' then message = 'Nenhum cargo inicial seguro foi encontrado.' end
    sendResponse(src, requestId, fail(message))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:removeMember', function(requestId, payload)
  local src = source
  local orgCode = normalizeOrgCode(type(payload) == 'table' and payload.orgCode or nil)
  local citizenid = normalizeCitizenId(type(payload) == 'table' and payload.citizenid or nil)

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  if not citizenid then
    sendResponse(src, requestId, fail('Membro alvo invalido.'))
    return
  end

  if rateLimited(RemoveRateLimit, src) then
    sendResponse(src, requestId, fail('Aguarde antes de remover novamente.'))
    return
  end

  local result, dataOrErr = safeExport('mz_core', 'RemoveOrgMember', src, orgCode, citizenid)
  if result ~= true then
    local message = 'Nao foi possivel remover o membro.'
    if dataOrErr == 'invalid_target' then message = 'Membro alvo invalido.' end
    if dataOrErr == 'invalid_org' or dataOrErr == 'org_not_found' then message = 'Organizacao invalida.' end
    if dataOrErr == 'not_member' or dataOrErr == 'membership_not_found' then message = 'O player nao e membro ativo desta organizacao.' end
    if dataOrErr == 'forbidden' then message = 'Sem permissao para remover membros.' end
    if dataOrErr == 'self_remove' then message = 'Voce nao pode remover a si mesmo.' end
    if dataOrErr == 'target_higher_or_equal' then message = 'Voce nao pode remover cargo igual ou superior.' end
    if dataOrErr == 'protected_target' then message = 'Este membro esta em cargo protegido.' end
    sendResponse(src, requestId, fail(message))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

local function memberGradeAction(src, requestId, payload, action)
  local orgCode = normalizeOrgCode(type(payload) == 'table' and payload.orgCode or nil)
  local citizenid = normalizeCitizenId(type(payload) == 'table' and payload.citizenid or nil)

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  if not citizenid then
    sendResponse(src, requestId, fail('Membro alvo invalido.'))
    return
  end

  if rateLimited(GradeRateLimit, src) then
    sendResponse(src, requestId, fail('Aguarde antes de alterar cargo novamente.'))
    return
  end

  local exportName = action == 'demote' and 'DemoteOrgMemberSecure' or 'PromoteOrgMemberSecure'
  local result, dataOrErr = safeExport('mz_core', exportName, src, orgCode, citizenid)
  if result ~= true then
    local message = action == 'demote' and 'Nao foi possivel rebaixar o membro.' or 'Nao foi possivel promover o membro.'
    if dataOrErr == 'invalid_target' then message = 'Membro alvo invalido.' end
    if dataOrErr == 'invalid_org' or dataOrErr == 'org_not_found' then message = 'Organizacao invalida.' end
    if dataOrErr == 'not_member' or dataOrErr == 'membership_not_found' then message = 'O player nao e membro ativo desta organizacao.' end
    if dataOrErr == 'forbidden' then message = 'Sem permissao para alterar cargo de membros.' end
    if dataOrErr == 'self_action' then message = 'Voce nao pode alterar o proprio cargo.' end
    if dataOrErr == 'target_higher_or_equal' then message = 'Voce nao pode mexer em cargo igual ou superior.' end
    if dataOrErr == 'promotion_above_actor' then message = 'Voce nao pode promover para cargo igual ou superior ao seu.' end
    if dataOrErr == 'max_grade' or dataOrErr == 'max_grade_reached' then message = 'O membro ja esta no cargo maximo.' end
    if dataOrErr == 'min_grade' or dataOrErr == 'min_grade_reached' then message = 'O membro ja esta no cargo minimo.' end
    if dataOrErr == 'protected_target' then message = 'Este membro esta em cargo protegido.' end
    if dataOrErr == 'grade_not_found' then message = 'Cargo da organizacao nao encontrado.' end
    sendResponse(src, requestId, fail(message))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end

RegisterNetEvent('mz_org:server:promoteMember', function(requestId, payload)
  memberGradeAction(source, requestId, payload, 'promote')
end)

RegisterNetEvent('mz_org:server:demoteMember', function(requestId, payload)
  memberGradeAction(source, requestId, payload, 'demote')
end)
