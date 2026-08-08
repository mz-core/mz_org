local ACTION_COOLDOWN = {}
local IN_FLIGHT = {}

local ERROR_MESSAGES = {
  invalid_target = 'Destino invalido.',
  target_not_found = 'Jogador de destino nao encontrado.',
  invalid_grade = 'Cargo invalido.',
  grade_not_found = 'Cargo inexistente.',
  grade_not_allowed = 'A hierarquia nao permite utilizar este cargo.',
  already_member = 'O jogador ja pertence a organizacao.',
  not_member = 'O jogador nao pertence a organizacao.',
  self_target = 'Nao e permitido executar esta acao em si mesmo.',
  self_remove = 'Nao e permitido remover a si mesmo.',
  self_action = 'Nao e permitido alterar o proprio cargo.',
  target_higher_or_equal = 'A hierarquia impede alterar cargo igual ou superior.',
  promotion_above_actor = 'A promocao ultrapassaria seu proprio cargo.',
  leader_permission_required = 'A acao atingiria o cargo de lideranca.',
  max_grade = 'O membro ja esta no cargo mais alto permitido.',
  min_grade = 'O membro ja esta no cargo mais baixo.',
  invalid_amount = 'Valor financeiro invalido.',
  insufficient_funds = 'Saldo insuficiente.',
  invalid_title = 'Titulo da meta invalido.',
  invalid_description = 'Descricao invalida.',
  invalid_recruitment = 'Registro de recrutamento invalido.',
  recruitment_not_found = 'Registro de recrutamento inexistente.',
  invalid_status = 'O registro de recrutamento nao esta pendente.',
  already_pending = 'Ja existe recrutamento pendente para este jogador.',
  forbidden = 'O servidor recusou a capability para esta acao.',
  org_archived = 'Organizacao arquivada nao aceita mutacoes.',
  audit_transaction_failed = 'A alteracao de cargo foi cancelada porque a auditoria falhou.',
  rate_limited = 'Aguarde antes de executar esta acao novamente.',
  operation_in_progress = 'Esta operacao ja esta em processamento.',
  invalid_grade_level = 'Nivel de cargo invalido.',
  invalid_grade_name = 'Nome de cargo invalido.',
  invalid_grade_code = 'Codigo de cargo invalido.',
  invalid_salary = 'Salario invalido.',
  invalid_priority = 'Prioridade invalida.',
  invalid_inheritance = 'Heranca de cargo invalida.',
  inheritance_not_lower = 'O cargo so pode herdar de um nivel inferior.',
  inheritance_cycle = 'A heranca criaria um ciclo.',
  grade_code_conflict = 'Ja existe um cargo com este codigo.',
  grade_level_conflict = 'Ja existe um cargo neste nivel.',
  grade_above_actor = 'O novo nivel deve permanecer abaixo do seu cargo.',
  grade_in_use = 'Nao e possivel desativar um cargo que possui membros.',
  top_grade_protected = 'O cargo de lideranca esta protegido.',
  grade_already_disabled = 'O cargo ja esta desativado.',
  grade_already_active = 'O cargo ja esta ativo.',
  grade_inactive = 'O cargo esta inativo.',
  invalid_permission = 'Capability organizacional invalida.',
  staff_permission_global_only = 'Permissoes staff.* nunca pertencem a cargos organizacionais.',
  capability_not_owned = 'Voce so pode delegar capabilities que o seu cargo possui.',
  permission_already_exists = 'A capability ja esta configurada diretamente neste cargo.',
  permission_not_found = 'A capability direta nao existe neste cargo.',
  actor_grade_inactive = 'Seu cargo atual esta inativo.',
  feature_disabled = 'A transferencia de lideranca esta desativada nesta instalacao.',
  leadership_not_supported = 'Este tipo de organizacao nao possui lideranca transferivel.',
  invalid_revision = 'A revisao da organizacao e invalida.',
  organization_revision_conflict = 'A organizacao mudou. Reabra o menu antes de transferir a lideranca.',
  invalid_reason = 'Informe um motivo valido para a transferencia.',
  self_transfer = 'Nao e permitido transferir a lideranca para si mesmo.',
  actor_not_leader = 'Somente o lider atual pode transferir a lideranca.',
  leader_state_invalid = 'A organizacao nao possui um lider unico. Solicite reparo ao Staff.',
  multiple_leaders_detected = 'Foram detectados multiplos lideres. Solicite reparo ao Staff.',
  successor_grade_not_found = 'Nao existe cargo sucessor abaixo da lideranca.',
  target_not_active_member = 'O destino nao e um membro ativo desta organizacao.',
  target_grade_inactive = 'O cargo atual do destino esta inativo.',
  target_already_leader = 'O destino ja ocupa o cargo de lideranca.',
  top_grade_not_found = 'O cargo superior da organizacao nao foi encontrado.'
}

local function message(code)
  return ERROR_MESSAGES[tostring(code or '')] or tostring(code or 'Operacao organizacional recusada.')
end

local function respond(sourceId, requestId, payload, ok, value)
  local context = type(payload) == 'table' and payload._context or {}
  local response = ok and { ok = true, data = value } or {
    ok = false,
    error = message(value),
    errorCode = value
  }
  response = MZOrgContext.ApplyResponseEnvelope(response, {
    requestId = requestId,
    sessionId = context.sessionId,
    sessionRevision = context.sessionRevision,
    contextKey = context.contextKey,
    orgCode = context.orgCode,
    module = context.module
  })
  TriggerClientEvent('mz_org:client:serverResponse', sourceId, requestId, response)
end

local function rateLimited(sourceId, action)
  local now = GetGameTimer()
  local key = tostring(sourceId) .. ':' .. tostring(action)
  local previous = ACTION_COOLDOWN[key] or 0
  if previous > 0 and now - previous < 1500 then return true end
  ACTION_COOLDOWN[key] = now
  return false
end

local function mutationKey(sourceId, requestId, payload)
  local context = type(payload) == 'table' and payload._context or {}
  return ('%s:%s:%s'):format(tostring(sourceId), tostring(context.sessionRevision), tostring(requestId))
end

local function authorize(sourceId, requestId, payload, moduleName, featureName, capabilities)
  local organization, authorizationError = MZOrgOrganizationMenuServer.AuthorizeMutation(
    sourceId, requestId, payload, moduleName, featureName, capabilities
  )
  if not organization then respond(sourceId, requestId, payload, false, authorizationError) end
  return organization
end

local function resultDto(action, organization, result)
  result = type(result) == 'table' and result or {}
  local recruitment = type(result.recruitment) == 'table' and result.recruitment or result
  local function gradeDto(grade)
    if type(grade) ~= 'table' then return nil end
    return {
      id = tonumber(grade.id) or grade.id,
      level = tonumber(grade.level) or 0,
      code = grade.code,
      name = grade.name
    }
  end
  return {
    action = action,
    auditId = result.auditId,
    organization = {
      code = organization.code,
      name = organization.name,
      organizationRevision = tonumber(result.organizationRevision) or organization.organizationRevision
    },
    target = {
      citizenid = result.targetCitizenId,
      name = result.targetName,
      oldGrade = result.oldGrade,
      oldGradeCode = result.oldGradeCode,
      newGrade = result.newGrade or result.gradeLevel or result.grade,
      newGradeCode = result.newGradeCode or result.gradeCode,
      removed = result.removed == true
    },
    account = result.balance ~= nil and {
      balance = tonumber(result.balance) or 0,
      currency = result.currency or 'R$',
      transactionId = result.transactionId
    } or nil,
    goal = result.title and {
      id = tonumber(result.id) or result.id,
      title = result.title,
      status = result.status,
      target = tonumber(result.target) or 0,
      progress = tonumber(result.progress) or 0
    } or nil,
    recruitment = recruitment and recruitment.status and {
      id = tonumber(recruitment.id) or recruitment.id,
      status = recruitment.status,
      candidateCitizenId = recruitment.candidateCitizenId or recruitment.targetCitizenId,
      candidateName = recruitment.candidateName or recruitment.targetName
    } or nil,
    grade = type(result.grade) == 'table' and {
      id = tonumber(result.grade.id) or result.grade.id,
      code = result.grade.code,
      name = result.grade.name,
      level = tonumber(result.grade.level) or 0,
      active = result.grade.active == true
    } or nil,
    capability = result.permission,
    leadership = result.previousLeader and result.newLeader and {
      previousLeader = {
        citizenid = result.previousLeader.citizenid,
        name = result.previousLeader.name,
        fromGrade = gradeDto(result.previousLeader.fromGrade),
        toGrade = gradeDto(result.previousLeader.toGrade)
      },
      newLeader = {
        citizenid = result.newLeader.citizenid,
        name = result.newLeader.name,
        fromGrade = gradeDto(result.newLeader.fromGrade),
        toGrade = gradeDto(result.newLeader.toGrade)
      },
      topGrade = gradeDto(result.topGrade),
      successorGrade = gradeDto(result.successorGrade),
      primaryMembershipChanged = result.primaryMembershipChanged == true
    } or nil
  }
end

local function execute(options)
  local sourceId, requestId, payload = options.sourceId, options.requestId, options.payload
  local organization = authorize(
    sourceId, requestId, payload, options.moduleName, options.featureName, options.capabilities
  )
  if not organization then return end
  if rateLimited(sourceId, options.action) then respond(sourceId, requestId, payload, false, 'rate_limited') return end
  local valid, sanitized = options.sanitizer(payload)
  if not valid then respond(sourceId, requestId, payload, false, sanitized) return end

  if options.preflight then
    local preflightOk, preflightError = options.preflight(sanitized, organization)
    if not preflightOk then respond(sourceId, requestId, payload, false, preflightError) return end
  end

  local key = mutationKey(sourceId, requestId, payload)
  if IN_FLIGHT[key] then respond(sourceId, requestId, payload, false, 'operation_in_progress') return end
  IN_FLIGHT[key] = true
  local callOk, coreOk, resultOrError = pcall(options.coreCall, sanitized, organization)
  IN_FLIGHT[key] = nil
  if not callOk then respond(sourceId, requestId, payload, false, 'core_export_failed') return end
  if coreOk ~= true or type(resultOrError) ~= 'table' then
    respond(sourceId, requestId, payload, false, resultOrError or 'core_mutation_failed')
    return
  end
  if options.requireAuditId and not resultOrError.auditId then
    respond(sourceId, requestId, payload, false, 'audit_transaction_failed')
    return
  end

  MZOrgSession.InvalidateOrganization(organization.code, options.action, sourceId)
  respond(sourceId, requestId, payload, true, resultDto(options.action, organization, resultOrError))
end

local function memberOperation(eventName, action, capabilities, operation, exportName, requireAuditId)
  RegisterNetEvent(eventName, function(requestId, payload)
    local sourceId = source
    execute({
      sourceId = sourceId, requestId = requestId, payload = payload,
      moduleName = 'members', featureName = 'members', capabilities = capabilities, action = action,
      sanitizer = function(value) return MZOrgOrganizationMutations.SanitizeMember(value, operation) end,
      coreCall = function(value, organization)
        if operation == 'invite' then
          return MZOrgSecurity.SafeExport(exportName, sourceId, organization.code, value.targetCitizenId, {
            gradeLevel = value.gradeLevel, gradeCode = value.gradeCode, reason = value.reason
          })
        end
        if operation == 'promote' or operation == 'demote' then
          return MZOrgSecurity.SafeExport(exportName, sourceId, organization.code, value.targetCitizenId, {
            reason = value.reason
          })
        end
        return MZOrgSecurity.SafeExport(exportName, sourceId, organization.code, value.targetCitizenId, {
          reason = value.reason
        })
      end,
      requireAuditId = requireAuditId
    })
  end)
end

memberOperation(
  'mz_org:server:organizationInviteMember', 'org.member.invite',
  { 'members.invite', 'manage.members' }, 'invite', 'InviteOrgMemberByCitizenId', false
)
memberOperation(
  'mz_org:server:organizationRemoveMember', 'org.member.remove',
  { 'members.remove', 'members.kick', 'manage.members' }, 'remove', 'RemoveOrgMember', false
)
memberOperation(
  'mz_org:server:organizationPromoteMember', 'org.member.promote',
  { 'members.promote', 'manage.members' }, 'promote', 'PromoteOrgMemberSecure', true
)
memberOperation(
  'mz_org:server:organizationDemoteMember', 'org.member.demote',
  { 'members.demote', 'manage.members' }, 'demote', 'DemoteOrgMemberSecure', true
)

RegisterNetEvent('mz_org:server:organizationTransferLeadership', function(requestId, payload)
  local sourceId = source
  local interface = type(Config.Interface) == 'table' and Config.Interface or {}
  if interface.organizationLeadershipTransfer ~= true then
    respond(sourceId, requestId, payload, false, 'feature_disabled')
    return
  end

  local orgCode = MZOrgSecurity.NormalizeOrgCode(type(payload) == 'table' and payload.orgCode or nil)
  local organization = orgCode and MZOrgSession.ResolveOrganization(sourceId, orgCode) or nil
  if type(organization) ~= 'table' or organization.supportsLeadership ~= true then
    respond(sourceId, requestId, payload, false, 'leadership_not_supported')
    return
  end

  execute({
    sourceId = sourceId,
    requestId = requestId,
    payload = payload,
    moduleName = 'members',
    featureName = 'members',
    capabilities = { 'members.set_leader' },
    action = 'org.member.transfer_leadership',
    sanitizer = MZOrgOrganizationMutations.SanitizeLeadershipTransfer,
    coreCall = function(value, organization)
      return MZOrgSecurity.SafeExport(
        'TransferOrganizationLeadership',
        sourceId,
        organization.code,
        value.targetCitizenId,
        {
          reason = value.reason,
          organizationRevision = organization.organizationRevision
        }
      )
    end,
    requireAuditId = true
  })
end)

local function accountOperation(eventName, action, capabilities, exportName)
  RegisterNetEvent(eventName, function(requestId, payload)
    local sourceId = source
    execute({
      sourceId = sourceId, requestId = requestId, payload = payload,
      moduleName = 'bank', featureName = 'bank', capabilities = capabilities, action = action,
      sanitizer = MZOrgOrganizationMutations.SanitizeAccount,
      coreCall = function(value, organization)
        return MZOrgSecurity.SafeExport(exportName, sourceId, organization.code, value.amount, value.reason)
      end
    })
  end)
end

accountOperation(
  'mz_org:server:organizationDeposit', 'org.account.deposit',
  { 'account.deposit', 'account.manage', 'manage.account' }, 'DepositOrgAccount'
)
accountOperation(
  'mz_org:server:organizationWithdraw', 'org.account.withdraw',
  { 'account.withdraw', 'account.manage', 'manage.account' }, 'WithdrawOrgAccount'
)

RegisterNetEvent('mz_org:server:organizationCreateGoal', function(requestId, payload)
  local sourceId = source
  execute({
    sourceId = sourceId, requestId = requestId, payload = payload,
    moduleName = 'goals', featureName = 'goals',
    capabilities = { 'goals.manage', 'manage.goals' }, action = 'org.goal.create',
    sanitizer = MZOrgOrganizationMutations.SanitizeGoal,
    coreCall = function(value, organization)
      return MZOrgSecurity.SafeExport('CreateOrgGoal', sourceId, organization.code, value)
    end
  })
end)

local RECRUITMENT_CAPABILITIES = { 'recruitment.manage', 'members.invite', 'manage.members' }

local function recruitmentPreflight(sourceId, value, organization)
  local row, readError = MZOrgSecurity.SafeExport('GetOrgRecruitment', sourceId, value.recruitmentId)
  if type(row) ~= 'table' then return false, readError or 'recruitment_not_found' end
  if row.orgCode ~= organization.code then return false, 'context_mismatch' end
  return true
end

local function recruitmentOperation(eventName, action, operation, exportName)
  RegisterNetEvent(eventName, function(requestId, payload)
    local sourceId = source
    execute({
      sourceId = sourceId, requestId = requestId, payload = payload,
      moduleName = 'recruitment', featureName = 'recruitment',
      capabilities = RECRUITMENT_CAPABILITIES, action = action,
      sanitizer = function(value) return MZOrgOrganizationMutations.SanitizeRecruitment(value, operation) end,
      preflight = operation ~= 'create' and function(value, organization)
        return recruitmentPreflight(sourceId, value, organization)
      end or nil,
      coreCall = function(value, organization)
        if operation == 'create' then
          return MZOrgSecurity.SafeExport('CreateOrgRecruitment', sourceId, organization.code, {
            citizenid = value.targetCitizenId,
            desiredGradeLevel = value.desiredGradeLevel,
            desiredGradeCode = value.desiredGradeCode,
            note = value.note or value.reason
          })
        end
        if operation == 'approve' then
          return MZOrgSecurity.SafeExport(exportName, sourceId, value.recruitmentId, {
            gradeLevel = value.desiredGradeLevel,
            gradeCode = value.desiredGradeCode,
            note = value.note or value.reason
          })
        end
        return MZOrgSecurity.SafeExport(exportName, sourceId, value.recruitmentId, value.reason)
      end
    })
  end)
end

recruitmentOperation(
  'mz_org:server:organizationCreateRecruitment', 'org.recruitment.create', 'create', 'CreateOrgRecruitment'
)
recruitmentOperation(
  'mz_org:server:organizationApproveRecruitment', 'org.recruitment.approve', 'approve', 'ApproveOrgRecruitment'
)
recruitmentOperation(
  'mz_org:server:organizationRejectRecruitment', 'org.recruitment.reject', 'reject', 'RejectOrgRecruitment'
)
recruitmentOperation(
  'mz_org:server:organizationCancelRecruitment', 'org.recruitment.cancel', 'cancel', 'CancelOrgRecruitment'
)

local function gradeOperation(eventName, action, operation, exportName)
  RegisterNetEvent(eventName, function(requestId, payload)
    local sourceId = source
    execute({
      sourceId = sourceId, requestId = requestId, payload = payload,
      moduleName = 'grades', featureName = 'grades',
      capabilities = { 'manage.permissions' }, action = action,
      sanitizer = function(value) return MZOrgOrganizationMutations.SanitizeGrade(value, operation) end,
      coreCall = function(value, organization)
        if operation == 'create' then
          return MZOrgSecurity.SafeExport(exportName, sourceId, organization.code, value)
        end
        if operation == 'edit' then
          return MZOrgSecurity.SafeExport(exportName, sourceId, organization.code, value.gradeId, value)
        end
        if operation == 'add_capability' or operation == 'remove_capability' then
          return MZOrgSecurity.SafeExport(
            exportName, sourceId, organization.code, value.gradeId, value.capability, value.reason
          )
        end
        return MZOrgSecurity.SafeExport(exportName, sourceId, organization.code, value.gradeId, value.reason)
      end
    })
  end)
end

gradeOperation(
  'mz_org:server:organizationCreateGrade', 'org.grade.create',
  'create', 'CreateOrganizationGrade'
)
gradeOperation(
  'mz_org:server:organizationUpdateGrade', 'org.grade.update',
  'edit', 'UpdateOrganizationGradeBasic'
)
gradeOperation(
  'mz_org:server:organizationDisableGrade', 'org.grade.disable',
  'disable', 'DisableOrganizationGrade'
)
gradeOperation(
  'mz_org:server:organizationReactivateGrade', 'org.grade.reactivate',
  'reactivate', 'ReactivateOrganizationGrade'
)
gradeOperation(
  'mz_org:server:organizationAddGradeCapability', 'org.grade.permission.add',
  'add_capability', 'AddOrganizationGradePermission'
)
gradeOperation(
  'mz_org:server:organizationRemoveGradeCapability', 'org.grade.permission.remove',
  'remove_capability', 'RemoveOrganizationGradePermission'
)
