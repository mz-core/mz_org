local root = arg and arg[1] or '.'

dofile(root .. '/shared/capabilities.lua')
dofile(root .. '/shared/menu_profiles.lua')
dofile(root .. '/shared/menu_features.lua')
dofile(root .. '/shared/menu_mutations.lua')

local function expect(condition, message)
  if not condition then error(message, 2) end
end

local ok, value = MZOrgMenuMutations.SanitizeStaffMember({
  targetCitizenId = 'CID_123',
  gradeLevel = 2,
  reason = 'Admissao aprovada pela administracao'
}, 'invite')
expect(ok == true and value.targetCitizenId == 'CID_123' and value.gradeLevel == 2, 'convite valido recusado')

ok = MZOrgMenuMutations.SanitizeStaffMember({
  targetCitizenId = 'CID 123',
  gradeLevel = 2,
  reason = 'Admissao aprovada pela administracao'
}, 'invite')
expect(ok == false, 'CitizenID com espaco foi aceito')

ok, value = MZOrgMenuMutations.SanitizeStaffGrade({
  level = 6,
  code = 'supervisor',
  name = 'Supervisor',
  salary = 1000,
  inheritsLevel = 5,
  priority = 6,
  reason = 'Novo cargo aprovado'
}, 'create')
expect(ok == true and value.code == 'supervisor' and value.inheritsLevel == 5, 'cargo valido recusado')

ok = MZOrgMenuMutations.SanitizeStaffGrade({
  level = 6,
  code = 'Supervisor Com Espaco',
  name = 'Supervisor',
  salary = 1000,
  reason = 'Novo cargo aprovado'
}, 'create')
expect(ok == false, 'codigo de cargo invalido foi aceito')

ok, value = MZOrgMenuMutations.SanitizeStaffGrade({
  gradeId = 10,
  capability = 'members.promote',
  reason = 'Capability aprovada'
}, 'add_capability')
expect(ok == true and value.capability == 'members.promote', 'capability oficial recusada')

ok = MZOrgMenuMutations.SanitizeStaffGrade({
  gradeId = 10,
  capability = 'staff.orgs.manage',
  reason = 'Tentativa invalida'
}, 'add_capability')
expect(ok == false, 'staff.* foi aceita como capability organizacional')

ok = MZOrgMenuMutations.SanitizeStaffGrade({
  gradeId = 10,
  capability = 'capability.inventada',
  reason = 'Tentativa invalida'
}, 'add_capability')
expect(ok == false, 'capability fora do catalogo foi aceita')

local capabilities = MZOrgMenuMutations.GetOfficialCapabilities()
expect(#capabilities > 0, 'catalogo oficial vazio')
for _, capability in ipairs(capabilities) do
  expect(not capability:lower():match('^staff%.'), 'catalogo retornou staff.*')
end

print(('lot6a_contract_harness: OK capabilities=%d'):format(#capabilities))
