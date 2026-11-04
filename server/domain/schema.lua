MZOrgState = MZOrgState or {
  schemaReady = false,
  seedReady = false,
  ready = false,
  stage = 'loading'
}

local statements = {
  [[CREATE TABLE IF NOT EXISTS mz_org_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(64) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_mz_org_types_code (code)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
  [[CREATE TABLE IF NOT EXISTS mz_orgs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_id INT NOT NULL,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(128) NOT NULL,
    is_public TINYINT(1) NOT NULL DEFAULT 0,
    requires_whitelist TINYINT(1) NOT NULL DEFAULT 1,
    has_salary TINYINT(1) NOT NULL DEFAULT 1,
    has_shared_account TINYINT(1) NOT NULL DEFAULT 0,
    has_storage TINYINT(1) NOT NULL DEFAULT 0,
    active TINYINT(1) NOT NULL DEFAULT 1,
    revision BIGINT UNSIGNED NOT NULL DEFAULT 1,
    config_json LONGTEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_mz_orgs_code (code),
    KEY idx_mz_orgs_type_id (type_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
  [[CREATE TABLE IF NOT EXISTS mz_org_grades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    org_id INT NOT NULL,
    level INT NOT NULL,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(128) NOT NULL,
    salary BIGINT NOT NULL DEFAULT 0,
    inherits_grade_id INT NULL,
    priority INT NOT NULL DEFAULT 0,
    active TINYINT(1) NOT NULL DEFAULT 1,
    config_json LONGTEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_mz_org_grade_level (org_id, level),
    UNIQUE KEY uq_mz_org_grade_code (org_id, code),
    KEY idx_mz_org_grades_org_id (org_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
  [[CREATE TABLE IF NOT EXISTS mz_org_permissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    org_id INT NOT NULL,
    grade_id INT NULL,
    permission VARCHAR(128) NOT NULL,
    allow TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_mz_org_permissions_unique (org_id, grade_id, permission),
    KEY idx_mz_org_permissions_org_id (org_id),
    KEY idx_mz_org_permissions_grade_id (grade_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
  [[CREATE TABLE IF NOT EXISTS mz_player_orgs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(32) NOT NULL,
    org_id INT NOT NULL,
    grade_id INT NOT NULL,
    is_primary TINYINT(1) NOT NULL DEFAULT 0,
    active TINYINT(1) NOT NULL DEFAULT 1,
    duty TINYINT(1) NOT NULL DEFAULT 0,
    expires_at TIMESTAMP NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_mz_player_org_unique (citizenid, org_id),
    KEY idx_mz_player_orgs_citizenid (citizenid),
    KEY idx_mz_player_orgs_org_id (org_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
  [[CREATE TABLE IF NOT EXISTS mz_org_goals (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    org_code VARCHAR(64) NOT NULL,
    title VARCHAR(120) NOT NULL,
    description TEXT NULL,
    type VARCHAR(32) NOT NULL DEFAULT 'manual',
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    target INT NOT NULL DEFAULT 1,
    progress INT NOT NULL DEFAULT 0,
    starts_at DATETIME NULL,
    ends_at DATETIME NULL,
    created_by_citizenid VARCHAR(64) NULL,
    created_by_name VARCHAR(120) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_mz_org_goals_org_code (org_code),
    KEY idx_mz_org_goals_status (status)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
  [[CREATE TABLE IF NOT EXISTS mz_org_recruitment (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    org_code VARCHAR(64) NOT NULL,
    target_citizenid VARCHAR(64) NOT NULL,
    target_name VARCHAR(120) NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    desired_grade_level INT NULL,
    desired_grade_code VARCHAR(64) NULL,
    note TEXT NULL,
    created_by_citizenid VARCHAR(64) NULL,
    created_by_name VARCHAR(120) NULL,
    reviewed_by_citizenid VARCHAR(64) NULL,
    reviewed_by_name VARCHAR(120) NULL,
    reviewed_at DATETIME NULL,
    decision_note TEXT NULL,
    metadata_json LONGTEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_mz_org_recruitment_org_code (org_code),
    KEY idx_mz_org_recruitment_target (target_citizenid),
    KEY idx_mz_org_recruitment_status (status),
    KEY idx_mz_org_recruitment_created_at (created_at)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
  [[CREATE TABLE IF NOT EXISTS mz_org_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    scope VARCHAR(32) NOT NULL DEFAULT 'orgs',
    action VARCHAR(96) NOT NULL,
    actor VARCHAR(64) NULL,
    target VARCHAR(64) NULL,
    org_code VARCHAR(64) NOT NULL,
    audit_id VARCHAR(96) NOT NULL,
    data_json LONGTEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_mz_org_audit_id (audit_id),
    KEY idx_mz_org_audit_org (org_code, created_at),
    KEY idx_mz_org_audit_action (action)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
}

CreateThread(function()
  local ok, err = xpcall(function()
    MZOrgState.stage = 'schema'
    for _, statement in ipairs(statements) do MySQL.query.await(statement) end
    for _, orgType in ipairs(Config.SeedOrgTypes or {}) do
      MySQL.insert.await([[
        INSERT INTO mz_org_types (code, name) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name)
      ]], { orgType.code, orgType.name })
    end
    MZOrgState.schemaReady = true
    MZOrgState.stage = 'seed'
    MZOrgSeed.ensureDefaultOrgs()
    MZOrgState.seedReady = true
    MZOrgState.ready = true
    MZOrgState.stage = 'ready'
    print('[mz_org] canonical organization schema and seed ready')
  end, debug.traceback)

  if not ok then
    MZOrgState.ready = false
    MZOrgState.error = tostring(err)
    print(('[mz_org] canonical organization bootstrap failed: %s'):format(tostring(err)))
  end
end)
