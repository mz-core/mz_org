local root = arg and arg[1] or 'mz_org'

dofile(root .. '/shared/menu_profiles.lua')
dofile(root .. '/shared/menu_features.lua')
dofile(root .. '/shared/menu_mutations.lua')

local passed = 0
local function expect(name, condition)
  if not condition then error(('FAIL %02d - %s'):format(passed + 1, name), 2) end
  passed = passed + 1
  print(('PASS %02d - %s'):format(passed, name))
end

local function read(path)
  local file = assert(io.open(path, 'rb'))
  local content = file:read('*a')
  file:close()
  return content
end

for _, orgType in ipairs({ 'job', 'gang', 'business', 'government', 'event' }) do
  expect('duty suportado para ' .. orgType, MZOrgMenuMutations.SupportsDutyType(orgType) == true)
end
expect('VIP nao recebe duty', MZOrgMenuMutations.SupportsDutyType('vip') == false)
expect('tipo desconhecido nao recebe duty', MZOrgMenuMutations.SupportsDutyType('unknown') == false)

local validPayload = {
  orgCode = 'police',
  organizationRevision = 4,
  dutyPoint = {
    enabled = true,
    coords = { x = 441.25, y = -981.80, z = 30.69 },
    radius = 2.0,
    drawDistance = 20.0,
    label = 'Recepcao da policia'
  },
  reason = 'Ponto definido no local operacional'
}
local ok, sanitized = MZOrgMenuMutations.SanitizeDutyPoint(validPayload, 'job')
expect('payload valido e aceito', ok == true and sanitized.dutyPoint.coords.x == 441.25)

ok = MZOrgMenuMutations.SanitizeDutyPoint(validPayload, 'vip')
expect('payload VIP e recusado', ok == false)

local invalidCoords = {
  dutyPoint = {
    enabled = true,
    coords = { x = 99999, y = 0, z = 0 },
    radius = 2.0,
    drawDistance = 20.0,
    label = 'Ponto invalido'
  },
  reason = 'Tentativa com coordenada invalida'
}
ok = MZOrgMenuMutations.SanitizeDutyPoint(invalidCoords, 'job')
expect('coordenadas fora do limite sao recusadas', ok == false)

local unknownField = {
  dutyPoint = {
    enabled = true,
    coords = { x = 0, y = 0, z = 0 },
    radius = 2.0,
    drawDistance = 20.0,
    label = 'Ponto valido',
    permission = 'staff.orgs.manage'
  },
  reason = 'Tentativa com campo desconhecido'
}
ok = MZOrgMenuMutations.SanitizeDutyPoint(unknownField, 'job')
expect('campo desconhecido no ponto e recusado', ok == false)

ok, sanitized = MZOrgMenuMutations.SanitizeDutyPoint({
  dutyPoint = { enabled = false },
  reason = 'Ponto desativado pelo gerente'
}, 'business')
expect('desativacao explicita e aceita', ok == true and sanitized.dutyPoint.enabled == false)

local coreService = read(root .. '/server/domain/service.lua')
expect('core valida ped no servidor', coreService:find('GetPlayerPed', 1, true) ~= nil)
expect('core valida coordenadas no servidor', coreService:find('GetEntityCoords', 1, true) ~= nil)
expect('core exige membership ativo', coreService:find('getActivePlayerMembership', 1, true) ~= nil)
expect('core possui contrato self-duty dedicado', coreService:find('setSelfDutyAtPoint', 1, true) ~= nil)

local repository = read(root .. '/server/domain/repository.lua')
expect('duty e log usam transacao', repository:find('setMembershipDutyWithAudit', 1, true) ~= nil
  and repository:find('MySQL.transaction.await', 1, true) ~= nil)
expect('transacao possui precondicao fail-closed', repository:find("data.action .. '.precondition_failed'", 1, true) ~= nil)
expect('transacao possui assercao fail-closed', repository:find("data.action .. '.assertion_failed'", 1, true) ~= nil)

local exportsFile = read(root .. '/server/domain/exports.lua')
expect('export self-duty explicito existe', exportsFile:find("exports('SetSelfOrgDutyAtPoint'", 1, true) ~= nil)
expect('export administrativo antigo foi preservado', exportsFile:find("exports('SetOrgMemberDuty'", 1, true) ~= nil)

local serverRuntime = read(root .. '/server/duty_points.lua')
expect('runtime nao recebe coordenadas do cliente', serverRuntime:find(
  "RegisterNetEvent('mz_org:server:setSelfDutyAtPoint', function(orgCode, desiredDuty)", 1, true
) ~= nil)
expect('runtime reconsulta contexto no servidor', serverRuntime:find("'GetPlayerOrgContext'", 1, true) ~= nil)

local clientRuntime = read(root .. '/client/duty_points.lua')
expect('mz_interact e somente projecao client', clientRuntime:find("exports['mz_interact']:AddPoint", 1, true) ~= nil)
expect('pontos do resource sao removidos', clientRuntime:find("exports['mz_interact']:RemovePoint", 1, true) ~= nil)

local staffServer = read(root .. '/server/menu_staff_mutations.lua')
expect('configuracao exige permissao exata', staffServer:find("'staff.orgs.duty'", 1, true) ~= nil)
expect('mutacao contextual dedicada existe', staffServer:find('staffUpdateOrganizationDutyPoint', 1, true) ~= nil)

local staffClient = read(root .. '/client/menu/staff_duty.lua')
expect('menu cria ponto no local atual', staffClient:find('GetEntityCoords', 1, true) ~= nil)
expect('menu suporta desativacao', staffClient:find('enabled = false', 1, true) ~= nil)

local manifest = read(root .. '/fxmanifest.lua')
expect('dependencia mz_interact e explicita', manifest:find("'mz_interact'", 1, true) ~= nil)

local runtime = {
  orgType = 'job',
  orgActive = 1,
  membership = { duty = 0 },
  playerCoords = { x = 100.0, y = 200.0, z = 30.0 },
  transactionResult = true,
  transactionCalls = 0
}
Config = { OwnerAce = 'group.mz_owner' }
MZUtils = {
  jsonDecode = function()
    return {
      dutyPoint = {
        enabled = true,
        coords = { x = 100.0, y = 200.0, z = 30.0 },
        radius = 2.0,
        drawDistance = 20.0,
        label = 'Ponto de teste'
      }
    }
  end,
  jsonEncode = function() return '{"contract":"self-duty"}' end
}
MZLogService = { createDetailed = function() end }
MZPlayerRepository = { getByCitizenId = function() return nil end }
MZPlayerService = {
  getPlayer = function(source)
    if tonumber(source) ~= 11 then return nil end
    return {
      source = 11,
      citizenid = 'CID_DUTY',
      charinfo = { firstname = 'Teste', lastname = 'Duty' }
    }
  end,
  getPlayerByCitizenId = function() return nil end
}
MZOrgRepository = {
  getOrgByCode = function(code)
    if code ~= 'alpha' then return nil end
    return {
      id = 7,
      code = 'alpha',
      name = 'Alpha',
      active = runtime.orgActive,
      type_code = runtime.orgType,
      config_json = '{}'
    }
  end,
  getActivePlayerMembership = function()
    return runtime.membership
  end,
  setMembershipDutyWithAudit = function(data)
    runtime.transactionCalls = runtime.transactionCalls + 1
    runtime.transactionData = data
    return runtime.transactionResult
  end
}
GetPlayerPed = function() return 77 end
GetEntityCoords = function() return runtime.playerCoords end
GetPlayerName = function() return 'Duty Tester' end
GetGameTimer = function() return 123 end
IsPlayerAceAllowed = function() return false end
TriggerClientEvent = function() end
TriggerEvent = function() end

dofile(root .. '/server/domain/service.lua')

ok, sanitized = MZOrgService.setSelfDutyAtPoint(11, 'alpha', true)
expect('self-duty valido chega a transacao', ok == true and runtime.transactionCalls == 1
  and runtime.transactionData.duty == true)

runtime.playerCoords = { x = 110.0, y = 200.0, z = 30.0 }
runtime.transactionCalls = 0
ok, sanitized = MZOrgService.setSelfDutyAtPoint(11, 'alpha', true)
expect('distancia e validada pelo core', ok == false and sanitized == 'too_far'
  and runtime.transactionCalls == 0)

runtime.playerCoords = { x = 100.0, y = 200.0, z = 30.0 }
runtime.orgType = 'vip'
ok, sanitized = MZOrgService.setSelfDutyAtPoint(11, 'alpha', true)
expect('core recusa duty para VIP', ok == false and sanitized == 'duty_not_supported')

runtime.orgType = 'job'
runtime.membership = nil
ok, sanitized = MZOrgService.setSelfDutyAtPoint(11, 'alpha', true)
expect('core recusa jogador sem membership ativo', ok == false and sanitized == 'not_member')

runtime.membership = { duty = 0 }
runtime.transactionResult = false
ok, sanitized = MZOrgService.setSelfDutyAtPoint(11, 'alpha', true)
expect('falha de auditoria e propagada', ok == false and sanitized == 'audit_transaction_failed')

assert(passed == 35, 'quantidade inesperada de cenarios')
print(('SELF DUTY CONTRACT HARNESS PASS scenarios=%d'):format(passed))
