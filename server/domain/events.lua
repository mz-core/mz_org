RegisterNetEvent('mz_org:server:refreshOrganizations', function()
  local src = source
  MZOrgService.loadPlayerOrgs(src)
  TriggerClientEvent('mz_org:client:organizationsChanged', src, MZOrgService.getPlayerOrgs(src))
end)

lib.callback.register('mz_org:server:getPlayerOrgs', function(source)
  MZOrgService.loadPlayerOrgs(source)
  return MZOrgService.getPlayerOrgs(source)
end)
