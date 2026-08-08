local COMMAND = 'mz_org_phase0_runtime'
local PREFIX = '[mz_org][phase0-runtime]'
local running = false

local function trim(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return '' end
  return tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
end

local function enabled()
  return GetConvarInt('mz_org_phase0_runtime_runner', 0) == 1
end

local function stagingGuard()
  if not enabled() then return false, 'runner_convar_disabled' end
  if trim(GetConvar('mz_org_phase0_environment', '')):lower() ~= 'staging' then
    return false, 'staging_environment_required'
  end
  local backupReference = trim(GetConvar('mz_org_phase0_backup_confirmed', ''))
  if backupReference == '' or backupReference == '0' then
    return false, 'backup_attestation_required'
  end
  return true, backupReference
end

local function encode(value)
  local ok, result = pcall(json.encode, value)
  return ok and result or '"evidence_encode_failed"'
end

local function resultLine(runId, status, number, scenario, reason, evidence)
  print(('%s run=%s %s %s - %s | reason=%s | evidence=%s'):format(
    PREFIX,
    tostring(runId),
    status,
    tostring(number),
    tostring(scenario),
    tostring(reason or ''),
    encode(evidence or {})
  ))
end

local function record(results, runId, number, scenario, passed, reason, evidence)
  local status = passed and 'PASS' or 'FAIL'
  results[#results + 1] = {
    number = tostring(number),
    scenario = scenario,
    status = status,
    reason = reason,
    evidence = evidence
  }
  resultLine(runId, status, number, scenario, reason, evidence)
  return passed
end

local function summarize(results, runId)
  local passed, failed = 0, 0
  for _, item in ipairs(results) do
    if item.status == 'PASS' then passed = passed + 1 else failed = failed + 1 end
  end
  print(('%s run=%s RESULT executed=%d passed=%d failed=%d'):format(
    PREFIX, tostring(runId), #results, passed, failed
  ))
  return failed == 0
end

local function coreExport(name, ...)
  local args = { ... }
  local ok, first, second = pcall(function()
    local core = exports['mz_core']
    return core[name](core, table.unpack(args))
  end)
  if not ok then return nil, 'export_exception:' .. tostring(first) end
  return first, second
end

local function hasItemById(items, id)
  for _, item in ipairs(type(items) == 'table' and items or {}) do
    if tonumber(item.id) == tonumber(id) then return true end
  end
  return false
end

local function runPreflight(runId)
  local results = {}
  local guardOk, backupReference = stagingGuard()
  record(results, runId, 'M01', 'runner restrito ao staging', guardOk,
    guardOk and 'staging_guard_ok' or backupReference,
    { environment = GetConvar('mz_org_phase0_environment', ''), runnerEnabled = enabled() })
  record(results, runId, 'M02', 'atestado operacional de backup informado', guardOk,
    guardOk and 'operator_attestation_present' or 'backup_attestation_missing',
    { backupReference = guardOk and backupReference or nil })

  local coreStarted = GetResourceState('mz_core') == 'started'
  local mysqlStarted = GetResourceState('oxmysql') == 'started'
  record(results, runId, 'M03', 'dependencias runtime iniciadas', coreStarted and mysqlStarted,
    coreStarted and mysqlStarted and 'resources_started' or 'resource_not_started',
    { mz_core = GetResourceState('mz_core'), oxmysql = GetResourceState('oxmysql') })

  if not coreStarted or not mysqlStarted then
    summarize(results, runId)
    return false
  end

  local tables = MySQL.query.await([[
    SELECT table_name, engine
    FROM information_schema.tables
    WHERE table_schema = DATABASE() AND table_name IN ('mz_logs', 'mz_player_orgs')
    ORDER BY table_name
  ]]) or {}
  local engines = {}
  for _, row in ipairs(tables) do engines[row.table_name] = tostring(row.engine or '') end
  local enginesOk = tostring(engines.mz_logs or ''):lower() == 'innodb'
    and tostring(engines.mz_player_orgs or ''):lower() == 'innodb'
  record(results, runId, 'M04', 'tabelas criticas usam InnoDB', enginesOk,
    enginesOk and 'engines_ok' or 'engine_invalid', engines)

  local columns = MySQL.query.await([[
    SELECT column_name, column_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'mz_logs'
      AND column_name IN ('org_code', 'audit_id')
    ORDER BY column_name
  ]]) or {}
  local columnMap = {}
  for _, row in ipairs(columns) do columnMap[row.column_name] = row end
  record(results, runId, 'M05', 'colunas de escopo e auditoria existem',
    columnMap.org_code ~= nil and columnMap.audit_id ~= nil,
    columnMap.org_code and columnMap.audit_id and 'columns_present' or 'column_missing', columns)

  local indexes = MySQL.query.await([[
    SELECT index_name, non_unique, GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'mz_logs'
      AND index_name IN ('idx_mz_logs_org_code', 'uq_mz_logs_audit_id')
    GROUP BY index_name, non_unique
    ORDER BY index_name
  ]]) or {}
  local indexMap = {}
  for _, row in ipairs(indexes) do indexMap[row.index_name] = row end
  local indexesOk = indexMap.idx_mz_logs_org_code ~= nil
    and indexMap.uq_mz_logs_audit_id ~= nil
    and tonumber(indexMap.uq_mz_logs_audit_id.non_unique) == 0
  record(results, runId, 'M06', 'indices de org_code e audit_id existem', indexesOk,
    indexesOk and 'indexes_present' or 'index_missing_or_not_unique', indexes)

  local counts = MySQL.single.await([[
    SELECT
      SUM(CASE WHEN org_code IS NOT NULL THEN 1 ELSE 0 END) AS logs_with_org_code,
      SUM(CASE WHEN org_code IS NULL THEN 1 ELSE 0 END) AS logs_without_org_code,
      COUNT(*) AS logs_total
    FROM mz_logs
  ]]) or {}
  local legacyPermissions = MySQL.single.await([[
    SELECT COUNT(*) AS total
    FROM mz_org_permissions
    WHERE permission LIKE 'staff.%'
  ]]) or {}
  record(results, runId, 'M07', 'inventario legado coletado sem limpeza', true,
    'read_only_inventory_complete', {
      logsTotal = tonumber(counts.logs_total) or 0,
      logsWithOrgCode = tonumber(counts.logs_with_org_code) or 0,
      logsWithoutOrgCode = tonumber(counts.logs_without_org_code) or 0,
      legacyOrgStaffPermissions = tonumber(legacyPermissions.total) or 0
    })

  record(results, runId, 44, 'convite por targetSource desativado por padrao',
    Config.AllowLegacyTargetSourceInvite == false,
    Config.AllowLegacyTargetSourceInvite == false and 'legacy_source_invite_disabled' or 'legacy_source_invite_enabled',
    { configured = Config.AllowLegacyTargetSourceInvite })

  return summarize(results, runId)
end

local function fixtureToken()
  local timer = type(GetGameTimer) == 'function' and GetGameTimer() or 0
  return ('%d_%d_%04d'):format(os.time(), timer, math.random(0, 9999))
end

local function runDatabaseTests(runId, viewerSource)
  local results = {}
  local guardOk, guardEvidence = stagingGuard()
  if not guardOk then
    record(results, runId, 'G01', 'guard de escrita staging', false, guardEvidence, {})
    summarize(results, runId)
    return false
  end

  viewerSource = tonumber(viewerSource)
  if not viewerSource or viewerSource <= 0 or not GetPlayerName(viewerSource) then
    record(results, runId, 'G02', 'viewer Staff/owner conectado fornecido', false,
      'online_viewer_source_required', { viewerSource = viewerSource })
    summarize(results, runId)
    return false
  end

  local token = fixtureToken()
  local codeA = ('mztest_police_%s'):format(token):sub(1, 63)
  local codeB = (codeA .. '2'):sub(1, 64)
  local codeArchived = ('mztest_archived_%s'):format(token):sub(1, 64)
  local citizenid = ('mztest_%s'):format(token):sub(1, 32)
  local auditPrefix = ('mztest_phase0_%s'):format(token):sub(1, 78)
  local orgIds = {}

  local function cleanup()
    local cleanupErrors = {}
    local operations = {
      function() MySQL.update.await('DELETE FROM mz_logs WHERE audit_id LIKE ?', { auditPrefix .. '%' }) end,
      function() MySQL.update.await('DELETE FROM mz_logs WHERE org_code IN (?, ?, ?)', { codeA, codeB, codeArchived }) end,
      function() MySQL.update.await('DELETE FROM mz_player_orgs WHERE citizenid = ?', { citizenid }) end,
      function()
        if #orgIds > 0 then
          for _, orgId in ipairs(orgIds) do
            MySQL.update.await('DELETE FROM mz_org_permissions WHERE org_id = ?', { orgId })
            MySQL.update.await('DELETE FROM mz_org_grades WHERE org_id = ?', { orgId })
          end
        end
      end,
      function() MySQL.update.await('DELETE FROM mz_orgs WHERE code IN (?, ?, ?)', { codeA, codeB, codeArchived }) end
    }
    for index, operation in ipairs(operations) do
      local ok, err = pcall(operation)
      if not ok then cleanupErrors[#cleanupErrors + 1] = { step = index, error = tostring(err) } end
    end
    local remaining = MySQL.single.await([[
      SELECT
        (SELECT COUNT(*) FROM mz_logs WHERE audit_id LIKE ? OR org_code IN (?, ?, ?)) AS logs_count,
        (SELECT COUNT(*) FROM mz_player_orgs WHERE citizenid = ?) AS membership_count,
        (SELECT COUNT(*) FROM mz_orgs WHERE code IN (?, ?, ?)) AS org_count
    ]], { auditPrefix .. '%', codeA, codeB, codeArchived, citizenid, codeA, codeB, codeArchived }) or {}
    local clean = #cleanupErrors == 0
      and tonumber(remaining.logs_count or 0) == 0
      and tonumber(remaining.membership_count or 0) == 0
      and tonumber(remaining.org_count or 0) == 0
    record(results, runId, 'C01', 'cleanup de fixtures temporarias', clean,
      clean and 'cleanup_complete' or 'cleanup_incomplete', { errors = cleanupErrors, remaining = remaining })
  end

  local ok, err = xpcall(function()
    local orgType = MySQL.single.await('SELECT id FROM mz_org_types ORDER BY id LIMIT 1')
    if not orgType then error('org_type_fixture_dependency_missing') end

    orgIds[1] = MySQL.insert.await([[
      INSERT INTO mz_orgs (type_id, code, name, active, has_shared_account)
      VALUES (?, ?, ?, 1, 0)
    ]], { orgType.id, codeA, 'Phase0 Runtime Police A' })
    orgIds[2] = MySQL.insert.await([[
      INSERT INTO mz_orgs (type_id, code, name, active, has_shared_account)
      VALUES (?, ?, ?, 1, 0)
    ]], { orgType.id, codeB, 'Phase0 Runtime Police B' })
    orgIds[3] = MySQL.insert.await([[
      INSERT INTO mz_orgs (type_id, code, name, active, has_shared_account)
      VALUES (?, ?, ?, 0, 0)
    ]], { orgType.id, codeArchived, 'Phase0 Runtime Archived' })
    if not orgIds[1] or not orgIds[2] or not orgIds[3] then error('org_fixture_insert_failed') end

    local grade1 = MySQL.insert.await([[
      INSERT INTO mz_org_grades (org_id, level, code, name, active)
      VALUES (?, 1, 'member', 'Member', 1)
    ]], { orgIds[1] })
    local grade2 = MySQL.insert.await([[
      INSERT INTO mz_org_grades (org_id, level, code, name, active)
      VALUES (?, 2, 'leader', 'Leader', 1)
    ]], { orgIds[1] })
    MySQL.insert.await([[
      INSERT INTO mz_player_orgs (citizenid, org_id, grade_id, active)
      VALUES (?, ?, ?, 1)
    ]], { citizenid, orgIds[1], grade1 })

    local auditA = auditPrefix .. '_log_a'
    local auditB = auditPrefix .. '_log_b'
    local auditGlobal = auditPrefix .. '_global'
    local auditLegacy = auditPrefix .. '_legacy'
    local logA, logAErr = coreExport('CreateDetailedLog', 'orgs', 'phase0.runtime.log_a', {
      actor = { type = 'runtime_runner', id = 'console' },
      target = { type = 'organization', id = codeA },
      context = { org_code = codeA }, auditId = auditA,
      meta = { runtime_fixture = true }
    })
    local logB, logBErr = coreExport('CreateDetailedLog', 'orgs', 'phase0.runtime.log_b', {
      actor = { type = 'runtime_runner', id = 'console' },
      target = { type = 'organization', id = codeB },
      context = { org_code = codeB }, auditId = auditB,
      meta = { runtime_fixture = true }
    })
    local logGlobal, globalErr = coreExport('CreateDetailedLog', 'core', 'phase0.runtime.global', {
      actor = { type = 'runtime_runner', id = 'console' },
      target = { type = 'runtime', id = token }, auditId = auditGlobal,
      meta = { runtime_fixture = true }
    })
    local legacyLog = MySQL.insert.await([[
      INSERT INTO mz_logs (scope, action, actor, target, org_code, audit_id, data_json)
      VALUES ('orgs', 'phase0.runtime.legacy', 'console', ?, NULL, ?, ?)
    ]], { codeA, auditLegacy, json.encode({ context = { org_code = codeA }, runtime_fixture = true }) })

    record(results, runId, 10, 'logs temporarios para codigos semelhantes criados',
      logA ~= nil and logB ~= nil and logGlobal ~= nil and legacyLog ~= nil,
      logA and logB and logGlobal and legacyLog and 'fixture_logs_created' or 'fixture_log_create_failed',
      { codeA = codeA, codeB = codeB, ids = { logA, logB, logGlobal, legacyLog }, errors = { logAErr, logBErr, globalErr } })

    local logsA, logsAErr = coreExport('ListOrgLogsSecure', viewerSource, codeA, { limit = 100 })
    local logsB, logsBErr = coreExport('ListOrgLogsSecure', viewerSource, codeB, { limit = 100 })
    record(results, runId, 11, 'consultas seguras dos dois escopos organizacionais',
      type(logsA) == 'table' and type(logsB) == 'table',
      type(logsA) == 'table' and type(logsB) == 'table' and 'secure_queries_succeeded' or 'secure_query_failed',
      { viewerSource = viewerSource, countA = type(logsA) == 'table' and #logsA or nil,
        countB = type(logsB) == 'table' and #logsB or nil, errors = { logsAErr, logsBErr } })
    record(results, runId, 12, 'isolamento exato por org_code',
      hasItemById(logsA, logA) and not hasItemById(logsA, logB)
        and hasItemById(logsB, logB) and not hasItemById(logsB, logA),
      'exact_org_code_comparison', { logA = logA, logB = logB })
    record(results, runId, 13, 'log global ausente das consultas organizacionais',
      not hasItemById(logsA, logGlobal) and not hasItemById(logsB, logGlobal),
      'global_log_isolated', { globalLogId = logGlobal })

    local globalLogs, globalLogsErr = coreExport('ListGlobalLogsSecure', viewerSource, { limit = 100 })
    record(results, runId, 14, 'logs organizacionais ausentes da consulta global',
      type(globalLogs) == 'table' and not hasItemById(globalLogs, logA) and not hasItemById(globalLogs, logB),
      type(globalLogs) == 'table' and 'org_logs_isolated_from_global' or 'global_query_failed',
      { error = globalLogsErr, count = type(globalLogs) == 'table' and #globalLogs or nil })
    record(results, runId, 15, 'log legado com org_code NULL segue escopo global estrutural',
      type(globalLogs) == 'table' and hasItemById(globalLogs, legacyLog) and not hasItemById(logsA, legacyLog),
      'legacy_null_scope_observed', { legacyLogId = legacyLog })

    local promoteAudit = auditPrefix .. '_promote'
    local promoted, promoteData = coreExport('Phase0RuntimeAuditProbe', {
      citizenid = citizenid, orgId = orgIds[1], orgCode = codeA, gradeId = grade2,
      auditId = promoteAudit, action = 'phase0.runtime.promote'
    })
    local promotedState = MySQL.single.await([[
      SELECT po.grade_id, l.id AS log_id, l.audit_id
      FROM mz_player_orgs po
      LEFT JOIN mz_logs l ON l.audit_id = ?
      WHERE po.citizenid = ? AND po.org_id = ?
      LIMIT 1
    ]], { promoteAudit, citizenid, orgIds[1] }) or {}
    record(results, runId, 16, 'promocao atomica cria auditId e log correspondente',
      promoted == true and tonumber(promotedState.grade_id) == tonumber(grade2)
        and promotedState.log_id ~= nil and promotedState.audit_id == promoteAudit,
      promoted == true and 'promotion_audited' or tostring(promoteData),
      { oldGradeId = grade1, newGradeId = promotedState.grade_id, auditId = promoteAudit, logId = promotedState.log_id })

    local demoteAudit = auditPrefix .. '_demote'
    local demoted, demoteData = coreExport('Phase0RuntimeAuditProbe', {
      citizenid = citizenid, orgId = orgIds[1], orgCode = codeA, gradeId = grade1,
      auditId = demoteAudit, action = 'phase0.runtime.demote'
    })
    local demotedState = MySQL.single.await([[
      SELECT po.grade_id, l.id AS log_id, l.audit_id
      FROM mz_player_orgs po
      LEFT JOIN mz_logs l ON l.audit_id = ?
      WHERE po.citizenid = ? AND po.org_id = ?
      LIMIT 1
    ]], { demoteAudit, citizenid, orgIds[1] }) or {}
    record(results, runId, 17, 'rebaixamento atomico cria auditId e log correspondente',
      demoted == true and tonumber(demotedState.grade_id) == tonumber(grade1)
        and demotedState.log_id ~= nil and demotedState.audit_id == demoteAudit,
      demoted == true and 'demotion_audited' or tostring(demoteData),
      { oldGradeId = grade2, newGradeId = demotedState.grade_id, auditId = demoteAudit, logId = demotedState.log_id })

    local duplicateAudit = auditPrefix .. '_duplicate'
    local blockerId = MySQL.insert.await([[
      INSERT INTO mz_logs (scope, action, actor, target, org_code, audit_id, data_json)
      VALUES ('runtime', 'phase0.runtime.blocker', 'console', ?, ?, ?, '{}')
    ]], { citizenid, codeA, duplicateAudit })
    local failedChange, failureReason = coreExport('Phase0RuntimeAuditProbe', {
      citizenid = citizenid, orgId = orgIds[1], orgCode = codeA, gradeId = grade2,
      auditId = duplicateAudit, action = 'phase0.runtime.rollback'
    })
    record(results, runId, 18, 'falha controlada no INSERT de auditoria',
      failedChange == false and failureReason == 'audit_transaction_failed',
      tostring(failureReason), { duplicateAuditId = duplicateAudit, blockerLogId = blockerId })

    local rollbackState = MySQL.single.await([[
      SELECT grade_id FROM mz_player_orgs WHERE citizenid = ? AND org_id = ? LIMIT 1
    ]], { citizenid, orgIds[1] }) or {}
    record(results, runId, 19, 'rollback real preserva cargo anterior',
      tonumber(rollbackState.grade_id) == tonumber(grade1),
      tonumber(rollbackState.grade_id) == tonumber(grade1) and 'grade_rollback_confirmed' or 'grade_changed_without_audit',
      { expectedGradeId = grade1, actualGradeId = rollbackState.grade_id })

    local duplicateRows = MySQL.single.await('SELECT COUNT(*) AS total FROM mz_logs WHERE audit_id = ?', { duplicateAudit }) or {}
    record(results, runId, 20, 'nenhuma alteracao persiste sem nova auditoria',
      tonumber(rollbackState.grade_id) == tonumber(grade1) and tonumber(duplicateRows.total) == 1,
      'membership_and_audit_count_checked', { gradeId = rollbackState.grade_id, auditRows = duplicateRows.total })

    local uniqueIndex = MySQL.single.await([[
      SELECT non_unique FROM information_schema.statistics
      WHERE table_schema = DATABASE() AND table_name = 'mz_logs'
        AND index_name = 'uq_mz_logs_audit_id'
      LIMIT 1
    ]])
    record(results, runId, 21, 'audit_id possui unicidade efetiva',
      uniqueIndex ~= nil and tonumber(uniqueIndex.non_unique) == 0 and failedChange == false,
      'unique_index_and_duplicate_rejection_confirmed', uniqueIndex or {})

    local active, archivedReason = MZOrgSecurity.RequireActiveOrg(codeArchived)
    record(results, runId, 22, 'organizacao arquivada rejeitada pelo guard do workspace',
      active == false and archivedReason == 'org_archived', tostring(archivedReason), { orgCode = codeArchived })

    local mutationOk, mutationReason = coreExport('CreateOrgGoal', viewerSource, codeArchived, {
      title = 'Must not persist', target = 1
    })
    record(results, runId, 26, 'endpoint server-side bloqueia mutacao em org arquivada',
      mutationOk == false and mutationReason == 'org_archived', tostring(mutationReason), { orgCode = codeArchived })
  end, debug.traceback)

  if not ok then
    record(results, runId, 'G99', 'execucao das fixtures', false, 'runner_exception', { error = tostring(err) })
  end
  cleanup()
  return summarize(results, runId)
end

local function inspectSession(runId, playerSource, requestedEntry)
  local results = {}
  playerSource = tonumber(playerSource)
  if not playerSource or playerSource <= 0 or not GetPlayerName(playerSource) then
    record(results, runId, 'S01', 'player de staging conectado', false, 'online_player_required', { source = playerSource })
    summarize(results, runId)
    return false
  end
  local session, err = MZOrgSession.Build(playerSource, requestedEntry)
  if not session then
    record(results, runId, 'S02', 'sessao V2 construida', false, tostring(err), { source = playerSource })
    summarize(results, runId)
    return false
  end
  record(results, runId, 'S02', 'sessao V2 construida', session.version == 2,
    session.version == 2 and 'session_v2' or 'unexpected_contract_version', {
      source = playerSource,
      sessionId = session.sessionId,
      revision = session.revision,
      entryAllowed = session.entryAllowed,
      denialReason = session.denialReason,
      staffContext = session.staffContext,
      modules = session.modules,
      organizationCount = #(session.organizations or {}),
      globalPermissions = session.global and session.global.permissions or {}
    })
  return summarize(results, runId)
end

RegisterCommand(COMMAND, function(source, args)
  if tonumber(source) ~= 0 then
    print(('%s BLOCKED console_only source=%s'):format(PREFIX, tostring(source)))
    return
  end
  if not enabled() then
    print(('%s BLOCKED runner_convar_disabled'):format(PREFIX))
    return
  end
  if running then
    print(('%s BLOCKED runner_already_running'):format(PREFIX))
    return
  end

  local mode = trim(args[1] or 'status'):lower()
  local runId = fixtureToken()
  if mode == 'status' then
    print(('%s run=%s STATUS enabled=true environment=%s backupAttested=%s core=%s mysql=%s'):format(
      PREFIX, runId, GetConvar('mz_org_phase0_environment', ''),
      tostring(trim(GetConvar('mz_org_phase0_backup_confirmed', '')) ~= ''),
      GetResourceState('mz_core'), GetResourceState('oxmysql')
    ))
    return
  end

  running = true
  CreateThread(function()
    local ok, err = xpcall(function()
      if mode == 'preflight' then
        runPreflight(runId)
      elseif mode == 'database' then
        runDatabaseTests(runId, args[2])
      elseif mode == 'all' then
        local preflightOk = runPreflight(runId)
        if preflightOk then runDatabaseTests(runId, args[2]) end
      elseif mode == 'session' then
        inspectSession(runId, args[2], args[3] or 'hub')
      else
        print(('%s run=%s FAIL invalid_mode expected=status|preflight|database|all|session'):format(PREFIX, runId))
      end
    end, debug.traceback)
    if not ok then print(('%s run=%s FAIL unhandled=%s'):format(PREFIX, runId, tostring(err))) end
    running = false
  end)
end, false)
