MZOrgStaffAppearance = MZOrgStaffAppearance or {}

local function hasAction(data)
  for _, value in ipairs(type(data) == 'table' and data.allowedActions or {}) do
    if value == 'appearance' then return true end
  end
  return false
end

local function copy(value)
  local result = {}
  for key, item in pairs(type(value) == 'table' and value or {}) do result[key] = item end
  return result
end

local function optional(value)
  value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
  return value ~= '' and value or nil
end

local function save(data, overrides, remove, resetAll, reason)
  local org = data.organization or {}
  local payload = {
    orgCode = org.code,
    organizationRevision = org.organizationRevision,
    overrides = overrides or {},
    remove = remove or {},
    resetAll = resetAll == true,
    reason = reason
  }
  MZOrgMenuRequest.BeginStaffModule('organizations', org.code)
  MZOrgMenuRequest.RequestMutation('mz_org:server:staffUpdateOrganizationAppearance', payload, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Alteracao visual recusada.', 'error')
      return
    end
    MZOrgStaffMenu.AfterMutation(response.data, org.code)
  end)
end

local function preview(data, draft, reason, allowSave)
  local org = data.organization or {}
  local current = copy(org.appearanceOverrides or {})
  for key, value in pairs(draft or {}) do current[key] = value end
  local presentation = MZOrgMenuProfiles.Resolve(org.type, current)
  local options = {
    {
      title = 'Preview local e descartavel',
      description = 'Este tema ainda nao foi persistido.',
      icon = 'eye',
      readOnly = true
    },
    {
      title = 'Cancelar preview',
      description = 'Voltar ao tema Staff sem salvar.',
      icon = 'x',
      onSelect = function() MZOrgStaffAppearance.Open(data) end
    }
  }
  if allowSave then
    options[#options + 1] = {
      title = 'Confirmar e salvar',
      description = 'Enviar o patch sanitizado ao servidor.',
      icon = 'check',
      onSelect = function()
        if MZOrgMenuCommon.Confirm('Salvar aparencia?', 'A configuracao sera revalidada e auditada pelo servidor.') then
          save(data, draft, {}, false, reason)
        end
      end
    }
  end
  MZOrgMenuCommon.OpenContext({
    id = 'mz_org:staff:org:' .. tostring(org.code) .. ':appearance:preview',
    title = presentation.title,
    subtitle = 'PREVIEW - nao salvo',
    menu = 'mz_org:staff:org:' .. tostring(org.code) .. ':appearance:editor',
    theme = presentation.theme,
    brand = presentation.brand,
    headerIcon = presentation.icon,
    badge = presentation.badge,
    options = options
  })
end

local function edit(data)
  local org = data.organization or {}
  local current = type(org.appearanceOverrides) == 'table' and org.appearanceOverrides or {}
  local values = MZOrgMenuCommon.InputDialog('Editar override visual', {
    { type = 'input', label = 'Accent (#RRGGBB)', default = current.accent or '' },
    { type = 'input', label = 'Accent 2 (#RRGGBB)', default = current.accent2 or '' },
    { type = 'input', label = 'Brand', default = current.brand or '' },
    { type = 'input', label = 'Header icon', default = current.headerIcon or current.icon or '' },
    { type = 'input', label = 'Badge', default = current.badge or '' },
    { type = 'select', label = 'Posicao', default = current.position or '', options = {
      { value = '', label = 'Sem novo override' }, { value = 'left', label = 'Esquerda' },
      { value = 'right', label = 'Direita' }, { value = 'center', label = 'Centro' }
    } },
    { type = 'number', label = 'Largura (320-640)', default = current.width },
    { type = 'input', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local raw = {
    accent = optional(values[1]), accent2 = optional(values[2]), brand = optional(values[3]),
    headerIcon = optional(values[4]), badge = optional(values[5]), position = optional(values[6]),
    width = values[7] and tonumber(values[7]) or nil
  }
  local valid, draft = MZOrgMenuMutations.SanitizeAppearanceValues(raw)
  if not valid then MZOrgMenuCommon.Notify('Aparencia invalida: ' .. tostring(draft), 'error') return end
  local reason = MZOrgMenuMutations.NormalizeReason(values[8])
  if not reason then MZOrgMenuCommon.Notify('Informe um motivo valido.', 'error') return end
  preview(data, draft, reason, true)
end

local function restoreProperty(data)
  local org = data.organization or {}
  local current = type(org.appearanceOverrides) == 'table' and org.appearanceOverrides or {}
  local options = {}
  for _, field in ipairs(MZOrgMenuMutations.GetAppearanceFields()) do
    local storedField = field == 'headerIcon' and (current.headerIcon or current.icon) or current[field]
    if storedField ~= nil then
      local selected = field
      options[#options + 1] = {
        title = 'Restaurar ' .. field,
        description = tostring(storedField) .. ' -> herdado',
        icon = 'refresh',
        onSelect = function()
          local values = MZOrgMenuCommon.InputDialog('Restaurar propriedade', {
            { type = 'input', label = 'Motivo', required = true }
          })
          if type(values) ~= 'table' then return end
          if MZOrgMenuCommon.Confirm('Restaurar ' .. selected .. '?', 'O override sera removido; o valor do perfil voltara a valer.') then
            save(data, {}, { selected }, false, values[1])
          end
        end
      }
    end
  end
  if #options == 0 then options[1] = { title = 'Nenhum override para restaurar', readOnly = true } end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. tostring(org.code) .. ':appearance:restore',
    title = 'Restaurar propriedade',
    menu = 'mz_org:staff:org:' .. tostring(org.code) .. ':appearance:editor',
    options = options
  }))
end

local function inherited(data)
  local org = data.organization or {}
  local profile = MZOrgMenuProfiles.Resolve(org.type, nil)
  local rows = {
    { 'Accent', profile.theme.accent }, { 'Accent 2', profile.theme.accent2 },
    { 'Brand', profile.brand }, { 'Header icon', profile.icon }, { 'Badge', profile.badge },
    { 'Position', profile.theme.position }, { 'Width', profile.theme.width }
  }
  local options = {}
  for _, row in ipairs(rows) do options[#options + 1] = { title = row[1], description = tostring(row[2]), icon = 'eye', readOnly = true } end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. tostring(org.code) .. ':appearance:inherited',
    title = 'Valores herdados', subtitle = 'Perfil ' .. tostring(org.type),
    menu = 'mz_org:staff:org:' .. tostring(org.code) .. ':appearance:editor', options = options
  }))
end

function MZOrgStaffAppearance.Open(data)
  local org = data.organization or {}
  local editable = org.status == 'active' and hasAction(data)
  local options = {
    { title = 'Ver valores herdados', icon = 'eye', onSelect = function() inherited(data) end },
    { title = 'Pre-visualizar configuracao efetiva', icon = 'eye', onSelect = function() preview(data, {}, nil, false) end }
  }
  if editable then
    options[#options + 1] = { title = 'Editar override', icon = 'settings', onSelect = function() edit(data) end }
    options[#options + 1] = { title = 'Restaurar propriedade', icon = 'refresh', onSelect = function() restoreProperty(data) end }
    options[#options + 1] = {
      title = 'Restaurar perfil completo', description = 'Remover somente overrides visuais.', icon = 'refresh',
      onSelect = function()
        local values = MZOrgMenuCommon.InputDialog('Restaurar perfil completo', { { type = 'input', label = 'Motivo', required = true } })
        if type(values) == 'table' and MZOrgMenuCommon.Confirm('Restaurar perfil completo?', 'Todos os overrides visuais serao removidos.') then
          save(data, {}, {}, true, values[1])
        end
      end
    }
  end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. tostring(org.code) .. ':appearance:editor',
    title = 'Aparencia', subtitle = editable and 'Overrides sanitizados' or 'Somente leitura',
    menu = 'mz_org:staff:org:' .. tostring(org.code) .. ':root', options = options
  }))
end
