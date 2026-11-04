local function economyPay(citizenid, memberships, actor)
  local ok, result, extra = pcall(function()
    return exports['mz_economy']:PayOrganizationSalaries(citizenid, memberships, actor, {
      requireDuty = not (Config.Payroll and Config.Payroll.requireDuty == false)
    })
  end)
  if not ok then return false, 'economy_unavailable' end
  return result, extra
end

local function payCitizen(citizenid, actor)
  citizenid = tostring(citizenid or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if citizenid == '' then return false, 'invalid_citizenid' end
  return economyPay(citizenid, MZOrgRepository.getPlayerMemberships(citizenid), actor)
end

local function runTick()
  local count = 0
  for _, rawSource in ipairs(GetPlayers()) do
    local sourceId = tonumber(rawSource)
    local player = sourceId and MZPlayerService.getPlayer(sourceId) or nil
    if player and player.citizenid then
      local ok = payCitizen(player.citizenid, 'payroll_tick')
      if ok then count = count + 1 end
    end
  end
  return count
end

CreateThread(function()
  while true do
    Wait(math.max(1, tonumber(Config.Payroll and Config.Payroll.intervalMinutes) or 30) * 60000)
    if not Config.Payroll or Config.Payroll.enabled ~= false then
      local ok, result = pcall(runTick)
      if ok then
        print(('[mz_org] payroll tick completed (%s players paid)'):format(result or 0))
      else
        print(('[mz_org] payroll tick failed: %s'):format(tostring(result)))
      end
    end
  end
end)

RegisterCommand('mzpay_citizen', function(source, args)
  if source ~= 0 and not MZStaffService.HasGlobalPermission(source, 'staff.orgs.manage') then return end
  local citizenid = args and args[1]
  local ok, result = payCitizen(citizenid, source)
  print(ok and ('[mz_org] salaries paid for %s'):format(citizenid)
    or ('[mz_org] payroll failed for %s: %s'):format(tostring(citizenid), tostring(result)))
end, true)

RegisterCommand('mzpay_tick', function(source)
  if source ~= 0 and not MZStaffService.HasGlobalPermission(source, 'staff.orgs.manage') then return end
  print(('[mz_org] payroll tick executed (%s players paid)'):format(runTick()))
end, true)
