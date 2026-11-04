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

local CreateOrgRateLimit = {}
local UpdateOrgBasicRateLimit = {}
local GradeActionRateLimit = {}
local ArchiveActionRateLimit = {}

local function rateLimited(bucket, src)
  local now = GetGameTimer()
  local last = bucket[src] or 0
  if now - last < 3000 then
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

local function normalizeCreateType(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', ''):lower()
  if value == 'legal' then value = 'job' end
  if value == 'illegal' then value = 'gang' end
  if value == 'job' or value == 'gang' or value == 'business' or value == 'government' or value == 'vip' or value == 'event' then
    return value
  end
  return nil
end

local function normalizeCreateCode(value)
  value = normalizeOrgCode(value)
  if not value then return nil end
  value = value:lower():gsub('%s+', '_')
  if #value < 2 or #value > 48 then return nil end
  if not value:match('^[a-z0-9_-]+$') then return nil end
  return value
end

local function normalizeCreateName(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' or #value < 2 then return nil end
  if #value > 120 then value = value:sub(1, 120) end
  return value
end

local function normalizeBasicName(value)
  return normalizeCreateName(value)
end

local function normalizeBasicStatus(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', ''):lower()
  if value == 'active' then value = 'private' end
  if value == 'public' or value == 'private' or value == 'inactive' then return value end
  return nil
end

local function normalizeGradeCode(value)
  value = normalizeOrgCode(value)
  if not value then return nil end
  value = value:lower():gsub('%s+', '_')
  if #value < 2 or #value > 48 then return nil end
  if not value:match('^[a-z0-9_-]+$') then return nil end
  return value
end

local function normalizeGradeName(value)
  return normalizeBasicName(value)
end

local function normalizeGradeLevel(value)
  local level = tonumber(value)
  if not level then return nil end
  level = math.floor(level)
  if level < 1 or level > 1000 then return nil end
  return level
end

local function normalizeGradeSalary(value)
  local salary = tonumber(value)
  if not salary then return nil end
  salary = math.floor(salary)
  if salary < 0 or salary > 100000000 then return nil end
  return salary
end

local function normalizeGradePriority(value, fallback)
  local priority = tonumber(value)
  if not priority then return fallback end
  priority = math.floor(priority)
  if priority < 0 then priority = 0 end
  if priority > 1000 then priority = 1000 end
  return priority
end

local function normalizeGradeId(value)
  local id = tonumber(value)
  if not id then return nil end
  id = math.floor(id)
  if id <= 0 then return nil end
  return id
end

local function normalizeReason(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' then return nil end
  if #value > 255 then value = value:sub(1, 255) end
  return value
end

local function normalizePermission(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', ''):lower()
  if value == '' or #value > 128 then return nil end
  if not value:match('^[a-z0-9_.-]+$') then return nil end
  if value:match('^staff%.') then return nil end
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
    requiresWhitelist = asBool(row.requiresWhitelist or row.requires_whitelist),
    hasSalary = asBool(row.hasSalary or row.has_salary),
    hasSharedAccount = asBool(row.hasSharedAccount or row.has_shared_account),
    hasStorage = asBool(row.hasStorage or row.has_storage),
    active = row.active == nil and true or asBool(row.active),
    status = row.status or ((row.active == nil or asBool(row.active)) and (asBool(row.is_public) and 'public' or 'private') or 'inactive'),
    locked = asBool(row.locked or row.is_locked),
    protected = asBool(row.protected or row.is_protected),
    memberCount = tonumber(row.memberCount or row.member_count),
    playerRole = context and (context.gradeCode or context.grade_code or (grade and grade.code)) or nil,
    grade = context and (tonumber(context.grade) or tonumber(context.grade_level) or (grade and tonumber(grade.level))) or nil,
    gradeCode = context and tostring(context.gradeCode or context.grade_code or (grade and grade.code) or '') or nil
  }
end

local function isOwner(src)
  return MZOrgSecurity.IsOwner(src)
end

local function canManageOrgs(src)
  if isOwner(src) then return true end

  return MZOrgSecurity.HasGlobalPermission(src, 'staff.orgs.view')
    or MZOrgSecurity.HasGlobalPermission(src, 'staff.orgs.manage')
    or MZOrgSecurity.HasGlobalPermission(src, 'staff.orgs.create')
    or MZOrgSecurity.HasGlobalPermission(src, 'staff.orgs.set_leader')
end

local function canCreateOrgs(src)
  if isOwner(src) then return true end
  return MZOrgSecurity.HasGlobalPermission(src, 'staff.orgs.create')
end

local function canUpdateOrgBasic(src)
  if isOwner(src) then return true end
  return MZOrgSecurity.HasGlobalPermission(src, 'staff.orgs.manage')
end

local function getPlayerContext(src)
  local context = safeExport('mz_org', 'GetPlayerOrgContext', src)
  if type(context) == 'table' then return context end

  context = safeExport('mz_org', 'GetPlayerOrgs', src)
  if type(context) == 'table' then return context end

  return {}
end

local function listVisibleOrgs(src)
  local context = getPlayerContext(src)
  local contextByCode = mapContextByCode(context)
  local canSeeAll = canManageOrgs(src)
  local rows = nil

  if canSeeAll then
    rows = safeExport('mz_org', 'ListOrgs')
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
  return MZOrgSecurity.CanOrg(src, orgCode, 'org.view')
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

  local row = safeExport('mz_org', 'GetOrgByCode', orgCode)
  if not row then
    sendResponse(src, requestId, fail('Organizacao nao encontrada.'))
    return
  end

  local contextByCode = mapContextByCode(getPlayerContext(src))
  sendResponse(src, requestId, ok(normalizeOrg(row, contextByCode)))
end)

RegisterNetEvent('mz_org:server:createOrgFromTemplate', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgType = normalizeCreateType(payload.type or payload.orgType)
  local code = normalizeCreateCode(payload.code or payload.orgCode)
  local name = normalizeCreateName(payload.name)
  local reason = normalizeReason(payload.reason)

  if not orgType then
    sendResponse(src, requestId, fail('Tipo de organizacao invalido.'))
    return
  end

  if not code then
    sendResponse(src, requestId, fail('Informe um codigo valido.'))
    return
  end

  if not name then
    sendResponse(src, requestId, fail('Informe um nome valido.'))
    return
  end

  if not canCreateOrgs(src) then
    sendResponse(src, requestId, fail('Voce nao tem permissao para criar organizacoes.'))
    return
  end

  if rateLimited(CreateOrgRateLimit, src) then
    sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.'))
    return
  end

  local result, dataOrErr = safeExport('mz_org', 'CreateOrgFromTemplate', src, {
    type = orgType,
    code = code,
    name = name,
    hasSalary = asBool(payload.hasSalary),
    hasSharedAccount = asBool(payload.hasSharedAccount),
    hasStorage = asBool(payload.hasStorage),
    reason = reason
  })

  if result ~= true then
    local message = 'Nao foi possivel criar a organizacao.'
    if dataOrErr == 'invalid_type' then message = 'Tipo de organizacao invalido.' end
    if dataOrErr == 'invalid_code' then message = 'Informe um codigo valido.' end
    if dataOrErr == 'invalid_name' then message = 'Informe um nome valido.' end
    if dataOrErr == 'org_already_exists' then message = 'Ja existe uma organizacao com esse codigo.' end
    if dataOrErr == 'forbidden' then message = 'Voce nao tem permissao para criar organizacoes.' end
    if dataOrErr == 'template_not_found' then message = 'Template nao encontrado.' end
    if dataOrErr == 'create_org_failed' then message = 'Nao foi possivel criar a organizacao.' end
    if dataOrErr == 'create_grade_failed' then message = 'Nao foi possivel criar os cargos padrao.' end
    if dataOrErr == 'create_permission_failed' then message = 'Nao foi possivel criar as permissoes padrao.' end
    if dataOrErr == 'create_account_failed' then message = 'Nao foi possivel criar a conta compartilhada.' end
    sendResponse(src, requestId, fail(message))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:updateOrgBasic', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeOrgCode(payload.orgCode)
  local name = normalizeBasicName(payload.name)
  local status = normalizeBasicStatus(payload.status or 'private')
  local reason = normalizeReason(payload.reason)

  if not orgCode then
    sendResponse(src, requestId, fail('Organizacao invalida.'))
    return
  end

  if not name then
    sendResponse(src, requestId, fail('Informe um nome valido.'))
    return
  end

  if not status then
    sendResponse(src, requestId, fail('Status invalido.'))
    return
  end

  if not canUpdateOrgBasic(src) then
    sendResponse(src, requestId, fail('Voce nao tem permissao para editar esta organizacao.'))
    return
  end

  if rateLimited(UpdateOrgBasicRateLimit, src) then
    sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.'))
    return
  end

  local result, dataOrErr = safeExport('mz_org', 'UpdateOrgBasicInfo', src, orgCode, {
    name = name,
    status = status,
    hasSalary = asBool(payload.hasSalary),
    hasSharedAccount = asBool(payload.hasSharedAccount),
    hasStorage = asBool(payload.hasStorage),
    reason = reason
  })

  if result ~= true then
    local message = 'Nao foi possivel atualizar a organizacao.'
    if dataOrErr == 'invalid_org' then message = 'Organizacao invalida.' end
    if dataOrErr == 'org_not_found' then message = 'Organizacao nao encontrada.' end
    if dataOrErr == 'invalid_name' then message = 'Informe um nome valido.' end
    if dataOrErr == 'invalid_status' then message = 'Status invalido.' end
    if dataOrErr == 'forbidden' then message = 'Voce nao tem permissao para editar esta organizacao.' end
    if dataOrErr == 'update_org_failed' then message = 'Nao foi possivel atualizar a organizacao.' end
    sendResponse(src, requestId, fail(message))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

local function gradeErrorMessage(errorCode)
  local message = 'Nao foi possivel salvar o cargo.'
  if errorCode == 'invalid_org' then message = 'Organizacao invalida.' end
  if errorCode == 'org_not_found' then message = 'Organizacao nao encontrada.' end
  if errorCode == 'org_archived' then message = 'Organizacao arquivada. Reative antes de gerenciar cargos.' end
  if errorCode == 'invalid_grade' then message = 'Cargo invalido.' end
  if errorCode == 'grade_not_found' then message = 'Cargo nao encontrado.' end
  if errorCode == 'invalid_code' then message = 'Informe um codigo valido para o cargo.' end
  if errorCode == 'invalid_name' then message = 'Informe um nome valido para o cargo.' end
  if errorCode == 'invalid_level' then message = 'Informe um nivel valido.' end
  if errorCode == 'grade_code_conflict' then message = 'Ja existe um cargo com esse codigo.' end
  if errorCode == 'grade_level_conflict' then message = 'Ja existe um cargo nesse nivel.' end
  if errorCode == 'invalid_salary' then message = 'Informe um salario valido.' end
  if errorCode == 'invalid_inheritance' then message = 'Heranca de cargo invalida.' end
  if errorCode == 'inheritance_cycle' then message = 'A heranca criaria um ciclo invalido.' end
  if errorCode == 'forbidden' then message = 'Voce nao tem permissao para gerenciar cargos.' end
  if errorCode == 'leader_permission_required' then message = 'Alterar cargo maximo exige permissao de lideranca.' end
  if errorCode == 'grade_in_use' then message = 'Este cargo possui membros e nao pode ser desativado.' end
  if errorCode == 'top_grade_protected' then message = 'Cargo maximo protegido.' end
  if errorCode == 'grade_already_disabled' then message = 'Cargo ja esta desativado.' end
  if errorCode == 'grade_already_active' then message = 'Cargo ja esta ativo.' end
  if errorCode == 'create_grade_failed' then message = 'Nao foi possivel criar o cargo.' end
  if errorCode == 'update_grade_failed' then message = 'Nao foi possivel atualizar o cargo.' end
  if errorCode == 'disable_grade_failed' then message = 'Nao foi possivel desativar o cargo.' end
  if errorCode == 'reactivate_grade_failed' then message = 'Nao foi possivel reativar o cargo.' end
  return message
end

local function archiveErrorMessage(errorCode)
  local message = 'Nao foi possivel atualizar o arquivamento.'
  if errorCode == 'invalid_org' then message = 'Organizacao invalida.' end
  if errorCode == 'org_not_found' then message = 'Organizacao nao encontrada.' end
  if errorCode == 'forbidden' then message = 'Voce nao tem permissao para arquivar ou reativar esta organizacao.' end
  if errorCode == 'org_already_archived' then message = 'Organizacao ja esta arquivada.' end
  if errorCode == 'org_already_active' then message = 'Organizacao ja esta ativa.' end
  if errorCode == 'protected_org' then message = 'Esta organizacao nao pode ser arquivada nesta fase.' end
  if errorCode == 'archive_org_failed' then message = 'Nao foi possivel arquivar a organizacao.' end
  if errorCode == 'reactivate_org_failed' then message = 'Nao foi possivel reativar a organizacao.' end
  return message
end

local function gradePermissionErrorMessage(errorCode)
  local message = 'Nao foi possivel alterar a permissao.'
  if errorCode == 'invalid_org' then message = 'Organizacao invalida.' end
  if errorCode == 'org_not_found' then message = 'Organizacao nao encontrada.' end
  if errorCode == 'org_archived' then message = 'Organizacao arquivada nao pode ser alterada.' end
  if errorCode == 'invalid_grade' then message = 'Cargo invalido.' end
  if errorCode == 'grade_not_found' then message = 'Cargo nao encontrado.' end
  if errorCode == 'grade_inactive' then message = 'Cargo inativo nao pode ser alterado.' end
  if errorCode == 'invalid_permission' then message = 'Permissao invalida.' end
  if errorCode == 'permission_not_allowed' then message = 'Esta permissao nao pode ser adicionada aqui.' end
  if errorCode == 'permission_not_allowed_for_org_type' then message = 'Esta permissao nao e permitida para este tipo de organizacao.' end
  if errorCode == 'sensitive_permission_requires_owner' then message = 'Esta permissao sensivel exige owner.' end
  if errorCode == 'leader_permission_required' then message = 'Definir lideranca exige permissao forte.' end
  if errorCode == 'leadership_not_supported' then
    message = 'Este tipo de organizacao nao possui lideranca.'
  end
  if errorCode == 'permission_already_exists' then message = 'Este cargo ja possui essa permissao.' end
  if errorCode == 'permission_not_found' then message = 'Permissao nao encontrada neste cargo.' end
  if errorCode == 'forbidden' then message = 'Voce nao tem permissao para gerenciar permissoes.' end
  if errorCode == 'add_permission_failed' then message = 'Nao foi possivel adicionar a permissao.' end
  if errorCode == 'remove_permission_failed' then message = 'Nao foi possivel remover a permissao.' end
  return message
end

RegisterNetEvent('mz_org:server:createGrade', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeOrgCode(payload.orgCode)
  local code = normalizeGradeCode(payload.code)
  local name = normalizeGradeName(payload.name)
  local level = normalizeGradeLevel(payload.level)
  local salary = normalizeGradeSalary(payload.salary or 0)
  local priority = normalizeGradePriority(payload.priority, level)
  local inheritsLevel = payload.inheritsLevel ~= nil and tostring(payload.inheritsLevel) ~= '' and normalizeGradeLevel(payload.inheritsLevel) or nil
  local reason = normalizeReason(payload.reason)

  if not orgCode then sendResponse(src, requestId, fail('Organizacao invalida.')) return end
  if not code then sendResponse(src, requestId, fail('Informe um codigo valido para o cargo.')) return end
  if not name then sendResponse(src, requestId, fail('Informe um nome valido para o cargo.')) return end
  if not level then sendResponse(src, requestId, fail('Informe um nivel valido.')) return end
  if not salary then sendResponse(src, requestId, fail('Informe um salario valido.')) return end
  if payload.inheritsLevel ~= nil and tostring(payload.inheritsLevel) ~= '' and not inheritsLevel then sendResponse(src, requestId, fail('Heranca de cargo invalida.')) return end
  if not canUpdateOrgBasic(src) then sendResponse(src, requestId, fail('Voce nao tem permissao para gerenciar cargos.')) return end
  if rateLimited(GradeActionRateLimit, src) then sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.')) return end

  local result, dataOrErr = safeExport('mz_org', 'CreateOrgGrade', src, orgCode, {
    code = code,
    name = name,
    level = level,
    salary = salary,
    priority = priority,
    inheritsLevel = inheritsLevel,
    reason = reason
  })

  if result ~= true then
    sendResponse(src, requestId, fail(gradeErrorMessage(dataOrErr)))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:updateGradeBasic', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeOrgCode(payload.orgCode)
  local gradeId = normalizeGradeId(payload.gradeId)
  local name = normalizeGradeName(payload.name)
  local level = normalizeGradeLevel(payload.level)
  local salary = normalizeGradeSalary(payload.salary or 0)
  local priority = normalizeGradePriority(payload.priority, level)
  local inheritsLevel = payload.inheritsLevel ~= nil and tostring(payload.inheritsLevel) ~= '' and normalizeGradeLevel(payload.inheritsLevel) or nil
  local reason = normalizeReason(payload.reason)

  if not orgCode then sendResponse(src, requestId, fail('Organizacao invalida.')) return end
  if not gradeId then sendResponse(src, requestId, fail('Cargo invalido.')) return end
  if not name then sendResponse(src, requestId, fail('Informe um nome valido para o cargo.')) return end
  if not level then sendResponse(src, requestId, fail('Informe um nivel valido.')) return end
  if not salary then sendResponse(src, requestId, fail('Informe um salario valido.')) return end
  if payload.inheritsLevel ~= nil and tostring(payload.inheritsLevel) ~= '' and not inheritsLevel then sendResponse(src, requestId, fail('Heranca de cargo invalida.')) return end
  if not canUpdateOrgBasic(src) then sendResponse(src, requestId, fail('Voce nao tem permissao para gerenciar cargos.')) return end
  if rateLimited(GradeActionRateLimit, src) then sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.')) return end

  local result, dataOrErr = safeExport('mz_org', 'UpdateOrgGradeBasic', src, orgCode, gradeId, {
    name = name,
    level = level,
    salary = salary,
    priority = priority,
    inheritsLevel = inheritsLevel,
    reason = reason
  })

  if result ~= true then
    sendResponse(src, requestId, fail(gradeErrorMessage(dataOrErr)))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:archiveOrg', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeOrgCode(payload.orgCode)
  local reason = normalizeReason(payload.reason)

  if not orgCode then sendResponse(src, requestId, fail('Organizacao invalida.')) return end
  if not canUpdateOrgBasic(src) then sendResponse(src, requestId, fail('Voce nao tem permissao para arquivar esta organizacao.')) return end
  if rateLimited(ArchiveActionRateLimit, src) then sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.')) return end

  local result, dataOrErr = safeExport('mz_org', 'ArchiveOrg', src, orgCode, reason)
  if result ~= true then
    sendResponse(src, requestId, fail(archiveErrorMessage(dataOrErr)))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:reactivateOrg', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeOrgCode(payload.orgCode)
  local reason = normalizeReason(payload.reason)

  if not orgCode then sendResponse(src, requestId, fail('Organizacao invalida.')) return end
  if not canUpdateOrgBasic(src) then sendResponse(src, requestId, fail('Voce nao tem permissao para reativar esta organizacao.')) return end
  if rateLimited(ArchiveActionRateLimit, src) then sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.')) return end

  local result, dataOrErr = safeExport('mz_org', 'ReactivateOrg', src, orgCode, reason)
  if result ~= true then
    sendResponse(src, requestId, fail(archiveErrorMessage(dataOrErr)))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:disableGrade', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeOrgCode(payload.orgCode)
  local gradeId = normalizeGradeId(payload.gradeId)
  local reason = normalizeReason(payload.reason)

  if not orgCode then sendResponse(src, requestId, fail('Organizacao invalida.')) return end
  if not gradeId then sendResponse(src, requestId, fail('Cargo invalido.')) return end
  if not canUpdateOrgBasic(src) then sendResponse(src, requestId, fail('Voce nao tem permissao para gerenciar cargos.')) return end
  if rateLimited(GradeActionRateLimit, src) then sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.')) return end

  local result, dataOrErr = safeExport('mz_org', 'DisableOrgGrade', src, orgCode, gradeId, reason)
  if result ~= true then
    sendResponse(src, requestId, fail(gradeErrorMessage(dataOrErr)))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:reactivateGrade', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeOrgCode(payload.orgCode)
  local gradeId = normalizeGradeId(payload.gradeId)
  local reason = normalizeReason(payload.reason)

  if not orgCode then sendResponse(src, requestId, fail('Organizacao invalida.')) return end
  if not gradeId then sendResponse(src, requestId, fail('Cargo invalido.')) return end
  if not canUpdateOrgBasic(src) then sendResponse(src, requestId, fail('Voce nao tem permissao para gerenciar cargos.')) return end
  if rateLimited(GradeActionRateLimit, src) then sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.')) return end

  local result, dataOrErr = safeExport('mz_org', 'ReactivateOrgGrade', src, orgCode, gradeId, reason)
  if result ~= true then
    sendResponse(src, requestId, fail(gradeErrorMessage(dataOrErr)))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:addGradePermission', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeOrgCode(payload.orgCode)
  local gradeId = normalizeGradeId(payload.gradeId)
  local permission = normalizePermission(payload.permission)
  local reason = normalizeReason(payload.reason)

  if not orgCode then sendResponse(src, requestId, fail('Organizacao invalida.')) return end
  if not gradeId then sendResponse(src, requestId, fail('Cargo invalido.')) return end
  if not permission then sendResponse(src, requestId, fail('Permissao invalida.')) return end
  if not canUpdateOrgBasic(src) then sendResponse(src, requestId, fail('Voce nao tem permissao para gerenciar permissoes.')) return end
  if rateLimited(GradeActionRateLimit, src) then sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.')) return end

  local result, dataOrErr = safeExport('mz_org', 'AddOrgGradePermission', src, orgCode, gradeId, permission, reason)
  if result ~= true then
    sendResponse(src, requestId, fail(gradePermissionErrorMessage(dataOrErr)))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)

RegisterNetEvent('mz_org:server:removeGradePermission', function(requestId, payload)
  local src = source
  payload = type(payload) == 'table' and payload or {}

  local orgCode = normalizeOrgCode(payload.orgCode)
  local gradeId = normalizeGradeId(payload.gradeId)
  local permission = normalizePermission(payload.permission)
  local reason = normalizeReason(payload.reason)

  if not orgCode then sendResponse(src, requestId, fail('Organizacao invalida.')) return end
  if not gradeId then sendResponse(src, requestId, fail('Cargo invalido.')) return end
  if not permission then sendResponse(src, requestId, fail('Permissao invalida.')) return end
  if not canUpdateOrgBasic(src) then sendResponse(src, requestId, fail('Voce nao tem permissao para gerenciar permissoes.')) return end
  if rateLimited(GradeActionRateLimit, src) then sendResponse(src, requestId, fail('Aguarde alguns segundos e tente novamente.')) return end

  local result, dataOrErr = safeExport('mz_org', 'RemoveOrgGradePermission', src, orgCode, gradeId, permission, reason)
  if result ~= true then
    sendResponse(src, requestId, fail(gradePermissionErrorMessage(dataOrErr)))
    return
  end

  sendResponse(src, requestId, ok(dataOrErr or {}))
end)
