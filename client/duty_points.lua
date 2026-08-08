MZOrgDutyPoints = MZOrgDutyPoints or {}

local registeredPoints = {}

local function removePoints()
  if GetResourceState('mz_interact') == 'started' then
    for pointId in pairs(registeredPoints) do
      exports['mz_interact']:RemovePoint(pointId)
    end
  end
  registeredPoints = {}
end

local function colorFromHex(value)
  if type(value) ~= 'string' then return { r = 80, g = 180, b = 255, a = 200 } end
  local hex = value:match('^#(%x%x%x%x%x%x)$')
  if not hex then return { r = 80, g = 180, b = 255, a = 200 } end
  return {
    r = tonumber(hex:sub(1, 2), 16),
    g = tonumber(hex:sub(3, 4), 16),
    b = tonumber(hex:sub(5, 6), 16),
    a = 200
  }
end

local function registerPoints(points)
  removePoints()
  if GetResourceState('mz_interact') ~= 'started' then return end

  for _, point in ipairs(type(points) == 'table' and points or {}) do
    if type(point) == 'table' and type(point.coords) == 'table'
      and type(point.orgCode) == 'string' and type(point.isDuty) == 'boolean' then
      local pointId = 'mz_org:duty:' .. point.orgCode
      local profile = MZOrgMenuProfiles.Resolve(point.orgType, nil)
      local color = colorFromHex(profile and profile.theme and profile.theme.accent)
      local action = point.isDuty and 'Sair de servico' or 'Entrar em servico'
      local ok = exports['mz_interact']:AddPoint({
        id = pointId,
        coords = vector3(
          tonumber(point.coords.x) or 0.0,
          tonumber(point.coords.y) or 0.0,
          tonumber(point.coords.z) or 0.0
        ),
        drawDistance = tonumber(point.drawDistance) or 20.0,
        interactDistance = tonumber(point.radius) or 2.0,
        marker = {
          enabled = true,
          type = 2,
          size = vector3(0.35, 0.35, 0.35),
          color = color,
          rotate = true,
          bobUpAndDown = false,
          faceCamera = false
        },
        blip = { enabled = false },
        text = {
          enabled = true,
          label = ('[E] %s - %s'):format(action, tostring(point.label or point.orgName))
        },
        event = {
          type = 'client',
          name = 'mz_org:client:useDutyPoint',
          args = { point.orgCode, not point.isDuty }
        }
      })
      if ok == true then registeredPoints[pointId] = true end
    end
  end
end

local function requestPoints()
  TriggerServerEvent('mz_org:server:requestDutyPoints')
end

RegisterNetEvent('mz_org:client:setDutyPoints', function(points)
  registerPoints(points)
end)

RegisterNetEvent('mz_org:client:refreshDutyPoints', function()
  requestPoints()
end)

RegisterNetEvent('mz_org:client:useDutyPoint', function(orgCode, desiredDuty)
  if type(orgCode) ~= 'string' or type(desiredDuty) ~= 'boolean' then return end
  TriggerServerEvent('mz_org:server:setSelfDutyAtPoint', orgCode, desiredDuty)
end)

RegisterNetEvent('mz_org:client:dutyResult', function(ok, text)
  MZOrgMenuCommon.Notify(text, ok == true and 'success' or 'error')
end)

RegisterNetEvent('mz_core:client:playerLoaded', function()
  SetTimeout(500, requestPoints)
end)

CreateThread(function()
  Wait(1000)
  requestPoints()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName == GetCurrentResourceName() or resourceName == 'mz_interact' then
    SetTimeout(1000, requestPoints)
  end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
  if resourceName == GetCurrentResourceName() then
    removePoints()
  elseif resourceName == 'mz_interact' then
    registeredPoints = {}
  end
end)

