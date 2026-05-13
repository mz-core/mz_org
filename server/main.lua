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

local function callCoreExport(exportName, ...)
  if GetResourceState('mz_core') ~= 'started' then
    return false, 'mz_core_not_started'
  end

  local args = { ... }
  return pcall(function()
    local coreExports = exports['mz_core']
    return coreExports[exportName](coreExports, table.unpack(args))
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

  local okOwner, owner = callCoreExport('HasGlobalPermission', src, Config.OwnerAce or 'group.mz_owner')
  printExportResult('HasGlobalPermission(group.mz_owner)', okOwner, owner)

  local okStaff, staff = callCoreExport('HasGlobalPermission', src, 'staff.orgs.manage')
  printExportResult('HasGlobalPermission(staff.orgs.manage)', okStaff, staff)

  local okContext, context = callCoreExport('GetPlayerOrgContext', src)
  printExportResult('GetPlayerOrgContext', okContext, context)

  local okCanView, canView = callCoreExport('CanOrg', src, orgCode, 'org.view')
  printExportResult(('CanOrg(%s, org.view)'):format(orgCode), okCanView, canView)

  local okCanInvite, canInvite = callCoreExport('CanOrg', src, orgCode, 'members.invite')
  printExportResult(('CanOrg(%s, members.invite)'):format(orgCode), okCanInvite, canInvite)

  local okMembers, members, membersErr = callCoreExport('ListOrgMembers', src, orgCode)
  printExportResult(('ListOrgMembers(%s)'):format(orgCode), okMembers, members, membersErr)

  print('[mz_org][debug] ---- mzorg_test end ----')
end, false)
