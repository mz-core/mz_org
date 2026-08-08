MZOrgSecurity = MZOrgSecurity or {}

local function trim(value, maxLength)
  if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
  value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' then return nil end
  if maxLength and #value > maxLength then value = value:sub(1, maxLength) end
  return value
end

function MZOrgSecurity.NormalizeSource(source)
  source = tonumber(source)
  if not source or source <= 0 then return nil end
  return math.floor(source)
end

function MZOrgSecurity.NormalizeOrgCode(value)
  return trim(value, 64)
end

function MZOrgSecurity.IsStaffPermission(permission)
  permission = trim(permission, 128)
  return permission ~= nil and permission:lower():match('^staff%.') ~= nil
end

function MZOrgSecurity.IsAceAllowed(source, ace)
  source = MZOrgSecurity.NormalizeSource(source)
  ace = trim(ace, 128)
  if not source or not ace then return false end
  local allowed = IsPlayerAceAllowed(source, ace)
  local normalized = tostring(allowed):lower()
  return allowed == true or allowed == 1 or normalized == '1' or normalized == 'true'
end

function MZOrgSecurity.IsOwner(source)
  return MZOrgSecurity.IsAceAllowed(source, Config.OwnerAce or 'group.mz_owner')
end

function MZOrgSecurity.SafeExport(exportName, ...)
  if GetResourceState('mz_core') ~= 'started' then return nil, 'core_unavailable' end
  local args = { ... }
  local ok, result, extra = pcall(function()
    local core = exports['mz_core']
    return core[exportName](core, table.unpack(args))
  end)
  if not ok then return nil, 'export_failed' end
  return result, extra
end

function MZOrgSecurity.GetGlobalPermissionGrant(source, permission)
  source = MZOrgSecurity.NormalizeSource(source)
  permission = trim(permission, 128)
  if not source or not permission then return false, nil end
  if MZOrgSecurity.IsOwner(source) then return true, 'owner' end
  if MZOrgSecurity.IsAceAllowed(source, permission) then return true, 'ace' end
  local allowed = MZOrgSecurity.SafeExport('HasGlobalPermission', source, permission)
  if allowed == true then return true, 'mz_core_global' end
  return false, nil
end

function MZOrgSecurity.HasGlobalPermission(source, permission)
  local allowed = MZOrgSecurity.GetGlobalPermissionGrant(source, permission)
  return allowed == true
end

function MZOrgSecurity.CanOrg(source, orgCode, capability)
  source = MZOrgSecurity.NormalizeSource(source)
  orgCode = MZOrgSecurity.NormalizeOrgCode(orgCode)
  capability = trim(capability, 128)
  if not source or not orgCode or not capability then return false end
  if MZOrgSecurity.IsStaffPermission(capability) then return false end
  if MZOrgSecurity.IsOwner(source) then return true end
  return MZOrgSecurity.SafeExport('CanOrg', source, orgCode, capability) == true
end

function MZOrgSecurity.GetOrg(orgCode)
  orgCode = MZOrgSecurity.NormalizeOrgCode(orgCode)
  if not orgCode then return nil, 'invalid_org' end
  local org, err = MZOrgSecurity.SafeExport('GetOrgByCode', orgCode)
  if org == nil then return nil, err or 'org_unavailable' end
  if type(org) ~= 'table' then return nil, 'org_not_found' end
  return org
end

function MZOrgSecurity.RequireActiveOrg(orgCode)
  local org, err = MZOrgSecurity.GetOrg(orgCode)
  if not org then return false, err end
  local active = org.active == true or org.active == 1 or tostring(org.active):lower() == 'true'
  if not active or tostring(org.status or ''):lower() == 'archived' or tostring(org.status or ''):lower() == 'inactive' then
    return false, 'org_archived'
  end
  return true, org
end

function MZOrgSecurity.ResolvePanelEntry(source, requestedContext)
  if not MZOrgSession or type(MZOrgSession.ResolvePanelEntry) ~= 'function' then
    return false, 'session_unavailable'
  end
  return MZOrgSession.ResolvePanelEntry(source, requestedContext)
end

exports('ResolvePanelEntry', function(source, requestedContext)
  return MZOrgSecurity.ResolvePanelEntry(source, requestedContext)
end)
