local failures = 0
local executed = 0

local function expect(name, condition, detail)
  executed = executed + 1
  if condition then
    print(('PASS %02d - %s'):format(executed, name))
    return
  end
  failures = failures + 1
  print(('FAIL %02d - %s: %s'):format(executed, name, tostring(detail or 'assertion_failed')))
end

local state = {
  owner = false,
  overrides = {},
  orgActive = true,
  auditCommit = true,
  targetGradeId = 1,
  legacyGradeUpdates = 0
}

Config = { OwnerAce = 'group.mz_owner' }
IsPlayerAceAllowed = function(_, ace) return state.owner and ace == Config.OwnerAce end
GetPlayerName = function(source) return 'Player ' .. tostring(source) end
GetGameTimer = function() return 12345 end
TriggerClientEvent = function() end

MZUtils = {
  jsonEncode = function() return '{}' end,
  jsonDecode = function(_, fallback) return fallback or {} end
}

local actor = { source = 10, citizenid = 'ACTOR', charinfo = { firstname = 'Actor', lastname = 'Test' }, orgs = {} }
MZPlayerService = {
  getPlayer = function(source) return tonumber(source) == 10 and actor or nil end,
  getPlayerByCitizenId = function() return nil end
}
MZPlayerRepository = {
  getByCitizenId = function(citizenid)
    return { citizenid = citizenid, firstname = 'Target', lastname = 'Test' }
  end
}

local function orgRow()
  return {
    id = 1, code = 'police', name = 'Police', type_code = 'job', type_name = 'Job',
    active = state.orgActive and 1 or 0, is_public = 0, has_salary = 1,
    has_shared_account = 1, has_storage = 1, config_json = '{}'
  }
end

local grades = {
  { id = 1, org_id = 1, level = 1, code = 'recruit', name = 'Recruit', active = 1 },
  { id = 2, org_id = 1, level = 2, code = 'officer', name = 'Officer', active = 1 },
  { id = 3, org_id = 1, level = 3, code = 'sergeant', name = 'Sergeant', active = 1 },
  { id = 4, org_id = 1, level = 4, code = 'chief', name = 'Chief', active = 1 }
}

MZOrgRepository = {
  getPlayerOverrides = function()
    local rows = {}
    for permission, allow in pairs(state.overrides) do
      rows[#rows + 1] = { permission = permission, allow = allow and 1 or 0 }
    end
    return rows
  end,
  getPlayerMemberships = function()
    return state.memberships or {}
  end,
  getGradesForOrg = function() return grades end,
  getPermissionsForOrg = function() return state.orgPermissions or {} end,
  getOrgByCode = function() return orgRow() end,
  getPlayerMembership = function()
    return { active = 1, grade_id = state.targetGradeId }
  end,
  getGradeById = function(id)
    for _, grade in ipairs(grades) do if tonumber(grade.id) == tonumber(id) then return grade end end
  end,
  updateMembershipGrade = function(_, _, gradeId)
    state.legacyGradeUpdates = state.legacyGradeUpdates + 1
    state.targetGradeId = gradeId
  end,
  updateMembershipGradeWithAudit = function(data)
    if state.auditCommit then state.targetGradeId = data.grade_id end
    return state.auditCommit
  end,
  setPrimaryMembership = function() end,
  setMembership = function(_, _, gradeId) state.targetGradeId = gradeId end,
  updateOrgBasicInfo = function() state.orgEdited = true return orgRow() end,
  getOrgGradePermission = function() return nil end,
  listOrgGradePermissions = function() return {} end,
  setPermission = function() return true end
}

MZLogService = nil
dofile('mz_core/server/orgs/service.lua')

state.owner = false
state.overrides = {}
actor.orgs = {
  { code = 'police', grade = { level = 3 }, permissions = { ['staff.orgs.manage'] = true } }
}
expect('membro comum nunca recebe staff.* global',
  MZOrgService.hasGlobalPermission(10, 'staff.orgs.manage') == false)

state.memberships = {
  {
    org_id = 1, org_code = 'police', org_name = 'Police', org_active = 1,
    type_code = 'job', grade_id = 2, grade_level = 2, grade_code = 'officer',
    grade_name = 'Officer', is_primary = 1, duty = 0, has_salary = 1,
    has_shared_account = 1, has_storage = 1, org_config_json = '{}'
  }
}
state.orgPermissions = {
  { org_id = 1, grade_id = 2, permission = 'org.view', allow = 1 },
  { org_id = 1, grade_id = 2, permission = 'staff.orgs.manage', allow = 1 }
}
local loaded = MZOrgService.loadPlayerOrgs(10)
expect('cargo legado com staff.* e ignorado',
  loaded[1] and loaded[1].permissions['org.view'] == true
    and loaded[1].permissions['staff.orgs.manage'] == nil)

state.overrides = { ['staff.orgs.view'] = true }
state.orgEdited = false
local edited, editErr = MZOrgService.updateOrgBasicInfo(10, 'police', { name = 'Changed' })
expect('staff.orgs.view nao permite editar organizacao',
  edited == false and editErr == 'forbidden' and state.orgEdited ~= true, editErr)

state.overrides = { ['staff.logs.view'] = true }
expect('staff.logs.view nao permite administrar organizacao',
  MZOrgService.hasGlobalPermission(10, 'staff.logs.view') == true
    and MZOrgService.hasGlobalPermission(10, 'staff.orgs.manage') == false)

state.overrides = { ['staff.orgs.set_leader'] = true }
state.orgActive = true
state.targetGradeId = 1
local leaderOk = MZOrgService.setLeaderByCitizenId(10, 'police', 'TARGET', {})
local unrelatedOk = MZOrgService.updateOrgBasicInfo(10, 'police', { name = 'Nope' })
expect('staff.orgs.set_leader global permite somente definir lideranca',
  leaderOk == true and unrelatedOk == false
    and MZOrgService.canOrg(10, 'police', 'staff.orgs.set_leader') == false)

local capturedSql, capturedParams
MZOrgService = {
  hasGlobalPermission = function() return false end,
  canOrg = function(_, orgCode, capability) return orgCode == 'police' and capability == 'logs.view' end
}
MZOrgRepository.getOrgByCode = function(code) return code == 'police' and orgRow() or nil end
MySQL = {
  query = {
    await = function(sql, params)
      capturedSql, capturedParams = sql, params
      return {
        { id = 1, scope = 'orgs', action = 'a', org_code = 'police', data_json = '{}', created_at = 'now' },
        { id = 2, scope = 'orgs', action = 'b', org_code = 'police2', data_json = '{}', created_at = 'now' }
      }
    end
  },
  insert = { await = function() return 1 end }
}
dofile('mz_core/server/logs/service.lua')
local policeLogs = MZLogService.listOrgLogsSecure(10, 'police', { limit = 50 })
expect('logs police nao retornam police2',
  #policeLogs == 1 and policeLogs[1].orgCode == 'police'
    and capturedSql:find('org_code = ?', 1, true) ~= nil
    and capturedParams[1] == 'police')

MZPlayerService.getPlayer = function(source) return tonumber(source) == 10 and actor or nil end
MZOrgRepository.getOrgByCode = function() return orgRow() end
MZOrgService = nil
dofile('mz_core/server/orgs/service.lua')
state.overrides = { ['staff.members.promote'] = true }
state.orgActive = true
state.targetGradeId = 1
state.auditCommit = false
state.legacyGradeUpdates = 0
actor.orgs = { { code = 'police', grade = { level = 3 }, permissions = {} } }
local promoted, promoteErr = MZOrgService.promoteOrgMemberSecure(10, 'police', 'TARGET', {})
expect('falha de auditoria cancela promocao',
  promoted == false and promoteErr == 'audit_transaction_failed'
    and state.targetGradeId == 1 and state.legacyGradeUpdates == 0, promoteErr)

dofile('mz_org/shared/context.lua')
local _, envelope = MZOrgContext.NormalizeRequestEnvelope({
  version = 2,
  requestId = 'req-old',
  sessionRevision = 'rev-old',
  context = { key = 'org:police' },
  payload = { orgCode = 'police' }
})
local contextual = MZOrgContext.ApplyResponseEnvelope({ ok = true, data = {} }, envelope)
expect('resposta contextual antiga e identificavel e descartavel',
  contextual.requestId == 'req-old'
    and MZOrgContext.IsResponseCurrent(contextual, 'rev-new', 'org:mechanic') == false)

state.orgActive = false
state.overrides = {}
local goalOk, goalErr = MZOrgService.createOrgGoal(10, 'police', { title = 'Blocked', target = 1 })
expect('organizacao arquivada bloqueia mutacoes', goalOk == false and goalErr == 'org_archived', goalErr)

state.owner = true
state.orgActive = true
expect('owner continua autorizado',
  MZOrgService.hasGlobalPermission(10, 'staff.orgs.manage') == true
    and MZOrgService.canOrg(10, 'police', 'org.view') == true)

print(('RESULT executed=%d passed=%d failed=%d'):format(executed, executed - failures, failures))
if failures > 0 then os.exit(1) end
