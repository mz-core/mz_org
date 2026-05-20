local isOpen = false
local requestSeq = 0
local pendingRequests = {}

local function nextRequestId()
  requestSeq = requestSeq + 1

  if requestSeq > 999999 then
    requestSeq = 1
  end

  return requestSeq
end

local function sendServerRequest(eventName, payload, cb)
  local requestId = nextRequestId()
  pendingRequests[requestId] = cb

  TriggerServerEvent(eventName, requestId, payload or {})

  SetTimeout(Config.NuiCallbackTimeoutMs or 5000, function()
    local pendingCb = pendingRequests[requestId]
    if not pendingCb then return end

    pendingRequests[requestId] = nil
    pendingCb({
      ok = false,
      error = 'Tempo esgotado ao consultar o servidor.'
    })
  end)
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
  openPanel('dashboard', 'hub')
end, false)

RegisterCommand(Config.Commands.Main, function()
  openPanel('dashboard', 'hub')
end, false)

RegisterCommand(Config.Commands.Org, function()
  openPanel('legal', 'legal')
end, false)

RegisterCommand(Config.Commands.Gang, function()
  openPanel('gang', 'illegal')
end, false)

RegisterCommand(Config.Commands.Staff, function()
  openPanel('staff', 'staff')
end, false)

RegisterCommand(Config.Commands.Vip, function()
  openPanel('vip', 'vip')
end, false)

RegisterCommand(Config.Commands.Business, function()
  openPanel('business', 'business')
end, false)

RegisterCommand(Config.Commands.Government, function()
  openPanel('government', 'government')
end, false)

RegisterCommand(Config.Commands.Event, function()
  openPanel('event', 'event')
end, false)

RegisterNUICallback('close', function(_, cb)
  closePanel()
  cb({ ok = true })
end)

RegisterNUICallback('session:get', function(_, cb)
  TriggerServerEvent('mz_org:server:requestSession')
  cb({ ok = true })
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

RegisterNetEvent('mz_org:client:serverResponse', function(requestId, response)
  requestId = tonumber(requestId)
  if not requestId then return end

  local cb = pendingRequests[requestId]
  if not cb then return end

  pendingRequests[requestId] = nil
  cb(response or {
    ok = false,
    error = 'Resposta vazia do servidor.'
  })
end)
