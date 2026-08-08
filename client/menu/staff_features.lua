MZOrgStaffFeatures = MZOrgStaffFeatures or {}

local function hasAction(data)
  for _, value in ipairs(type(data) == 'table' and data.allowedActions or {}) do
    if value == 'features' then return true end
  end
  return false
end

local function stateLabel(feature)
  if feature.applicable == false then return 'nao aplicavel ao tipo' end
  if feature.dependency and feature.dependencyAvailable == false then return 'indisponivel por dependencia' end
  if feature.override == true then return 'habilitado por override' end
  if feature.override == false then return 'desabilitado por override' end
  return 'herdado'
end

local function save(data, feature)
  local org = data.organization or {}
  local values = MZOrgMenuCommon.InputDialog('Configurar feature: ' .. tostring(feature.label or feature.name), {
    { type = 'select', label = 'Estado', required = true, default = feature.override == nil and 'inherit' or (feature.override and 'enabled' or 'disabled'), options = {
      { value = 'inherit', label = 'Herdado do perfil' },
      { value = 'enabled', label = 'Habilitado por override' },
      { value = 'disabled', label = 'Desabilitado por override' }
    } },
    { type = 'input', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local payload = {
    orgCode = org.code,
    organizationRevision = org.organizationRevision,
    overrides = {},
    remove = {},
    reason = values[2]
  }
  if values[1] == 'inherit' then payload.remove[1] = feature.name
  else payload.overrides[feature.name] = values[1] == 'enabled' end
  if not MZOrgMenuCommon.Confirm('Salvar feature?', ('%s\nEstado: %s'):format(feature.label or feature.name, values[1])) then return end
  MZOrgMenuRequest.BeginStaffModule('organizations', org.code)
  MZOrgMenuRequest.RequestMutation('mz_org:server:staffUpdateOrganizationFeatures', payload, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Alteracao de feature recusada.', 'error')
      return
    end
    MZOrgStaffMenu.AfterMutation(response.data, org.code)
  end)
end

function MZOrgStaffFeatures.Open(data)
  local org = data.organization or {}
  local editable = org.status == 'active' and hasAction(data)
  local options = {}
  for _, feature in ipairs(data.features or {}) do
    local selected = feature
    local option = {
      title = feature.label or feature.name,
      description = ('%s / efetivo: %s'):format(stateLabel(feature), feature.effective and 'sim' or 'nao'),
      icon = feature.effective and 'check' or 'x',
      metadata = {
        { label = 'Descricao', value = feature.description or '-' },
        { label = 'Herdado', value = feature.profileEnabled and 'habilitado' or 'desabilitado' },
        { label = 'Override', value = feature.override == nil and 'nenhum' or tostring(feature.override) },
        { label = 'Dependencia', value = feature.dependency or 'nenhuma' },
        { label = 'Disponibilidade', value = feature.dependencyAvailable == false and 'indisponivel' or 'disponivel' },
        { label = 'Origem', value = feature.origin or '-' }
      },
      readOnly = not editable or feature.applicable == false
    }
    if editable and feature.applicable ~= false then option.onSelect = function() save(data, selected) end end
    options[#options + 1] = option
  end
  if #options == 0 then options[1] = { title = 'Nenhuma feature configuravel', readOnly = true } end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. tostring(org.code) .. ':features:editor',
    title = 'Features',
    subtitle = editable and 'Catalogo oficial / selecione para editar' or 'Somente leitura',
    menu = 'mz_org:staff:org:' .. tostring(org.code) .. ':root',
    options = options
  }))
end

