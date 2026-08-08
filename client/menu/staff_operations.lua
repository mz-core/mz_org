MZOrgStaffOperations = MZOrgStaffOperations or {}

local function hasAction(data, action)
  for _, value in ipairs(type(data) == 'table' and data.allowedActions or {}) do
    if value == action then return true end
  end
  return false
end

local VIP_CAPABILITIES = {
  ['org.view'] = true,
  ['members.view'] = true,
  ['logs.view'] = true
}

local function capabilityAllowedForType(orgType, capability)
  orgType = tostring(orgType or ''):lower()
  capability = tostring(capability or ''):lower()
  if orgType ~= 'vip' then return true end
  return VIP_CAPABILITIES[capability] == true or capability:match('^vip%.') ~= nil
end

local function parentId(data)
  return 'mz_org:staff:org:' .. tostring(data.organization.code) .. ':root'
end

local function request(data, eventName, payload)
  local org = data.organization or {}
  payload = type(payload) == 'table' and payload or {}
  payload.orgCode = org.code
  payload.organizationRevision = org.organizationRevision
  MZOrgMenuRequest.BeginStaffModule('organizations', org.code)
  MZOrgMenuRequest.RequestMutation(eventName, payload, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Operacao Staff recusada.', 'error')
      return
    end
    MZOrgStaffMenu.AfterMutation(response.data, org.code)
  end)
end

local function reasonInput(title)
  local values = MZOrgMenuCommon.InputDialog(title, {
    { type = 'textarea', label = 'Motivo', required = true, description = 'Registrado na auditoria da operacao.' }
  })
  if type(values) ~= 'table' then return nil end
  return MZOrgMenuMutations.NormalizeReason(values[1])
end

local function gradeOptions(data, includeInactive, includeBlank)
  local options = {}
  if includeBlank then options[#options + 1] = { value = '', label = 'Sem heranca' } end
  for _, grade in ipairs(data.grades or {}) do
    if includeInactive or grade.active then
      options[#options + 1] = {
        value = tostring(grade.level),
        label = ('Nivel %s - %s%s'):format(
          tostring(grade.level), tostring(grade.name or grade.code), grade.active and '' or ' (inativo)'
        )
      }
    end
  end
  return options
end

local function memberOptions(data)
  local options = {}
  for _, member in ipairs(data.members or {}) do
    options[#options + 1] = {
      value = tostring(member.citizenid),
      label = ('%s - %s'):format(tostring(member.name or member.citizenid), tostring(member.gradeName or member.gradeCode))
    }
  end
  return options
end

local function mutateMember(data, member, operation)
  local definitions = {
    promote = {
      action = 'membersPromote', event = 'mz_org:server:staffPromoteMember',
      title = 'Promover membro?', verb = 'Promover'
    },
    demote = {
      action = 'membersDemote', event = 'mz_org:server:staffDemoteMember',
      title = 'Rebaixar membro?', verb = 'Rebaixar'
    },
    remove = {
      action = 'membersRemove', event = 'mz_org:server:staffRemoveMember',
      title = 'Remover membro?', verb = 'Remover'
    }
  }
  local definition = definitions[operation]
  if not definition or not hasAction(data, definition.action) then return end
  local reason = reasonInput(definition.verb .. ' membro')
  if not reason then return end
  local content = ('Organizacao: %s\nMembro: %s\nCargo atual: %s\n\nA hierarquia sera revalidada pelo servidor.'):format(
    tostring(data.organization.code), tostring(member.name or member.citizenid),
    tostring(member.gradeName or member.gradeCode or member.gradeLevel)
  )
  if not MZOrgMenuCommon.Confirm(definition.title, content, {
    labels = { confirm = definition.verb, cancel = 'Cancelar' }
  }) then return end
  request(data, definition.event, { targetCitizenId = member.citizenid, reason = reason })
end

function MZOrgStaffOperations.OpenMember(data, member)
  local options = {
    { title = tostring(member.name or member.citizenid), description = tostring(member.gradeName or member.gradeCode), icon = member.isLeader and 'crown' or 'users', readOnly = true },
    { title = 'CitizenID', description = tostring(member.citizenid), icon = 'info', readOnly = true },
    { title = 'Em servico', description = member.isDuty and 'Sim' or 'Nao', icon = 'power', readOnly = true }
  }
  if hasAction(data, 'setLeader') then
    options[#options + 1] = {
      title = 'Definir como lider',
      description = 'Move para o cargo mais alto e torna a organizacao primaria.',
      icon = 'crown',
      onSelect = function()
        local reason = reasonInput('Definir lideranca')
        if not reason then return end
        if not MZOrgMenuCommon.Confirm('Alterar lideranca?', ('Novo lider: %s\nCitizenID: %s'):format(
          tostring(member.name or member.citizenid), tostring(member.citizenid)
        )) then return end
        request(data, 'mz_org:server:staffSetLeader', { targetCitizenId = member.citizenid, reason = reason })
      end
    }
  end
  if hasAction(data, 'membersPromote') then
    options[#options + 1] = { title = 'Promover', icon = 'arrow-up', onSelect = function() mutateMember(data, member, 'promote') end }
  end
  if hasAction(data, 'membersDemote') then
    options[#options + 1] = { title = 'Rebaixar', icon = 'arrow-down', onSelect = function() mutateMember(data, member, 'demote') end }
  end
  if hasAction(data, 'membersRemove') then
    options[#options + 1] = {
      title = 'Remover da organizacao',
      description = 'Operacao sensivel e auditada.',
      icon = 'x',
      onSelect = function() mutateMember(data, member, 'remove') end
    }
  end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. data.organization.code .. ':member:' .. tostring(member.citizenid),
    title = 'Detalhes do membro',
    subtitle = data.organization.name,
    menu = 'mz_org:staff:org:' .. data.organization.code .. ':members:operational',
    options = options
  }))
end

function MZOrgStaffOperations.InviteMember(data)
  if not hasAction(data, 'membersInvite') then return end
  local grades = gradeOptions(data, false, false)
  if #grades == 0 then MZOrgMenuCommon.Notify('Nenhum cargo ativo disponivel.', 'error') return end
  local values = MZOrgMenuCommon.InputDialog('Convidar membro', {
    { type = 'input', label = 'CitizenID', required = true },
    { type = 'select', label = 'Cargo inicial', required = true, options = grades, default = grades[1].value },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local citizenid = MZOrgMenuMutations.NormalizeCitizenId(values[1])
  local reason = MZOrgMenuMutations.NormalizeReason(values[3])
  if not citizenid or not reason then MZOrgMenuCommon.Notify('CitizenID ou motivo invalido.', 'error') return end
  if not MZOrgMenuCommon.Confirm('Adicionar membro?', ('CitizenID: %s\nCargo nivel: %s'):format(citizenid, tostring(values[2]))) then return end
  request(data, 'mz_org:server:staffInviteMember', {
    targetCitizenId = citizenid, gradeLevel = tonumber(values[2]), reason = reason
  })
end

function MZOrgStaffOperations.OpenMembers(data)
  local options = {}
  if hasAction(data, 'membersInvite') then
    options[#options + 1] = {
      title = 'Adicionar membro',
      description = 'Adiciona por CitizenID em um cargo ativo.',
      icon = 'plus',
      onSelect = function() MZOrgStaffOperations.InviteMember(data) end
    }
  end
  local operational = hasAction(data, 'setLeader') or hasAction(data, 'membersRemove')
    or hasAction(data, 'membersPromote') or hasAction(data, 'membersDemote')
  for _, member in ipairs(data.members or {}) do
    local selected = member
    options[#options + 1] = {
      title = tostring(selected.name or selected.citizenid),
      description = tostring(selected.gradeName or selected.gradeCode or 'Sem cargo'),
      icon = selected.isLeader and 'crown' or 'users',
      metadata = {
        { label = 'CitizenID', value = selected.citizenid },
        { label = 'Entrada', value = MZOrgMenuCommon.FormatDateTime(selected.joinedAt) }
      },
      readOnly = not operational,
      onSelect = operational and function() MZOrgStaffOperations.OpenMember(data, selected) end or nil
    }
  end
  if #options == 0 then options[1] = { title = 'Nenhum membro encontrado', icon = 'users', readOnly = true } end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. data.organization.code .. ':members:operational',
    title = 'Membros',
    subtitle = data.organization.name .. (operational and ' / operacional' or ' / somente leitura'),
    menu = parentId(data),
    options = options
  }))
end

function MZOrgStaffOperations.OpenLeadership(data)
  local options = {}
  local leader = data.leader
  if leader then
    options[#options + 1] = {
      title = tostring(leader.name or leader.citizenid),
      description = tostring(leader.gradeName or leader.gradeCode),
      icon = 'crown',
      readOnly = true
    }
  else
    options[#options + 1] = { title = 'Lideranca nao identificada', icon = 'warning', readOnly = true }
  end
  if hasAction(data, 'setLeader') then
    options[#options + 1] = {
      title = 'Alterar lideranca',
      description = 'Seleciona um membro atual e aplica o cargo mais alto.',
      icon = 'crown',
      onSelect = function()
        local members = memberOptions(data)
        if #members == 0 then MZOrgMenuCommon.Notify('A organizacao nao possui membros.', 'error') return end
        local values = MZOrgMenuCommon.InputDialog('Alterar lideranca', {
          { type = 'select', label = 'Novo lider', required = true, options = members, default = members[1].value },
          { type = 'textarea', label = 'Motivo', required = true }
        })
        if type(values) ~= 'table' then return end
        local reason = MZOrgMenuMutations.NormalizeReason(values[2])
        if not reason then MZOrgMenuCommon.Notify('Motivo invalido.', 'error') return end
        if not MZOrgMenuCommon.Confirm('Confirmar nova lideranca?', 'A hierarquia e o cargo mais alto serao revalidados pelo servidor.') then return end
        request(data, 'mz_org:server:staffSetLeader', { targetCitizenId = values[1], reason = reason })
      end
    }
  end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. data.organization.code .. ':leadership:operational',
    title = 'Lideranca',
    subtitle = data.organization.name,
    menu = parentId(data),
    options = options
  }))
end

function MZOrgStaffOperations.CreateGrade(data)
  if not hasAction(data, 'grades') then return end
  local inheritance = gradeOptions(data, true, true)
  local values = MZOrgMenuCommon.InputDialog('Criar cargo', {
    { type = 'number', label = 'Nivel', required = true },
    { type = 'input', label = 'Codigo', required = true, placeholder = 'ex.: supervisor' },
    { type = 'input', label = 'Nome', required = true },
    { type = 'number', label = 'Salario', default = 0 },
    { type = 'select', label = 'Herda de', options = inheritance, default = '' },
    { type = 'number', label = 'Prioridade', description = 'Vazio utiliza o nivel.' },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  if not MZOrgMenuCommon.Confirm('Criar cargo?', ('Nivel: %s\nCodigo: %s\nNome: %s'):format(
    tostring(values[1]), tostring(values[2]), tostring(values[3])
  )) then return end
  request(data, 'mz_org:server:staffCreateGrade', {
    level = tonumber(values[1]), code = values[2], name = values[3],
    salary = tonumber(values[4]) or 0,
    inheritsLevel = values[5] ~= '' and tonumber(values[5]) or nil,
    priority = values[6] and tonumber(values[6]) or tonumber(values[1]),
    reason = values[7]
  })
end

function MZOrgStaffOperations.EditGrade(data, grade)
  if not hasAction(data, 'grades') then return end
  local inheritance = gradeOptions(data, true, true)
  local values = MZOrgMenuCommon.InputDialog('Editar cargo', {
    { type = 'number', label = 'Nivel', required = true, default = grade.level },
    { type = 'input', label = 'Nome', required = true, default = grade.name },
    { type = 'number', label = 'Salario', default = grade.salary or 0 },
    { type = 'select', label = 'Herda de', options = inheritance, default = grade.inheritsLevel and tostring(grade.inheritsLevel) or '' },
    { type = 'number', label = 'Prioridade', default = grade.priority or grade.level },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  if not MZOrgMenuCommon.Confirm('Salvar cargo?', 'Alteracoes de nivel e heranca podem afetar a hierarquia.') then return end
  request(data, 'mz_org:server:staffUpdateGrade', {
    gradeId = grade.id, level = tonumber(values[1]), name = values[2],
    salary = tonumber(values[3]) or 0,
    inheritsLevel = values[4] ~= '' and tonumber(values[4]) or nil,
    priority = tonumber(values[5]) or tonumber(values[1]),
    reason = values[6]
  })
end

function MZOrgStaffOperations.AddCapability(data, grade)
  local current = {}
  for _, capability in ipairs(grade.directCapabilities or {}) do current[capability] = true end
  local available = {}
  for _, capability in ipairs(MZOrgMenuMutations.GetOfficialCapabilities()) do
    if not current[capability] and capabilityAllowedForType(data.organization and data.organization.type, capability) then
      available[#available + 1] = { value = capability, label = capability }
    end
  end
  if #available == 0 then MZOrgMenuCommon.Notify('Todas as capabilities oficiais ja estao configuradas.', 'inform') return end
  local values = MZOrgMenuCommon.InputDialog('Adicionar capability', {
    { type = 'select', label = 'Capability organizacional', required = true, options = available, default = available[1].value },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  request(data, 'mz_org:server:staffAddGradeCapability', {
    gradeId = grade.id, capability = values[1], reason = values[2]
  })
end

function MZOrgStaffOperations.RemoveCapability(data, grade)
  local options = {}
  for _, capability in ipairs(grade.directCapabilities or {}) do
    options[#options + 1] = { value = capability, label = capability }
  end
  if #options == 0 then MZOrgMenuCommon.Notify('Este cargo nao possui capability direta para remover.', 'inform') return end
  local values = MZOrgMenuCommon.InputDialog('Remover capability', {
    { type = 'select', label = 'Capability direta', required = true, options = options, default = options[1].value },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  if not MZOrgMenuCommon.Confirm('Remover capability?', tostring(values[1])) then return end
  request(data, 'mz_org:server:staffRemoveGradeCapability', {
    gradeId = grade.id, capability = values[1], reason = values[2]
  })
end

function MZOrgStaffOperations.OpenGrade(data, grade)
  local capabilities = table.concat(grade.capabilities or {}, ', ')
  local options = {
    { title = tostring(grade.name or grade.code), description = 'Nivel ' .. tostring(grade.level), icon = 'shield', readOnly = true },
    { title = 'Salario', description = MZOrgMenuCommon.FormatMoney(grade.salary or 0), icon = 'wallet', readOnly = true },
    { title = 'Heranca', description = tostring(grade.inheritsCode or grade.inheritsLevel or 'Nenhuma'), icon = 'layers', readOnly = true },
    { title = 'Capabilities efetivas', description = capabilities ~= '' and capabilities or 'Nenhuma', icon = 'lock', readOnly = true },
    { title = 'Membros', description = tostring(grade.memberCount or 0), icon = 'users', readOnly = true }
  }
  if hasAction(data, 'grades') then
    options[#options + 1] = { title = 'Editar cargo', icon = 'edit', onSelect = function() MZOrgStaffOperations.EditGrade(data, grade) end }
    if grade.active then
      options[#options + 1] = { title = 'Adicionar capability', icon = 'plus', onSelect = function() MZOrgStaffOperations.AddCapability(data, grade) end }
      options[#options + 1] = { title = 'Remover capability direta', icon = 'x', onSelect = function() MZOrgStaffOperations.RemoveCapability(data, grade) end }
      options[#options + 1] = {
        title = 'Desativar cargo', icon = 'archive',
        onSelect = function()
          local reason = reasonInput('Desativar cargo')
          if not reason then return end
          if not MZOrgMenuCommon.Confirm('Desativar cargo?', 'Cargos com membros e o cargo mais alto sao protegidos.') then return end
          request(data, 'mz_org:server:staffDisableGrade', { gradeId = grade.id, reason = reason })
        end
      }
    else
      options[#options + 1] = {
        title = 'Reativar cargo', icon = 'refresh',
        onSelect = function()
          local reason = reasonInput('Reativar cargo')
          if reason then request(data, 'mz_org:server:staffReactivateGrade', { gradeId = grade.id, reason = reason }) end
        end
      }
    end
  end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. data.organization.code .. ':grade:' .. tostring(grade.id),
    title = 'Cargo',
    subtitle = data.organization.name,
    menu = 'mz_org:staff:org:' .. data.organization.code .. ':grades:operational',
    options = options
  }))
end

function MZOrgStaffOperations.OpenGrades(data)
  local options = {}
  if hasAction(data, 'grades') then
    options[#options + 1] = {
      title = 'Criar cargo',
      description = 'Novo nivel usando o contrato oficial.',
      icon = 'plus',
      onSelect = function() MZOrgStaffOperations.CreateGrade(data) end
    }
  end
  for _, grade in ipairs(data.grades or {}) do
    local selected = grade
    options[#options + 1] = {
      title = ('%s - %s'):format(tostring(selected.level), tostring(selected.name or selected.code)),
      description = ('%s / %s membro(s)'):format(selected.active and 'Ativo' or 'Inativo', tostring(selected.memberCount or 0)),
      icon = 'shield',
      onSelect = function() MZOrgStaffOperations.OpenGrade(data, selected) end
    }
  end
  if #options == 0 then options[1] = { title = 'Nenhum cargo encontrado', icon = 'shield', readOnly = true } end
  MZOrgMenuCommon.OpenContext(MZOrgStaffMenu.Visual({
    id = 'mz_org:staff:org:' .. data.organization.code .. ':grades:operational',
    title = 'Cargos',
    subtitle = data.organization.name .. (hasAction(data, 'grades') and ' / operacional' or ' / somente leitura'),
    menu = parentId(data),
    options = options
  }))
end
