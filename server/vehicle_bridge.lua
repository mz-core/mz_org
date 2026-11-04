local function vehicleExport(name, ...)
  local args = { ... }
  local ok, result, extra = pcall(function()
    local vehicles = exports['mz_vehicles']
    return vehicles[name](vehicles, table.unpack(args))
  end)
  if not ok then return false, 'vehicle_service_unavailable' end
  return result, extra
end

local function organizationByCode(code)
  local org = MZOrgService.getOrgByCode(code)
  if type(org) ~= 'table' or not tonumber(org.id) then return nil, 'org_not_found' end
  return org
end

exports('GetOrganizationVehicles', function(orgCode)
  local org, err = organizationByCode(orgCode)
  if not org then return false, err end
  return vehicleExport('GetVehiclesByOwner', 'org', tostring(org.id))
end)

exports('OrganizationOwnsVehicle', function(orgCode, plate)
  local org = organizationByCode(orgCode)
  if not org then return false end
  local owns = vehicleExport('OwnerOwnsVehicle', 'org', tostring(org.id), plate)
  return owns == true
end)

exports('CanAccessVehicle', function(source, plate)
  source = tonumber(source)
  local player = source and MZPlayerService.getPlayer(source) or nil
  if not player or not player.citizenid then return false, 'player_not_loaded' end

  local ok, vehicle = vehicleExport('GetVehicleByPlate', plate)
  if ok ~= true or type(vehicle) ~= 'table' then return false, vehicle or 'vehicle_not_found' end
  if tostring(vehicle.owner_type) == 'player' then
    return tostring(vehicle.owner_id) == tostring(player.citizenid), vehicle
  end
  if tostring(vehicle.owner_type) ~= 'org' then return false, 'vehicle_access_denied' end

  local orgId = tonumber(vehicle.owner_id)
  if not orgId or not MZOrgService.isMember(player.citizenid, orgId) then
    return false, 'vehicle_access_denied'
  end
  local granted, grantResult = vehicleExport('GrantVehicleOwnerAccess', source, plate, 'org', tostring(orgId))
  if granted ~= true then return false, grantResult end
  return true, vehicle
end)
