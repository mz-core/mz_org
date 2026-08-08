MZOrgOrganizationMenuServer = MZOrgOrganizationMenuServer or {}

local function respond(sourceId, requestId, response)
  sourceId = MZOrgSecurity.NormalizeSource(sourceId)
  if not sourceId then
    print(('[mz_org][organization] Resposta descartada: source invalido (requestId=%s).'):format(tostring(requestId)))
    return false
  end
  TriggerClientEvent('mz_org:client:serverResponse', sourceId, requestId, response)
  return true
end

local function fail(message)
  return { ok = false, error = message or 'Falha ao consultar a organizacao.' }
end

local function findOrganization(session, orgCode)
  for _, organization in ipairs(type(session) == 'table' and session.organizations or {}) do
    if organization.code == orgCode then return organization end
  end
  return nil
end

local function hasFeature(organization, featureName)
  for _, feature in ipairs(type(organization) == 'table' and organization.features or {}) do
    if feature == featureName then return true end
  end
  return false
end

local function architectureEnabled()
  local architecture = type(Config.MenuArchitecture) == 'table' and Config.MenuArchitecture or {}
  local interface = type(Config.Interface) == 'table' and Config.Interface or {}
  return architecture.enabled == true and interface.organizationMenu == true
end

function MZOrgOrganizationMenuServer.Respond(sourceId, requestId, ok, dataOrError)
  return respond(sourceId, requestId, ok and {
    ok = true,
    data = dataOrError
  } or fail(dataOrError))
end

function MZOrgOrganizationMenuServer.RespondRead(sourceId, requestId, payload, data)
  local context = type(payload) == 'table' and payload._context or nil
  if type(context) ~= 'table' or not MZOrgSession.IsRevisionCurrent(sourceId, context.sessionRevision) then
    return MZOrgOrganizationMenuServer.Respond(sourceId, requestId, false, 'Sessao organizacional alterada durante a leitura.')
  end
  return MZOrgOrganizationMenuServer.Respond(sourceId, requestId, true, data)
end

function MZOrgOrganizationMenuServer.AuthorizeRead(sourceId, requestId, payload, moduleName, featureName)
  sourceId = MZOrgSecurity.NormalizeSource(sourceId)
  if not sourceId then return nil, 'Origem da requisicao invalida.' end
  if not architectureEnabled() then return nil, 'Menu organizacional desativado.' end
  if type(requestId) ~= 'number' or type(payload) ~= 'table' or tonumber(payload.requestId) ~= requestId then
    return nil, 'Envelope de leitura invalido.'
  end

  local context = payload._context
  if type(context) ~= 'table' or tonumber(context.requestId) ~= requestId then
    return nil, 'RequestId contextual divergente.'
  end

  local orgCode = MZOrgSecurity.NormalizeOrgCode(payload.orgCode)
  if not orgCode or context.orgCode ~= orgCode then return nil, 'Organizacao contextual divergente.' end
  if context.module ~= moduleName then return nil, 'Modulo organizacional divergente.' end
  if context.contextKey ~= ('org:' .. orgCode) then return nil, 'Chave organizacional divergente.' end
  if context.sessionId == nil or context.sessionId ~= context.sessionRevision then
    return nil, 'Identificador de sessao organizacional divergente.'
  end
  if not MZOrgSession.IsRevisionCurrent(sourceId, context.sessionRevision) then
    return nil, 'Sessao organizacional obsoleta.'
  end

  local active, activeError = MZOrgSecurity.RequireActiveOrg(orgCode)
  if not active then
    return nil, activeError == 'org_archived' and 'Organizacao arquivada.' or 'Organizacao indisponivel.'
  end

  local organization, organizationError = MZOrgSession.ResolveOrganization(sourceId, orgCode)
  if not organization or organization.status ~= 'active' then
    return nil, organizationError == 'context_not_found'
      and 'A organizacao nao pertence mais ao jogador.' or 'Contexto organizacional indisponivel.'
  end
  if not hasFeature(organization, featureName) then
    return nil, 'Modulo nao autorizado para esta organizacao.'
  end
  return organization
end

function MZOrgOrganizationMenuServer.AuthorizeMutation(
  sourceId, requestId, payload, moduleName, featureName, capabilities
)
  local organization, authorizationError = MZOrgOrganizationMenuServer.AuthorizeRead(
    sourceId, requestId, payload, moduleName, featureName
  )
  if not organization then return nil, authorizationError end

  local currentOrg, currentError = MZOrgSecurity.GetOrg(organization.code)
  if not currentOrg then return nil, currentError or 'Organizacao inexistente.' end
  if currentOrg.active ~= true then return nil, 'Organizacao arquivada.' end
  if tonumber(payload.organizationRevision) ~= tonumber(currentOrg.organizationRevision) then
    return nil, 'A organizacao mudou. Reabra o menu antes de tentar novamente.'
  end

  local granted = {}
  for _, capability in ipairs(organization.capabilities or {}) do
    if type(capability) == 'string' and not MZOrgSecurity.IsStaffPermission(capability) then
      granted[capability] = true
    end
  end
  for _, capability in ipairs(capabilities or {}) do
    if granted[capability] and MZOrgSecurity.CanOrg(sourceId, organization.code, capability) then
      organization.organizationRevision = tonumber(currentOrg.organizationRevision) or 1
      return organization
    end
  end
  return nil, 'Capability organizacional insuficiente para esta acao.'
end

RegisterNetEvent('mz_org:server:getOrganizationMenuContext', function(requestId, payload)
  local sourceId = source
  if not architectureEnabled() then
    respond(sourceId, requestId, fail('Menu organizacional desativado.'))
    return
  end
  local requestContext = type(payload) == 'table' and payload._context or nil
  if type(requestId) ~= 'number' or type(payload) ~= 'table' or tonumber(payload.requestId) ~= requestId
    or type(requestContext) ~= 'table' or tonumber(requestContext.requestId) ~= requestId then
    respond(sourceId, requestId, fail('Envelope organizacional invalido.'))
    return
  end
  local orgCode = MZOrgSecurity.NormalizeOrgCode(type(payload) == 'table' and payload.orgCode or nil)
  if not orgCode or requestContext.orgCode ~= orgCode or requestContext.contextKey ~= ('org:' .. orgCode) then
    respond(sourceId, requestId, fail('Contexto organizacional divergente.'))
    return
  end

  local active, orgOrError = MZOrgSecurity.RequireActiveOrg(orgCode)
  if not active then
    respond(sourceId, requestId, fail(orgOrError == 'org_archived' and 'Organizacao arquivada.' or 'Organizacao indisponivel.'))
    return
  end
  if not MZOrgSecurity.CanOrg(sourceId, orgCode, 'org.view') then
    respond(sourceId, requestId, fail('Sem permissao para consultar esta organizacao.'))
    return
  end

  local session, sessionError = MZOrgSession.Build(sourceId, {
    requestedEntry = 'organization',
    requestedOrgCode = orgCode
  })
  if not session or session.entryAllowed ~= true then
    respond(sourceId, requestId, fail(sessionError or session and session.denialReason or 'Contexto organizacional negado.'))
    return
  end

  local organization = findOrganization(session, orgCode)
  if not organization or organization.status ~= 'active' then
    respond(sourceId, requestId, fail('Contexto organizacional negado.'))
    return
  end
  organization.organizationRevision = tonumber(orgOrError.organizationRevision) or 1

  local members, membersError = MZOrgSecurity.SafeExport('ListOrgMembers', sourceId, orgCode)
  if type(members) ~= 'table' then
    respond(sourceId, requestId, fail(membersError == 'org_archived' and 'Organizacao arquivada.' or 'Leitura de membros indisponivel.'))
    return
  end

  local progression
  local facilities
  if GetResourceState('mz_org_activities') == 'started' then
    local ok, result = pcall(function()
      local activities = exports['mz_org_activities']
      return activities:GetOrgProgressionForSource(sourceId, orgCode)
    end)
    if ok and type(result) == 'table' then progression = result end
    local facilitiesOk, facilitiesResult = pcall(function()
      local activities = exports['mz_org_activities']
      return activities:ListOrgFacilitiesForSource(sourceId, orgCode)
    end)
    if facilitiesOk and type(facilitiesResult) == 'table' then facilities = facilitiesResult end
  end

  respond(sourceId, requestId, {
    ok = true,
    data = {
      session = {
        sessionId = session.sessionId,
        revision = session.revision
      },
      contextKey = organization.id,
      organization = organization,
      overview = {
        memberCount = #members,
        isDuty = organization.membership and organization.membership.isDuty == true,
        hasSharedAccount = organization.flags and organization.flags.hasSharedAccount == true,
        activeFeatures = organization.features,
        progression = progression,
        facilities = facilities
      }
    }
  })
end)
