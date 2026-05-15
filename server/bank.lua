local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org:bank]', ...)
end

local bankActionCooldown = {}

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

local function normalizeAmount(value)
  value = math.floor(tonumber(value) or 0)
  if value <= 0 then return nil end
  return value
end

local function translateBankError(err)
  local messages = {
    invalid_org = 'Organizacao invalida.',
    org_not_found = 'Organizacao nao encontrada.',
    org_has_no_shared_account = 'Esta organizacao nao possui conta compartilhada.',
    invalid_amount = 'Valor invalido.',
    invalid_reason = 'Motivo invalido.',
    player_not_loaded = 'Player nao carregado.',
    insufficient_player_funds = 'Saldo insuficiente na sua conta bancaria.',
    insufficient_org_funds = 'Saldo insuficiente na conta da organizacao.',
    forbidden = 'Sem permissao para esta operacao.',
    deposit_failed = 'Nao foi possivel depositar.',
    withdraw_failed = 'Nao foi possivel sacar.',
    transaction_failed = 'Nao foi possivel registrar a transacao.',
    rate_limited = 'Aguarde alguns segundos para tentar novamente.'
  }

  return messages[tostring(err or '')] or 'Nao foi possivel concluir a operacao.'
end

local function checkBankActionRateLimit(src)
  local now = os.time()
  local last = bankActionCooldown[src] or 0
  if now - last < 2 then
    return false
  end

  bankActionCooldown[src] = now
  return true
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
  local okResult, result = safeExport('mz_core', 'ListOrgAccountTransactions', src, orgCode, normalizeTransactionFilters(payload))
  if okResult == false then
    sendResponse(src, requestId, fail(translateBankError(result)))
    return
  end

  if type(result) ~= 'table' then
    debugPrint('ListOrgAccountTransactions indisponivel no mz_core; retornando extrato vazio seguro.')
    sendResponse(src, requestId, ok({}))
    return
  end

  sendResponse(src, requestId, ok(result))
end)

RegisterNetEvent('mz_org:server:depositOrgBank', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = normalizeString(payload.orgCode, 48)
  local amount = normalizeAmount(payload.amount)
  local reason = normalizeString(payload.reason, 255)

  if not checkBankActionRateLimit(src) then
    sendResponse(src, requestId, fail(translateBankError('rate_limited')))
    return
  end

  if not orgCode then
    sendResponse(src, requestId, fail(translateBankError('invalid_org')))
    return
  end

  if not amount then
    sendResponse(src, requestId, fail(translateBankError('invalid_amount')))
    return
  end

  local okResult, result = safeExport('mz_core', 'DepositOrgAccount', src, orgCode, amount, reason)
  if okResult == false then
    sendResponse(src, requestId, fail(translateBankError(result)))
    return
  end
  if okResult ~= true then
    sendResponse(src, requestId, fail(translateBankError('deposit_failed')))
    return
  end

  sendResponse(src, requestId, ok(result or {}))
end)

RegisterNetEvent('mz_org:server:withdrawOrgBank', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = normalizeString(payload.orgCode, 48)
  local amount = normalizeAmount(payload.amount)
  local reason = normalizeString(payload.reason, 255)

  if not checkBankActionRateLimit(src) then
    sendResponse(src, requestId, fail(translateBankError('rate_limited')))
    return
  end

  if not orgCode then
    sendResponse(src, requestId, fail(translateBankError('invalid_org')))
    return
  end

  if not amount then
    sendResponse(src, requestId, fail(translateBankError('invalid_amount')))
    return
  end

  local okResult, result = safeExport('mz_core', 'WithdrawOrgAccount', src, orgCode, amount, reason)
  if okResult == false then
    sendResponse(src, requestId, fail(translateBankError(result)))
    return
  end
  if okResult ~= true then
    sendResponse(src, requestId, fail(translateBankError('withdraw_failed')))
    return
  end

  sendResponse(src, requestId, ok(result or {}))
end)
