MZOrgMenuRequest = MZOrgMenuRequest or {}

local requestSequence = 0
local pendingRequests = {}
local contextStates = {
  organization = { generation = 0, kind = 'organization' },
  staff = { generation = 0, kind = 'staff' }
}
local activeKind = nil

local function nextRequestId()
  requestSequence = requestSequence + 1
  if requestSequence > 999999 then requestSequence = 1 end
  return requestSequence
end

local function copyContext(context)
  return {
    generation = context.generation,
    kind = context.kind,
    sessionId = context.sessionId,
    sessionRevision = context.sessionRevision,
    contextKey = context.contextKey,
    orgCode = context.orgCode,
    module = context.module
  }
end

local function currentContext()
  return contextStates[activeKind] or { generation = 0 }
end

local function isPendingContextCurrent(pending)
  if not pending.contextual then return true end
  local expected = pending.expected
  if not expected or expected.kind ~= activeKind then return false end
  local activeContext = currentContext()
  if expected.generation ~= activeContext.generation then return false end
  if expected.orgCode ~= activeContext.orgCode then return false end
  if expected.module ~= activeContext.module then return false end
  if expected.sessionRevision and expected.sessionRevision ~= activeContext.sessionRevision then return false end
  if expected.contextKey and expected.contextKey ~= activeContext.contextKey then return false end
  return true
end

local function applyEnvelope(response, envelope)
  return MZOrgContext.ApplyResponseEnvelope(response or {
    ok = false,
    error = 'Resposta vazia do servidor.'
  }, envelope)
end

local function finishRequest(requestId, response)
  local pending = pendingRequests[requestId]
  if not pending then return end
  pendingRequests[requestId] = nil
  if not isPendingContextCurrent(pending) then return end

  local contextual = applyEnvelope(response, pending.envelope)
  local delayMs = 0
  if GetConvarInt('mz_org_phase0_client_delay_enabled', 0) == 1 then
    delayMs = math.max(0, math.min(GetConvarInt('mz_org_phase0_response_delay_ms', 0), 4000))
  end

  local function deliver()
    if not isPendingContextCurrent(pending) then return end
    pending.callback(contextual)
  end

  if delayMs > 0 then SetTimeout(delayMs, deliver) else deliver() end
end

function MZOrgMenuRequest.BeginContext(orgCode)
  local previous = contextStates.organization
  contextStates.organization = {
    generation = (previous.generation or 0) + 1,
    kind = 'organization',
    orgCode = tostring(orgCode or ''),
    contextKey = 'org:' .. tostring(orgCode or '')
  }
  activeKind = 'organization'
  return copyContext(contextStates.organization)
end

function MZOrgMenuRequest.SetContext(session, organization)
  session = type(session) == 'table' and session or {}
  organization = type(organization) == 'table' and organization or {}
  local context = contextStates.organization
  context.sessionId = session.sessionId or session.revision
  context.sessionRevision = session.revision or session.sessionRevision
  context.orgCode = organization.code or context.orgCode
  context.contextKey = organization.id or ('org:' .. tostring(context.orgCode or ''))
  context.module = 'root'
  activeKind = 'organization'
  return copyContext(context)
end

function MZOrgMenuRequest.BeginOrganizationModule(module)
  local previous = contextStates.organization
  contextStates.organization = {
    generation = (previous.generation or 0) + 1,
    kind = 'organization',
    sessionId = previous.sessionId,
    sessionRevision = previous.sessionRevision,
    module = tostring(module or 'root'),
    orgCode = previous.orgCode,
    contextKey = 'org:' .. tostring(previous.orgCode or '')
  }
  activeKind = 'organization'
  return copyContext(contextStates.organization)
end

function MZOrgMenuRequest.BeginStaffContext(module)
  local previous = contextStates.staff
  contextStates.staff = {
    generation = (previous.generation or 0) + 1,
    kind = 'staff',
    module = module or 'entry',
    contextKey = 'staff:' .. tostring(module or 'entry')
  }
  activeKind = 'staff'
  return copyContext(contextStates.staff)
end

function MZOrgMenuRequest.SetStaffContext(session, module, orgCode)
  session = type(session) == 'table' and session or {}
  local context = contextStates.staff
  context.sessionId = session.sessionId or session.revision
  context.sessionRevision = session.revision or session.sessionRevision
  context.module = module or context.module or 'root'
  context.orgCode = orgCode
  context.contextKey = orgCode and ('staff:' .. context.module .. ':org:' .. orgCode) or ('staff:' .. context.module)
  activeKind = 'staff'
  return copyContext(context)
end

function MZOrgMenuRequest.BeginStaffModule(module, orgCode)
  local previous = contextStates.staff
  contextStates.staff = {
    generation = (previous.generation or 0) + 1,
    kind = 'staff',
    sessionId = previous.sessionId,
    sessionRevision = previous.sessionRevision,
    module = tostring(module or 'root'),
    orgCode = orgCode,
    contextKey = orgCode and ('staff:' .. tostring(module) .. ':org:' .. orgCode) or ('staff:' .. tostring(module or 'root'))
  }
  activeKind = 'staff'
  return copyContext(contextStates.staff)
end

function MZOrgMenuRequest.ClearContext(kind)
  kind = kind or activeKind
  if kind ~= 'organization' and kind ~= 'staff' then return end
  local previous = contextStates[kind]
  contextStates[kind] = { generation = (previous.generation or 0) + 1, kind = kind }
  if activeKind == kind then activeKind = nil end
end

function MZOrgMenuRequest.GetContext()
  return copyContext(currentContext())
end

function MZOrgMenuRequest.Request(eventName, payload, callback, options)
  options = type(options) == 'table' and options or {}
  callback = type(callback) == 'function' and callback or function() end

  local requestId = nextRequestId()
  local serverPayload, envelope = MZOrgContext.NormalizeRequestEnvelope(payload)
  local contextual = options.contextual == true
  local expected = contextual and copyContext(currentContext()) or nil

  if contextual then
    serverPayload = {}
    for key, value in pairs(type(payload) == 'table' and payload or {}) do serverPayload[key] = value end
    serverPayload._context = {
      requestId = requestId,
      sessionId = expected.sessionId,
      sessionRevision = expected.sessionRevision,
      contextKey = expected.contextKey,
      orgCode = expected.orgCode,
      module = expected.module
    }
    envelope = {
      requestId = requestId,
      sessionId = expected.sessionId,
      sessionRevision = expected.sessionRevision,
      contextKey = expected.contextKey,
      orgCode = expected.orgCode,
      module = expected.module
    }
    serverPayload.requestId = requestId
  end

  pendingRequests[requestId] = {
    callback = callback,
    envelope = envelope,
    contextual = contextual,
    expected = expected
  }

  TriggerServerEvent(eventName, requestId, serverPayload or {})

  SetTimeout(Config.NuiCallbackTimeoutMs or 5000, function()
    local pending = pendingRequests[requestId]
    if not pending then return end
    pendingRequests[requestId] = nil
    if not isPendingContextCurrent(pending) then return end
    pending.callback(applyEnvelope({
      ok = false,
      error = 'Tempo esgotado ao consultar o servidor.'
    }, pending.envelope))
  end)

  return requestId
end

function MZOrgMenuRequest.RequestContextual(eventName, payload, callback)
  return MZOrgMenuRequest.Request(eventName, payload, callback, { contextual = true })
end

function MZOrgMenuRequest.RequestMutation(eventName, payload, callback, options)
  payload = type(payload) == 'table' and payload or {}
  options = type(options) == 'table' and options or {}
  if options.withoutOrganizationRevision ~= true and tonumber(payload.organizationRevision) == nil then
    callback = type(callback) == 'function' and callback or function() end
    callback({ ok = false, error = 'Revisao da organizacao ausente.', errorCode = 'invalid_revision' })
    return nil
  end
  return MZOrgMenuRequest.Request(eventName, payload, callback, { contextual = true, mutation = true })
end

function MZOrgMenuRequest.GetActiveKind()
  return activeKind
end

function MZOrgMenuRequest.IsActive(kind, orgCode)
  if activeKind ~= kind then return false end
  if orgCode ~= nil and contextStates[kind] and contextStates[kind].orgCode ~= orgCode then return false end
  return true
end

RegisterNetEvent('mz_org:client:serverResponse', function(requestId, response)
  requestId = tonumber(requestId)
  if requestId then finishRequest(requestId, response) end
end)
