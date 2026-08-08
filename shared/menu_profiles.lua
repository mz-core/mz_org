MZOrgMenuProfiles = MZOrgMenuProfiles or {}

local MIN_WIDTH = 320
local MAX_WIDTH = 640
local POSITIONS = { left = true, right = true, center = true }
local ICONS = {
  shield = true,
  skull = true,
  briefcase = true,
  landmark = true,
  crown = true,
  calendar = true,
  settings = true,
  users = true,
  info = true,
  building = true,
  archive = true,
  layers = true,
  eye = true
}

local PROFILES = {
  job = {
    label = 'Organizacao',
    panelTitle = 'Painel da Organizacao',
    icon = 'shield',
    accent = '#2563EB',
    accent2 = '#06B6D4',
    defaultFeatures = {
      overview = true, members = true, grades = true, bank = true,
      goals = true, recruitment = true, logs = true
    }
  },
  gang = {
    label = 'Faccao',
    panelTitle = 'Painel da Faccao',
    icon = 'skull',
    accent = '#DC2626',
    accent2 = '#7C3AED',
    defaultFeatures = {
      overview = true, members = true, grades = true, bank = true,
      goals = true, recruitment = true, logs = true
    }
  },
  business = {
    label = 'Empresa',
    panelTitle = 'Gestao da Empresa',
    icon = 'briefcase',
    accent = '#D97706',
    accent2 = '#FACC15',
    defaultFeatures = {
      overview = true, members = true, grades = true, bank = true,
      goals = true, recruitment = true, logs = true
    }
  },
  government = {
    label = 'Governo',
    panelTitle = 'Gestao Governamental',
    icon = 'landmark',
    accent = '#0F766E',
    accent2 = '#22C55E',
    defaultFeatures = {
      overview = true, members = true, grades = true, bank = true,
      goals = true, recruitment = false, logs = true
    }
  },
  vip = {
    label = 'VIP',
    panelTitle = 'Beneficios VIP',
    icon = 'crown',
    accent = '#7C3AED',
    accent2 = '#D946EF',
    defaultFeatures = {
      overview = true, members = true, grades = false, bank = false,
      goals = false, recruitment = false, logs = false
    }
  },
  event = {
    label = 'Evento',
    panelTitle = 'Gestao do Evento',
    icon = 'calendar',
    accent = '#DB2777',
    accent2 = '#F97316',
    defaultFeatures = {
      overview = true, members = true, grades = true, bank = false,
      goals = true, recruitment = true, logs = true
    }
  },
  staff = {
    label = 'Administracao',
    panelTitle = 'Controle de Organizacoes',
    icon = 'settings',
    accent = '#334155',
    accent2 = '#0EA5E9',
    defaultFeatures = { overview = true }
  }
}

local function copy(source)
  local result = {}
  for key, value in pairs(type(source) == 'table' and source or {}) do
    if type(value) == 'table' then
      result[key] = copy(value)
    else
      result[key] = value
    end
  end
  return result
end

local function trim(value, maxLength)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' then return nil end
  if maxLength and #value > maxLength then value = value:sub(1, maxLength) end
  return value
end

local function normalizeType(value)
  value = tostring(value or ''):lower()
  if value == 'legal' then return 'job' end
  if value == 'illegal' then return 'gang' end
  if PROFILES[value] then return value end
  return 'job'
end

local function validHex(value)
  return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

function MZOrgMenuProfiles.NormalizeType(value)
  return normalizeType(value)
end

function MZOrgMenuProfiles.Get(value)
  return copy(PROFILES[normalizeType(value)])
end

function MZOrgMenuProfiles.SupportsLeadership(value)
  local orgType = tostring(value or ''):lower()
  if orgType == 'legal' then orgType = 'job' end
  if orgType == 'illegal' then orgType = 'gang' end
  return orgType == 'job'
    or orgType == 'gang'
    or orgType == 'business'
    or orgType == 'government'
    or orgType == 'event'
end

function MZOrgMenuProfiles.Resolve(orgType, ui)
  ui = type(ui) == 'table' and ui or {}
  local actualType = normalizeType(orgType)
  local rawProfile = tostring(ui.profile or ''):lower()
  local requestedProfile = PROFILES[rawProfile] and rawProfile or actualType
  if requestedProfile == 'staff' and actualType ~= 'staff' then requestedProfile = actualType end

  local base = PROFILES[requestedProfile] or PROFILES[actualType] or PROFILES.job
  local resolved = copy(base)
  resolved.key = requestedProfile
  resolved.orgType = actualType
  resolved.supportsLeadership = MZOrgMenuProfiles.SupportsLeadership(orgType)
  resolved.title = trim(ui.title, 96) or resolved.panelTitle
  resolved.subtitle = trim(ui.subtitle, 128) or resolved.label
  resolved.brand = trim(ui.brand, 48) or 'MZ Organizations'
  local requestedIcon = trim(ui.headerIcon, 32) or trim(ui.icon, 32)
  resolved.icon = ICONS[requestedIcon or ''] and requestedIcon or resolved.icon
  resolved.badge = trim(ui.badge, 16) or actualType:upper()

  local position = tostring(ui.position or ''):lower()
  local width = tonumber(ui.width)
  resolved.theme = {
    accent = validHex(ui.accent) and ui.accent or resolved.accent,
    accent2 = validHex(ui.accent2) and ui.accent2 or resolved.accent2,
    position = POSITIONS[position] and position or 'left',
    width = width and math.floor(math.max(MIN_WIDTH, math.min(MAX_WIDTH, width))) or 400
  }
  resolved.sources = {
    profile = requestedProfile == actualType and ('type:' .. actualType) or 'organization_override',
    title = trim(ui.title, 96) and 'organization_override' or ('profile:' .. requestedProfile),
    subtitle = trim(ui.subtitle, 128) and 'organization_override' or ('profile:' .. requestedProfile),
    brand = trim(ui.brand, 48) and 'organization_override' or 'mz_org_default',
    icon = ICONS[requestedIcon or ''] and 'organization_override' or ('profile:' .. requestedProfile),
    badge = trim(ui.badge, 16) and 'organization_override' or 'organization_type',
    accent = validHex(ui.accent) and 'organization_override' or ('profile:' .. requestedProfile),
    accent2 = validHex(ui.accent2) and 'organization_override' or ('profile:' .. requestedProfile),
    position = POSITIONS[position] and 'organization_override' or 'mz_org_default',
    width = width and 'organization_override' or 'mz_org_default'
  }

  return resolved
end

function MZOrgMenuProfiles.IsAllowedIcon(value)
  return ICONS[tostring(value or '')] == true
end
