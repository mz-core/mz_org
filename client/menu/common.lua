MZOrgMenuCommon = MZOrgMenuCommon or {}

local MENU_ACTION_EVENT = 'mz_org:client:menuAction'
local menuActionGeneration = 0
local menuActions = {}

local function copyTable(source, excludedKey)
  local copy = {}
  for key, value in pairs(type(source) == 'table' and source or {}) do
    if key ~= excludedKey then copy[key] = value end
  end
  return copy
end

-- Funcoes aninhadas nao atravessam exports entre resources de forma confiavel.
-- Mantemos os callbacks no mz_org e enviamos ao mz_menu somente evento + token.
local function prepareContext(context)
  if type(context) ~= 'table' then return context end

  menuActionGeneration = menuActionGeneration + 1
  local prepared = copyTable(context, 'options')
  local contextId = tostring(context.id or '')
  if contextId == '' then
    contextId = ('mz_org:menu:%s:%s'):format(GetGameTimer(), menuActionGeneration)
    prepared.id = contextId
  end

  local actionContext = {
    generation = menuActionGeneration,
    callbacks = {},
    lifecycle = {}
  }
  menuActions[contextId] = actionContext
  prepared.options = {}

  for _, lifecycleName in ipairs({ 'onExit', 'onBack' }) do
    if type(context[lifecycleName]) == 'function' then
      actionContext.lifecycle[lifecycleName] = context[lifecycleName]
      prepared[lifecycleName] = nil
      prepared[lifecycleName .. 'Event'] = MENU_ACTION_EVENT
      prepared[lifecycleName .. 'Args'] = {
        contextId = contextId,
        generation = actionContext.generation,
        lifecycle = lifecycleName
      }
    end
  end

  for index, option in ipairs(type(context.options) == 'table' and context.options or {}) do
    local transported = copyTable(option, 'onSelect')
    if type(option.onSelect) == 'function' then
      actionContext.callbacks[index] = {
        callback = option.onSelect,
        args = option.args,
        option = option
      }

      -- onSelect possui precedencia sobre submenu no contrato do mz_menu.
      transported.menu = nil
      transported.event = MENU_ACTION_EVENT
      transported.args = {
        contextId = contextId,
        generation = actionContext.generation,
        optionIndex = index
      }
    end
    prepared.options[index] = transported
  end

  return prepared
end

AddEventHandler(MENU_ACTION_EVENT, function(action)
  if type(action) ~= 'table' then return end
  local contextId = tostring(action.contextId or '')
  local generation = tonumber(action.generation)
  local optionIndex = tonumber(action.optionIndex)
  local actionContext = menuActions[contextId]
  if not actionContext or actionContext.generation ~= generation then return end

  local lifecycle = tostring(action.lifecycle or '')
  if lifecycle ~= '' then
    local callback = actionContext.lifecycle[lifecycle]
    if type(callback) ~= 'function' then return end
    local ok, err = pcall(callback)
    if not ok then
      print(('[mz_org][menu] Falha no lifecycle %s/%s: %s'):format(contextId, lifecycle, tostring(err)))
    end
    return
  end

  if not optionIndex then return end

  local selected = actionContext.callbacks[optionIndex]
  if not selected or type(selected.callback) ~= 'function' then return end
  local ok, err = pcall(selected.callback, selected.args, selected.option)
  if not ok then
    print(('[mz_org][menu] Falha na acao %s/%s: %s'):format(contextId, optionIndex, tostring(err)))
  end
end)

local function callMenu(exportName, ...)
  if GetResourceState('mz_menu') ~= 'started' then return false, 'mz_menu_unavailable' end
  local args = { ... }
  local ok, result, extra = pcall(function()
    local menu = exports['mz_menu']
    return menu[exportName](menu, table.unpack(args))
  end)
  if not ok then return false, tostring(result) end
  return result, extra
end

function MZOrgMenuCommon.OpenContext(context)
  return callMenu('OpenContext', prepareContext(context))
end

function MZOrgMenuCommon.RegisterContext(context)
  return callMenu('RegisterContext', prepareContext(context))
end

function MZOrgMenuCommon.CloseContext()
  return callMenu('CloseContext')
end

function MZOrgMenuCommon.InputDialog(title, rows, options)
  return callMenu('InputDialog', title, rows, options)
end

function MZOrgMenuCommon.Confirm(title, content, options)
  return callMenu('Confirm', title, content, options) == true
end

function MZOrgMenuCommon.AlertDialog(dataOrTitle, content, options)
  return callMenu('AlertDialog', dataOrTitle, content, options)
end

function MZOrgMenuCommon.Notify(message, kind)
  local ok = callMenu('Notify', {
    title = 'MZ Organizations',
    description = tostring(message or ''),
    type = kind or 'inform'
  })
  if ok == false then
    TriggerEvent('chat:addMessage', {
      color = kind == 'error' and { 255, 100, 100 } or { 120, 190, 255 },
      args = { 'mz_org', tostring(message or '') }
    })
  end
end

local function formatUnixUtc(timestamp)
  local days = math.floor(timestamp / 86400)
  local secondsOfDay = timestamp - (days * 86400)
  local hour = math.floor(secondsOfDay / 3600)
  local minute = math.floor((secondsOfDay % 3600) / 60)

  -- Conversao civil_from_days (epoch 1970), sem depender da biblioteca os no client FiveM.
  local z = days + 719468
  local era = math.floor((z >= 0 and z or z - 146096) / 146097)
  local dayOfEra = z - (era * 146097)
  local yearOfEra = math.floor((dayOfEra - math.floor(dayOfEra / 1460)
    + math.floor(dayOfEra / 36524) - math.floor(dayOfEra / 146096)) / 365)
  local year = yearOfEra + (era * 400)
  local dayOfYear = dayOfEra - ((365 * yearOfEra) + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100))
  local monthPosition = math.floor(((5 * dayOfYear) + 2) / 153)
  local day = dayOfYear - math.floor(((153 * monthPosition) + 2) / 5) + 1
  local month = monthPosition + (monthPosition < 10 and 3 or -9)
  year = year + (month <= 2 and 1 or 0)

  return ('%02d/%02d/%04d %02d:%02d'):format(day, month, year, hour, minute)
end

function MZOrgMenuCommon.FormatDateTime(value, fallback)
  fallback = fallback or 'Nao disponibilizado'
  if value == nil or value == '' then return fallback end

  local timestamp = tonumber(value)
  if timestamp then
    -- Alguns adapters JSON retornam epoch em milissegundos; o Lua espera segundos.
    if timestamp >= 100000000000 then timestamp = timestamp / 1000 end
    timestamp = math.floor(timestamp)
    if timestamp > 0 then return formatUnixUtc(timestamp) end
    return tostring(value)
  end

  local text = tostring(value)
  local year, month, day, hour, minute = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d)')
  if year then return ('%s/%s/%s %s:%s'):format(day, month, year, hour, minute) end

  year, month, day = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
  if year then return ('%s/%s/%s'):format(day, month, year) end
  return text
end

function MZOrgMenuCommon.FormatMoney(value, currency)
  local amount = tonumber(value) or 0
  local negative = amount < 0
  amount = math.abs(amount)
  local units = math.floor(amount)
  local cents = math.floor(((amount - units) * 100) + 0.5)
  if cents >= 100 then units, cents = units + 1, 0 end

  local formatted = tostring(units):reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
  return ('%s%s %s,%02d'):format(negative and '-' or '', tostring(currency or 'R$'), formatted, cents)
end

function MZOrgMenuCommon.HasFeature(organization, feature)
  for _, value in ipairs(type(organization) == 'table' and organization.features or {}) do
    if value == feature then return true end
  end
  return false
end

function MZOrgMenuCommon.HasCapability(organization, capability)
  if type(capability) ~= 'string' or capability:lower():match('^staff%.') then return false end
  for _, value in ipairs(type(organization) == 'table' and organization.capabilities or {}) do
    if value == capability then return true end
  end
  return false
end

function MZOrgMenuCommon.HasAnyCapability(organization, capabilities)
  for _, capability in ipairs(capabilities or {}) do
    if MZOrgMenuCommon.HasCapability(organization, capability) then return true end
  end
  return false
end

function MZOrgMenuCommon.VisualFields(organization)
  local profile = MZOrgMenuTheme.Resolve(organization)
  return {
    theme = profile.theme,
    brand = profile.brand,
    headerIcon = profile.icon,
    badge = profile.badge
  }
end
