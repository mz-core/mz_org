MZOrgStaffDuty = MZOrgStaffDuty or {}

local function hasAction(data)
  for _, value in ipairs(type(data) == 'table' and data.allowedActions or {}) do
    if value == 'dutyPoint' then return true end
  end
  return false
end

local function pointDescription(point)
  if type(point) ~= 'table' or point.enabled ~= true or type(point.coords) ~= 'table' then
    return 'Nao configurado'
  end
  return ('X %.2f / Y %.2f / Z %.2f'):format(
    tonumber(point.coords.x) or 0.0,
    tonumber(point.coords.y) or 0.0,
    tonumber(point.coords.z) or 0.0
  )
end

local function save(data, dutyPoint, reason)
  local org = data.organization or {}
  MZOrgMenuRequest.BeginStaffModule('organizations', org.code)
  MZOrgMenuRequest.RequestMutation('mz_org:server:staffUpdateOrganizationDutyPoint', {
    orgCode = org.code,
    organizationRevision = org.organizationRevision,
    dutyPoint = dutyPoint,
    reason = reason
  }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Alteracao do ponto recusada.', 'error')
      return
    end
    MZOrgStaffMenu.AfterMutation(response.data, org.code)
  end)
end

local function createOrMove(data)
  local org = data.organization or {}
  local current = type(org.dutyPoint) == 'table' and org.dutyPoint or {}
  local values = MZOrgMenuCommon.InputDialog('Configurar ponto de servico', {
    {
      type = 'input',
      label = 'Nome do ponto',
      required = true,
      default = current.label or ((org.name or org.code) .. ' - Ponto')
    },
    {
      type = 'number',
      label = 'Raio de interacao (1-5 m)',
      required = true,
      default = tonumber(current.radius) or 2.0
    },
    {
      type = 'number',
      label = 'Distancia de desenho (5-50 m)',
      required = true,
      default = tonumber(current.drawDistance) or 20.0
    },
    { type = 'input', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local dutyPoint = {
    enabled = true,
    coords = { x = coords.x, y = coords.y, z = coords.z },
    radius = tonumber(values[2]),
    drawDistance = tonumber(values[3]),
    label = values[1]
  }
  local content = ('Organizacao: %s\nLocal atual: %.2f, %.2f, %.2f\nRaio: %s m'):format(
    tostring(org.name or org.code),
    coords.x,
    coords.y,
    coords.z,
    tostring(values[2])
  )
  if not MZOrgMenuCommon.Confirm('Salvar ponto de servico?', content) then return end
  save(data, dutyPoint, values[4])
end

local function disable(data)
  local org = data.organization or {}
  local values = MZOrgMenuCommon.InputDialog('Desativar ponto de servico', {
    { type = 'input', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  if not MZOrgMenuCommon.Confirm(
    'Desativar ponto?',
    'Membros nao poderao entrar ou sair de servico ate um novo ponto ser criado.'
  ) then
    return
  end
  save(data, { enabled = false }, values[1])
end

function MZOrgStaffDuty.Open(data)
  local org = type(data) == 'table' and data.organization or {}
  local point = type(org.dutyPoint) == 'table' and org.dutyPoint or nil
  local configured = point ~= nil and point.enabled == true
  local editable = org.status == 'active' and org.supportsDuty == true and hasAction(data)
  local options = {
    {
      title = configured and tostring(point.label or 'Ponto de servico') or 'Ponto nao configurado',
      description = pointDescription(point),
      icon = configured and 'check' or 'info',
      metadata = configured and {
        { label = 'Raio', value = tostring(point.radius or '-') .. ' m' },
        { label = 'Desenho', value = tostring(point.drawDistance or '-') .. ' m' },
        { label = 'Tipo', value = tostring(org.type or '-') }
      } or nil,
      readOnly = true
    }
  }
  if editable then
    options[#options + 1] = {
      title = configured and 'Reposicionar ponto no local atual' or 'Criar ponto no local atual',
      description = 'Use F6 para liberar o movimento, posicione-se e selecione esta opcao.',
      icon = 'building',
      onSelect = function() createOrMove(data) end
    }
    if configured then
      options[#options + 1] = {
        title = 'Desativar ponto de servico',
        description = 'Remove a interacao sem apagar historico ou vinculos.',
        icon = 'archive',
        onSelect = function() disable(data) end
      }
    end
  elseif org.status ~= 'active' then
    options[#options + 1] = {
      title = 'Organizacao arquivada',
      description = 'Reative a organizacao antes de editar o ponto.',
      icon = 'archive',
      readOnly = true
    }
  elseif not hasAction(data) then
    options[#options + 1] = {
      title = 'Somente leitura',
      description = 'Requer a permissao global staff.orgs.duty.',
      icon = 'shield',
      readOnly = true
    }
  end

  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. tostring(org.code) .. ':duty',
    title = 'Ponto de servico',
    subtitle = tostring(org.name or org.code),
    menu = 'mz_org:staff:org:' .. tostring(org.code) .. ':root',
    options = options
  }))
end

