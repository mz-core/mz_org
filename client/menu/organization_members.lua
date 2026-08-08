MZOrgOrganizationMembers = MZOrgOrganizationMembers or {}

local function can(organization, capabilities)
  return MZOrgMenuCommon.HasAnyCapability(organization, capabilities)
end

local function reason(title)
  local values = MZOrgMenuCommon.InputDialog(title, {
    { type = 'textarea', label = 'Motivo', required = true, description = 'A operacao sera auditada.' }
  })
  if type(values) ~= 'table' then return nil end
  return MZOrgMenuMutations.NormalizeReason(values[1])
end

local function mutateMember(context, member, operation)
  local definitions = {
    promote = {
      capabilities = { 'members.promote', 'manage.members' },
      event = 'mz_org:server:organizationPromoteMember', label = 'Promover'
    },
    demote = {
      capabilities = { 'members.demote', 'manage.members' },
      event = 'mz_org:server:organizationDemoteMember', label = 'Rebaixar'
    },
    remove = {
      capabilities = { 'members.remove', 'members.kick', 'manage.members' },
      event = 'mz_org:server:organizationRemoveMember', label = 'Remover'
    }
  }
  local definition = definitions[operation]
  if not definition or not can(context.organization, definition.capabilities) then return end
  local operationReason = reason(definition.label .. ' membro')
  if not operationReason then return end
  if not MZOrgMenuCommon.Confirm(definition.label .. ' membro?', ('Membro: %s\nCargo: %s\n\nA hierarquia sera revalidada pelo servidor.'):format(
    tostring(member.name or member.citizenid), tostring(member.gradeName or member.gradeCode)
  )) then return end
  MZOrgOrganizationCommon.Mutate(context, definition.event, {
    targetCitizenId = member.citizenid,
    reason = operationReason
  })
end

local function transferLeadership(context, member)
  local organization = context.organization
  if context.leadershipTransferAllowed ~= true
    or not can(organization, { 'members.set_leader' }) then
    return
  end

  local operationReason = reason('Transferir lideranca')
  if not operationReason then return end
  local actorGrade = organization.grade or {}
  local confirmed = MZOrgMenuCommon.Confirm(
    'Transferir a lideranca?',
    ('Novo lider: %s\nCargo atual: %s\n\nVoce deixara o cargo superior e sera movido para o cargo sucessor definido pelo servidor. A troca e atomica, auditada e exige um lider atual unico.'):format(
      tostring(member.name or member.citizenid),
      tostring(actorGrade.name or actorGrade.code or actorGrade.level or 'Lideranca')
    )
  )
  if not confirmed then return end

  MZOrgOrganizationCommon.Mutate(context, 'mz_org:server:organizationTransferLeadership', {
    targetCitizenId = member.citizenid,
    reason = operationReason
  })
end

local function openMember(context, member)
  local organization = context.organization
  local options = {
    { title = tostring(member.name or member.citizenid), description = tostring(member.gradeName or member.gradeCode), icon = member.isLeader and 'crown' or 'users', readOnly = true },
    { title = 'CitizenID', description = tostring(member.citizenid), icon = 'info', readOnly = true },
    { title = 'Servico', description = member.isDuty and 'Em servico' or 'Fora de servico', icon = 'power', readOnly = true }
  }
  if can(organization, { 'members.promote', 'manage.members' }) then
    options[#options + 1] = { title = 'Promover', icon = 'arrow-up', onSelect = function() mutateMember(context, member, 'promote') end }
  end
  if can(organization, { 'members.demote', 'manage.members' }) then
    options[#options + 1] = { title = 'Rebaixar', icon = 'arrow-down', onSelect = function() mutateMember(context, member, 'demote') end }
  end
  if can(organization, { 'members.remove', 'members.kick', 'manage.members' }) then
    options[#options + 1] = { title = 'Remover da organizacao', icon = 'x', onSelect = function() mutateMember(context, member, 'remove') end }
  end
  local actorCitizenId = organization.membership and organization.membership.citizenId
  local actorLevel = tonumber(organization.grade and organization.grade.level) or 0
  local targetLevel = tonumber(member.gradeLevel or member.grade) or 0
  if context.leadershipTransferAllowed == true
    and can(organization, { 'members.set_leader' })
    and tostring(member.citizenid or '') ~= tostring(actorCitizenId or '')
    and member.isLeader ~= true
    and targetLevel < actorLevel then
    options[#options + 1] = {
      title = 'Transferir lideranca',
      description = 'Promove este membro e move voce para o cargo sucessor.',
      icon = 'crown',
      onSelect = function() transferLeadership(context, member) end
    }
  end
  MZOrgMenuCommon.OpenContext(MZOrgOrganizationCommon.Visual({
    id = 'mz_org:org:' .. organization.code .. ':member:' .. tostring(member.citizenid),
    title = 'Membro',
    subtitle = organization.name,
    menu = 'mz_org:org:' .. organization.code .. ':members',
    options = options
  }))
end

local function invite(context, grades)
  local organization = context.organization
  if not can(organization, { 'members.invite', 'manage.members' }) then return end
  local actorLevel = tonumber(organization.grade and organization.grade.level) or 0
  local options = {}
  for _, grade in ipairs(grades or {}) do
    if tonumber(grade.level) and tonumber(grade.level) < actorLevel then
      options[#options + 1] = {
        value = tostring(grade.level),
        label = ('Nivel %s - %s'):format(tostring(grade.level), tostring(grade.name or grade.code))
      }
    end
  end
  if #options == 0 then MZOrgMenuCommon.Notify('Nenhum cargo inferior esta disponivel para convite.', 'error') return end
  local values = MZOrgMenuCommon.InputDialog('Adicionar membro', {
    { type = 'input', label = 'CitizenID', required = true },
    { type = 'select', label = 'Cargo inicial', required = true, options = options, default = options[1].value },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local citizenid = MZOrgMenuMutations.NormalizeCitizenId(values[1])
  local operationReason = MZOrgMenuMutations.NormalizeReason(values[3])
  if not citizenid or not operationReason then MZOrgMenuCommon.Notify('CitizenID ou motivo invalido.', 'error') return end
  if not MZOrgMenuCommon.Confirm('Adicionar membro?', ('CitizenID: %s\nCargo nivel: %s'):format(citizenid, tostring(values[2]))) then return end
  MZOrgOrganizationCommon.Mutate(context, 'mz_org:server:organizationInviteMember', {
    targetCitizenId = citizenid,
    gradeLevel = tonumber(values[2]),
    reason = operationReason
  })
end

local function open(context, offset)
  local organization = context.organization
  MZOrgOrganizationCommon.Request(context, 'members', 'mz_org:server:organizationListMembers', {
    offset = offset or 0
  }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Nao foi possivel listar membros.', 'error')
      return
    end

    local options = {}
    context.leadershipTransferAllowed = type(response.data.leadership) == 'table'
      and response.data.leadership.enabled == true
      and response.data.leadership.canTransfer == true
    if can(organization, { 'members.invite', 'manage.members' }) then
      options[#options + 1] = {
        title = 'Adicionar membro',
        description = 'Convite por CitizenID e cargo inferior.',
        icon = 'plus',
        onSelect = function() invite(context, response.data.grades or {}) end
      }
    end
    local operational = can(organization, {
      'members.promote', 'members.demote', 'members.remove', 'members.kick', 'manage.members',
      'members.set_leader'
    }) and (
      can(organization, {
        'members.promote', 'members.demote', 'members.remove', 'members.kick', 'manage.members'
      }) or context.leadershipTransferAllowed == true
    )
    for _, member in ipairs(response.data.items or {}) do
      local selected = member
      local description = tostring(selected.gradeName or selected.gradeCode or 'Sem cargo')
      if selected.isLeader then description = description .. ' / Lideranca' end
      options[#options + 1] = {
        title = tostring(selected.name or selected.citizenid or 'Membro'),
        description = description,
        icon = selected.isLeader and 'crown' or 'users',
        metadata = {
          { label = 'CitizenID', value = selected.citizenid },
          { label = 'Servico', value = selected.isDuty and 'Sim' or 'Nao' }
        },
        readOnly = not operational,
        onSelect = operational and function() openMember(context, selected) end or nil
      }
    end
    MZOrgOrganizationCommon.Empty(options, 'Nenhum membro encontrado', 'users')
    MZOrgOrganizationCommon.AddPagination(options, response.data.pagination, function(nextOffset) open(context, nextOffset) end)
    MZOrgOrganizationCommon.Open(context, 'members', 'Membros', organization.name .. (operational and ' / operacional' or ' / somente leitura'), options)
  end)
end

function MZOrgOrganizationMembers.Open(context)
  open(context, 0)
end
