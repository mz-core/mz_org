local root = arg and arg[1] or '.'

dofile(root .. '/shared/capabilities.lua')
dofile(root .. '/shared/menu_profiles.lua')
dofile(root .. '/shared/menu_features.lua')
dofile(root .. '/shared/menu_mutations.lua')
dofile(root .. '/shared/menu_organization_mutations.lua')

local function expect(condition, message)
  if not condition then error(message, 2) end
end

local ok, value = MZOrgOrganizationMutations.SanitizeMember({
  targetCitizenId = 'CID_200',
  gradeLevel = 2,
  reason = 'Convite autorizado pela lideranca'
}, 'invite')
expect(ok == true and value.gradeLevel == 2, 'convite organizacional valido recusado')

ok = MZOrgOrganizationMutations.SanitizeMember({
  targetCitizenId = 'CID_200',
  gradeLevel = 2,
  reason = 'Convite autorizado',
  ['staff.members.invite'] = true
}, 'invite')
expect(ok == false, 'campo staff.* aceito no payload organizacional')

ok, value = MZOrgOrganizationMutations.SanitizeAccount({
  amount = 1500,
  reason = 'Reposicao do caixa operacional'
})
expect(ok == true and value.amount == 1500, 'movimentacao valida recusada')

ok = MZOrgOrganizationMutations.SanitizeAccount({
  amount = -10,
  reason = 'Valor invalido'
})
expect(ok == false, 'valor financeiro negativo aceito')

ok, value = MZOrgOrganizationMutations.SanitizeGoal({
  title = 'Atendimentos semanais',
  description = 'Meta manual da equipe',
  target = 50,
  type = 'manual',
  reason = 'Planejamento semanal aprovado'
})
expect(ok == true and value.target == 50, 'meta valida recusada')

ok = MZOrgOrganizationMutations.SanitizeGoal({
  title = '<script>',
  target = 50,
  reason = 'Tentativa invalida'
})
expect(ok == false, 'HTML aceito no titulo da meta')

ok, value = MZOrgOrganizationMutations.SanitizeRecruitment({
  targetCitizenId = 'CID_300',
  desiredGradeLevel = 1,
  note = 'Candidato indicado',
  reason = 'Abertura aprovada'
}, 'create')
expect(ok == true and value.targetCitizenId == 'CID_300', 'recrutamento valido recusado')

ok, value = MZOrgOrganizationMutations.SanitizeRecruitment({
  recruitmentId = 10,
  reason = 'Aprovacao revisada'
}, 'approve')
expect(ok == true and value.recruitmentId == 10, 'decisao valida recusada')

local job = MZOrgMenuProfiles.Get('job')
local features = MZOrgMenuFeatures.Resolve(job.defaultFeatures, {}, {
  'org.view', 'manage.members'
}, {
  orgType = 'job', hasSharedAccount = true
}, 'active')
local recruitmentEnabled = false
for _, feature in ipairs(features) do
  if feature == 'recruitment' then recruitmentEnabled = true end
end
expect(recruitmentEnabled, 'manage.members nao habilitou o modulo de recrutamento')

print('lot6b_contract_harness: OK')
