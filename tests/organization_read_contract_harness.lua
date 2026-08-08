MZOrgMenuProfiles = nil
MZOrgMenuFeatures = nil

dofile('shared/menu_profiles.lua')
dofile('shared/menu_features.lua')

local function contains(values, expected)
  for _, value in ipairs(values or {}) do
    if value == expected then return true end
  end
  return false
end

local function expect(condition, message)
  if not condition then error(message, 2) end
end

local job = MZOrgMenuProfiles.Get('job')
local allowed = MZOrgMenuFeatures.Resolve(job.defaultFeatures, {}, {
  'org.view', 'members.view', 'manage.permissions', 'account.view',
  'goals.view', 'recruitment.view', 'logs.view'
}, {
  orgType = 'job', hasSharedAccount = true
}, 'active')

for _, feature in ipairs({ 'overview', 'members', 'grades', 'bank', 'goals', 'recruitment', 'logs' }) do
  expect(contains(allowed, feature), 'feature esperada ausente: ' .. feature)
end

local disabled = MZOrgMenuFeatures.Resolve(job.defaultFeatures, { bank = false }, {
  'org.view', 'account.view'
}, {
  orgType = 'job', hasSharedAccount = true
}, 'active')
expect(not contains(disabled, 'bank'), 'override false nao pode liberar bank')

local missingDependency = MZOrgMenuFeatures.Resolve(job.defaultFeatures, {}, {
  'org.view', 'account.view'
}, {
  orgType = 'job', hasSharedAccount = false
}, 'active')
expect(not contains(missingDependency, 'bank'), 'bank nao pode existir sem conta compartilhada')

local archived = MZOrgMenuFeatures.Resolve(job.defaultFeatures, {}, {
  'org.view', 'members.view', 'account.view', 'logs.view'
}, {
  orgType = 'job', hasSharedAccount = true
}, 'archived')
expect(#archived == 0, 'organizacao arquivada nao pode ter features efetivas')

local staffOnly = MZOrgMenuFeatures.Resolve(job.defaultFeatures, {}, {
  'staff.orgs.view', 'staff.orgs.manage', 'staff.logs.view'
}, {
  orgType = 'job', hasSharedAccount = true
}, 'active')
expect(#staffOnly == 0, 'staff.* nao pode liberar capability organizacional')

print('organization_read_contract_harness: OK')
