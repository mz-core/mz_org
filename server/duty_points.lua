MZOrgDutyPointsServer = MZOrgDutyPointsServer or {}

local SUPPORTED_TYPES = {
  job = true,
  gang = true,
  business = true,
  government = true,
  event = true
}
local lastToggleAt = {}

local ERROR_MESSAGES = {
  invalid_request = 'Solicitacao de ponto invalida.',
  invalid_duty_state = 'Estado de servico invalido.',
  player_not_loaded = 'Personagem ainda nao carregado.',
  invalid_org = 'Organizacao inexistente.',
  org_archived = 'Organizacao arquivada.',
  duty_not_supported = 'Este tipo de organizacao nao utiliza ponto de servico.',
  duty_point_not_configured = 'A organizacao nao possui ponto de servico configurado.',
  invalid_duty_point = 'O ponto de servico configurado e invalido.',
  not_member = 'Voce nao possui vinculo ativo com esta organizacao.',
  server_position_unavailable = 'O servidor nao conseguiu validar sua posicao.',
  too_far = 'Aproxime-se do ponto para entrar ou sair de servico.',
  audit_transaction_failed = 'A alteracao foi cancelada porque o log nao foi confirmado.',
  core_unavailable = 'mz_core indisponivel.'
}

local function message(code)
  return ERROR_MESSAGES[tostring(code or '')] or tostring(code or 'Nao foi possivel alterar o servico.')
end

local function normalizePoint(org)
  if type(org) ~= 'table' or org.active ~= true
    or SUPPORTED_TYPES[tostring(org.type or ''):lower()] ~= true then
    return nil
  end
  local config = type(org.config) == 'table' and org.config or {}
  local point = type(config.dutyPoint) == 'table' and config.dutyPoint or nil
  if not point or point.enabled ~= true or type(point.coords) ~= 'table' then return nil end
  local x, y, z = tonumber(point.coords.x), tonumber(point.coords.y), tonumber(point.coords.z)
  local radius, drawDistance = tonumber(point.radius), tonumber(point.drawDistance)
  local label = type(point.label) == 'string' and point.label or nil
  local function finite(value)
    return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge
  end
  if not finite(x) or not finite(y) or not finite(z)
    or x < -10000.0 or x > 10000.0 or y < -10000.0 or y > 10000.0
    or z < -1000.0 or z > 3000.0
    or not finite(radius) or radius < 1.0 or radius > 5.0
    or not finite(drawDistance) or drawDistance < 5.0 or drawDistance > 50.0
    or drawDistance < radius or not label or #label < 2 or #label > 64
    or label:find('[<>{}]') then
    return nil
  end
  return {
    orgCode = tostring(org.code),
    orgName = tostring(org.name or org.code),
    orgType = tostring(org.type),
    coords = { x = x, y = y, z = z },
    radius = radius,
    drawDistance = drawDistance,
    label = label,
    isDuty = org.duty == true
  }
end

local function sendPoints(sourceId)
  local orgs, err = MZOrgSecurity.SafeExport('GetPlayerOrgContext', sourceId)
  if type(orgs) ~= 'table' then
    TriggerClientEvent('mz_org:client:setDutyPoints', sourceId, {})
    if err then
      print(('[mz_org] Falha ao carregar pontos de servico source=%s error=%s'):format(
        tostring(sourceId), tostring(err)
      ))
    end
    return
  end
  local points = {}
  for _, org in ipairs(orgs) do
    local point = normalizePoint(org)
    if point then points[#points + 1] = point end
  end
  TriggerClientEvent('mz_org:client:setDutyPoints', sourceId, points)
end

RegisterNetEvent('mz_org:server:requestDutyPoints', function()
  sendPoints(source)
end)

RegisterNetEvent('mz_org:server:setSelfDutyAtPoint', function(orgCode, desiredDuty)
  local sourceId = MZOrgSecurity.NormalizeSource(source)
  if not sourceId then return end
  local now = type(GetGameTimer) == 'function' and GetGameTimer() or 0
  if now - (lastToggleAt[sourceId] or -10000) < 800 then return end
  lastToggleAt[sourceId] = now

  if type(orgCode) ~= 'string' or #orgCode < 2 or #orgCode > 48
    or not orgCode:match('^[a-z0-9][a-z0-9_-]*$') or type(desiredDuty) ~= 'boolean' then
    TriggerClientEvent('mz_org:client:dutyResult', sourceId, false, message('invalid_request'))
    return
  end
  local ok, resultOrError = MZOrgSecurity.SafeExport(
    'SetSelfOrgDutyAtPoint',
    sourceId,
    orgCode,
    desiredDuty
  )
  if ok ~= true or type(resultOrError) ~= 'table' then
    TriggerClientEvent(
      'mz_org:client:dutyResult',
      sourceId,
      false,
      message(resultOrError or 'core_unavailable')
    )
    return
  end
  TriggerClientEvent(
    'mz_org:client:dutyResult',
    sourceId,
    true,
    desiredDuty and 'Voce entrou em servico.' or 'Voce saiu de servico.'
  )
  sendPoints(sourceId)
end)

RegisterNetEvent('mz_org:server:refreshOwnDutyPoints', function()
  sendPoints(source)
end)

AddEventHandler('playerDropped', function()
  lastToggleAt[source] = nil
end)
