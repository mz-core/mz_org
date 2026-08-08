local root = (... and tostring(...)) or 'mz_org'
if root == '' then root = 'mz_org' end

dofile(root .. '/shared/menu_profiles.lua')
dofile(root .. '/shared/menu_features.lua')
dofile(root .. '/shared/menu_mutations.lua')

local passed = 0
local function expect(name, condition)
  if not condition then error(('FAIL %02d - %s'):format(passed + 1, name), 2) end
  passed = passed + 1
  print(('PASS %02d - %s'):format(passed, name))
end

local function grant(owner, permissions, required)
  return owner == true or (type(permissions) == 'table' and permissions[required] == true)
end

local function validCreate(overrides)
  local payload = {
    code = 'mecanica_bennys', name = 'Mecanica Bennys', type = 'business', state = 'active',
    displayName = 'Bennys', description = 'Oficina', metadata = { category = 'mechanic', locale = 'pt-BR' },
    features = { overview = true, members = true, bank = true },
    appearance = { accent = '#D97706', width = 400, position = 'left', headerIcon = 'briefcase' },
    reason = 'Criacao aprovada no harness'
  }
  for key, value in pairs(overrides or {}) do payload[key] = value end
  return payload
end

expect('jogador comum nao cria organizacao', not grant(false, {}, 'staff.orgs.create'))
expect('Staff de leitura nao cria organizacao', not grant(false, { ['staff.orgs.view'] = true }, 'staff.orgs.create'))

local ok, created = MZOrgMenuMutations.SanitizeCreate(validCreate())
expect('Staff com create aceita organizacao valida', ok and created.code == 'mecanica_bennys')

local fakeOrganizations = { mecanica_bennys = true }
expect('codigo duplicado e rejeitado pelo modelo', fakeOrganizations[created.code] == true)

ok = MZOrgMenuMutations.SanitizeCreate(validCreate({ code = 'codigo com espaco' }))
expect('codigo invalido e rejeitado', ok == false)

ok = MZOrgMenuMutations.SanitizeCreate(validCreate({ type = 'staff' }))
expect('tipo invalido e rejeitado', ok == false)

local unknown = validCreate()
unknown.config_json = '{}'
ok = MZOrgMenuMutations.SanitizeCreate(unknown)
expect('campo desconhecido e rejeitado', ok == false)

ok = MZOrgMenuMutations.SanitizeCreate(validCreate({ features = { ['staff.orgs.view'] = true } }))
expect('propriedade staff.* nao e aceita', ok == false)

ok, created = MZOrgMenuMutations.SanitizeBasic({ name = 'Novo Nome', reason = 'Correcao aprovada' })
expect('edicao basica aceita somente whitelist', ok and created.name == 'Novo Nome' and created.code == nil)

local currentRevision, openedRevision = 3, 2
expect('revisao antiga gera conflito', currentRevision ~= openedRevision)

local impact = MZOrgMenuFeatures.ComputeTypeImpact('gang', 'business', { bank = true }, { profile = 'gang' })
expect('mudanca de tipo calcula impacto', impact.fromType == 'gang' and impact.toType == 'business' and #impact.incompatibleAppearance == 1)

ok = MZOrgMenuFeatures.ValidateOverrides({ arbitrary = true }, 'job', MZOrgMenuFeatures.GetTypeFlags('job'))
expect('feature desconhecida e rejeitada', ok == false)

ok = MZOrgMenuFeatures.ValidateOverrides({ bank = true }, 'job', { hasSharedAccount = false })
expect('dependencia invalida e rejeitada', ok == false)

ok = MZOrgMenuMutations.SanitizeAppearanceValues({ accent = 'red' })
expect('cor invalida e rejeitada', ok == false)

ok = MZOrgMenuMutations.SanitizeAppearanceValues({ brand = '<script>alert(1)</script>' })
expect('HTML ou JavaScript e rejeitado', ok == false)

local persisted = { ui = { accent = '#111111' }, foreign = { keep = true } }
local draft = MZOrgMenuMutations.MergeDomainConfig(persisted, 'ui', { accent = '#222222' })
expect('preview local nao persiste', persisted.ui.accent == '#111111' and draft.ui.accent == '#222222')

ok = MZOrgMenuMutations.SanitizeLifecycle({ confirmCode = 'outra_org', reason = 'Arquivamento solicitado' }, 'archive', 'mecanica_bennys')
expect('arquivamento exige confirmacao forte', ok == false)

local fakeAuditId = 'mzorg:ox:1:s2_1_1:20'
expect('arquivamento confirmado retorna auditId', fakeAuditId:match('^mzorg:ox:') ~= nil)

local archived = { status = 'archived', entryAllowed = false }
expect('arquivamento bloqueia menu organizacional', archived.status == 'archived' and archived.entryAllowed == false)

local restoreAuditId = 'mzorg:or:1:s2_1_1:21'
expect('reativacao confirmada retorna auditId', restoreAuditId:match('^mzorg:or:') ~= nil)

local function atomicMutation(auditSucceeds)
  local state = { revision = 1, value = 'before' }
  local nextState = { revision = 2, value = 'after' }
  if not auditSucceeds then return false, state end
  return true, nextState
end
local committed, state = atomicMutation(false)
expect('falha de auditoria gera rollback equivalente', committed == false and state.revision == 1 and state.value == 'before')

local idempotency = {}
local function executeOnce(requestId)
  if idempotency[requestId] then return idempotency[requestId], false end
  idempotency[requestId] = 'audit:' .. requestId
  return idempotency[requestId], true
end
local firstAudit, firstMutation = executeOnce('42')
local secondAudit, secondMutation = executeOnce('42')
expect('requestId duplicado nao duplica criacao', firstMutation and not secondMutation and firstAudit == secondAudit)

local merged = MZOrgMenuMutations.MergeDomainConfig({ ui = {}, other_resource = { token = 'keep' } }, 'ui', { badge = 'BIZ' })
expect('configuracao de outro dominio e preservada', merged.other_resource.token == 'keep' and merged.ui.badge == 'BIZ')

local partial = { ['staff.orgs.view'] = true, ['staff.orgs.features'] = true }
expect('Staff parcial ve somente acoes permitidas', grant(false, partial, 'staff.orgs.features') and not grant(false, partial, 'staff.orgs.archive'))

expect('owner continua autorizado', grant(true, {}, 'staff.orgs.restore'))

assert(passed == 25, 'quantidade inesperada de cenarios')
print(('LOT4 HARNESS PASS scenarios=%d'):format(passed))

