local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org:goals]', ...)
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

local CreateGoalRateLimit = {}

local function rateLimited(bucket, src)
  local now = GetGameTimer()
  local last = bucket[src] or 0
  if now - last < 2000 then
    return true
  end

  bucket[src] = now
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

local function normalizeOptionalDate(value)
  if value == nil or value == '' then return nil end
  return normalizeString(value, 32)
end

local function normalizeGoalTarget(value)
  local target = tonumber(value)
  if not target then return false end
  target = math.floor(target)
  if target < 1 or target > 100000 then return false end
  return target
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

local function canViewGoals(src, orgCode)
  if isOwner(src) then return true end

  if safeExport('mz_core', 'HasGlobalPermission', src, 'staff.orgs.view') == true then
    return true
  end

  if safeExport('mz_core', 'HasGlobalPermission', src, 'staff.orgs.manage') == true then
    return true
  end

  if safeExport('mz_core', 'HasGlobalPermission', src, 'staff.orgs.create') == true then
    return true
  end

  if safeExport('mz_core', 'HasGlobalPermission', src, 'staff.orgs.set_leader') == true then
    return true
  end

  if not orgCode then
    return false
  end

  if safeExport('mz_core', 'CanOrg', src, orgCode, 'goals.view') == true then
    return true
  end

  if safeExport('mz_core', 'CanOrg', src, orgCode, 'goals.manage') == true then
    return true
  end

  return safeExport('mz_core', 'CanOrg', src, orgCode, 'org.view') == true
end

local function canManageGoals(src, orgCode)
  if isOwner(src) then return true end

  if safeExport('mz_core', 'HasGlobalPermission', src, 'staff.orgs.manage') == true then
    return true
  end

  if not orgCode then
    return false
  end

  if safeExport('mz_core', 'CanOrg', src, orgCode, 'goals.manage') == true then
    return true
  end

  return safeExport('mz_core', 'CanOrg', src, orgCode, 'manage.goals') == true
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

local function normalizeGoalRow(row)
  if type(row) ~= 'table' then return nil end

  local target = tonumber(row.target or row.targetValue or row.target_value) or 0
  local progress = tonumber(row.progress or row.current or row.currentValue or row.current_value) or 0
  local percent = tonumber(row.progressPercent or row.progress_percent)

  if not percent then
    percent = target > 0 and math.floor((progress / target) * 100) or 0
  end

  if percent < 0 then percent = 0 end
  if percent > 100 then percent = 100 end

  return {
    id = row.id,
    orgCode = row.orgCode or row.org_code,
    title = row.title or row.name,
    description = row.description,
    type = row.type,
    status = row.status,
    target = target,
    progress = progress,
    progressPercent = percent,
    startsAt = row.startsAt or row.starts_at,
    endsAt = row.endsAt or row.ends_at,
    createdByName = row.createdByName or row.created_by_name,
    priority = row.priority
  }
end

RegisterNetEvent('mz_org:server:listGoals', function(requestId, payload)
  local src = source
  local filters = normalizeFilters(payload)

  if not canViewGoals(src, filters.orgCode) then
    sendResponse(src, requestId, fail('Sem permissao para visualizar metas.'))
    return
  end

  local rows = safeExport('mz_core', 'ListOrgGoals', src, filters)
  if rows == false then
    sendResponse(src, requestId, fail('Nao foi possivel listar metas.'))
    return
  end

  if type(rows) ~= 'table' then
    debugPrint('ListOrgGoals indisponivel; retornando lista vazia segura.')
    sendResponse(src, requestId, ok({}))
    return
  end

  local out = {}
  for _, row in ipairs(rows) do
    local item = normalizeGoalRow(row)
    if item then
      out[#out + 1] = item
    end
  end

  sendResponse(src, requestId, ok(out))
end)

RegisterNetEvent('mz_org:server:getGoal', function(requestId, payload)
  local src = source
  local id = normalizeString(type(payload) == 'table' and payload.id or nil, 64)
  local orgCode = normalizeString(type(payload) == 'table' and payload.orgCode or nil, 48)

  if not id then
    sendResponse(src, requestId, fail('Meta invalida.'))
    return
  end

  if not canViewGoals(src, orgCode) then
    sendResponse(src, requestId, fail('Sem permissao para visualizar metas.'))
    return
  end

  local row = safeExport('mz_core', 'GetOrgGoal', src, id)
  local item = normalizeGoalRow(row)
  if not item then
    debugPrint('GetOrgGoal indisponivel; retornando detalhe vazio seguro.')
    sendResponse(src, requestId, ok({}))
    return
  end

  sendResponse(src, requestId, ok(item))
end)

RegisterNetEvent('mz_org:server:createGoal', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeString(payload.orgCode, 48)
  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  if not canManageGoals(src, orgCode) then
    sendResponse(src, requestId, fail('Sem permissao para criar metas.'))
    return
  end

  if rateLimited(CreateGoalRateLimit, src) then
    sendResponse(src, requestId, fail('Aguarde antes de criar outra meta.'))
    return
  end

  local data = {
    title = normalizeString(payload.title, 120),
    description = normalizeString(payload.description, 1000),
    type = normalizeString(payload.type, 32),
    target = normalizeGoalTarget(payload.target),
    startsAt = normalizeOptionalDate(payload.startsAt),
    endsAt = normalizeOptionalDate(payload.endsAt)
  }

  if data.target == false then
    sendResponse(src, requestId, fail('Objetivo da meta invalido.'))
    return
  end

  local result, dataOrErr = safeExport('mz_core', 'CreateOrgGoal', src, orgCode, data)
  if result ~= true then
    local message = 'Nao foi possivel criar a meta.'
    if dataOrErr == 'invalid_org' or dataOrErr == 'org_not_found' then message = 'Organizacao invalida.' end
    if dataOrErr == 'forbidden' then message = 'Sem permissao para criar metas.' end
    if dataOrErr == 'invalid_title' then message = 'Informe um titulo valido.' end
    if dataOrErr == 'invalid_description' then message = 'Descricao muito longa ou invalida.' end
    if dataOrErr == 'invalid_type' then message = 'Tipo de meta invalido.' end
    if dataOrErr == 'invalid_target' then message = 'Objetivo da meta invalido.' end
    if dataOrErr == 'invalid_dates' then message = 'Datas da meta invalidas.' end
    if dataOrErr == 'create_failed' then message = 'Falha ao salvar a meta.' end
    sendResponse(src, requestId, fail(message))
    return
  end

  local item = normalizeGoalRow(dataOrErr)
  sendResponse(src, requestId, ok(item or dataOrErr or {}))
end)
