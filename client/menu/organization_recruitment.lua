MZOrgOrganizationRecruitment = MZOrgOrganizationRecruitment or {}

local MANAGE_CAPABILITIES = { 'recruitment.manage', 'members.invite', 'manage.members' }

local function reason(title)
  local values = MZOrgMenuCommon.InputDialog(title, {
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return nil end
  return MZOrgMenuMutations.NormalizeReason(values[1])
end

local function decide(context, item, operation)
  local definitions = {
    approve = { event = 'mz_org:server:organizationApproveRecruitment', label = 'Aprovar' },
    reject = { event = 'mz_org:server:organizationRejectRecruitment', label = 'Rejeitar' },
    cancel = { event = 'mz_org:server:organizationCancelRecruitment', label = 'Cancelar' }
  }
  local definition = definitions[operation]
  if not definition then return end
  local operationReason = reason(definition.label .. ' recrutamento')
  if not operationReason then return end
  if not MZOrgMenuCommon.Confirm(definition.label .. ' registro?', ('Candidato: %s\nCitizenID: %s'):format(
    tostring(item.candidateName or item.candidateCitizenId), tostring(item.candidateCitizenId)
  )) then return end
  MZOrgOrganizationCommon.Mutate(context, definition.event, {
    recruitmentId = item.id,
    reason = operationReason
  })
end

local function openItem(context, item)
  local organization = context.organization
  local options = {
    { title = tostring(item.candidateName or item.candidateCitizenId), description = tostring(item.status), icon = 'user-search', readOnly = true },
    { title = 'CitizenID', description = tostring(item.candidateCitizenId or '-'), icon = 'info', readOnly = true },
    { title = 'Cargo desejado', description = tostring(item.desiredGradeCode or item.desiredGradeLevel or '-'), icon = 'shield', readOnly = true },
    { title = 'Observacao', description = tostring(item.note or 'Nao informada'), icon = 'info', readOnly = true }
  }
  if item.status == 'pending' and MZOrgMenuCommon.HasAnyCapability(organization, MANAGE_CAPABILITIES) then
    options[#options + 1] = { title = 'Aprovar', icon = 'check', onSelect = function() decide(context, item, 'approve') end }
    options[#options + 1] = { title = 'Rejeitar', icon = 'x', onSelect = function() decide(context, item, 'reject') end }
    options[#options + 1] = { title = 'Cancelar', icon = 'archive', onSelect = function() decide(context, item, 'cancel') end }
  end
  MZOrgMenuCommon.OpenContext(MZOrgOrganizationCommon.Visual({
    id = 'mz_org:org:' .. organization.code .. ':recruitment:' .. tostring(item.id),
    title = 'Recrutamento',
    subtitle = organization.name,
    menu = 'mz_org:org:' .. organization.code .. ':recruitment',
    options = options
  }))
end

local function create(context, grades)
  local organization = context.organization
  local actorLevel = tonumber(organization.grade and organization.grade.level) or 0
  local gradeOptions = {}
  for _, grade in ipairs(grades or {}) do
    if tonumber(grade.level) and tonumber(grade.level) < actorLevel then
      gradeOptions[#gradeOptions + 1] = {
        value = tostring(grade.level),
        label = ('Nivel %s - %s'):format(tostring(grade.level), tostring(grade.name or grade.code))
      }
    end
  end
  if #gradeOptions == 0 then MZOrgMenuCommon.Notify('Nenhum cargo inferior disponivel.', 'error') return end
  local values = MZOrgMenuCommon.InputDialog('Novo recrutamento', {
    { type = 'input', label = 'CitizenID do candidato', required = true },
    { type = 'select', label = 'Cargo desejado', required = true, options = gradeOptions, default = gradeOptions[1].value },
    { type = 'textarea', label = 'Observacao' },
    { type = 'textarea', label = 'Motivo', required = true }
  })
  if type(values) ~= 'table' then return end
  local valid, normalized = MZOrgOrganizationMutations.SanitizeRecruitment({
    targetCitizenId = values[1], desiredGradeLevel = tonumber(values[2]),
    note = values[3], reason = values[4]
  }, 'create')
  if not valid then MZOrgMenuCommon.Notify('Dados de recrutamento invalidos.', 'error') return end
  MZOrgOrganizationCommon.Mutate(context, 'mz_org:server:organizationCreateRecruitment', normalized)
end

local function open(context, offset)
  MZOrgOrganizationCommon.Request(context, 'recruitment', 'mz_org:server:organizationListRecruitment', {
    offset = offset or 0
  }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Nao foi possivel consultar o recrutamento.', 'error')
      return
    end

    local options = {}
    local operational = MZOrgMenuCommon.HasAnyCapability(context.organization, MANAGE_CAPABILITIES)
    if operational then
      options[#options + 1] = {
        title = 'Novo recrutamento',
        description = 'Registra candidato por CitizenID.',
        icon = 'plus',
        onSelect = function() create(context, response.data.grades or {}) end
      }
    end
    for _, item in ipairs(response.data.items or {}) do
      local selected = item
      local desiredGrade = item.desiredGradeCode or item.desiredGradeLevel or 'Nao definido'
      options[#options + 1] = {
        title = tostring(item.candidateName or item.candidateCitizenId or 'Candidato'),
        description = tostring(item.status or 'sem status') .. ' / ' .. MZOrgMenuCommon.FormatDateTime(item.createdAt),
        icon = 'user-search',
        metadata = {
          { label = 'CitizenID', value = item.candidateCitizenId or '-' },
          { label = 'Cargo desejado', value = desiredGrade },
          { label = 'Observacao', value = item.note or 'Nao informada' },
          { label = 'Criado por', value = item.createdByName or 'Nao informado' },
          { label = 'Revisado por', value = item.reviewedByName or 'Pendente' }
        },
        readOnly = not operational,
        onSelect = operational and function() openItem(context, selected) end or nil
      }
    end
    MZOrgOrganizationCommon.Empty(options, 'Nenhum registro de recrutamento', 'user-search')
    MZOrgOrganizationCommon.AddPagination(options, response.data.pagination, function(nextOffset) open(context, nextOffset) end)
    MZOrgOrganizationCommon.Open(
      context, 'recruitment', 'Recrutamento',
      context.organization.name .. (operational and ' / operacional' or ' / somente leitura'),
      options
    )
  end)
end

function MZOrgOrganizationRecruitment.Open(context)
  open(context, 0)
end
