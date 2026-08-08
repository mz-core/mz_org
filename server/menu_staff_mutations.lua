MZOrgStaffMutationServer = MZOrgStaffMutationServer or {}

local ERROR_MESSAGES = {
  forbidden = 'Sem permissao global especifica para esta acao.',
  invalid_context = 'Envelope contextual invalido.',
  context_mismatch = 'A organizacao nao pertence ao contexto Staff atual.',
  conflict = 'Esta organizacao foi alterada por outro administrador. Reabra o formulario antes de tentar novamente.',
  invalid_revision = 'Revisao da organizacao invalida.',
  org_not_found = 'Organizacao inexistente.',
  org_archived = 'Organizacao arquivada nao permite edicao comum.',
  org_already_exists = 'Ja existe uma organizacao com este codigo.',
  org_already_active = 'A organizacao ja esta ativa.',
  invalid_code = 'Codigo invalido.',
  invalid_name = 'Nome invalido.',
  invalid_type = 'Tipo invalido.',
  invalid_state = 'Estado inicial invalido.',
  invalid_reason = 'Informe um motivo valido.',
  display_name_required = 'Informe nome de exibicao ou brand.',
  unknown_field = 'O payload possui propriedade desconhecida.',
  unknown_feature = 'Feature desconhecida.',
  feature_not_applicable = 'Feature nao aplicavel ao tipo.',
  feature_dependency_unavailable = 'Dependencia da feature indisponivel.',
  invalid_features = 'Configuracao de features invalida.',
  invalid_appearance = 'Configuracao de aparencia invalida.',
  invalid_color = 'Cor invalida. Use #RRGGBB.',
  invalid_width = 'Largura invalida. Use um valor entre 320 e 640.',
  invalid_position = 'Posicao invalida.',
  invalid_icon = 'Icone invalido.',
  invalid_duty_type = 'Este tipo de organizacao nao utiliza ponto de servico.',
  duty_point_required = 'Informe os dados do ponto de servico.',
  invalid_duty_point = 'Configuracao do ponto de servico invalida.',
  invalid_coords = 'Coordenadas do ponto de servico invalidas.',
  invalid_radius = 'Raio invalido. Use um valor entre 1 e 5 metros.',
  invalid_draw_distance = 'Distancia de desenho invalida. Use um valor entre 5 e 50 metros.',
  invalid_label = 'Nome do ponto de servico invalido.',
  incompatible_overrides = 'Existem overrides incompativeis. Revise o impacto antes de confirmar.',
  same_type = 'A organizacao ja possui este tipo.',
  strong_confirmation_failed = 'A confirmacao forte nao corresponde ao codigo da organizacao.',
  audit_transaction_failed = 'A mutacao foi cancelada porque a auditoria nao foi confirmada.'
}

local function message(errorCode)
  return ERROR_MESSAGES[tostring(errorCode or '')] or tostring(errorCode or 'Mutacao Staff negada.')
end

local function logBlocked(sourceId, requestId, payload, permission, reason)
  local context = type(payload) == 'table' and payload._context or {}
  MZOrgSecurity.SafeExport('CreateDetailedLog', 'orgs', 'staff.org.mutation.blocked', {
    actor = { type = 'source', id = tostring(sourceId), source = sourceId },
    target = { type = 'org', id = tostring(context.orgCode or 'new'), code = context.orgCode },
    context = { org_code = context.orgCode, context_key = context.contextKey, module = context.module },
    meta = { reason = reason, permission = permission, request_id = requestId }
  })
end

local function contextualResponse(sourceId, requestId, payload, ok, value)
  local context = type(payload) == 'table' and payload._context or {}
  local response = ok and { ok = true, data = value } or { ok = false, error = message(value), errorCode = value }
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

local function mutationDto(result)
  local org = type(result) == 'table' and result.organization or {}
  return {
    auditId = result and result.auditId or nil,
    idempotent = result and result.idempotent == true or false,
    organization = {
      id = org.id,
      code = org.code,
      name = org.name,
      type = MZOrgMenuProfiles.NormalizeType(org.type),
      status = org.status,
      active = org.active == true,
      organizationRevision = tonumber(org.organizationRevision) or 1,
      updatedAt = org.updatedAt
    }
  }
end

local function authorize(sourceId, requestId, payload, moduleName, permission, orgCode)
  local allowed, err = MZOrgStaffMenuServer.AuthorizeMutation(
    sourceId, requestId, payload, moduleName, permission, orgCode
  )
  if not allowed then
    logBlocked(sourceId, requestId, payload, permission, err)
    contextualResponse(sourceId, requestId, payload, false, err)
    return false
  end
  return true
end

local function corePayload(requestId, payload, sanitized)
  local result = {}
  for key, value in pairs(type(sanitized) == 'table' and sanitized or {}) do result[key] = value end
  result.context = MZOrgStaffMenuServer.MutationContext(requestId, payload)
  return result
end

local function execute(sourceId, requestId, payload, exportName, sanitized)
  local ok, resultOrError = MZOrgSecurity.SafeExport(exportName, sourceId, corePayload(requestId, payload, sanitized))
  if ok ~= true or type(resultOrError) ~= 'table' then
    logBlocked(sourceId, requestId, payload, exportName, resultOrError or 'core_mutation_failed')
    contextualResponse(sourceId, requestId, payload, false, resultOrError or 'core_mutation_failed')
    return false
  end
  if not resultOrError.auditId then
    contextualResponse(sourceId, requestId, payload, false, 'audit_transaction_failed')
    return false
  end
  contextualResponse(sourceId, requestId, payload, true, mutationDto(resultOrError))
  if exportName == 'UpdateStaffOrganizationDutyPoint'
    or exportName == 'ChangeStaffOrganizationType'
    or exportName == 'ArchiveStaffOrganization'
    or exportName == 'RestoreStaffOrganization' then
    TriggerClientEvent('mz_org:client:refreshDutyPoints', -1)
  end
  return true
end

RegisterNetEvent('mz_org:server:staffCreateOrganization', function(requestId, payload)
  local sourceId = source
  payload = type(payload) == 'table' and payload or {}
  if not authorize(sourceId, requestId, payload, 'create', 'staff.orgs.create') then return end
  local valid, sanitized = MZOrgMenuMutations.SanitizeCreate(payload)
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end
  execute(sourceId, requestId, payload, 'CreateStaffOrganization', {
    code = sanitized.code,
    name = sanitized.name,
    type = sanitized.type,
    active = sanitized.state == 'active',
    public = sanitized.public,
    features = sanitized.features,
    appearance = sanitized.appearance,
    reason = sanitized.reason
  })
end)

RegisterNetEvent('mz_org:server:staffUpdateOrganizationBasic', function(requestId, payload)
  local sourceId = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = MZOrgMenuMutations.NormalizeOrgCode(payload.orgCode)
  if not orgCode then contextualResponse(sourceId, requestId, payload, false, 'invalid_code') return end
  if not authorize(sourceId, requestId, payload, 'organizations', 'staff.orgs.edit', orgCode) then return end
  local valid, sanitized = MZOrgMenuMutations.SanitizeBasic(payload)
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end
  local public = {}
  if payload.displayName ~= nil then public.displayName = sanitized.displayName end
  if payload.description ~= nil then public.description = sanitized.description end
  if payload.metadata ~= nil then public.metadata = sanitized.metadata end
  execute(sourceId, requestId, payload, 'UpdateStaffOrganizationBasic', {
    orgCode = orgCode,
    organizationRevision = tonumber(payload.organizationRevision),
    name = sanitized.name,
    public = public,
    reason = sanitized.reason
  })
end)

RegisterNetEvent('mz_org:server:staffPreviewOrganizationType', function(requestId, payload)
  local sourceId = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = MZOrgMenuMutations.NormalizeOrgCode(payload.orgCode)
  if not orgCode then contextualResponse(sourceId, requestId, payload, false, 'invalid_code') return end
  if not authorize(sourceId, requestId, payload, 'organizations', 'staff.orgs.edit', orgCode) then return end
  local valid, sanitized = MZOrgMenuMutations.SanitizeTypeChange(payload)
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end
  local org, orgError = MZOrgSecurity.GetOrg(orgCode)
  if not org then contextualResponse(sourceId, requestId, payload, false, orgError or 'org_not_found') return end
  if org.active ~= true then contextualResponse(sourceId, requestId, payload, false, 'org_archived') return end
  if tonumber(org.organizationRevision) ~= tonumber(payload.organizationRevision) then
    contextualResponse(sourceId, requestId, payload, false, 'conflict') return
  end
  if MZOrgMenuProfiles.NormalizeType(org.type) == sanitized.targetType then
    contextualResponse(sourceId, requestId, payload, false, 'same_type') return
  end
  local config = type(org.config) == 'table' and org.config or {}
  local impact = MZOrgMenuFeatures.ComputeTypeImpact(org.type, sanitized.targetType, config.features, config.ui)
  if type(config.dutyPoint) == 'table'
    and not MZOrgMenuMutations.SupportsDutyType(sanitized.targetType) then
    impact.incompatibleFeatures = type(impact.incompatibleFeatures) == 'table'
      and impact.incompatibleFeatures
      or {}
    impact.incompatibleFeatures[#impact.incompatibleFeatures + 1] = 'dutyPoint'
  end
  impact.requiresDropConfirmation = #(impact.incompatibleFeatures or {}) > 0 or #(impact.incompatibleAppearance or {}) > 0
  contextualResponse(sourceId, requestId, payload, true, {
    impact = impact,
    organizationRevision = tonumber(org.organizationRevision) or 1
  })
end)

RegisterNetEvent('mz_org:server:staffChangeOrganizationType', function(requestId, payload)
  local sourceId = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = MZOrgMenuMutations.NormalizeOrgCode(payload.orgCode)
  if not orgCode then contextualResponse(sourceId, requestId, payload, false, 'invalid_code') return end
  if not authorize(sourceId, requestId, payload, 'organizations', 'staff.orgs.edit', orgCode) then return end
  local valid, sanitized = MZOrgMenuMutations.SanitizeTypeChange(payload)
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end
  execute(sourceId, requestId, payload, 'ChangeStaffOrganizationType', {
    orgCode = orgCode,
    organizationRevision = tonumber(payload.organizationRevision),
    targetType = sanitized.targetType,
    dropIncompatible = sanitized.dropIncompatible,
    reason = sanitized.reason
  })
end)

RegisterNetEvent('mz_org:server:staffUpdateOrganizationFeatures', function(requestId, payload)
  local sourceId = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = MZOrgMenuMutations.NormalizeOrgCode(payload.orgCode)
  if not orgCode then contextualResponse(sourceId, requestId, payload, false, 'invalid_code') return end
  if not authorize(sourceId, requestId, payload, 'organizations', 'staff.orgs.features', orgCode) then return end
  local org, orgError = MZOrgSecurity.GetOrg(orgCode)
  if not org then contextualResponse(sourceId, requestId, payload, false, orgError or 'org_not_found') return end
  local valid, sanitized = MZOrgMenuMutations.SanitizeFeaturePatch(payload, org.type, {
    orgType = org.type,
    hasSharedAccount = org.hasSharedAccount == true,
    hasSalary = org.hasSalary == true,
    hasStorage = org.hasStorage == true
  })
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end
  execute(sourceId, requestId, payload, 'UpdateStaffOrganizationFeatures', {
    orgCode = orgCode,
    organizationRevision = tonumber(payload.organizationRevision),
    overrides = sanitized.overrides,
    remove = sanitized.remove,
    reason = sanitized.reason
  })
end)

RegisterNetEvent('mz_org:server:staffUpdateOrganizationAppearance', function(requestId, payload)
  local sourceId = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = MZOrgMenuMutations.NormalizeOrgCode(payload.orgCode)
  if not orgCode then contextualResponse(sourceId, requestId, payload, false, 'invalid_code') return end
  if not authorize(sourceId, requestId, payload, 'organizations', 'staff.orgs.appearance', orgCode) then return end
  local valid, sanitized = MZOrgMenuMutations.SanitizeAppearancePatch(payload)
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end
  execute(sourceId, requestId, payload, 'UpdateStaffOrganizationAppearance', {
    orgCode = orgCode,
    organizationRevision = tonumber(payload.organizationRevision),
    overrides = sanitized.overrides,
    remove = sanitized.remove,
    resetAll = sanitized.resetAll,
    reason = sanitized.reason
  })
end)

RegisterNetEvent('mz_org:server:staffUpdateOrganizationDutyPoint', function(requestId, payload)
  local sourceId = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = MZOrgMenuMutations.NormalizeOrgCode(payload.orgCode)
  if not orgCode then contextualResponse(sourceId, requestId, payload, false, 'invalid_code') return end
  if not authorize(sourceId, requestId, payload, 'organizations', 'staff.orgs.duty', orgCode) then return end
  local org, orgError = MZOrgSecurity.GetOrg(orgCode)
  if not org then contextualResponse(sourceId, requestId, payload, false, orgError or 'org_not_found') return end
  local valid, sanitized = MZOrgMenuMutations.SanitizeDutyPoint(payload, org.type)
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end
  execute(sourceId, requestId, payload, 'UpdateStaffOrganizationDutyPoint', {
    orgCode = orgCode,
    organizationRevision = tonumber(payload.organizationRevision),
    dutyPoint = sanitized.dutyPoint,
    reason = sanitized.reason
  })
end)

RegisterNetEvent('mz_org:server:staffArchiveOrganization', function(requestId, payload)
  local sourceId = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = MZOrgMenuMutations.NormalizeOrgCode(payload.orgCode)
  if not orgCode then contextualResponse(sourceId, requestId, payload, false, 'invalid_code') return end
  if not authorize(sourceId, requestId, payload, 'organizations', 'staff.orgs.archive', orgCode) then return end
  local valid, sanitized = MZOrgMenuMutations.SanitizeLifecycle(payload, 'archive', orgCode)
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end
  execute(sourceId, requestId, payload, 'ArchiveStaffOrganization', {
    orgCode = orgCode,
    organizationRevision = tonumber(payload.organizationRevision),
    confirmCode = sanitized.confirmCode,
    reason = sanitized.reason
  })
end)

RegisterNetEvent('mz_org:server:staffRestoreOrganization', function(requestId, payload)
  local sourceId = source
  payload = type(payload) == 'table' and payload or {}
  local orgCode = MZOrgMenuMutations.NormalizeOrgCode(payload.orgCode)
  if not orgCode then contextualResponse(sourceId, requestId, payload, false, 'invalid_code') return end
  if not authorize(sourceId, requestId, payload, 'organizations', 'staff.orgs.restore', orgCode) then return end
  local valid, sanitized = MZOrgMenuMutations.SanitizeLifecycle(payload, 'restore', orgCode)
  if not valid then contextualResponse(sourceId, requestId, payload, false, sanitized) return end
  execute(sourceId, requestId, payload, 'RestoreStaffOrganization', {
    orgCode = orgCode,
    organizationRevision = tonumber(payload.organizationRevision),
    reason = sanitized.reason
  })
end)
