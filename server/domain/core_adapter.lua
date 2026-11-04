MZOrgCore = MZOrgCore or {}

local playersBySource = {}
local playersByCitizenId = {}

local function coreExport(name, ...)
  if GetResourceState('mz_core') ~= 'started' then return nil, 'core_unavailable' end
  local args = { ... }
  local ok, result, extra = pcall(function()
    local core = exports['mz_core']
    return core[name](core, table.unpack(args))
  end)
  if not ok then return nil, 'core_export_failed' end
  return result, extra
end

function MZOrgCore.Call(name, ...)
  return coreExport(name, ...)
end

local function cachePlayer(snapshot)
  if type(snapshot) ~= 'table' or not snapshot.source or not snapshot.citizenid then return nil end
  local sourceId = tonumber(snapshot.source)
  if not sourceId then return nil end

  local cached = playersBySource[sourceId]
  if cached and tostring(cached.citizenid) ~= tostring(snapshot.citizenid) then
    playersByCitizenId[tostring(cached.citizenid)] = nil
    cached = nil
  end
  snapshot.orgs = cached and cached.orgs or nil
  snapshot.job = cached and cached.job or nil
  snapshot.gang = cached and cached.gang or nil
  playersBySource[sourceId] = snapshot
  playersByCitizenId[tostring(snapshot.citizenid)] = snapshot
  return snapshot
end

MZPlayerService = MZPlayerService or {}

function MZPlayerService.getPlayer(source)
  source = tonumber(source)
  if not source then return nil end
  local snapshot = coreExport('GetPlayerSnapshot', source)
  if type(snapshot) ~= 'table' then return nil end
  return cachePlayer(snapshot)
end

function MZPlayerService.getPlayerByCitizenId(citizenid)
  citizenid = tostring(citizenid or '')
  if citizenid == '' then return nil end
  local source = coreExport('GetSourceByCitizenId', citizenid)
  if source then return MZPlayerService.getPlayer(source) end
  return playersByCitizenId[citizenid]
end

function MZPlayerService.clear(source)
  source = tonumber(source)
  local cached = source and playersBySource[source] or nil
  if cached and cached.citizenid then playersByCitizenId[tostring(cached.citizenid)] = nil end
  if source then playersBySource[source] = nil end
end

MZPlayerRepository = MZPlayerRepository or {}

function MZPlayerRepository.getByCitizenId(citizenid)
  return coreExport('GetCharacterByCitizenId', citizenid)
end

MZStaffService = MZStaffService or {}

function MZStaffService.HasGlobalPermission(source, permission)
  return coreExport('HasGlobalPermission', source, permission) == true
end

MZLogService = MZLogService or {}

function MZLogService.createDetailed(scope, action, payload)
  return coreExport('CreateDetailedLog', scope, action, payload)
end

MZUtils = MZUtils or {}

function MZUtils.jsonDecode(value, fallback)
  if value == nil or value == '' then return fallback end
  local ok, decoded = pcall(json.decode, value)
  return ok and decoded or fallback
end

function MZUtils.jsonEncode(value, fallback)
  local ok, encoded = pcall(json.encode, value)
  return ok and encoded or (fallback or '{}')
end

AddEventHandler('mz_core:server:playerLoaded', function(sourceId)
  if MZOrgService and MZOrgService.loadPlayerOrgs then
    MZOrgService.loadPlayerOrgs(sourceId)
  end
end)

AddEventHandler('playerDropped', function()
  MZPlayerService.clear(source)
end)

AddEventHandler('mz_core:server:identitySessionClosed', function(sourceId)
  MZPlayerService.clear(sourceId)
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  playersBySource = {}
  playersByCitizenId = {}
end)
