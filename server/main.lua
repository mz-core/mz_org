local function debugPrint(...)
  if not Config.Debug then return end
  print('[mz_org]', ...)
end

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  debugPrint('resource iniciado')
end)

local function encodeDebug(value)
  local ok, encoded = pcall(function()
    local toEncode = value
    if toEncode == nil then
      toEncode = {}
    end

    if json and json.encode then
      return json.encode(toEncode)
    end

    return tostring(toEncode)
  end)

  if ok then
    return encoded
  end

  return ('<encode failed: %s>'):format(tostring(encoded))
end

local function callExport(resourceName, exportName, ...)
  if GetResourceState(resourceName) ~= 'started' then
    return false, resourceName .. '_not_started'
  end

  local args = { ... }
  return pcall(function()
    local resourceExports = exports[resourceName]
    return resourceExports[exportName](resourceExports, table.unpack(args))
  end)
end

local function printExportResult(label, ok, result, extra)
  print(('[mz_org][debug] %s ok=%s result=%s extra=%s'):format(
    label,
    tostring(ok),
    encodeDebug(result),
    encodeDebug(extra)
  ))
end

RegisterCommand('mzorg_test', function(source, args)
  if Config.DebugCommands ~= true then
    return
  end

  local src = tonumber(source) or 0
  if src <= 0 then
    print('[mz_org][debug] Use este comando dentro do jogo.')
    return
  end

  local orgCode = tostring(args and args[1] or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if orgCode == '' then
    orgCode = 'mafia'
  end

  print(('[mz_org][debug] ---- mzorg_test start source=%s name=%s orgCode=%s ----'):format(
    tostring(src),
    tostring(GetPlayerName(src) or 'unknown'),
    tostring(orgCode)
  ))

  local okOwner, owner = callExport('mz_core', 'HasGlobalPermission', src, Config.OwnerAce or 'group.mz_owner')
  printExportResult('HasGlobalPermission(group.mz_owner)', okOwner, owner)

  local okStaff, staff = callExport('mz_core', 'HasGlobalPermission', src, 'staff.orgs.manage')
  printExportResult('HasGlobalPermission(staff.orgs.manage)', okStaff, staff)

  local okContext, context = callExport('mz_org', 'GetPlayerOrgContext', src)
  printExportResult('GetPlayerOrgContext', okContext, context)

  local okOrg, organization = callExport('mz_org', 'GetOrgByCode', orgCode)
  printExportResult(('GetOrgByCode(%s)'):format(orgCode), okOrg, organization)

  local capabilities = {
    'org.view',
    'members.view',
    'members.invite',
    'members.remove',
    'members.promote',
    'members.demote',
    'manage.members',
    'members.set_leader',
    'vip.chat.tag'
  }
  for _, capability in ipairs(capabilities) do
    local okCapability, allowed = callExport('mz_org', 'CanOrg', src, orgCode, capability)
    printExportResult(
      ('CanOrg(%s, %s)'):format(orgCode, capability),
      okCapability,
      allowed
    )
  end

  local okMembers, members, membersErr = callExport('mz_org', 'ListOrgMembers', src, orgCode)
  printExportResult(('ListOrgMembers(%s)'):format(orgCode), okMembers, members, membersErr)

  print('[mz_org][debug] ---- mzorg_test end ----')
end, false)
