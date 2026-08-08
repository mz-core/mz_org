MZOrgMenuMutations = MZOrgMenuMutations or {}

local ORG_TYPES = { job = true, gang = true, business = true, government = true, vip = true, event = true }
local DUTY_ORG_TYPES = { job = true, gang = true, business = true, government = true, event = true }
local APPEARANCE_FIELDS = {
  accent = true, accent2 = true, brand = true, headerIcon = true,
  badge = true, position = true, width = true
}
local PUBLIC_METADATA_FIELDS = { category = true, locale = true }
local POSITIONS = { left = true, right = true, center = true }
local OFFICIAL_CAPABILITIES = {}
for _, capability in ipairs(type(MZOrgCapabilities) == 'table' and MZOrgCapabilities or {}) do
  if type(capability) == 'string' and not capability:lower():match('^staff%.') then
    OFFICIAL_CAPABILITIES[capability] = true
  end
end

local function trim(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  return value ~= '' and value or nil
end

local function safeText(value, minLength, maxLength, optional)
  value = trim(value)
  if not value then return optional and nil or false end
  if #value < (minLength or 1) or #value > (maxLength or 128) then return false end
  local lower = value:lower()
  if value:find('[<>]') or lower:find('javascript:', 1, true) or lower:find('data:', 1, true)
    or lower:find('http://', 1, true) or lower:find('https://', 1, true)
    or lower:find('url(', 1, true) or value:find('[{}]') then
    return false
  end
  return value
end

local function rejectUnknown(payload, allowed)
  if type(payload) ~= 'table' then return false, 'invalid_payload' end
  for key in pairs(payload) do
    if not allowed[key] then return false, 'unknown_field:' .. tostring(key) end
    if type(key) == 'string' and key:lower():match('^staff%.') then
      return false, 'staff_permission_global_only'
    end
  end
  return true
end

local function normalizeMetadata(metadata)
  if metadata == nil then return true, nil end
  if type(metadata) ~= 'table' then return false, 'invalid_metadata' end
  local result = {}
  for key, value in pairs(metadata) do
    if not PUBLIC_METADATA_FIELDS[key] then return false, 'unknown_metadata:' .. tostring(key) end
    local normalized = safeText(value, 1, key == 'locale' and 16 or 48, true)
    if value ~= nil and trim(value) and not normalized then return false, 'invalid_metadata:' .. tostring(key) end
    result[key] = normalized
  end
  return true, result
end

local function normalizeAppearanceValue(field, value)
  if field == 'accent' or field == 'accent2' then
    value = trim(value)
    if not value or not value:match('^#%x%x%x%x%x%x$') then return nil, 'invalid_color:' .. field end
    return value:upper()
  end
  if field == 'position' then
    value = trim(value)
    value = value and value:lower() or nil
    if not POSITIONS[value] then return nil, 'invalid_position' end
    return value
  end
  if field == 'width' then
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < 320 or value > 640 then return nil, 'invalid_width' end
    return value
  end
  if field == 'headerIcon' then
    value = trim(value)
    if not value or not value:match('^[a-z0-9][a-z0-9_-]*$')
      or not MZOrgMenuProfiles.IsAllowedIcon(value) then
      return nil, 'invalid_icon'
    end
    return value
  end
  local limit = field == 'badge' and 16 or 48
  value = safeText(value, 1, limit, false)
  if not value then return nil, 'invalid_text:' .. field end
  return value
end

function MZOrgMenuMutations.NormalizeOrgType(value)
  value = trim(value)
  value = value and value:lower() or nil
  return value and ORG_TYPES[value] and value or nil
end

function MZOrgMenuMutations.NormalizeOrgCode(value)
  value = trim(value)
  if not value then return nil end
  value = value:lower()
  if #value < 2 or #value > 48 or not value:match('^[a-z0-9][a-z0-9_-]*$') then return nil end
  return value
end

function MZOrgMenuMutations.NormalizeReason(value)
  return safeText(value, 3, 255, false) or nil
end

function MZOrgMenuMutations.SupportsDutyType(orgType)
  orgType = MZOrgMenuMutations.NormalizeOrgType(orgType)
  return orgType ~= nil and DUTY_ORG_TYPES[orgType] == true
end

function MZOrgMenuMutations.SanitizeDutyPoint(payload, orgType)
  local ok, err = rejectUnknown(payload, {
    dutyPoint = true, reason = true, organizationRevision = true,
    orgCode = true, _context = true, requestId = true
  })
  if not ok then return false, err end
  if not MZOrgMenuMutations.SupportsDutyType(orgType) then return false, 'invalid_duty_type' end

  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  if type(payload.dutyPoint) ~= 'table' then return false, 'duty_point_required' end

  local pointOk, pointError = rejectUnknown(payload.dutyPoint, {
    enabled = true, coords = true, radius = true, drawDistance = true, label = true
  })
  if not pointOk then return false, pointError end
  if type(payload.dutyPoint.enabled) ~= 'boolean' then return false, 'invalid_duty_point' end
  if payload.dutyPoint.enabled == false then
    return true, { dutyPoint = { enabled = false }, reason = reason }
  end

  local coords = payload.dutyPoint.coords
  if type(coords) ~= 'table' then return false, 'invalid_coords' end
  local coordsOk, coordsError = rejectUnknown(coords, { x = true, y = true, z = true })
  if not coordsOk then return false, coordsError end
  local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
  local function finite(value)
    return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge
  end
  if not finite(x) or not finite(y) or not finite(z)
    or x < -10000.0 or x > 10000.0 or y < -10000.0 or y > 10000.0
    or z < -1000.0 or z > 3000.0 then
    return false, 'invalid_coords'
  end

  local radius = tonumber(payload.dutyPoint.radius)
  if not finite(radius) or radius < 1.0 or radius > 5.0 then return false, 'invalid_radius' end
  local drawDistance = tonumber(payload.dutyPoint.drawDistance)
  if not finite(drawDistance) or drawDistance < 5.0 or drawDistance > 50.0
    or drawDistance < radius then
    return false, 'invalid_draw_distance'
  end
  local label = safeText(payload.dutyPoint.label, 2, 64, false)
  if not label then return false, 'invalid_label' end

  return true, {
    dutyPoint = {
      enabled = true,
      coords = { x = x, y = y, z = z },
      radius = radius,
      drawDistance = drawDistance,
      label = label
    },
    reason = reason
  }
end

function MZOrgMenuMutations.NormalizeCitizenId(value)
  value = trim(value)
  if not value or #value > 64 or not value:match('^[%w:_-]+$') then return nil end
  return value
end

function MZOrgMenuMutations.IsOfficialCapability(value)
  value = trim(value)
  return value ~= nil and OFFICIAL_CAPABILITIES[value] == true
end

function MZOrgMenuMutations.GetOfficialCapabilities()
  local result = {}
  for _, capability in ipairs(type(MZOrgCapabilities) == 'table' and MZOrgCapabilities or {}) do
    if MZOrgMenuMutations.IsOfficialCapability(capability) then result[#result + 1] = capability end
  end
  return result
end

function MZOrgMenuMutations.SanitizeStaffMember(payload, operation)
  local ok, err = rejectUnknown(payload, {
    targetCitizenId = true, gradeLevel = true, gradeCode = true, reason = true,
    organizationRevision = true, orgCode = true, _context = true, requestId = true
  })
  if not ok then return false, err end
  local targetCitizenId = MZOrgMenuMutations.NormalizeCitizenId(payload.targetCitizenId)
  if not targetCitizenId then return false, 'invalid_target' end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  local result = { targetCitizenId = targetCitizenId, reason = reason }
  if operation == 'invite' then
    result.gradeLevel = tonumber(payload.gradeLevel)
    result.gradeCode = safeText(payload.gradeCode, 1, 48, true)
    if not result.gradeLevel and not result.gradeCode then return false, 'invalid_grade' end
  end
  return true, result
end

function MZOrgMenuMutations.SanitizeStaffGrade(payload, operation)
  local ok, err = rejectUnknown(payload, {
    gradeId = true, level = true, code = true, name = true, salary = true,
    inheritsLevel = true, priority = true, capability = true, reason = true,
    organizationRevision = true, orgCode = true, _context = true, requestId = true
  })
  if not ok then return false, err end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  local result = { reason = reason }

  if operation ~= 'create' then
    result.gradeId = tonumber(payload.gradeId)
    if not result.gradeId or result.gradeId <= 0 then return false, 'invalid_grade' end
  end
  if operation == 'create' or operation == 'edit' then
    result.level = tonumber(payload.level)
    result.name = safeText(payload.name, 2, 80, false)
    result.salary = tonumber(payload.salary) or 0
    result.inheritsLevel = payload.inheritsLevel ~= nil and tonumber(payload.inheritsLevel) or nil
    result.priority = payload.priority ~= nil and tonumber(payload.priority) or result.level
    if not result.level or result.level < 0 or result.level > 1000 or result.level ~= math.floor(result.level) then
      return false, 'invalid_grade_level'
    end
    if not result.name then return false, 'invalid_grade_name' end
    if result.salary < 0 or result.salary > 100000000 or result.salary ~= math.floor(result.salary) then
      return false, 'invalid_salary'
    end
    if result.inheritsLevel and (result.inheritsLevel < 0 or result.inheritsLevel > 1000
      or result.inheritsLevel ~= math.floor(result.inheritsLevel)) then
      return false, 'invalid_inheritance'
    end
    if not result.priority or result.priority < 0 or result.priority > 1000
      or result.priority ~= math.floor(result.priority) then
      return false, 'invalid_priority'
    end
    if operation == 'create' then
      result.code = safeText(payload.code, 1, 48, false)
      if not result.code or not result.code:match('^[a-z0-9][a-z0-9_-]*$') then return false, 'invalid_grade_code' end
    end
  elseif operation == 'add_capability' or operation == 'remove_capability' then
    if not MZOrgMenuMutations.IsOfficialCapability(payload.capability) then
      return false, 'invalid_permission'
    end
    result.capability = tostring(payload.capability)
  end
  return true, result
end

function MZOrgMenuMutations.SanitizeAppearanceValues(values)
  if values == nil then return true, {} end
  if type(values) ~= 'table' then return false, 'invalid_appearance' end
  local result = {}
  for field, value in pairs(values) do
    if not APPEARANCE_FIELDS[field] then return false, 'unknown_appearance_field:' .. tostring(field) end
    if value ~= nil and trim(value) then
      local normalized, err = normalizeAppearanceValue(field, value)
      if normalized == nil then return false, err end
      result[field] = normalized
    end
  end
  return true, result
end

function MZOrgMenuMutations.SanitizeCreate(payload)
  local ok, err = rejectUnknown(payload, {
    code = true, name = true, type = true, state = true, displayName = true,
    description = true, metadata = true, features = true, appearance = true, reason = true,
    _context = true, requestId = true
  })
  if not ok then return false, err end
  local code = MZOrgMenuMutations.NormalizeOrgCode(payload.code)
  if not code then return false, 'invalid_code' end
  local name = safeText(payload.name, 2, 120, false)
  if not name then return false, 'invalid_name' end
  local orgType = MZOrgMenuMutations.NormalizeOrgType(payload.type)
  if not orgType then return false, 'invalid_type' end
  local state = trim(payload.state)
  state = state and state:lower() or 'active'
  if state ~= 'active' and state ~= 'archived' then return false, 'invalid_state' end
  local displayName = safeText(payload.displayName, 2, 48, true)
  local description = safeText(payload.description, 1, 160, true)
  local metadataOk, metadata = normalizeMetadata(payload.metadata)
  if not metadataOk then return false, metadata end
  local featuresOk, features = MZOrgMenuFeatures.ValidateOverrides(payload.features or {}, orgType, MZOrgMenuFeatures.GetTypeFlags(orgType))
  if not featuresOk then return false, features end
  local appearanceOk, appearance = MZOrgMenuMutations.SanitizeAppearanceValues(payload.appearance)
  if not appearanceOk then return false, appearance end
  if not displayName and not appearance.brand then return false, 'display_name_required' end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  return true, {
    code = code, name = name, type = orgType, state = state, reason = reason,
    public = { displayName = displayName, description = description, metadata = metadata or {} },
    features = features, appearance = appearance
  }
end

function MZOrgMenuMutations.SanitizeBasic(payload)
  local ok, err = rejectUnknown(payload, {
    name = true, displayName = true, description = true, metadata = true,
    reason = true, organizationRevision = true, orgCode = true, _context = true, requestId = true
  })
  if not ok then return false, err end
  local result = { reason = MZOrgMenuMutations.NormalizeReason(payload.reason) }
  if not result.reason then return false, 'invalid_reason' end
  if payload.name ~= nil then
    result.name = safeText(payload.name, 2, 120, false)
    if not result.name then return false, 'invalid_name' end
  end
  if payload.displayName ~= nil then
    result.displayName = safeText(payload.displayName, 2, 48, true)
    if trim(payload.displayName) and not result.displayName then return false, 'invalid_display_name' end
  end
  if payload.description ~= nil then
    result.description = safeText(payload.description, 1, 160, true)
    if trim(payload.description) and not result.description then return false, 'invalid_description' end
  end
  local metadataOk, metadata = normalizeMetadata(payload.metadata)
  if not metadataOk then return false, metadata end
  result.metadata = metadata
  if result.name == nil and payload.displayName == nil and payload.description == nil and metadata == nil then
    return false, 'empty_patch'
  end
  return true, result
end

function MZOrgMenuMutations.SanitizeFeaturePatch(payload, orgType, flags)
  local ok, err = rejectUnknown(payload, {
    overrides = true, remove = true, reason = true, organizationRevision = true,
    orgCode = true, _context = true, requestId = true
  })
  if not ok then return false, err end
  local valid, overrides = MZOrgMenuFeatures.ValidateOverrides(payload.overrides or {}, orgType, flags)
  if not valid then return false, overrides end
  local remove, seen = {}, {}
  for _, name in ipairs(type(payload.remove) == 'table' and payload.remove or {}) do
    if not MZOrgMenuFeatures.IsKnown(name) then return false, 'unknown_feature:' .. tostring(name) end
    if not seen[name] then remove[#remove + 1], seen[name] = name, true end
  end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  if next(overrides) == nil and #remove == 0 then return false, 'empty_patch' end
  return true, { overrides = overrides, remove = remove, reason = reason }
end

function MZOrgMenuMutations.SanitizeAppearancePatch(payload)
  local ok, err = rejectUnknown(payload, {
    overrides = true, remove = true, resetAll = true, reason = true,
    organizationRevision = true, orgCode = true, _context = true, requestId = true
  })
  if not ok then return false, err end
  local valid, overrides = MZOrgMenuMutations.SanitizeAppearanceValues(payload.overrides or {})
  if not valid then return false, overrides end
  local remove, seen = {}, {}
  for _, field in ipairs(type(payload.remove) == 'table' and payload.remove or {}) do
    if not APPEARANCE_FIELDS[field] then return false, 'unknown_appearance_field:' .. tostring(field) end
    if not seen[field] then remove[#remove + 1], seen[field] = field, true end
  end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  if next(overrides) == nil and #remove == 0 and payload.resetAll ~= true then return false, 'empty_patch' end
  return true, { overrides = overrides, remove = remove, resetAll = payload.resetAll == true, reason = reason }
end

function MZOrgMenuMutations.SanitizeTypeChange(payload)
  local ok, err = rejectUnknown(payload, {
    targetType = true, dropIncompatible = true, reason = true, organizationRevision = true,
    orgCode = true, _context = true, requestId = true
  })
  if not ok then return false, err end
  local targetType = MZOrgMenuMutations.NormalizeOrgType(payload.targetType)
  if not targetType then return false, 'invalid_type' end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  return true, { targetType = targetType, dropIncompatible = payload.dropIncompatible == true, reason = reason }
end

function MZOrgMenuMutations.SanitizeLifecycle(payload, operation, expectedCode)
  local ok, err = rejectUnknown(payload, {
    confirmCode = true, reason = true, organizationRevision = true,
    orgCode = true, _context = true, requestId = true
  })
  if not ok then return false, err end
  local reason = MZOrgMenuMutations.NormalizeReason(payload.reason)
  if not reason then return false, 'invalid_reason' end
  if operation == 'archive' and MZOrgMenuMutations.NormalizeOrgCode(payload.confirmCode) ~= expectedCode then
    return false, 'strong_confirmation_failed'
  end
  return true, { reason = reason, confirmCode = payload.confirmCode }
end

function MZOrgMenuMutations.GetAppearanceFields()
  local result = {}
  for _, field in ipairs({ 'accent', 'accent2', 'brand', 'headerIcon', 'badge', 'position', 'width' }) do
    result[#result + 1] = field
  end
  return result
end

function MZOrgMenuMutations.MergeDomainConfig(config, domain, patch, remove, resetAll)
  local result = {}
  for key, value in pairs(type(config) == 'table' and config or {}) do result[key] = value end
  local current = {}
  if not resetAll then
    for key, value in pairs(type(result[domain]) == 'table' and result[domain] or {}) do current[key] = value end
  end
  for _, key in ipairs(type(remove) == 'table' and remove or {}) do current[key] = nil end
  for key, value in pairs(type(patch) == 'table' and patch or {}) do current[key] = value end
  result[domain] = current
  return result
end
