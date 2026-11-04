local PURPOSE_CAPABILITY = {
  facility_purchase = 'facility.purchase',
  furniture_purchase = 'facility.furniture.buy'
}

local ALLOWED_COMMERCE_CALLERS = {
  mz_org_activities = true,
  mz_furniture = true
}

local CALLER_CAPABILITY = {
  mz_org_activities = 'facility.purchase',
  mz_furniture = 'facility.furniture.buy'
}

local function economyExport(name, ...)
  if GetResourceState('mz_economy') ~= 'started' then return false, 'economy_unavailable' end
  local args = { ... }
  local ok, result, extra = pcall(function()
    local economy = exports['mz_economy']
    return economy[name](economy, table.unpack(args))
  end)
  if not ok then return false, 'economy_unavailable' end
  return result, extra
end

local function activeOrganization(orgCode)
  local org = MZOrgService.getOrgByCode(orgCode)
  if type(org) ~= 'table' then return nil, 'invalid_org' end
  local active = org.active == true or org.active == 1 or tostring(org.active):lower() == 'true'
  if not active then return nil, 'org_archived' end
  return org
end

local function hasAnyOrgCapability(source, orgCode, capabilities)
  if MZOrgSecurity.HasGlobalPermission(source, (Config and Config.OwnerAce) or 'group.mz_owner') then
    return true
  end
  for _, capability in ipairs(capabilities) do
    if MZOrgService.canOrg(source, orgCode, capability) == true then return true end
  end
  return false
end

local function authorizedOrganization(source, orgCode, capabilities)
  source = tonumber(source)
  if not source or source <= 0 then return nil, 'invalid_source' end
  local org, err = activeOrganization(orgCode)
  if not org then return nil, err end
  if not hasAnyOrgCapability(source, org.code, capabilities) then return nil, 'forbidden' end
  return org
end

exports('GetOrgAccount', function(source, orgCode)
  local org, err = authorizedOrganization(source, orgCode, { 'account.view', 'org.view' })
  if not org then return false, err end
  return economyExport('GetOrganizationAccount', source, org)
end)

exports('ListOrgAccountTransactions', function(source, orgCode, filters)
  local org, err = authorizedOrganization(source, orgCode, { 'account.view', 'org.view' })
  if not org then return false, err end
  return economyExport('ListOrganizationAccountTransactions', source, org, filters)
end)

exports('DepositOrgAccount', function(source, orgCode, amount, reason)
  local org, err = authorizedOrganization(source, orgCode, {
    'account.deposit', 'account.manage', 'manage.account'
  })
  if not org then return false, err end
  return economyExport('DepositOrganizationAccount', source, org, amount, reason)
end)

exports('WithdrawOrgAccount', function(source, orgCode, amount, reason)
  local org, err = authorizedOrganization(source, orgCode, {
    'account.withdraw', 'account.manage', 'manage.account'
  })
  if not org then return false, err end
  return economyExport('WithdrawOrganizationAccount', source, org, amount, reason)
end)

exports('GetOrgAccountCommerceCapabilities', function()
  return economyExport('GetOrganizationAccountCommerceCapabilities')
end)

exports('SpendOrgAccount', function(source, orgCode, amount, options)
  local caller = GetInvokingResource()
  if not ALLOWED_COMMERCE_CALLERS[caller] then return false, 'forbidden_caller' end
  options = type(options) == 'table' and options or {}
  local capability = PURPOSE_CAPABILITY[tostring(options.purpose or '')]
  if not capability then return false, 'commerce_purpose_forbidden' end
  local org, err = authorizedOrganization(source, orgCode, { capability })
  if not org then return false, err end
  return economyExport('SpendOrganizationAccount', source, org, amount, options, caller)
end)

exports('RefundOrgAccount', function(source, orgCode, receiptId, options)
  local caller = GetInvokingResource()
  if not ALLOWED_COMMERCE_CALLERS[caller] then return false, 'forbidden_caller' end
  local org, err = authorizedOrganization(source, orgCode, { CALLER_CAPABILITY[caller] })
  if not org then return false, err end
  return economyExport('RefundOrganizationAccount', source, org, receiptId, options, caller)
end)
