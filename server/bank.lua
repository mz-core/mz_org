local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org:bank]', ...)
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

local function normalizeTransactionFilters(payload)
  payload = type(payload) == 'table' and payload or {}
  local filters = type(payload.filters) == 'table' and payload.filters or payload

  return {
    limit = normalizeNumber(filters.limit, 50, 1, 100),
    offset = normalizeNumber(filters.offset, 0, 0, 10000),
    type = normalizeString(filters.type, 32),
    status = normalizeString(filters.status, 32),
    search = normalizeString(filters.search, 80)
  }
end

local function normalizeBankAccount(row)
  if type(row) ~= 'table' then return nil end

  return {
    orgCode = row.orgCode or row.org_code,
    balance = tonumber(row.balance) or 0,
    currency = row.currency or 'R$',
    canView = row.canView ~= false
  }
end

RegisterNetEvent('mz_org:server:getOrgBank', function(requestId, payload)
  local src = source
  local orgCode = normalizeString(type(payload) == 'table' and payload.orgCode or nil, 48)

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  local okResult, result = safeExport('mz_core', 'GetOrgAccount', src, orgCode)
  if okResult == false then
    local message = 'Nao foi possivel carregar o banco da organizacao.'
    if result == 'forbidden' then message = 'Sem permissao para visualizar o banco.' end
    if result == 'org_has_no_shared_account' then message = 'Esta organizacao nao possui conta compartilhada.' end
    if result == 'org_not_found' then message = 'Organizacao nao encontrada.' end
    sendResponse(src, requestId, fail(message))
    return
  end

  local account = normalizeBankAccount(result)
  if not account then
    debugPrint('GetOrgAccount indisponivel ou falhou no mz_core.')
    sendResponse(src, requestId, fail('Banco da organizacao indisponivel.'))
    return
  end

  sendResponse(src, requestId, ok(account))
end)

RegisterNetEvent('mz_org:server:listOrgBankTransactions', function(requestId, payload)
  local src = source
  local orgCode = normalizeString(type(payload) == 'table' and payload.orgCode or nil, 48)

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  -- Ainda nao existe tabela/export dedicado de extrato no mz_core.
  -- Mantemos a consulta read-only com fallback vazio seguro.
  local rows, err = safeExport('mz_core', 'ListOrgAccountTransactions', src, orgCode, normalizeTransactionFilters(payload))
  if rows == false then
    sendResponse(src, requestId, fail(err == 'forbidden' and 'Sem permissao para visualizar extrato.' or 'Nao foi possivel listar extrato.'))
    return
  end

  if type(rows) ~= 'table' then
    debugPrint('ListOrgAccountTransactions indisponivel no mz_core; retornando extrato vazio seguro.')
    sendResponse(src, requestId, ok({}))
    return
  end

  sendResponse(src, requestId, ok(rows))
end)
