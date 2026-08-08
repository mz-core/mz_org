local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org:recruitment]', ...)
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

local RecruitmentRateLimit = {}

local function rateLimited(src, action)
  local now = GetGameTimer()
  local key = tostring(src) .. ':' .. tostring(action or 'default')
  local last = RecruitmentRateLimit[key] or 0
  if now - last < 2000 then
    return true
  end

  RecruitmentRateLimit[key] = now
  return false
end

local function normalizeString(value, maxLength)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end

  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' then return nil end

  maxLength = tonumber(maxLength) or 64
  if #value > maxLength then
    value = value:sub(1, maxLength)
  end

  return value
end

local function normalizeNumber(value, fallback, minValue, maxValue)
  value = tonumber(value) or fallback
  value = math.floor(value or 0)
  if minValue and value < minValue then value = minValue end
  if maxValue and value > maxValue then value = maxValue end
  return value
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
  return MZOrgSecurity.IsOwner(src)
end

local function canViewRecruitment(src, orgCode)
  if isOwner(src) then return true end

  if not orgCode then
    return false
  end

  if MZOrgSecurity.CanOrg(src, orgCode, 'recruitment.view') then
    return true
  end

  if MZOrgSecurity.CanOrg(src, orgCode, 'recruitment.manage') then
    return true
  end

  if MZOrgSecurity.CanOrg(src, orgCode, 'members.invite') then
    return true
  end

  return MZOrgSecurity.CanOrg(src, orgCode, 'manage.members')
end

local function canManageRecruitment(src, orgCode)
  if isOwner(src) then return true end
  if not orgCode then return false end

  if MZOrgSecurity.CanOrg(src, orgCode, 'recruitment.manage') then
    return true
  end

  if MZOrgSecurity.CanOrg(src, orgCode, 'members.invite') then
    return true
  end

  return MZOrgSecurity.CanOrg(src, orgCode, 'manage.members')
end

local function normalizeFilters(payload)
  payload = type(payload) == 'table' and payload or {}

  return {
    orgCode = normalizeString(payload.orgCode, 48),
    status = normalizeString(payload.status, 32),
    type = normalizeString(payload.type, 32),
    search = normalizeString(payload.search, 80),
    limit = normalizeNumber(payload.limit, 50, 1, 100),
    offset = normalizeNumber(payload.offset, 0, 0, 10000)
  }
end

local function normalizeRecruitmentRow(row)
  if type(row) ~= 'table' then return nil end

  return {
    id = row.id,
    orgCode = row.orgCode or row.org_code,
    type = row.type,
    status = row.status,
    candidateName = row.candidateName or row.targetName or row.target_name or row.candidate_name or row.name,
    candidateCitizenId = row.candidateCitizenId or row.targetCitizenId or row.target_citizenid or row.candidate_citizenid or row.citizenid,
    targetName = row.targetName or row.target_name or row.candidateName,
    targetCitizenId = row.targetCitizenId or row.target_citizenid or row.candidateCitizenId,
    desiredGradeLevel = row.desiredGradeLevel or row.desired_grade_level,
    desiredGradeCode = row.desiredGradeCode or row.desired_grade_code,
    note = row.note,
    decisionNote = row.decisionNote or row.decision_note,
    createdAt = row.createdAt or row.created_at,
    updatedAt = row.updatedAt or row.updated_at,
    reviewedAt = row.reviewedAt or row.reviewed_at,
    message = row.message or row.note,
    source = nil
  }
end

local function translateError(err, fallback)
  local messages = {
    invalid_org = 'Organizacao invalida.',
    org_not_found = 'Organizacao invalida.',
    invalid_target = 'CitizenID do candidato invalido.',
    target_not_found = 'Player nao encontrado.',
    already_member = 'O player ja e membro desta organizacao.',
    already_pending = 'Ja existe uma candidatura pendente para este CitizenID.',
    invalid_recruitment = 'Candidatura invalida.',
    recruitment_not_found = 'Candidatura nao encontrada.',
    invalid_status = 'Esta candidatura nao esta pendente.',
    forbidden = 'Sem permissao para gerenciar recrutamento.',
    invalid_grade = 'Cargo inicial invalido.',
    grade_not_found = 'Cargo inicial invalido.',
    grade_not_allowed = 'Voce nao pode usar este cargo inicial.',
    leader_permission_required = 'Voce nao tem permissao para alterar lideranca ou cargo maximo.',
    approve_failed = 'Nao foi possivel aprovar a candidatura.',
    reject_failed = 'Nao foi possivel recusar a candidatura.',
    cancel_failed = 'Nao foi possivel arquivar a candidatura.',
    player_not_loaded = 'Player nao carregado.',
    rate_limited = 'Aguarde alguns segundos para tentar novamente.'
  }

  return messages[tostring(err or '')] or fallback or 'Nao foi possivel concluir a acao.'
end

RegisterNetEvent('mz_org:server:listRecruitment', function(requestId, payload)
  local src = source
  local filters = normalizeFilters(payload)

  if not canViewRecruitment(src, filters.orgCode) then
    sendResponse(src, requestId, fail('Sem permissao para visualizar recrutamento.'))
    return
  end

  local rows, err = safeExport('mz_core', 'ListOrgRecruitment', src, filters.orgCode, filters)
  if rows == false then
    sendResponse(src, requestId, fail(translateError(err, 'Nao foi possivel listar candidaturas.')))
    return
  end

  if type(rows) ~= 'table' then
    debugPrint('ListOrgRecruitment indisponivel.')
    sendResponse(src, requestId, fail('Recrutamento indisponivel.'))
    return
  end

  local out = {}
  for _, row in ipairs(rows) do
    local item = normalizeRecruitmentRow(row)
    if item then
      out[#out + 1] = item
    end
  end

  sendResponse(src, requestId, ok(out))
end)

RegisterNetEvent('mz_org:server:getRecruitment', function(requestId, payload)
  local src = source
  local id = normalizeString(type(payload) == 'table' and payload.id or nil, 64)
  local orgCode = normalizeString(type(payload) == 'table' and payload.orgCode or nil, 48)

  if not id then
    sendResponse(src, requestId, fail('Candidatura invalida.'))
    return
  end

  if not canViewRecruitment(src, orgCode) then
    sendResponse(src, requestId, fail('Sem permissao para visualizar recrutamento.'))
    return
  end

  local row, err = safeExport('mz_core', 'GetOrgRecruitment', src, id)
  if row == false then
    sendResponse(src, requestId, fail(translateError(err, 'Nao foi possivel carregar a candidatura.')))
    return
  end

  local item = normalizeRecruitmentRow(row)
  if not item then
    debugPrint('GetOrgRecruitment indisponivel.')
    sendResponse(src, requestId, fail('Candidatura nao encontrada.'))
    return
  end

  sendResponse(src, requestId, ok(item))
end)

RegisterNetEvent('mz_org:server:createRecruitment', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeString(payload.orgCode, 48)
  local citizenid = normalizeString(payload.citizenid or payload.targetCitizenId or payload.passport, 64)
  local desiredGradeLevel = payload.desiredGradeLevel or payload.gradeLevel

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  if not citizenid then
    sendResponse(src, requestId, fail('CitizenID do candidato invalido.'))
    return
  end

  if not canManageRecruitment(src, orgCode) then
    sendResponse(src, requestId, fail('Sem permissao para gerenciar recrutamento.'))
    return
  end

  if rateLimited(src, 'create') then
    sendResponse(src, requestId, fail(translateError('rate_limited')))
    return
  end

  local result, dataOrErr = safeExport('mz_core', 'CreateOrgRecruitment', src, orgCode, {
    citizenid = citizenid,
    desiredGradeLevel = desiredGradeLevel,
    desiredGradeCode = normalizeString(payload.desiredGradeCode or payload.gradeCode, 64),
    note = normalizeString(payload.note, 1000)
  })

  if result ~= true then
    sendResponse(src, requestId, fail(translateError(dataOrErr, 'Nao foi possivel criar a candidatura.')))
    return
  end

  sendResponse(src, requestId, ok(normalizeRecruitmentRow(dataOrErr) or dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:approveRecruitment', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}
  local id = normalizeNumber(payload.id, 0, 1, nil)

  if not id or id <= 0 then
    sendResponse(src, requestId, fail('Candidatura invalida.'))
    return
  end

  if rateLimited(src, 'approve') then
    sendResponse(src, requestId, fail(translateError('rate_limited')))
    return
  end

  local result, dataOrErr = safeExport('mz_core', 'ApproveOrgRecruitment', src, id, {
    gradeLevel = payload.gradeLevel,
    gradeCode = normalizeString(payload.gradeCode, 64),
    note = normalizeString(payload.note, 1000)
  })

  if result ~= true then
    sendResponse(src, requestId, fail(translateError(dataOrErr, 'Nao foi possivel aprovar a candidatura.')))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:rejectRecruitment', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}
  local id = normalizeNumber(payload.id, 0, 1, nil)

  if not id or id <= 0 then
    sendResponse(src, requestId, fail('Candidatura invalida.'))
    return
  end

  if rateLimited(src, 'reject') then
    sendResponse(src, requestId, fail(translateError('rate_limited')))
    return
  end

  local result, dataOrErr = safeExport('mz_core', 'RejectOrgRecruitment', src, id, normalizeString(payload.reason or payload.note, 1000))
  if result ~= true then
    sendResponse(src, requestId, fail(translateError(dataOrErr, 'Nao foi possivel recusar a candidatura.')))
    return
  end

  sendResponse(src, requestId, ok(normalizeRecruitmentRow(dataOrErr) or dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:cancelRecruitment', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}
  local id = normalizeNumber(payload.id, 0, 1, nil)

  if not id or id <= 0 then
    sendResponse(src, requestId, fail('Candidatura invalida.'))
    return
  end

  if rateLimited(src, 'cancel') then
    sendResponse(src, requestId, fail(translateError('rate_limited')))
    return
  end

  local result, dataOrErr = safeExport('mz_core', 'CancelOrgRecruitment', src, id, normalizeString(payload.reason or payload.note, 1000))
  if result ~= true then
    sendResponse(src, requestId, fail(translateError(dataOrErr, 'Nao foi possivel arquivar a candidatura.')))
    return
  end

  sendResponse(src, requestId, ok(normalizeRecruitmentRow(dataOrErr) or dataOrErr or {}))
end)
