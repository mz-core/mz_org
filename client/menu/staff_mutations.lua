MZOrgStaffMutations = MZOrgStaffMutations or {}

local ORG_TYPES = { 'job', 'gang', 'business', 'government', 'vip', 'event' }

local function hasAction(data, action)
  for _, value in ipairs(type(data) == 'table' and data.allowedActions or {}) do
    if value == action then return true end
  end
  return false
end

local function typeOptions(includeBlank)
  local options = {}
  if includeBlank then options[#options + 1] = { value = '', label = 'Herdado' } end
  for _, orgType in ipairs(ORG_TYPES) do options[#options + 1] = { value = orgType, label = orgType } end
  return options
end

local function notifyFailure(response)
  MZOrgMenuCommon.Notify(response and response.error or 'Operacao Staff recusada.', 'error')
end

local function request(eventName, payload, callback, options)
  MZOrgMenuRequest.RequestMutation(eventName, payload, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      notifyFailure(response)
      return
    end
    callback(response.data)
  end, options)
end

local function optional(value)
  value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
  return value ~= '' and value or nil
end

function MZOrgStaffMutations.CreateOrganization()
  if not MZOrgStaffMenu.HasAction('create') then return end
  local stepOptions = { labels = { confirm = 'Proximo', cancel = 'Cancelar' } }
  local identity = MZOrgMenuCommon.InputDialog('Criar organizacao - 1/4 Identidade', {
    {
      type = 'input', label = 'Codigo estrutural', required = true,
      placeholder = 'ex.: mecanica_bennys',
      description = 'Identificador unico: letras minusculas, numeros, _ ou -. Nao podera ser alterado depois.'
    },
    {
      type = 'input', label = 'Nome oficial', required = true,
      description = 'Nome administrativo da organizacao, com 2 a 120 caracteres.'
    },
    {
      type = 'select', label = 'Tipo', required = true, default = 'job', options = typeOptions(false),
      description = 'Define o perfil herdado de features e aparencia.'
    },
    { type = 'select', label = 'Estado inicial', required = true, default = 'active', options = {
      { value = 'active', label = 'Ativa' }, { value = 'archived', label = 'Arquivada' }
    }, description = 'Arquivada nasce invisivel para os menus organizacionais comuns.' },
    {
      type = 'textarea', label = 'Motivo da criacao', required = true,
      description = 'Justificativa registrada na auditoria.'
    }
  }, stepOptions)
  if type(identity) ~= 'table' then return end

  local code = MZOrgMenuMutations.NormalizeOrgCode(identity[1])
  local orgType = MZOrgMenuMutations.NormalizeOrgType(identity[3])
  local reason = MZOrgMenuMutations.NormalizeReason(identity[5])
  if not code then MZOrgMenuCommon.Notify('Codigo estrutural invalido.', 'error') return end
  if not orgType then MZOrgMenuCommon.Notify('Tipo de organizacao invalido.', 'error') return end
  if not reason then MZOrgMenuCommon.Notify('O motivo precisa ter entre 3 e 255 caracteres validos.', 'error') return end

  local public = MZOrgMenuCommon.InputDialog('Criar organizacao - 2/4 Apresentacao', {
    {
      type = 'input', label = 'Nome de exibicao', required = true, default = identity[2],
      description = 'Nome apresentado aos jogadores. Pode ser diferente do nome oficial.'
    },
    {
      type = 'textarea', label = 'Descricao curta',
      description = 'Resumo publico opcional, limitado e sem HTML ou URLs.'
    },
    {
      type = 'input', label = 'Categoria publica', placeholder = 'ex.: servicos',
      description = 'Metadata publica opcional aprovada pelo contrato.'
    },
    {
      type = 'input', label = 'Locale', placeholder = 'ex.: pt-BR',
      description = 'Identificador regional opcional, com ate 16 caracteres.'
    }
  }, stepOptions)
  if type(public) ~= 'table' then return end

  local profile = MZOrgMenuProfiles.Get(orgType)
  local defaults = profile.defaultFeatures or {}
  local featureRows, featureNames = {}, {}
  local featureContract = MZOrgMenuFeatures.GetContract()
  for _, featureName in ipairs(MZOrgMenuFeatures.GetOrder()) do
    if MZOrgMenuFeatures.IsApplicable(featureName, orgType) then
      local feature = featureContract[featureName] or {}
      featureNames[#featureNames + 1] = featureName
      featureRows[#featureRows + 1] = {
        type = 'checkbox',
        label = feature.label or featureName,
        description = feature.description,
        checked = defaults[featureName] == true
      }
    end
  end
  local featureInput = MZOrgMenuCommon.InputDialog('Criar organizacao - 3/4 Features', featureRows, stepOptions)
  if type(featureInput) ~= 'table' then return end

  local selectedFeatures = {}
  for index, featureName in ipairs(featureNames) do
    selectedFeatures[featureName] = featureInput[index] == true
  end

  local appearanceInput = MZOrgMenuCommon.InputDialog('Criar organizacao - 4/4 Aparencia opcional', {
    { type = 'input', label = 'Cor principal', placeholder = '#RRGGBB', description = 'Vazio mantem a cor herdada do tipo.' },
    { type = 'input', label = 'Cor secundaria', placeholder = '#RRGGBB', description = 'Vazio mantem a cor secundaria herdada.' },
    { type = 'input', label = 'Brand visual', description = 'Titulo visual opcional, com ate 48 caracteres.' },
    { type = 'input', label = 'Icone do cabecalho', placeholder = profile.icon or '', description = 'Use um identificador do catalogo aprovado.' },
    { type = 'input', label = 'Badge', description = 'Texto curto opcional, com ate 16 caracteres.' },
    { type = 'select', label = 'Posicao', default = '', options = {
      { value = '', label = 'Herdada' }, { value = 'left', label = 'Esquerda' },
      { value = 'right', label = 'Direita' }, { value = 'center', label = 'Centro' }
    }, description = 'Vazio utiliza a posicao do perfil.' },
    { type = 'number', label = 'Largura', placeholder = '320 a 640', description = 'Vazio utiliza a largura herdada.' }
  }, { labels = { confirm = 'Revisar', cancel = 'Cancelar' } })
  if type(appearanceInput) ~= 'table' then return end

  local payload = {
    code = code, name = identity[2], type = orgType, state = identity[4],
    displayName = public[1], description = optional(public[2]),
    metadata = { category = optional(public[3]), locale = optional(public[4]) },
    reason = reason,
    features = selectedFeatures,
    appearance = {
      accent = optional(appearanceInput[1]), accent2 = optional(appearanceInput[2]), brand = optional(appearanceInput[3]),
      headerIcon = optional(appearanceInput[4]), badge = optional(appearanceInput[5]), position = optional(appearanceInput[6]),
      width = appearanceInput[7] and tonumber(appearanceInput[7]) or nil
    }
  }
  local valid, normalized = MZOrgMenuMutations.SanitizeCreate(payload)
  if not valid then MZOrgMenuCommon.Notify('Dados invalidos: ' .. tostring(normalized), 'error') return end
  local enabledFeatures = {}
  for _, featureName in ipairs(featureNames) do
    if selectedFeatures[featureName] then enabledFeatures[#enabledFeatures + 1] = featureName end
  end
  local summary = ('Codigo: %s\nNome: %s\nTipo: %s\nEstado: %s\nExibicao: %s\nFeatures: %s\nAparencia: %s'):format(
    normalized.code, normalized.name, normalized.type, normalized.state,
    normalized.public.displayName or normalized.appearance.brand or '-',
    #enabledFeatures > 0 and table.concat(enabledFeatures, ', ') or 'nenhuma',
    next(normalized.appearance or {}) and 'override configurado' or 'perfil herdado'
  )
  if not MZOrgMenuCommon.Confirm('Criar organizacao?', summary, { labels = { confirm = 'Criar', cancel = 'Cancelar' } }) then return end
  MZOrgMenuRequest.BeginStaffModule('create')
  request('mz_org:server:staffCreateOrganization', payload, function(result)
    MZOrgStaffMenu.AfterMutation(result, result.organization and result.organization.code or normalized.code)
  end, { withoutOrganizationRevision = true })
end

function MZOrgStaffMutations.EditBasic(data)
  if not hasAction(data, 'edit') then return end
  local org = data.organization or {}
  local public = type(org.public) == 'table' and org.public or {}
  local metadata = type(public.metadata) == 'table' and public.metadata or {}
  local values = MZOrgMenuCommon.InputDialog('Editar dados basicos', {
    { type = 'input', label = 'Nome oficial', required = true, default = org.name },
    { type = 'input', label = 'Nome de exibicao', default = public.displayName or '' },
    { type = 'input', label = 'Descricao curta', default = public.description or '' },
    { type = 'input', label = 'Metadata: categoria', default = metadata.category or '' },
    { type = 'input', label = 'Metadata: locale', default = metadata.locale or '' },
    { type = 'input', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local payload = {
    orgCode = org.code, organizationRevision = org.organizationRevision,
    name = values[1], displayName = optional(values[2]), description = optional(values[3]),
    metadata = { category = optional(values[4]), locale = optional(values[5]) }, reason = values[6]
  }
  if not MZOrgMenuCommon.Confirm('Salvar dados basicos?', ('Organizacao: %s\nNome: %s'):format(org.code, tostring(values[1]))) then return end
  MZOrgMenuRequest.BeginStaffModule('organizations', org.code)
  request('mz_org:server:staffUpdateOrganizationBasic', payload, function(result)
    MZOrgStaffMenu.AfterMutation(result, org.code)
  end)
end

function MZOrgStaffMutations.ChangeType(data)
  if not hasAction(data, 'edit') then return end
  local org = data.organization or {}
  local values = MZOrgMenuCommon.InputDialog('Alterar tipo', {
    { type = 'select', label = 'Novo tipo', required = true, default = org.type, options = typeOptions(false) },
    { type = 'input', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local payload = {
    orgCode = org.code, organizationRevision = org.organizationRevision,
    targetType = values[1], dropIncompatible = false, reason = values[2]
  }
  MZOrgMenuRequest.BeginStaffModule('organizations', org.code)
  request('mz_org:server:staffPreviewOrganizationType', payload, function(preview)
    local impact = preview.impact or {}
    local enabled = #(impact.enabled or {}) > 0 and table.concat(impact.enabled, ', ') or 'nenhuma'
    local disabled = #(impact.disabled or {}) > 0 and table.concat(impact.disabled, ', ') or 'nenhuma'
    local incompatible = {}
    for _, name in ipairs(impact.incompatibleFeatures or {}) do incompatible[#incompatible + 1] = 'feature:' .. name end
    for _, name in ipairs(impact.incompatibleAppearance or {}) do incompatible[#incompatible + 1] = name end
    local content = ('Alterar de %s para %s?\n\nHabilitadas: %s\nDesabilitadas: %s\nTema herdado: %s -> %s\nOverrides incompativeis: %s'):format(
      tostring(impact.fromType), tostring(impact.toType), enabled, disabled,
      tostring(impact.theme and impact.theme.from), tostring(impact.theme and impact.theme.to),
      #incompatible > 0 and table.concat(incompatible, ', ') or 'nenhum'
    )
    if not MZOrgMenuCommon.Confirm('Confirmar mudanca sensivel?', content) then return end
    payload.dropIncompatible = preview.impact and preview.impact.requiresDropConfirmation == true
    payload.organizationRevision = preview.organizationRevision
    request('mz_org:server:staffChangeOrganizationType', payload, function(result)
      MZOrgStaffMenu.AfterMutation(result, org.code)
    end)
  end)
end

function MZOrgStaffMutations.Archive(data)
  if not hasAction(data, 'archive') then return end
  local org = data.organization or {}
  local values = MZOrgMenuCommon.InputDialog('Arquivar organizacao', {
    { type = 'input', label = 'Digite o codigo para confirmar: ' .. tostring(org.code), required = true },
    { type = 'input', label = 'Motivo do arquivamento', required = true }
  })
  if type(values) ~= 'table' then return end
  local content = ('Arquivar "%s"?\n\nA organizacao deixara de aparecer para membros e nao aceitara mutacoes. Membros, cargos, registros, saldo e historico serao preservados.'):format(org.name or org.code)
  if not MZOrgMenuCommon.Confirm('Confirmacao forte', content) then return end
  local payload = {
    orgCode = org.code, organizationRevision = org.organizationRevision,
    confirmCode = values[1], reason = values[2]
  }
  MZOrgMenuRequest.BeginStaffModule('organizations', org.code)
  request('mz_org:server:staffArchiveOrganization', payload, function(result)
    MZOrgStaffMenu.AfterMutation(result, org.code)
  end)
end

function MZOrgStaffMutations.Restore(data)
  if not hasAction(data, 'restore') then return end
  local org = data.organization or {}
  local values = MZOrgMenuCommon.InputDialog('Reativar organizacao', {
    { type = 'input', label = 'Motivo da reativacao', required = true }
  })
  if type(values) ~= 'table' then return end
  if not MZOrgMenuCommon.Confirm('Reativar organizacao?', ('Codigo: %s\nTipo: %s\nMembros e lideranca nao serao alterados.'):format(org.code, org.type)) then return end
  local payload = { orgCode = org.code, organizationRevision = org.organizationRevision, reason = values[1] }
  MZOrgMenuRequest.BeginStaffModule('organizations', org.code)
  request('mz_org:server:staffRestoreOrganization', payload, function(result)
    MZOrgStaffMenu.AfterMutation(result, org.code)
  end)
end
