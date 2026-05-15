local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org:permissions]', ...)
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

local function normalizeList(values)
  local out = {}
  if type(values) ~= 'table' then return out end

  for _, value in ipairs(values) do
    if type(value) == 'string' and value ~= '' then
      out[#out + 1] = value
    end
  end

  return out
end

local function normalizeGrade(row)
  if type(row) ~= 'table' then return nil end

  return {
    level = tonumber(row.level) or 0,
    code = tostring(row.code or ''),
    name = tostring(row.name or ''),
    salary = tonumber(row.salary) or 0,
    inheritsLevel = row.inheritsLevel or row.inherits_level,
    inheritsCode = row.inheritsCode or row.inherits_code,
    capabilities = normalizeList(row.capabilities),
    directCapabilities = normalizeList(row.directCapabilities or row.direct_capabilities)
  }
end

local function normalizeAccessModel(row)
  if type(row) ~= 'table' then return nil end

  local grades = {}
  for _, gradeRow in ipairs(row.grades or {}) do
    local grade = normalizeGrade(gradeRow)
    if grade then grades[#grades + 1] = grade end
  end

  return {
    orgCode = tostring(row.orgCode or row.org_code or ''),
    orgName = tostring(row.orgName or row.org_name or row.name or ''),
    type = tostring(row.type or ''),
    baseCapabilities = normalizeList(row.baseCapabilities or row.base_capabilities),
    grades = grades,
    playerOverrides = type(row.playerOverrides or row.player_overrides) == 'table' and (row.playerOverrides or row.player_overrides) or {}
  }
end

RegisterNetEvent('mz_org:server:getOrgAccess', function(requestId, payload)
  local src = source
  local orgCode = normalizeString(type(payload) == 'table' and payload.orgCode or nil, 48)

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  local result, err = safeExport('mz_core', 'GetOrgAccessModel', src, orgCode)
  if result == false then
    sendResponse(src, requestId, fail(err == 'forbidden' and 'Sem permissao para visualizar cargos.' or 'Nao foi possivel carregar cargos.'))
    return
  end

  local model = normalizeAccessModel(result)
  if not model then
    debugPrint('GetOrgAccessModel indisponivel ou falhou no mz_core; retornando modelo vazio seguro.')
    sendResponse(src, requestId, ok({
      orgCode = orgCode,
      orgName = orgCode,
      type = '',
      baseCapabilities = {},
      grades = {},
      playerOverrides = {}
    }))
    return
  end

  sendResponse(src, requestId, ok(model))
end)
