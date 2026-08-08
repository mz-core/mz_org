local PAGE_SIZE = 25
local MAX_OFFSET = 10000

local function respond(sourceId, requestId, ok, dataOrError)
  MZOrgOrganizationMenuServer.Respond(sourceId, requestId, ok, dataOrError)
end

local function authorize(sourceId, requestId, payload, moduleName, featureName)
  local organization, errorMessage = MZOrgOrganizationMenuServer.AuthorizeRead(
    sourceId, requestId, payload, moduleName, featureName
  )
  if not organization then respond(sourceId, requestId, false, errorMessage) end
  return organization
end

local function offsetFrom(payload)
  local offset = math.floor(tonumber(type(payload) == 'table' and payload.offset) or 0)
  return math.max(0, math.min(MAX_OFFSET, offset))
end

local function pagination(offset, returned)
  return { offset = offset, limit = PAGE_SIZE, returned = returned }
end

local function slice(rows, offset)
  local items = {}
  for index = offset + 1, math.min(#rows, offset + PAGE_SIZE) do items[#items + 1] = rows[index] end
  return items
end

local function memberDto(member)
  return {
    citizenid = member.citizenid,
    name = member.name,
    gradeLevel = tonumber(member.gradeLevel or member.grade) or 0,
    gradeCode = member.gradeCode,
    gradeName = member.gradeName,
    isLeader = member.isLeader == true,
    isDuty = member.isDuty == true,
    joinedAt = member.joinedAt,
    lastSeen = member.lastSeen,
    status = member.status
  }
end

local function gradeDto(grade, memberCounts, exposeCapabilities)
  local result = {
    id = tonumber(grade.id) or grade.id,
    level = tonumber(grade.level) or 0,
    code = grade.code,
    name = grade.name,
    salary = tonumber(grade.salary) or 0,
    priority = tonumber(grade.priority) or tonumber(grade.level) or 0,
    active = grade.active == true,
    inheritsLevel = tonumber(grade.inheritsLevel),
    inheritsCode = grade.inheritsCode,
    memberCount = memberCounts[tonumber(grade.level) or 0] or 0
  }
  if exposeCapabilities then
    result.capabilities = type(grade.capabilities) == 'table' and grade.capabilities or {}
    result.directCapabilities = type(grade.directCapabilities) == 'table' and grade.directCapabilities or {}
  end
  return result
end

local function transactionDto(item)
  return {
    id = tonumber(item.id) or item.id,
    type = item.type,
    amount = tonumber(item.amount) or 0,
    balanceBefore = tonumber(item.balanceBefore) or 0,
    balanceAfter = tonumber(item.balanceAfter) or 0,
    actorCitizenId = item.actorCitizenId,
    actorName = item.actorName,
    reason = item.reason,
    createdAt = item.createdAt
  }
end

local function goalDto(item)
  return {
    id = tonumber(item.id) or item.id,
    title = item.title,
    description = item.description,
    type = item.type,
    status = item.status,
    target = tonumber(item.target) or 0,
    progress = tonumber(item.progress) or 0,
    progressPercent = tonumber(item.progressPercent) or 0,
    startsAt = item.startsAt,
    endsAt = item.endsAt,
    createdByName = item.createdByName,
    createdAt = item.createdAt,
    updatedAt = item.updatedAt
  }
end

local function recruitmentDto(item)
  return {
    id = tonumber(item.id) or item.id,
    candidateCitizenId = item.candidateCitizenId or item.targetCitizenId,
    candidateName = item.candidateName or item.targetName,
    status = item.status,
    desiredGradeLevel = tonumber(item.desiredGradeLevel),
    desiredGradeCode = item.desiredGradeCode,
    note = item.note or item.message,
    createdByName = item.createdByName,
    reviewedByName = item.reviewedByName,
    reviewedAt = item.reviewedAt,
    decisionNote = item.decisionNote,
    createdAt = item.createdAt,
    updatedAt = item.updatedAt
  }
end

local function logDto(item)
  return {
    id = tonumber(item.id) or item.id,
    action = item.action,
    category = item.category,
    severity = item.severity,
    auditId = item.auditId,
    actorName = item.actorName,
    actorCitizenId = item.actorCitizenId,
    targetName = item.targetName,
    targetCitizenId = item.targetCitizenId,
    message = item.message,
    reason = item.reason,
    createdAt = item.createdAt
  }
end

RegisterNetEvent('mz_org:server:organizationListMembers', function(requestId, payload)
  local sourceId = source
  local organization = authorize(sourceId, requestId, payload, 'members', 'members')
  if not organization then return end

  local rows, readError = MZOrgSecurity.SafeExport('ListOrgMembers', sourceId, organization.code)
  if type(rows) ~= 'table' then
    respond(sourceId, requestId, false, readError == 'org_archived' and 'Organizacao arquivada.' or 'Leitura de membros indisponivel.')
    return
  end

  local offset = offsetFrom(payload)
  local selected = slice(rows, offset)
  local items = {}
  for _, member in ipairs(selected) do items[#items + 1] = memberDto(member) end
  local grades = {}
  local topGradeLevel = 0
  local accessModel = MZOrgSecurity.SafeExport('GetOrgAccessModel', sourceId, organization.code)
  if type(accessModel) == 'table' then
    for _, grade in ipairs(accessModel.grades or {}) do
      if grade.active == true then
        topGradeLevel = math.max(topGradeLevel, tonumber(grade.level) or 0)
        grades[#grades + 1] = {
          id = tonumber(grade.id) or grade.id,
          level = tonumber(grade.level) or 0,
          code = grade.code,
          name = grade.name
        }
      end
    end
    table.sort(grades, function(left, right) return left.level < right.level end)
  end

  local capabilityGranted = false
  for _, capability in ipairs(organization.capabilities or {}) do
    if capability == 'members.set_leader' then
      capabilityGranted = true
      break
    end
  end
  local interface = type(Config.Interface) == 'table' and Config.Interface or {}
  local actorLevel = tonumber(organization.grade and organization.grade.level) or 0
  local leadershipEnabled = organization.supportsLeadership == true
    and interface.organizationLeadershipTransfer == true
  local canTransferLeadership = leadershipEnabled
    and capabilityGranted
    and MZOrgSecurity.CanOrg(sourceId, organization.code, 'members.set_leader')
    and actorLevel > 0
    and actorLevel == topGradeLevel

  MZOrgOrganizationMenuServer.RespondRead(sourceId, requestId, payload, {
    items = items,
    grades = grades,
    leadership = {
      enabled = leadershipEnabled,
      canTransfer = canTransferLeadership == true
    },
    pagination = pagination(offset, #items)
  })
end)

RegisterNetEvent('mz_org:server:organizationListGrades', function(requestId, payload)
  local sourceId = source
  local organization = authorize(sourceId, requestId, payload, 'grades', 'grades')
  if not organization then return end

  local accessModel, accessError = MZOrgSecurity.SafeExport('GetOrgAccessModel', sourceId, organization.code)
  if type(accessModel) ~= 'table' then
    respond(sourceId, requestId, false, accessError == 'forbidden' and 'Sem permissao para consultar cargos.' or 'Leitura de cargos indisponivel.')
    return
  end
  local members = MZOrgSecurity.SafeExport('ListOrgMembers', sourceId, organization.code)
  if type(members) ~= 'table' then
    respond(sourceId, requestId, false, 'Contagem de membros por cargo indisponivel.')
    return
  end

  local counts = {}
  for _, member in ipairs(members) do
    local level = tonumber(member.gradeLevel or member.grade) or 0
    counts[level] = (counts[level] or 0) + 1
  end
  local exposeCapabilities = MZOrgSecurity.CanOrg(sourceId, organization.code, 'manage.permissions')
  local items = {}
  for _, grade in ipairs(accessModel.grades or {}) do
    items[#items + 1] = gradeDto(grade, counts, exposeCapabilities)
  end
  table.sort(items, function(left, right) return left.level > right.level end)
  MZOrgOrganizationMenuServer.RespondRead(sourceId, requestId, payload, {
    items = items,
    capabilitiesVisible = exposeCapabilities
  })
end)

RegisterNetEvent('mz_org:server:organizationGetFinance', function(requestId, payload)
  local sourceId = source
  local organization = authorize(sourceId, requestId, payload, 'bank', 'bank')
  if not organization then return end

  local accountOk, account = MZOrgSecurity.SafeExport('GetOrgAccount', sourceId, organization.code)
  if accountOk ~= true or type(account) ~= 'table' then
    respond(sourceId, requestId, false, account == 'org_has_no_shared_account' and 'Esta organizacao nao possui conta compartilhada.' or 'Conta organizacional indisponivel.')
    return
  end
  local offset = offsetFrom(payload)
  local transactionsOk, transactions = MZOrgSecurity.SafeExport('ListOrgAccountTransactions', sourceId, organization.code, {
    limit = PAGE_SIZE,
    offset = offset
  })
  if transactionsOk ~= true or type(transactions) ~= 'table' then
    respond(sourceId, requestId, false, 'Extrato organizacional indisponivel.')
    return
  end

  local items = {}
  for _, item in ipairs(transactions) do items[#items + 1] = transactionDto(item) end
  MZOrgOrganizationMenuServer.RespondRead(sourceId, requestId, payload, {
    account = {
      balance = tonumber(account.balance) or 0,
      currency = account.currency or 'R$'
    },
    items = items,
    pagination = pagination(offset, #items)
  })
end)

RegisterNetEvent('mz_org:server:organizationListGoals', function(requestId, payload)
  local sourceId = source
  local organization = authorize(sourceId, requestId, payload, 'goals', 'goals')
  if not organization then return end
  local offset = offsetFrom(payload)
  local rows, readError = MZOrgSecurity.SafeExport('ListOrgGoals', sourceId, {
    orgCode = organization.code,
    limit = PAGE_SIZE,
    offset = offset
  })
  if type(rows) ~= 'table' then
    respond(sourceId, requestId, false, readError == 'forbidden' and 'Sem permissao para consultar metas.' or 'Leitura de metas indisponivel.')
    return
  end
  local items = {}
  for _, item in ipairs(rows) do items[#items + 1] = goalDto(item) end
  MZOrgOrganizationMenuServer.RespondRead(sourceId, requestId, payload, {
    items = items,
    pagination = pagination(offset, #items)
  })
end)

RegisterNetEvent('mz_org:server:organizationListRecruitment', function(requestId, payload)
  local sourceId = source
  local organization = authorize(sourceId, requestId, payload, 'recruitment', 'recruitment')
  if not organization then return end
  local offset = offsetFrom(payload)
  local rows, readError = MZOrgSecurity.SafeExport('ListOrgRecruitment', sourceId, organization.code, {
    limit = PAGE_SIZE,
    offset = offset
  })
  if type(rows) ~= 'table' then
    respond(sourceId, requestId, false, readError == 'forbidden' and 'Sem permissao para consultar recrutamento.' or 'Leitura de recrutamento indisponivel.')
    return
  end
  local items = {}
  for _, item in ipairs(rows) do items[#items + 1] = recruitmentDto(item) end
  local grades = {}
  local accessModel = MZOrgSecurity.SafeExport('GetOrgAccessModel', sourceId, organization.code)
  if type(accessModel) == 'table' then
    for _, grade in ipairs(accessModel.grades or {}) do
      if grade.active == true then
        grades[#grades + 1] = {
          level = tonumber(grade.level) or 0,
          code = grade.code,
          name = grade.name
        }
      end
    end
    table.sort(grades, function(left, right) return left.level < right.level end)
  end
  MZOrgOrganizationMenuServer.RespondRead(sourceId, requestId, payload, {
    items = items,
    grades = grades,
    pagination = pagination(offset, #items)
  })
end)

RegisterNetEvent('mz_org:server:organizationListLogs', function(requestId, payload)
  local sourceId = source
  local organization = authorize(sourceId, requestId, payload, 'logs', 'logs')
  if not organization then return end
  local offset = offsetFrom(payload)
  local rows, readError = MZOrgSecurity.SafeExport('ListOrgLogsSecure', sourceId, organization.code, {
    limit = PAGE_SIZE,
    offset = offset
  })
  if type(rows) ~= 'table' then
    respond(sourceId, requestId, false, readError == 'forbidden' and 'Sem permissao para consultar logs.' or 'Leitura de logs indisponivel.')
    return
  end
  local items = {}
  for _, item in ipairs(rows) do items[#items + 1] = logDto(item) end
  MZOrgOrganizationMenuServer.RespondRead(sourceId, requestId, payload, {
    items = items,
    pagination = pagination(offset, #items)
  })
end)
