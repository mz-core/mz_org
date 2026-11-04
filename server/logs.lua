local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org:logs]', ...)
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

local function normalizeFilters(payload)
  payload = type(payload) == 'table' and payload or {}

  return {
    orgCode = normalizeString(payload.orgCode, 48),
    category = normalizeString(payload.category, 32),
    severity = normalizeString(payload.severity, 24),
    search = normalizeString(payload.search, 80),
    dateFrom = normalizeString(payload.dateFrom, 32),
    dateTo = normalizeString(payload.dateTo, 32),
    limit = normalizeNumber(payload.limit, 50, 1, 100),
    offset = normalizeNumber(payload.offset, 0, 0, 10000)
  }
end

local function normalizeLog(row)
  if type(row) ~= 'table' then return nil end

  return {
    id = row.id,
    scope = row.scope,
    createdAt = row.createdAt or row.created_at,
    category = row.category or row.scope,
    action = row.action,
    severity = row.severity,
    orgCode = row.orgCode or row.org_code,
    actorName = row.actorName or row.actor_name,
    actorCitizenId = row.actorCitizenId or row.actor_citizenid,
    targetName = row.targetName or row.target_name,
    targetCitizenId = row.targetCitizenId or row.target_citizenid,
    message = row.message,
    reason = row.reason,
    meta = type(row.meta) == 'table' and row.meta or {}
  }
end

local function listOrganizationLogs(source, orgCode, filters)
  if not (MZOrgSecurity.HasGlobalPermission(source, 'staff.logs.view')
      or MZOrgSecurity.CanOrg(source, orgCode, 'logs.view')) then
    return false, 'forbidden'
  end
  if not MZOrgSecurity.GetOrg(orgCode) then return false, 'invalid_org' end
  return safeExport('mz_core', 'ListOrganizationLogs', orgCode, filters)
end

exports('ListOrgLogsSecure', listOrganizationLogs)

RegisterNetEvent('mz_org:server:listLogs', function(requestId, payload)
  local src = source
  local filters = normalizeFilters(payload)

  local exportName = filters.orgCode and 'ListOrganizationLogs' or 'ListGlobalLogsSecure'
  local rows, err
  if filters.orgCode then
    rows, err = listOrganizationLogs(src, filters.orgCode, filters)
  else
    rows, err = safeExport('mz_core', exportName, src, filters)
  end
  if rows == false then
    sendResponse(src, requestId, fail(err == 'forbidden' and 'Sem permissao para visualizar logs.' or 'Nao foi possivel listar logs.'))
    return
  end

  if type(rows) ~= 'table' then
    debugPrint(('%s indisponivel ou falhou no mz_core; negando por padrao.'):format(exportName))
    sendResponse(src, requestId, fail('Servico de logs indisponivel.'))
    return
  end

  local out = {}
  for _, row in ipairs(rows) do
    local item = normalizeLog(row)
    if item then
      out[#out + 1] = item
    end
  end

  sendResponse(src, requestId, ok(out))
end)
