MZOrgOrganizationGrades = MZOrgOrganizationGrades or {}

local function canManage(context)
  return MZOrgMenuCommon.HasCapability(context.organization, 'manage.permissions')
end

local function actorLevel(context)
  local grade = type(context.organization.grade) == 'table' and context.organization.grade or {}
  return tonumber(grade.level) or 0
end

local function canManageGrade(context, grade)
  return canManage(context) and actorLevel(context) > (tonumber(grade.level) or 0)
end

local function reasonInput(title)
  local values = MZOrgMenuCommon.InputDialog(title, {
    {
      type = 'textarea',
      label = 'Motivo',
      required = true,
      description = 'O motivo sera registrado na auditoria.'
    }
  })
  if type(values) ~= 'table' then return nil end
  return MZOrgMenuMutations.NormalizeReason(values[1])
end

local function mutate(context, eventName, payload)
  MZOrgOrganizationCommon.Mutate(context, eventName, payload)
end

local function inheritanceOptions(context, grades, includeBlank, excludedGradeId)
  local options = {}
  if includeBlank then options[#options + 1] = { value = '', label = 'Sem heranca' } end
  for _, grade in ipairs(grades or {}) do
    if grade.active == true
      and tonumber(grade.id) ~= tonumber(excludedGradeId)
      and (tonumber(grade.level) or 0) < actorLevel(context)
    then
      options[#options + 1] = {
        value = tostring(grade.level),
        label = ('Nivel %s - %s'):format(tostring(grade.level), tostring(grade.name or grade.code))
      }
    end
  end
  return options
end

local function ownedCapabilities(context)
  local result = {}
  for _, capability in ipairs(context.organization.capabilities or {}) do
    if type(capability) == 'string'
      and not capability:lower():match('^staff%.')
      and capability ~= 'members.set_leader'
      and MZOrgMenuMutations.IsOfficialCapability(capability)
    then
      result[#result + 1] = capability
    end
  end
  table.sort(result)
  return result
end

function MZOrgOrganizationGrades.Create(context, data)
  if not canManage(context) then return end
  local inheritance = inheritanceOptions(context, data.items, true)
  local values = MZOrgMenuCommon.InputDialog('Criar cargo inferior', {
    { type = 'number', label = 'Nivel', required = true, description = 'Deve ser menor que o seu nivel atual.' },
    { type = 'input', label = 'Codigo', required = true, placeholder = 'ex.: supervisor' },
    { type = 'input', label = 'Nome', required = true },
    { type = 'number', label = 'Salario', default = 0 },
    { type = 'select', label = 'Herda de', options = inheritance, default = '' },
    { type = 'number', label = 'Prioridade', description = 'Vazio utiliza o nivel.' },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local reason = MZOrgMenuMutations.NormalizeReason(values[7])
  if not reason then MZOrgMenuCommon.Notify('Motivo invalido.', 'error') return end
  if not MZOrgMenuCommon.Confirm('Criar cargo?', ('Nivel: %s\nCodigo: %s\nNome: %s'):format(
    tostring(values[1]), tostring(values[2]), tostring(values[3])
  )) then return end
  mutate(context, 'mz_org:server:organizationCreateGrade', {
    level = tonumber(values[1]),
    code = values[2],
    name = values[3],
    salary = tonumber(values[4]) or 0,
    inheritsLevel = values[5] ~= '' and tonumber(values[5]) or nil,
    priority = values[6] and tonumber(values[6]) or tonumber(values[1]),
    reason = reason
  })
end

function MZOrgOrganizationGrades.Edit(context, data, grade)
  if not canManageGrade(context, grade) or grade.active ~= true then return end
  local inheritance = inheritanceOptions(context, data.items, true, grade.id)
  local values = MZOrgMenuCommon.InputDialog('Editar cargo inferior', {
    { type = 'number', label = 'Nivel', required = true, default = grade.level },
    { type = 'input', label = 'Nome', required = true, default = grade.name },
    { type = 'number', label = 'Salario', default = grade.salary or 0 },
    {
      type = 'select',
      label = 'Herda de',
      options = inheritance,
      default = grade.inheritsLevel and tostring(grade.inheritsLevel) or ''
    },
    { type = 'number', label = 'Prioridade', default = grade.priority or grade.level },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local reason = MZOrgMenuMutations.NormalizeReason(values[6])
  if not reason then MZOrgMenuCommon.Notify('Motivo invalido.', 'error') return end
  if not MZOrgMenuCommon.Confirm(
    'Salvar cargo?',
    'O servidor recusara nivel igual/superior ao seu e heranca que nao seja inferior.'
  ) then return end
  mutate(context, 'mz_org:server:organizationUpdateGrade', {
    gradeId = grade.id,
    level = tonumber(values[1]),
    name = values[2],
    salary = tonumber(values[3]) or 0,
    inheritsLevel = values[4] ~= '' and tonumber(values[4]) or nil,
    priority = tonumber(values[5]) or tonumber(values[1]),
    reason = reason
  })
end

function MZOrgOrganizationGrades.AddCapability(context, grade)
  if not canManageGrade(context, grade) or grade.active ~= true then return end
  local direct = {}
  for _, capability in ipairs(grade.directCapabilities or {}) do direct[capability] = true end
  local options = {}
  for _, capability in ipairs(ownedCapabilities(context)) do
    if not direct[capability] then options[#options + 1] = { value = capability, label = capability } end
  end
  if #options == 0 then
    MZOrgMenuCommon.Notify('Nao ha capability propria disponivel para delegar.', 'inform')
    return
  end
  local values = MZOrgMenuCommon.InputDialog('Delegar capability', {
    { type = 'select', label = 'Capability', required = true, options = options, default = options[1].value },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local reason = MZOrgMenuMutations.NormalizeReason(values[2])
  if not reason then MZOrgMenuCommon.Notify('Motivo invalido.', 'error') return end
  mutate(context, 'mz_org:server:organizationAddGradeCapability', {
    gradeId = grade.id,
    capability = values[1],
    reason = reason
  })
end

function MZOrgOrganizationGrades.RemoveCapability(context, grade)
  if not canManageGrade(context, grade) or grade.active ~= true then return end
  local owned = {}
  for _, capability in ipairs(ownedCapabilities(context)) do owned[capability] = true end
  local options = {}
  for _, capability in ipairs(grade.directCapabilities or {}) do
    if owned[capability] then options[#options + 1] = { value = capability, label = capability } end
  end
  if #options == 0 then
    MZOrgMenuCommon.Notify('Nao ha capability direta propria que possa ser removida.', 'inform')
    return
  end
  local values = MZOrgMenuCommon.InputDialog('Remover capability direta', {
    { type = 'select', label = 'Capability', required = true, options = options, default = options[1].value },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local reason = MZOrgMenuMutations.NormalizeReason(values[2])
  if not reason then MZOrgMenuCommon.Notify('Motivo invalido.', 'error') return end
  if not MZOrgMenuCommon.Confirm('Remover capability?', tostring(values[1])) then return end
  mutate(context, 'mz_org:server:organizationRemoveGradeCapability', {
    gradeId = grade.id,
    capability = values[1],
    reason = reason
  })
end

function MZOrgOrganizationGrades.OpenGrade(context, data, grade)
  local effective = table.concat(grade.capabilities or {}, ', ')
  local direct = table.concat(grade.directCapabilities or {}, ', ')
  local manageable = canManageGrade(context, grade)
  local options = {
    {
      title = tostring(grade.name or grade.code),
      description = ('Nivel %s / %s'):format(tostring(grade.level), grade.active and 'ativo' or 'inativo'),
      icon = 'shield',
      readOnly = true
    },
    { title = 'Codigo', description = tostring(grade.code or '-'), icon = 'info', readOnly = true },
    {
      title = 'Salario',
      description = MZOrgMenuCommon.FormatMoney(grade.salary or 0),
      icon = 'wallet',
      readOnly = true
    },
    {
      title = 'Heranca',
      description = tostring(grade.inheritsCode or grade.inheritsLevel or 'Nenhuma'),
      icon = 'layers',
      readOnly = true
    },
    {
      title = 'Capabilities efetivas',
      description = effective ~= '' and effective or 'Nenhuma',
      icon = 'lock',
      readOnly = true
    },
    {
      title = 'Capabilities diretas',
      description = direct ~= '' and direct or 'Nenhuma',
      icon = 'key',
      readOnly = true
    },
    {
      title = 'Membros',
      description = tostring(grade.memberCount or 0),
      icon = 'users',
      readOnly = true
    }
  }

  if manageable and grade.active == true then
    options[#options + 1] = {
      title = 'Editar dados do cargo',
      icon = 'edit',
      onSelect = function() MZOrgOrganizationGrades.Edit(context, data, grade) end
    }
    options[#options + 1] = {
      title = 'Delegar capability propria',
      description = 'Somente capabilities efetivas do seu cargo.',
      icon = 'plus',
      onSelect = function() MZOrgOrganizationGrades.AddCapability(context, grade) end
    }
    options[#options + 1] = {
      title = 'Remover capability direta',
      icon = 'x',
      onSelect = function() MZOrgOrganizationGrades.RemoveCapability(context, grade) end
    }
    if tonumber(grade.memberCount) == 0 then
      options[#options + 1] = {
        title = 'Desativar cargo',
        description = 'O cargo deve permanecer vazio.',
        icon = 'archive',
        onSelect = function()
          local reason = reasonInput('Desativar cargo')
          if not reason then return end
          if not MZOrgMenuCommon.Confirm('Desativar cargo?', tostring(grade.name or grade.code)) then return end
          mutate(context, 'mz_org:server:organizationDisableGrade', {
            gradeId = grade.id,
            reason = reason
          })
        end
      }
    end
  elseif manageable then
    options[#options + 1] = {
      title = 'Reativar cargo',
      icon = 'refresh',
      onSelect = function()
        local reason = reasonInput('Reativar cargo')
        if reason then
          mutate(context, 'mz_org:server:organizationReactivateGrade', {
            gradeId = grade.id,
            reason = reason
          })
        end
      end
    }
  end

  MZOrgMenuCommon.OpenContext(MZOrgOrganizationCommon.Visual({
    id = ('mz_org:org:%s:grade:%s'):format(context.organization.code, tostring(grade.id)),
    title = 'Cargo',
    subtitle = manageable and 'Gestao limitada pela hierarquia' or 'Somente leitura',
    menu = ('mz_org:org:%s:grades'):format(context.organization.code),
    options = options
  }))
end

function MZOrgOrganizationGrades.Open(context)
  MZOrgOrganizationCommon.Request(context, 'grades', 'mz_org:server:organizationListGrades', {}, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Nao foi possivel listar os cargos.', 'error')
      return
    end

    local data = response.data
    local options = {}
    if canManage(context) then
      options[#options + 1] = {
        title = 'Criar cargo inferior',
        description = ('Seu nivel atual: %s. O novo cargo deve ficar abaixo.'):format(tostring(actorLevel(context))),
        icon = 'plus',
        onSelect = function() MZOrgOrganizationGrades.Create(context, data) end
      }
    end

    for _, grade in ipairs(data.items or {}) do
      local selected = grade
      local description = ('Nivel %s / %s membro(s) / %s'):format(
        tostring(selected.level or 0),
        tostring(selected.memberCount or 0),
        selected.active and 'ativo' or 'inativo'
      )
      options[#options + 1] = {
        title = tostring(selected.name or selected.code or 'Cargo'),
        description = description,
        icon = 'shield',
        metadata = {
          { label = 'Codigo', value = selected.code or '-' },
          { label = 'Herda de', value = selected.inheritsCode or selected.inheritsLevel or 'Nenhum' }
        },
        onSelect = function() MZOrgOrganizationGrades.OpenGrade(context, data, selected) end
      }
    end

    MZOrgOrganizationCommon.Empty(options, 'Nenhum cargo disponivel', 'shield')
    MZOrgOrganizationCommon.Open(
      context,
      'grades',
      'Cargos',
      nil,
      options
    )
  end)
end
