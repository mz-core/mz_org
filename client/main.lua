local isOpen = false

local function sendServerRequest(eventName, payload, cb)
  return MZOrgMenuRequest.Request(eventName, payload, cb)
end

local function sendOpenMessage(initialModule, mode)
  SendNUIMessage({
    action = 'open',
    payload = {
      initialModule = initialModule,
      mode = mode
    }
  })
end

local function openPanel(initialModule, mode)
  if isOpen then
    sendOpenMessage(initialModule, mode)
    return
  end

  isOpen = true
  SetNuiFocus(true, true)

  SetTimeout(100, function()
    if not isOpen then return end
    sendOpenMessage(initialModule, mode)
  end)
end

local function closePanel()
  if not isOpen then return end

  isOpen = false
  SetNuiFocus(false, false)

  SendNUIMessage({
    action = 'close'
  })
end

RegisterCommand(Config.Commands.Dev, function()
  if Config.DebugCommands == true and MZOrgMenuRouter.CanUseNui() then
    openPanel('dashboard', 'hub')
  else
    MZOrgMenuCommon.Notify('Comando de desenvolvimento desativado.', 'error')
  end
end, false)

RegisterCommand(Config.Commands.Main, function()
  if MZOrgMenuRouter.ShouldUseOrganizationMenu() then
    MZOrgMenuRouter.OpenOrganizations('job', Config.Commands.Main)
  elseif MZOrgMenuRouter.CanUseNui() then
    openPanel('legal', 'legal')
  else
    MZOrgMenuCommon.Notify('Interface organizacional desativada.', 'error')
  end
end, false)

RegisterCommand(Config.Commands.Org, function()
  if MZOrgMenuRouter.ShouldUseOrganizationMenu() then
    MZOrgMenuRouter.OpenOrganizations('job', Config.Commands.Org)
  elseif MZOrgMenuRouter.CanUseNui() then
    openPanel('legal', 'legal')
  else
    MZOrgMenuCommon.Notify('Interface organizacional desativada.', 'error')
  end
end, false)

RegisterCommand(Config.Commands.Gang, function()
  if MZOrgMenuRouter.ShouldUseOrganizationMenu() then
    MZOrgMenuRouter.OpenOrganizations('gang', Config.Commands.Gang)
  elseif MZOrgMenuRouter.CanUseNui() then
    openPanel('gang', 'illegal')
  else
    MZOrgMenuCommon.Notify('Nenhuma interface disponivel.', 'error')
  end
end, false)

local staffMenuCommand = (Config.MenuArchitecture or {}).staffCommand or 'stafforg'
if staffMenuCommand ~= Config.Commands.Staff then
  RegisterCommand(staffMenuCommand, function()
    if MZOrgMenuRouter.CanUseNui() then
      openPanel('staff', 'staff')
    elseif MZOrgMenuRouter.ShouldUseStaffMenu() then
      MZOrgStaffMenu.Open()
    else
      MZOrgMenuCommon.Notify('Interface Staff desativada.', 'error')
    end
  end, false)
end

RegisterCommand(Config.Commands.Staff, function()
  local architecture = type(Config.MenuArchitecture) == 'table' and Config.MenuArchitecture or {}
  if MZOrgMenuRouter.CanUseNui() then
    openPanel('staff', 'staff')
  elseif MZOrgMenuRouter.ShouldUseStaffMenu() and (staffMenuCommand == Config.Commands.Staff or architecture.staffAliasCommandEnabled == true) then
    MZOrgStaffMenu.Open()
  else
    MZOrgMenuCommon.Notify('Interface Staff desativada.', 'error')
  end
end, false)

RegisterCommand(Config.Commands.Vip, function()
  if MZOrgMenuRouter.ShouldUseOrganizationMenu() then
    MZOrgMenuRouter.OpenOrganizations('vip', Config.Commands.Vip)
  elseif MZOrgMenuRouter.CanUseNui() then
    openPanel('vip', 'vip')
  else
    MZOrgMenuCommon.Notify('Nenhuma interface disponivel.', 'error')
  end
end, false)

RegisterCommand(Config.Commands.Business, function()
  if MZOrgMenuRouter.ShouldUseOrganizationMenu() then
    MZOrgMenuRouter.OpenOrganizations('business', Config.Commands.Business)
  elseif MZOrgMenuRouter.CanUseNui() then
    openPanel('business', 'business')
  else
    MZOrgMenuCommon.Notify('Nenhuma interface disponivel.', 'error')
  end
end, false)

RegisterCommand(Config.Commands.Government, function()
  if MZOrgMenuRouter.ShouldUseOrganizationMenu() then
    MZOrgMenuRouter.OpenOrganizations('government', Config.Commands.Government)
  elseif MZOrgMenuRouter.CanUseNui() then
    openPanel('government', 'government')
  else
    MZOrgMenuCommon.Notify('Nenhuma interface disponivel.', 'error')
  end
end, false)

RegisterCommand(Config.Commands.Event, function()
  if MZOrgMenuRouter.ShouldUseOrganizationMenu() then
    MZOrgMenuRouter.OpenOrganizations('event', Config.Commands.Event)
  elseif MZOrgMenuRouter.CanUseNui() then
    openPanel('event', 'event')
  else
    MZOrgMenuCommon.Notify('Nenhuma interface disponivel.', 'error')
  end
end, false)

RegisterNUICallback('close', function(_, cb)
  closePanel()
  cb({ ok = true })
end)

RegisterNUICallback('session:get', function(data, cb)
  sendServerRequest('mz_org:server:requestSession', data, cb)
end)

RegisterNUICallback('orgs:list', function(data, cb)
  sendServerRequest('mz_org:server:listOrgs', data, cb)
end)

RegisterNUICallback('orgs:get', function(data, cb)
  sendServerRequest('mz_org:server:getOrg', data, cb)
end)

RegisterNUICallback('orgs:createFromTemplate', function(data, cb)
  sendServerRequest('mz_org:server:createOrgFromTemplate', data, cb)
end)

RegisterNUICallback('orgs:updateBasic', function(data, cb)
  sendServerRequest('mz_org:server:updateOrgBasic', data, cb)
end)

RegisterNUICallback('orgs:createGrade', function(data, cb)
  sendServerRequest('mz_org:server:createGrade', data, cb)
end)

RegisterNUICallback('orgs:updateGradeBasic', function(data, cb)
  sendServerRequest('mz_org:server:updateGradeBasic', data, cb)
end)

RegisterNUICallback('orgs:archive', function(data, cb)
  sendServerRequest('mz_org:server:archiveOrg', data, cb)
end)

RegisterNUICallback('orgs:reactivate', function(data, cb)
  sendServerRequest('mz_org:server:reactivateOrg', data, cb)
end)

RegisterNUICallback('orgs:disableGrade', function(data, cb)
  sendServerRequest('mz_org:server:disableGrade', data, cb)
end)

RegisterNUICallback('orgs:reactivateGrade', function(data, cb)
  sendServerRequest('mz_org:server:reactivateGrade', data, cb)
end)

RegisterNUICallback('orgs:addGradePermission', function(data, cb)
  sendServerRequest('mz_org:server:addGradePermission', data, cb)
end)

RegisterNUICallback('orgs:removeGradePermission', function(data, cb)
  sendServerRequest('mz_org:server:removeGradePermission', data, cb)
end)

RegisterNUICallback('members:list', function(data, cb)
  sendServerRequest('mz_org:server:listMembers', data, cb)
end)

RegisterNUICallback('members:invite', function(data, cb)
  sendServerRequest('mz_org:server:inviteMember', data, cb)
end)

RegisterNUICallback('members:remove', function(data, cb)
  sendServerRequest('mz_org:server:removeMember', data, cb)
end)

RegisterNUICallback('members:promote', function(data, cb)
  sendServerRequest('mz_org:server:promoteMember', data, cb)
end)

RegisterNUICallback('members:demote', function(data, cb)
  sendServerRequest('mz_org:server:demoteMember', data, cb)
end)

RegisterNUICallback('members:setLeader', function(data, cb)
  sendServerRequest('mz_org:server:setOrgLeader', data, cb)
end)

RegisterNUICallback('logs:list', function(data, cb)
  sendServerRequest('mz_org:server:listLogs', data, cb)
end)

RegisterNUICallback('org-bank:get', function(data, cb)
  sendServerRequest('mz_org:server:getOrgBank', data, cb)
end)

RegisterNUICallback('org-bank:transactions', function(data, cb)
  sendServerRequest('mz_org:server:listOrgBankTransactions', data, cb)
end)

RegisterNUICallback('org-bank:deposit', function(data, cb)
  sendServerRequest('mz_org:server:depositOrgBank', data, cb)
end)

RegisterNUICallback('org-bank:withdraw', function(data, cb)
  sendServerRequest('mz_org:server:withdrawOrgBank', data, cb)
end)

RegisterNUICallback('recruitment:list', function(data, cb)
  sendServerRequest('mz_org:server:listRecruitment', data, cb)
end)

RegisterNUICallback('recruitment:get', function(data, cb)
  sendServerRequest('mz_org:server:getRecruitment', data, cb)
end)

RegisterNUICallback('recruitment:create', function(data, cb)
  sendServerRequest('mz_org:server:createRecruitment', data, cb)
end)

RegisterNUICallback('recruitment:approve', function(data, cb)
  sendServerRequest('mz_org:server:approveRecruitment', data, cb)
end)

RegisterNUICallback('recruitment:reject', function(data, cb)
  sendServerRequest('mz_org:server:rejectRecruitment', data, cb)
end)

RegisterNUICallback('recruitment:cancel', function(data, cb)
  sendServerRequest('mz_org:server:cancelRecruitment', data, cb)
end)

RegisterNUICallback('goals:list', function(data, cb)
  sendServerRequest('mz_org:server:listGoals', data, cb)
end)

RegisterNUICallback('goals:get', function(data, cb)
  sendServerRequest('mz_org:server:getGoal', data, cb)
end)

RegisterNUICallback('goals:create', function(data, cb)
  sendServerRequest('mz_org:server:createGoal', data, cb)
end)

RegisterNUICallback('org-access:get', function(data, cb)
  sendServerRequest('mz_org:server:getOrgAccess', data, cb)
end)

RegisterNetEvent('mz_org:client:receiveSession', function(session)
  SendNUIMessage({
    action = 'session:set',
    payload = session
  })
end)

RegisterNetEvent('mz_org:client:organizationInvalidated', function(change)
  change = type(change) == 'table' and change or {}
  local kind = MZOrgMenuRequest.GetActiveKind()
  local context = MZOrgMenuRequest.GetContext()
  if kind == 'staff' or (kind == 'organization' and context.orgCode == change.orgCode) then
    MZOrgMenuRequest.ClearContext(kind)
    if kind == 'staff' then MZOrgStaffMenu.State = {} end
    MZOrgMenuCommon.CloseContext()
    MZOrgMenuCommon.Notify('A organizacao foi alterada. Reabra o menu para carregar a revisao atual.', 'warning')
  end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  isOpen = false
  SetNuiFocus(false, false)
end)
