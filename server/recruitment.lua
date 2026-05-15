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
  return isAceAllowed(src, Config.OwnerAce)
end

local function canViewRecruitment(src, orgCode)
  if isOwner(src) then return true end

  if safeExport('mz_core', 'HasGlobalPermission', src, 'staff.orgs.manage') == true then
    return true
  end

  if safeExport('mz_core', 'HasGlobalPermission', src, 'staff.panel.open') == true then
    return true
  end

  if not orgCode then
    -- Player comum sem orgCode fica limitado a candidaturas proprias futuras.
    -- Como nao existe backend real nesta etapa, o retorno e vazio seguro.
    return true
  end

  if safeExport('mz_core', 'CanOrg', src, orgCode, 'members.invite') == true then
    return true
  end

  if safeExport('mz_core', 'CanOrg', src, orgCode, 'recruitment.view') == true then
    return true
  end

  return safeExport('mz_core', 'CanOrg', src, orgCode, 'org.view') == true
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
    candidateName = row.candidateName or row.candidate_name or row.name,
    candidateCitizenId = row.candidateCitizenId or row.candidate_citizenid or row.citizenid,
    createdAt = row.createdAt or row.created_at,
    updatedAt = row.updatedAt or row.updated_at,
    message = row.message,
    source = row.source
  }
end

RegisterNetEvent('mz_org:server:listRecruitment', function(requestId, payload)
  local src = source
  local filters = normalizeFilters(payload)

  if not canViewRecruitment(src, filters.orgCode) then
    sendResponse(src, requestId, fail('Sem permissao para visualizar recrutamento.'))
    return
  end

  -- Backend real de recrutamento ainda nao foi encontrado no mz_core/mz_org.
  -- Mantemos contrato read-only pronto, sem criar tabelas ou acoes de escrita.
  local rows = safeExport('mz_core', 'ListOrgRecruitment', src, filters)
  if type(rows) ~= 'table' then
    debugPrint('ListOrgRecruitment indisponivel; retornando lista vazia segura.')
    sendResponse(src, requestId, ok({}))
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

  local row = safeExport('mz_core', 'GetOrgRecruitment', src, id)
  local item = normalizeRecruitmentRow(row)
  if not item then
    debugPrint('GetOrgRecruitment indisponivel; retornando detalhe vazio seguro.')
    sendResponse(src, requestId, ok({}))
    return
  end

  sendResponse(src, requestId, ok(item))
end)
