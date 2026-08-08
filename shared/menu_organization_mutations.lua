MZOrgOrganizationMutations = MZOrgOrganizationMutations or {}

local function trim(value, maxLength)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' or (maxLength and #value > maxLength) then return nil end
  return value
end

local function safeText(value, minLength, maxLength, optional)
  value = trim(value, maxLength)
  if not value then return optional and nil or false end
  if #value < (minLength or 1) then return false end
  local lower = value:lower()
  if value:find('[<>]') or value:find('[{}]') or lower:find('javascript:', 1, true)
    or lower:find('data:', 1, true) or lower:find('http://', 1, true)
    or lower:find('https://', 1, true) or lower:find('url(', 1, true) then
    return false
  end
  return value
end

local function onlyKeys(payload, allowed)
  if type(payload) ~= 'table' then return false, 'invalid_payload' end
  for key in pairs(payload) do
    if not allowed[key] then return false, 'unknown_field:' .. tostring(key) end
    if type(key) == 'string' and key:lower():match('^staff%.') then return false, 'staff_global_only' end
  end
  return true
end

function MZOrgOrganizationMutations.SanitizeMember(payload, operation)
  local allowed, allowError = onlyKeys(payload, {
    orgCode = true, organizationRevision = true, targetCitizenId = true,
    gradeLevel = true, gradeCode = true, reason = true, _context = true, requestId = true
  })
  if not allowed then return false, allowError end
  local citizenid = MZOrgMenuMutations.NormalizeCitizenId(payload.targetCitizenId)
  if not citizenid then return false, 'invalid_target' end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  local result = { targetCitizenId = citizenid, reason = reason }
  if operation == 'invite' then
    result.gradeLevel = tonumber(payload.gradeLevel)
    result.gradeCode = trim(payload.gradeCode, 48)
    if not result.gradeLevel and not result.gradeCode then return false, 'invalid_grade' end
  end
  return true, result
end

function MZOrgOrganizationMutations.SanitizeLeadershipTransfer(payload)
  local allowed, allowError = onlyKeys(payload, {
    orgCode = true, organizationRevision = true, targetCitizenId = true,
    reason = true, _context = true, requestId = true
  })
  if not allowed then return false, allowError end
  local citizenid = MZOrgMenuMutations.NormalizeCitizenId(payload.targetCitizenId)
  if not citizenid then return false, 'invalid_target' end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason or #reason < 3 then return false, 'invalid_reason' end
  return true, { targetCitizenId = citizenid, reason = reason }
end

function MZOrgOrganizationMutations.SanitizeAccount(payload)
  local allowed, allowError = onlyKeys(payload, {
    orgCode = true, organizationRevision = true, amount = true, reason = true,
    _context = true, requestId = true
  })
  if not allowed then return false, allowError end
  local amount = tonumber(payload.amount)
  if not amount or amount ~= math.floor(amount) or amount < 1 or amount > 100000000 then
    return false, 'invalid_amount'
  end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  return true, { amount = amount, reason = reason }
end

function MZOrgOrganizationMutations.SanitizeGoal(payload)
  local allowed, allowError = onlyKeys(payload, {
    orgCode = true, organizationRevision = true, title = true, description = true,
    type = true, target = true, startsAt = true, endsAt = true, reason = true,
    _context = true, requestId = true
  })
  if not allowed then return false, allowError end
  local title = safeText(payload.title, 2, 120, false)
  local description = safeText(payload.description, 1, 1000, true)
  local goalType = safeText(payload.type, 1, 32, true) or 'manual'
  local target = tonumber(payload.target)
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not title then return false, 'invalid_title' end
  if payload.description ~= nil and trim(payload.description) and not description then return false, 'invalid_description' end
  if not target or target ~= math.floor(target) or target < 1 or target > 100000 then return false, 'invalid_target' end
  if not reason then return false, 'invalid_reason' end
  return true, {
    title = title, description = description, type = goalType, target = target,
    startsAt = trim(payload.startsAt, 32), endsAt = trim(payload.endsAt, 32), reason = reason
  }
end

function MZOrgOrganizationMutations.SanitizeRecruitment(payload, operation)
  local allowed, allowError = onlyKeys(payload, {
    orgCode = true, organizationRevision = true, recruitmentId = true,
    targetCitizenId = true, desiredGradeLevel = true, desiredGradeCode = true,
    note = true, reason = true, _context = true, requestId = true
  })
  if not allowed then return false, allowError end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  local result = { reason = reason, note = safeText(payload.note, 1, 1000, true) }
  if operation == 'create' then
    result.targetCitizenId = MZOrgMenuMutations.NormalizeCitizenId(payload.targetCitizenId)
    result.desiredGradeLevel = tonumber(payload.desiredGradeLevel)
    result.desiredGradeCode = trim(payload.desiredGradeCode, 48)
    if not result.targetCitizenId then return false, 'invalid_target' end
    if not result.desiredGradeLevel and not result.desiredGradeCode then return false, 'invalid_grade' end
  else
    result.recruitmentId = tonumber(payload.recruitmentId)
    if not result.recruitmentId or result.recruitmentId <= 0
      or result.recruitmentId ~= math.floor(result.recruitmentId) then
      return false, 'invalid_recruitment'
    end
    result.desiredGradeLevel = tonumber(payload.desiredGradeLevel)
    result.desiredGradeCode = trim(payload.desiredGradeCode, 48)
  end
  return true, result
end

function MZOrgOrganizationMutations.SanitizeGrade(payload, operation)
  local allowed, allowError = onlyKeys(payload, {
    orgCode = true, organizationRevision = true, gradeId = true, level = true,
    code = true, name = true, salary = true, inheritsLevel = true, priority = true,
    capability = true, reason = true, _context = true, requestId = true
  })
  if not allowed then return false, allowError end

  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  local result = { reason = reason }

  if operation ~= 'create' then
    result.gradeId = tonumber(payload.gradeId)
    if not result.gradeId or result.gradeId ~= math.floor(result.gradeId) or result.gradeId <= 0 then
      return false, 'invalid_grade'
    end
  end

  if operation == 'create' or operation == 'edit' then
    result.level = tonumber(payload.level)
    result.name = safeText(payload.name, 2, 80, false)
    result.salary = tonumber(payload.salary) or 0
    result.inheritsLevel = payload.inheritsLevel ~= nil and tonumber(payload.inheritsLevel) or nil
    result.priority = payload.priority ~= nil and tonumber(payload.priority) or result.level

    if not result.level or result.level ~= math.floor(result.level)
      or result.level < 1 or result.level > 1000 then
      return false, 'invalid_grade_level'
    end
    if not result.name then return false, 'invalid_grade_name' end
    if result.salary ~= math.floor(result.salary) or result.salary < 0 or result.salary > 100000000 then
      return false, 'invalid_salary'
    end
    if result.inheritsLevel and (
      result.inheritsLevel ~= math.floor(result.inheritsLevel)
      or result.inheritsLevel < 1 or result.inheritsLevel > 1000
      or result.inheritsLevel >= result.level
    ) then
      return false, 'invalid_inheritance'
    end
    if not result.priority or result.priority ~= math.floor(result.priority)
      or result.priority < 0 or result.priority > 1000 then
      return false, 'invalid_priority'
    end

    if operation == 'create' then
      result.code = trim(payload.code, 48)
      result.code = result.code and result.code:lower() or nil
      if not result.code or #result.code < 2 or not result.code:match('^[a-z0-9][a-z0-9_-]*$') then
        return false, 'invalid_grade_code'
      end
    end
  elseif operation == 'add_capability' or operation == 'remove_capability' then
    if not MZOrgMenuMutations.IsOfficialCapability(payload.capability) then
      return false, 'invalid_permission'
    end
    result.capability = tostring(payload.capability)
  end

  return true, result
end
