local root = arg and arg[1] or '.'

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

local ok, value = MZOrgOrganizationMutations.SanitizeGrade({
  level = 3,
  code = 'supervisor',
  name = 'Supervisor',
  salary = 2500,
  inheritsLevel = 2,
  priority = 3,
  reason = 'Novo cargo aprovado pela lideranca'
}, 'create')
expect(ok == true and value.code == 'supervisor', 'criacao valida de cargo foi recusada')

ok = MZOrgOrganizationMutations.SanitizeGrade({
  level = 2,
  code = 'supervisor',
  name = 'Supervisor',
  inheritsLevel = 2,
  reason = 'Heranca invalida'
}, 'create')
expect(ok == false, 'heranca igual ou superior foi aceita')

ok = MZOrgOrganizationMutations.SanitizeGrade({
  gradeId = 10,
  capability = 'staff.orgs.manage',
  reason = 'Tentativa de escalada global'
}, 'add_capability')
expect(ok == false, 'capability staff.* foi aceita no payload organizacional')

ok, value = MZOrgOrganizationMutations.SanitizeGrade({
  gradeId = 10,
  capability = 'members.invite',
  reason = 'Delegacao operacional aprovada'
}, 'add_capability')
expect(ok == true and value.capability == 'members.invite', 'capability oficial foi recusada')

local operations = read(root .. '/server/menu_organization_operations.lua')
for _, eventName in ipairs({
  'organizationCreateGrade',
  'organizationUpdateGrade',
  'organizationDisableGrade',
  'organizationReactivateGrade',
  'organizationAddGradeCapability',
  'organizationRemoveGradeCapability'
}) do
  expect(operations:find(eventName, 1, true), 'evento ausente: ' .. eventName)
end
expect(operations:find("capabilities = { 'manage.permissions' }", 1, true), 'guard manage.permissions ausente')
expect(not operations:find("'staff.orgs.manage'", 1, true), 'fallback Staff encontrado nas operacoes organizacionais')

local coreService = read(root .. '/server/domain/service.lua')
expect(coreService:find('ORGANIZATION_GRADE_MANAGEMENT', 1, true), 'sentinel privado do core ausente')
expect(coreService:find('target_higher_or_equal', 1, true), 'proteção de cargo igual ou superior ausente')
expect(coreService:find('capability_not_owned', 1, true), 'proteção contra delegação indevida ausente')
expect(coreService:find('inheritance_not_lower', 1, true), 'proteção de herança inferior ausente')
expect(coreService:find("permission == 'members.set_leader'", 1, true), 'proteção de liderança ausente')

print('lot6c_contract_harness: OK')
