local root = arg and arg[1] or '.'

dofile(root .. '/shared/config.lua')
dofile(root .. '/shared/capabilities.lua')
dofile(root .. '/shared/menu_profiles.lua')
dofile(root .. '/shared/menu_features.lua')
dofile(root .. '/shared/menu_mutations.lua')
dofile(root .. '/shared/menu_organization_mutations.lua')

local function expect(condition, message)
  if not condition then error(message, 2) end
end

local function read(path)
  local file = assert(io.open(path, 'rb'))
  local content = file:read('*a')
  file:close()
  return content
end

expect(Config.Interface.organizationLeadershipTransfer == false, 'gate de lideranca deve iniciar desabilitado')
expect(Config.Debug == false, 'mz_org deve iniciar com debug desabilitado')
expect(Config.AllowDevMockSession == false, 'mock de desenvolvimento deve iniciar desabilitado')
expect(Config.DebugCommands == false, 'comandos de debug devem iniciar desabilitados')

local ok, value = MZOrgOrganizationMutations.SanitizeLeadershipTransfer({
  targetCitizenId = 'CID_TARGET',
  reason = 'Sucessao aprovada pela lideranca'
})
expect(ok == true and value.targetCitizenId == 'CID_TARGET', 'payload valido de transferencia foi recusado')

ok = MZOrgOrganizationMutations.SanitizeLeadershipTransfer({
  targetCitizenId = 'CID_TARGET',
  reason = 'Sucessao valida',
  ['staff.orgs.set_leader'] = true
})
expect(ok == false, 'campo staff.* foi aceito na transferencia organizacional')

ok = MZOrgOrganizationMutations.SanitizeLeadershipTransfer({
  targetCitizenId = 'CID_TARGET',
  reason = 'x'
})
expect(ok == false, 'motivo insuficiente foi aceito')

local grades = {
  { id = 1, org_id = 10, level = 1, code = 'member', name = 'Membro', active = 1 },
  { id = 2, org_id = 10, level = 2, code = 'manager', name = 'Gerente', active = 1 },
  { id = 3, org_id = 10, level = 3, code = 'leader', name = 'Lider', active = 1 }
}
local gradeById = {}
for _, grade in ipairs(grades) do gradeById[grade.id] = grade end

local state = {}
local function reset(overrides)
  overrides = type(overrides) == 'table' and overrides or {}
  state = {
    revision = overrides.revision or 7,
    orgType = overrides.orgType or 'job',
    leaderCount = overrides.leaderCount == nil and 1 or overrides.leaderCount,
    actorGradeId = overrides.actorGradeId or 3,
    targetGradeId = overrides.targetGradeId or 2,
    targetActive = overrides.targetActive ~= false,
    grantCapability = overrides.grantCapability ~= false,
    transactionResult = overrides.transactionResult ~= false,
    transactionCalls = 0,
    emitted = nil
  }
end
reset()

Config.OwnerAce = 'group.mz_owner'
IsPlayerAceAllowed = function() return true end
GetGameTimer = function() return 42 end
GetPlayerName = function() return 'Actor Runtime Name' end
TriggerClientEvent = function() end
TriggerEvent = function(_, payload) state.emitted = payload end

MZUtils = {
  jsonEncode = function() return '{"contract":"lot6d"}' end,
  jsonDecode = function(_, fallback) return fallback end
}
MZLogService = { createDetailed = function() end }
MZPlayerRepository = {
  getByCitizenId = function(citizenid)
    if citizenid == 'CID_TARGET' then
      return { citizenid = citizenid, firstname = 'Novo', lastname = 'Lider' }
    end
    return nil
  end
}
MZPlayerService = {
  getPlayer = function(source)
    if tonumber(source) == 11 then
      return {
        source = 11,
        citizenid = 'CID_ACTOR',
        charinfo = { firstname = 'Lider', lastname = 'Atual' },
        orgs = {}
      }
    end
    return nil
  end,
  getPlayerByCitizenId = function() return nil end
}
MZOrgRepository = {
  getOrgByCode = function(code)
    if code ~= 'alpha' then return nil end
    return {
      id = 10,
      code = 'alpha',
      name = 'Alpha',
      active = 1,
      revision = state.revision,
      type_code = state.orgType
    }
  end,
  getActivePlayerMembership = function(citizenid)
    if citizenid == 'CID_ACTOR' then
      return { citizenid = citizenid, org_id = 10, grade_id = state.actorGradeId, active = 1 }
    end
    if citizenid == 'CID_TARGET' and state.targetActive then
      return { citizenid = citizenid, org_id = 10, grade_id = state.targetGradeId, active = 1 }
    end
    return nil
  end,
  getOrgGradeById = function(_, gradeId) return gradeById[tonumber(gradeId)] end,
  getGradesForOrg = function() return grades end,
  getPermissionsForOrg = function()
    if not state.grantCapability then return {} end
    return { { org_id = 10, grade_id = 3, permission = 'members.set_leader', allow = 1 } }
  end,
  getPlayerOverrides = function() return {} end,
  countActiveMembersByGrade = function() return state.leaderCount end,
  transferOrganizationLeadershipWithAudit = function(data)
    state.transactionCalls = state.transactionCalls + 1
    state.transactionData = data
    return state.transactionResult
  end
}

MZOrgService = {}
dofile(root .. '/../mz_core/server/orgs/service.lua')

local vipTemplate = MZOrgService.getCreationTemplate('vip')
expect(type(vipTemplate) == 'table', 'template VIP ausente')
for _, permissions in pairs(vipTemplate.grade_permissions or {}) do
  for _, permission in ipairs(permissions or {}) do
    expect(permission ~= 'members.set_leader', 'template VIP ainda concede members.set_leader')
    expect(permission:match('^vip%.'), 'template VIP concede gestao organizacional: ' .. permission)
  end
end
expect(MZOrgMenuProfiles.SupportsLeadership('vip') == false, 'perfil VIP anunciou lideranca')
expect(MZOrgMenuProfiles.SupportsLeadership('job') == true, 'perfil job perdeu lideranca')
expect(MZOrgMenuProfiles.SupportsLeadership('gang') == true, 'perfil gang perdeu lideranca')
expect(MZOrgMenuProfiles.SupportsLeadership('business') == true, 'perfil business perdeu lideranca')
expect(MZOrgMenuProfiles.SupportsLeadership('government') == true, 'perfil government perdeu lideranca')
expect(MZOrgMenuProfiles.SupportsLeadership('event') == true, 'perfil event perdeu lideranca')
expect(MZOrgMenuProfiles.SupportsLeadership('unknown') == false, 'tipo desconhecido ganhou lideranca por fallback')
expect(MZOrgMenuProfiles.SupportsLeadership(nil) == false, 'tipo ausente ganhou lideranca por fallback')

ok, value = MZOrgService.transferOrganizationLeadership(11, 'alpha', 'CID_TARGET', {
  organizationRevision = 7,
  reason = 'Sucessao planejada e aprovada'
})
expect(ok == true, 'transferencia valida foi recusada: ' .. tostring(value))
expect(type(value.auditId) == 'string' and value.auditId:match('^leadership:'), 'auditId de lideranca ausente')
expect(state.transactionCalls == 1, 'transacao dedicada nao foi executada')
expect(state.transactionData.top_grade_id == 3, 'cargo superior incorreto na transacao')
expect(state.transactionData.successor_grade_id == 2, 'cargo sucessor incorreto na transacao')
expect(state.transactionData.target_grade_id == 2, 'cargo anterior do alvo incorreto na transacao')
expect(value.previousLeader.toGrade.id == 2 and value.newLeader.toGrade.id == 3, 'DTO da troca esta inconsistente')
expect(value.primaryMembershipChanged == false, 'primary membership foi alterada por suposicao')
expect(state.emitted and state.emitted.action == 'org.member.transfer_leadership', 'evento interno de invalidacao ausente')

reset({ orgType = 'vip' })
expect(
  MZOrgService.canOrg(11, 'alpha', 'members.set_leader') == false,
  'CanOrg autorizou members.set_leader para VIP'
)
expect(
  MZOrgService.canOrg(11, 'alpha', 'members.invite') == false,
  'CanOrg autorizou gestao de membership para VIP'
)
expect(
  MZOrgService.canOrg(11, 'alpha', 'vip.chat.tag') == true,
  'CanOrg recusou capability de privilegio VIP'
)
ok, value = MZOrgService.transferOrganizationLeadership(11, 'alpha', 'CID_TARGET', {
  organizationRevision = 7,
  reason = 'VIP usa niveis de privilegio'
})
expect(ok == false and value == 'leadership_not_supported', 'VIP aceitou transferencia de lideranca')
expect(state.transactionCalls == 0, 'VIP iniciou transacao de lideranca')

ok, value = MZOrgService.setLeaderByCitizenId(11, 'alpha', 'CID_TARGET', {
  reason = 'VIP usa niveis de privilegio'
})
expect(ok == false and value == 'leadership_not_supported', 'Staff conseguiu definir lider em VIP')
expect(state.transactionCalls == 0, 'Staff iniciou transacao de lideranca em VIP')

reset({ grantCapability = false })
ok, value = MZOrgService.transferOrganizationLeadership(11, 'alpha', 'CID_TARGET', {
  organizationRevision = 7,
  reason = 'Tentativa sem capability'
})
expect(ok == false and value == 'forbidden', 'owner/ACE contornou a capability organizacional')
expect(state.transactionCalls == 0, 'transacao executada sem members.set_leader')

reset({ leaderCount = 2 })
ok, value = MZOrgService.transferOrganizationLeadership(11, 'alpha', 'CID_TARGET', {
  organizationRevision = 7,
  reason = 'Estado ambiguo de lideranca'
})
expect(ok == false and value == 'multiple_leaders_detected', 'multiplos lideres nao falharam fechado')

reset({ targetActive = false })
ok, value = MZOrgService.transferOrganizationLeadership(11, 'alpha', 'CID_TARGET', {
  organizationRevision = 7,
  reason = 'Destino inativo'
})
expect(ok == false and value == 'target_not_active_member', 'destino inativo foi aceito')

reset()
ok, value = MZOrgService.transferOrganizationLeadership(11, 'alpha', 'CID_ACTOR', {
  organizationRevision = 7,
  reason = 'Transferencia para si'
})
expect(ok == false and value == 'self_transfer', 'self-transfer foi aceita')

reset({ transactionResult = false })
ok, value = MZOrgService.transferOrganizationLeadership(11, 'alpha', 'CID_TARGET', {
  organizationRevision = 7,
  reason = 'Falha transacional controlada'
})
expect(ok == false and value == 'audit_transaction_failed', 'falha transacional nao foi propagada')

local repository = read(root .. '/../mz_core/server/orgs/repository.lua')
expect(repository:find('MySQL.transaction.await', 1, true), 'transacao MySQL dedicada ausente')
expect(repository:find("data.action .. '.precondition_failed'", 1, true), 'assertion de precondicao ausente')
expect(repository:find("data.action .. '.assertion_failed'", 1, true), 'assertion de rollback transacional ausente')
expect(repository:find('o.revision = ?', 1, true), 'revision nao participa da transacao')
expect(repository:find('current_leader.expires_at', 1, true), 'expiracao nao participa da unicidade da lideranca')
expect(
  repository:find("t.code IN ('job', 'gang', 'business', 'government', 'event')", 1, true),
  'is_leader nao esta restrito aos tipos com lideranca'
)

local exportsFile = read(root .. '/../mz_core/server/orgs/exports.lua')
expect(exportsFile:find("exports('TransferOrganizationLeadership'", 1, true), 'export explicito do core ausente')
expect(exportsFile:find("exports('SetOrgLeaderByCitizenId'", 1, true), 'export Staff anterior foi removido')

local operations = read(root .. '/server/menu_organization_operations.lua')
expect(operations:find('organizationTransferLeadership', 1, true), 'evento organizacional explicito ausente')
expect(operations:find("capabilities = { 'members.set_leader' }", 1, true), 'guard members.set_leader ausente')
expect(operations:find('organization.supportsLeadership ~= true', 1, true), 'guard de tipo da lideranca ausente')
expect(not operations:find("capabilities = { 'staff.orgs.set_leader' }", 1, true), 'fallback Staff encontrado na rota organizacional')

local staffOperations = read(root .. '/client/menu/staff_operations.lua')
expect(
  staffOperations:find('capabilityAllowedForType', 1, true),
  'editor Staff nao filtra capabilities incompatíveis com VIP'
)

local debugCommand = read(root .. '/server/main.lua')
for _, capability in ipairs({
  'members.invite',
  'members.remove',
  'members.promote',
  'members.demote',
  'manage.members',
  'members.set_leader',
  'vip.chat.tag'
}) do
  expect(
    debugCommand:find("'" .. capability .. "'", 1, true),
    'mzorg_test nao diagnostica ' .. capability
  )
end

local menuConfig = read(root .. '/../mz_menu/shared/config.lua')
expect(
  menuConfig:find('MZMenuConfig.EnableTestCommand = false', 1, true),
  'comandos de teste do mz_menu iniciam habilitados'
)

local playerExports = read(root .. '/../mz_core/server/player/exports.lua')
expect(
  playerExports:find('canUseIdentityDebug', 1, true)
    and playerExports:find("aceAllowed(source, 'mzcore.debug')", 1, true),
  'mzcore_identity_debug nao exige debug e ACE'
)

local profiles = read(root .. '/shared/menu_profiles.lua')
expect(profiles:find('function MZOrgMenuProfiles.SupportsLeadership', 1, true), 'contrato de perfil de lideranca ausente')

local seeds = read(root .. '/../mz_core/server/seed/default_orgs.lua')
local function seedBlock(code, nextCode)
  local marker = "code = '" .. code .. "'"
  local startAt = assert(seeds:find(marker, 1, true), 'seed ausente: ' .. code)
  local endAt = nextCode and seeds:find("code = '" .. nextCode .. "'", startAt + #marker, true) or #seeds + 1
  return seeds:sub(startAt, (endAt or (#seeds + 1)) - 1)
end

for _, entry in ipairs({
  { code = 'ambulance', nextCode = 'mechanic' },
  { code = 'mechanic', nextCode = 'mafia' },
  { code = 'vip', nextCode = nil }
}) do
  local block = seedBlock(entry.code, entry.nextCode)
  expect(block:find("'org.view'", 1, true), 'seed sem org.view: ' .. entry.code)
  expect(block:find("'members.view'", 1, true), 'seed sem members.view: ' .. entry.code)
end
expect(
  not seedBlock('vip', nil):find("'members.set_leader'", 1, true),
  'seed VIP recebeu members.set_leader'
)

print('lot6d_contract_harness: OK')
