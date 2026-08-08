MZOrgMenuFeatures = MZOrgMenuFeatures or {}

local ALL_TYPES = { job = true, gang = true, business = true, government = true, vip = true, event = true }

local FEATURES = {
  overview = {
    label = 'Visao geral',
    description = 'Resumo estrutural da organizacao.',
    applicableTypes = ALL_TYPES,
    viewAny = { 'org.view' }
  },
  members = {
    label = 'Membros',
    description = 'Consulta de membros da organizacao.',
    applicableTypes = ALL_TYPES,
    viewAny = { 'members.view', 'org.view' }
  },
  grades = {
    label = 'Cargos',
    description = 'Hierarquia e cargos organizacionais.',
    applicableTypes = { job = true, gang = true, business = true, government = true, event = true },
    viewAny = { 'members.view', 'manage.permissions', 'manage.members' }
  },
  bank = {
    label = 'Financeiro',
    description = 'Conta compartilhada oficial da organizacao.',
    applicableTypes = { job = true, gang = true, business = true, government = true },
    requiresFlag = 'hasSharedAccount',
    viewAny = { 'account.view', 'account.deposit', 'account.withdraw', 'account.manage' }
  },
  goals = {
    label = 'Metas',
    description = 'Metas e progresso organizacional.',
    applicableTypes = { job = true, gang = true, business = true, government = true, event = true },
    viewAny = { 'goals.view', 'goals.manage' }
  },
  recruitment = {
    label = 'Recrutamento',
    description = 'Candidaturas e convites organizacionais.',
    applicableTypes = { job = true, gang = true, business = true, government = true, event = true },
    viewAny = { 'recruitment.view', 'recruitment.manage', 'members.invite', 'manage.members' }
  },
  logs = {
    label = 'Logs',
    description = 'Historico estrutural da organizacao.',
    applicableTypes = ALL_TYPES,
    viewAny = { 'logs.view' }
  },
  settings = {
    label = 'Configuracoes',
    description = 'Configuracoes organizacionais autorizadas.',
    applicableTypes = ALL_TYPES,
    viewAny = { 'org.settings' }
  }
}

local ORDER = { 'overview', 'members', 'grades', 'bank', 'goals', 'recruitment', 'logs', 'settings' }

local function permissionSet(capabilities)
  local set = {}
  for key, value in pairs(type(capabilities) == 'table' and capabilities or {}) do
    local permission = type(key) == 'number' and value or (value == true and key or nil)
    if type(permission) == 'string' and not permission:lower():match('^staff%.') then
      set[permission] = true
    end
  end
  return set
end

local function canView(spec, permissions)
  for _, permission in ipairs(spec.viewAny or {}) do
    if permissions[permission] then return true end
  end
  return false
end

function MZOrgMenuFeatures.Resolve(defaults, overrides, capabilities, flags, status)
  if tostring(status or ''):lower() ~= 'active' then return {} end

  defaults = type(defaults) == 'table' and defaults or {}
  overrides = type(overrides) == 'table' and overrides or {}
  flags = type(flags) == 'table' and flags or {}
  local permissions = permissionSet(capabilities)
  local enabled = {}

  for _, featureName in ipairs(ORDER) do
    local desired = overrides[featureName]
    if type(desired) ~= 'boolean' then desired = defaults[featureName] == true end
    local spec = FEATURES[featureName]
    local orgType = flags.orgType or flags.type or 'job'
    local applicable = MZOrgMenuFeatures.IsApplicable(featureName, orgType)
    local flagAllowed = not spec.requiresFlag or flags[spec.requiresFlag] == true
    if applicable and desired and flagAllowed and canView(spec, permissions) then
      enabled[#enabled + 1] = featureName
    end
  end

  return enabled
end

function MZOrgMenuFeatures.GetContract()
  return FEATURES
end

function MZOrgMenuFeatures.GetOrder()
  local result = {}
  for _, name in ipairs(ORDER) do result[#result + 1] = name end
  return result
end

function MZOrgMenuFeatures.IsKnown(name)
  return type(name) == 'string' and FEATURES[name] ~= nil
end

function MZOrgMenuFeatures.IsApplicable(name, orgType)
  local spec = FEATURES[tostring(name or '')]
  if not spec then return false end
  orgType = MZOrgMenuProfiles and MZOrgMenuProfiles.NormalizeType(orgType) or tostring(orgType or '')
  return spec.applicableTypes[orgType] == true
end

function MZOrgMenuFeatures.GetTypeFlags(orgType)
  orgType = MZOrgMenuProfiles and MZOrgMenuProfiles.NormalizeType(orgType) or tostring(orgType or '')
  return {
    hasSharedAccount = orgType == 'job' or orgType == 'gang' or orgType == 'business' or orgType == 'government',
    hasSalary = orgType == 'job' or orgType == 'business' or orgType == 'government',
    hasStorage = orgType ~= 'vip' and orgType ~= 'event'
  }
end

function MZOrgMenuFeatures.ValidateOverrides(overrides, orgType, flags)
  if type(overrides) ~= 'table' then return false, 'invalid_features' end
  flags = type(flags) == 'table' and flags or MZOrgMenuFeatures.GetTypeFlags(orgType)
  local result = {}
  for name, value in pairs(overrides) do
    local spec = FEATURES[name]
    if not spec then return false, 'unknown_feature:' .. tostring(name) end
    if type(value) ~= 'boolean' then return false, 'invalid_feature_value:' .. tostring(name) end
    if not MZOrgMenuFeatures.IsApplicable(name, orgType) then
      return false, 'feature_not_applicable:' .. tostring(name)
    end
    if value == true and spec.requiresFlag and flags[spec.requiresFlag] ~= true then
      return false, 'feature_dependency_unavailable:' .. tostring(name)
    end
    result[name] = value
  end
  return true, result
end

function MZOrgMenuFeatures.ComputeTypeImpact(currentType, targetType, overrides, currentAppearance)
  overrides = type(overrides) == 'table' and overrides or {}
  currentAppearance = type(currentAppearance) == 'table' and currentAppearance or {}
  local currentProfile = MZOrgMenuProfiles.Get(currentType)
  local targetProfile = MZOrgMenuProfiles.Get(targetType)
  local enabled, disabled, incompatible = {}, {}, {}

  for _, name in ipairs(ORDER) do
    local before = overrides[name]
    if type(before) ~= 'boolean' then before = currentProfile.defaultFeatures[name] == true end
    local after = overrides[name]
    if type(after) ~= 'boolean' then after = targetProfile.defaultFeatures[name] == true end
    if not MZOrgMenuFeatures.IsApplicable(name, targetType) then
      if overrides[name] ~= nil then incompatible[#incompatible + 1] = name end
      after = false
    end
    if before ~= after then
      local target = after and enabled or disabled
      target[#target + 1] = name
    end
  end

  local incompatibleAppearance = {}
  if currentAppearance.profile ~= nil then incompatibleAppearance[#incompatibleAppearance + 1] = 'profile' end
  return {
    fromType = MZOrgMenuProfiles.NormalizeType(currentType),
    toType = MZOrgMenuProfiles.NormalizeType(targetType),
    enabled = enabled,
    disabled = disabled,
    incompatibleFeatures = incompatible,
    incompatibleAppearance = incompatibleAppearance,
    theme = {
      from = MZOrgMenuProfiles.NormalizeType(currentType),
      to = MZOrgMenuProfiles.NormalizeType(targetType)
    }
  }
end

function MZOrgMenuFeatures.ExplainConfiguration(defaults, overrides, flags, status)
  defaults = type(defaults) == 'table' and defaults or {}
  overrides = type(overrides) == 'table' and overrides or {}
  flags = type(flags) == 'table' and flags or {}
  status = tostring(status or ''):lower()
  local result = {}

  for _, featureName in ipairs(ORDER) do
    local spec = FEATURES[featureName]
    local profileEnabled = defaults[featureName] == true
    local override = nil
    if type(overrides[featureName]) == 'boolean' then override = overrides[featureName] end
    local configured = override == nil and profileEnabled or override
    local applicable = MZOrgMenuFeatures.IsApplicable(featureName, flags.orgType or flags.type or 'job')
    local dependencyAvailable = not spec.requiresFlag or flags[spec.requiresFlag] == true
    local effective = status == 'active' and applicable and configured and dependencyAvailable
    local origin
    if status ~= 'active' then
      origin = 'organization_status'
    elseif not applicable then
      origin = 'not_applicable'
    elseif override ~= nil then
      origin = 'organization_override'
    elseif not dependencyAvailable then
      origin = 'dependency:' .. tostring(spec.requiresFlag)
    else
      origin = 'type_profile'
    end

    result[#result + 1] = {
      name = featureName,
      label = spec.label,
      description = spec.description,
      profileEnabled = profileEnabled,
      override = override,
      dependency = spec.requiresFlag,
      dependencyAvailable = dependencyAvailable,
      applicable = applicable,
      effective = effective == true,
      origin = origin
    }
  end

  return result
end
