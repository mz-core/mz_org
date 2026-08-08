MZOrgContext = MZOrgContext or {}

function MZOrgContext.NormalizeRequestEnvelope(data)
  data = type(data) == 'table' and data or {}
  local isV2 = data.version == 2 or data.contractVersion == 2
    or (data.requestId ~= nil and type(data.payload) == 'table')
  if not isV2 then return data, nil end
  local context = type(data.context) == 'table' and data.context or {}
  return type(data.payload) == 'table' and data.payload or {}, {
    requestId = data.requestId,
    sessionId = data.sessionId or context.sessionId,
    sessionRevision = data.sessionRevision or data.revision,
    contextKey = data.contextKey or context.key,
    orgCode = data.orgCode or context.orgCode,
    module = data.module or context.module
  }
end

function MZOrgContext.ApplyResponseEnvelope(response, envelope)
  response = type(response) == 'table' and response or {
    ok = false,
    error = 'Resposta vazia do servidor.'
  }
  if not envelope then return response end
  response.requestId = envelope.requestId
  response.sessionId = envelope.sessionId
  response.sessionRevision = envelope.sessionRevision
  response.contextKey = envelope.contextKey
  response.orgCode = envelope.orgCode
  response.module = envelope.module
  return response
end

function MZOrgContext.IsResponseCurrent(response, sessionRevision, contextKey, orgCode)
  if type(response) ~= 'table' then return false end
  if response.sessionRevision ~= sessionRevision or response.contextKey ~= contextKey then return false end
  if orgCode ~= nil and response.orgCode ~= orgCode then return false end
  return true
end
