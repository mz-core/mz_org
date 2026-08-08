local IN_FLIGHT = {}

local ERROR_MESSAGES = {
  invalid_target = 'CitizenID de destino invalido.',
  target_not_found = 'Jogador de destino nao encontrado.',
  invalid_grade = 'Cargo invalido.',
  grade_not_found = 'Cargo inexistente.',
  grade_inactive = 'Cargo inativo.',
  grade_in_use = 'O cargo ainda possui membros.',
  grade_already_disabled = 'O cargo ja esta desativado.',
  grade_already_active = 'O cargo ja esta ativo.',
  top_grade_protected = 'O cargo de lideranca nao pode ser desativado.',
  max_grade = 'O membro ja esta no cargo mais alto.',
  min_grade = 'O membro ja esta no cargo mais baixo.',
  already_member = 'O jogador ja pertence a organizacao.',
  not_member = 'O jogador nao pertence a organizacao.',
  self_target = 'Nao e permitido executar esta acao em si mesmo.',
  self_remove = 'Nao e permitido remover a si mesmo.',
  self_action = 'Nao e permitido executar esta acao em si mesmo.',
  target_higher_or_equal = 'A hierarquia impede alterar cargo igual ou superior.',
  promotion_above_actor = 'A promocao ultrapassaria a hierarquia permitida.',
  leader_permission_required = 'Esta acao exige permissao para alterar a lideranca.',
  leadership_not_supported = 'Este tipo de organizacao usa niveis de privilegio e nao possui lideranca.',
  invalid_grade_level = 'Nivel de cargo invalido.',
  invalid_grade_code = 'Codigo de cargo invalido.',
  invalid_grade_name = 'Nome de cargo invalido.',
  grade_level_conflict = 'Ja existe outro cargo neste nivel.',
  grade_code_conflict = 'Ja existe outro cargo com este codigo.',
  invalid_salary = 'Salario de cargo invalido.',
  invalid_priority = 'Prioridade de cargo invalida.',
  invalid_inheritance = 'Heranca de cargo invalida.',
  inheritance_cycle = 'A heranca criaria um ciclo.',
  invalid_permission = 'Capability organizacional invalida.',
  permission_already_exists = 'O cargo ja possui esta capability direta.',
  permission_not_found = 'A capability direta nao existe neste cargo.',
  staff_permission_global_only = 'Permissoes staff.* sao exclusivamente globais.',
  org_archived = 'Organizacao arquivada nao aceita mutacoes.',
  conflict = 'A organizacao mudou. Reabra a inspecao antes de tentar novamente.',
  operation_in_progress = 'Esta operacao ja esta em processamento.',
  audit_transaction_failed = 'A operacao foi cancelada porque a auditoria transacional falhou.'
}

local function errorMessage(code)
  return ERROR_MESSAGES[tostring(code or '')] or tostring(code or 'Operacao Staff recusada.')
end

local function contextualResponse(sourceId, requestId, payload, ok, value)
  local context = type(payload) == 'table' and payload._context or {}
  local response = ok and { ok = true, data = value } or {
    ok = false,
    error = errorMessage(value),
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

local function logBlocked(sourceId, requestId, payload, permission, reason)
  local context = type(payload) == 'table' and payload._context or {}
  MZOrgSecurity.SafeExport('CreateDetailedLog', 'orgs', 'staff.org.operation.blocked', {
    actor = { type = 'source', id = tostring(sourceId), source = sourceId },
    target = { type = 'org', id = tostring(context.orgCode or 'unknown'), code = context.orgCode },
    context = { org_code = context.orgCode, context_key = context.contextKey, module = context.module },
    meta = { reason = reason, permission = permission, request_id = requestId }
  })
end

local function authorize(sourceId, requestId, payload, permission)
  payload = type(payload) == 'table' and payload or {}
  local orgCode = MZOrgMenuMutations.NormalizeOrgCode(payload.orgCode)
  if not orgCode then return nil, 'invalid_code' end
  local allowed, authorizationError = MZOrgStaffMenuServer.AuthorizeMutation(
    sourceId, requestId, payload, 'organizations', permission, orgCode
  )
  if not allowed then
    logBlocked(sourceId, requestId, payload, permission, authorizationError)
    return nil, authorizationError
  end
  local org, orgError = MZOrgSecurity.GetOrg(orgCode)
  if not org then return nil, orgError or 'org_not_found' end
  if org.active ~= true then return nil, 'org_archived' end
  if tonumber(org.organizationRevision) ~= tonumber(payload.organizationRevision) then
    return nil, 'conflict'
  end
  return org
end

local function operationKey(sourceId, requestId, payload)
  local context = type(payload) == 'table' and payload._context or {}
  return ('%s:%s:%s'):format(tostring(sourceId), tostring(context.sessionRevision), tostring(requestId))
end

local function operationDto(operation, org, result)
  result = type(result) == 'table' and result or {}
  local grade = type(result.grade) == 'table' and result.grade or nil
  return {
    operation = operation,
    auditId = result.auditId,
    organization = {
      id = tonumber(org.id) or org.id,
      code = org.code,
      name = org.name,
      organizationRevision = tonumber(org.organizationRevision) or 1
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
    grade = grade and {
      id = tonumber(grade.id) or grade.id,
      level = tonumber(grade.level),
      code = grade.code,
      name = grade.name,
      salary = tonumber(grade.salary) or 0,
      priority = tonumber(grade.priority),
      active = grade.active == true,
      inheritsLevel = tonumber(grade.inheritsLevel),
      memberCount = tonumber(grade.memberCount) or 0
    } or nil,
    capability = result.permission,
    capabilities = type(result.permissions) == 'table' and result.permissions or nil
  }
end

local function execute(sourceId, requestId, payload, permission, operation, sanitizer, coreCall, requireAuditId)
  local org, authorizationError = authorize(sourceId, requestId, payload, permission)
  if not org then contextualResponse(sourceId, requestId, payload, false, authorizationError) return end
  local valid, sanitized = sanitizer(payload)
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end

  local key = operationKey(sourceId, requestId, payload)
  if IN_FLIGHT[key] then contextualResponse(sourceId, requestId, payload, false, 'operation_in_progress') return end
  IN_FLIGHT[key] = true
  local callOk, coreOk, resultOrError = pcall(coreCall, sanitized, org)
  IN_FLIGHT[key] = nil
  if not callOk then
    logBlocked(sourceId, requestId, payload, permission, 'core_export_failed')
    contextualResponse(sourceId, requestId, payload, false, 'core_export_failed')
    return
  end
  if coreOk ~= true or type(resultOrError) ~= 'table' then
    logBlocked(sourceId, requestId, payload, permission, resultOrError or 'core_mutation_failed')
    contextualResponse(sourceId, requestId, payload, false, resultOrError or 'core_mutation_failed')
    return
  end
  if requireAuditId and not resultOrError.auditId then
    contextualResponse(sourceId, requestId, payload, false, 'audit_transaction_failed')
    return
  end

  MZOrgSession.InvalidateOrganization(org.code, operation, sourceId)
  contextualResponse(sourceId, requestId, payload, true, operationDto(operation, org, resultOrError))
end

local function memberSanitizer(operation)
  return function(payload) return MZOrgMenuMutations.SanitizeStaffMember(payload, operation) end
end

local function gradeSanitizer(operation)
  return function(payload) return MZOrgMenuMutations.SanitizeStaffGrade(payload, operation) end
end

RegisterNetEvent('mz_org:server:staffInviteMember', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.members.invite', 'staff.member.invite', memberSanitizer('invite'),
    function(value, org)
      return MZOrgSecurity.SafeExport('InviteOrgMemberByCitizenId', sourceId, org.code, value.targetCitizenId, {
        gradeLevel = value.gradeLevel, gradeCode = value.gradeCode, reason = value.reason
      })
    end, false)
end)

RegisterNetEvent('mz_org:server:staffRemoveMember', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.members.remove', 'staff.member.remove', memberSanitizer('remove'),
    function(value, org)
      return MZOrgSecurity.SafeExport('RemoveOrgMember', sourceId, org.code, value.targetCitizenId, {
        reason = value.reason
      })
    end, false)
end)

RegisterNetEvent('mz_org:server:staffPromoteMember', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.members.promote', 'staff.member.promote', memberSanitizer('promote'),
    function(value, org)
      return MZOrgSecurity.SafeExport('PromoteOrgMemberSecure', sourceId, org.code, value.targetCitizenId, {
        reason = value.reason
      })
    end, true)
end)

RegisterNetEvent('mz_org:server:staffDemoteMember', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.members.demote', 'staff.member.demote', memberSanitizer('demote'),
    function(value, org)
      return MZOrgSecurity.SafeExport('DemoteOrgMemberSecure', sourceId, org.code, value.targetCitizenId, {
        reason = value.reason
      })
    end, true)
end)

RegisterNetEvent('mz_org:server:staffSetLeader', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.orgs.set_leader', 'staff.member.set_leader', memberSanitizer('set_leader'),
    function(value, org)
      return MZOrgSecurity.SafeExport('SetOrgLeaderByCitizenId', sourceId, org.code, value.targetCitizenId, {
        reason = value.reason
      })
    end, false)
end)

RegisterNetEvent('mz_org:server:staffCreateGrade', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.orgs.manage', 'staff.grade.create', gradeSanitizer('create'),
    function(value, org)
      return MZOrgSecurity.SafeExport('CreateOrgGrade', sourceId, org.code, value)
    end, false)
end)

RegisterNetEvent('mz_org:server:staffUpdateGrade', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.orgs.manage', 'staff.grade.update', gradeSanitizer('edit'),
    function(value, org)
      return MZOrgSecurity.SafeExport('UpdateOrgGradeBasic', sourceId, org.code, value.gradeId, value)
    end, false)
end)

RegisterNetEvent('mz_org:server:staffDisableGrade', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.orgs.manage', 'staff.grade.disable', gradeSanitizer('disable'),
    function(value, org)
      return MZOrgSecurity.SafeExport('DisableOrgGrade', sourceId, org.code, value.gradeId, value.reason)
    end, false)
end)

RegisterNetEvent('mz_org:server:staffReactivateGrade', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.orgs.manage', 'staff.grade.reactivate', gradeSanitizer('reactivate'),
    function(value, org)
      return MZOrgSecurity.SafeExport('ReactivateOrgGrade', sourceId, org.code, value.gradeId, value.reason)
    end, false)
end)

RegisterNetEvent('mz_org:server:staffAddGradeCapability', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.orgs.manage', 'staff.grade.capability.add', gradeSanitizer('add_capability'),
    function(value, org)
      return MZOrgSecurity.SafeExport(
        'AddOrgGradePermission', sourceId, org.code, value.gradeId, value.capability, value.reason
      )
    end, false)
end)

RegisterNetEvent('mz_org:server:staffRemoveGradeCapability', function(requestId, payload)
  local sourceId = source
  execute(sourceId, requestId, payload, 'staff.orgs.manage', 'staff.grade.capability.remove', gradeSanitizer('remove_capability'),
    function(value, org)
      return MZOrgSecurity.SafeExport(
        'RemoveOrgGradePermission', sourceId, org.code, value.gradeId, value.capability, value.reason
      )
    end, false)
end)
