MZOrgOrganizationMenu = MZOrgOrganizationMenu or {}

local function copyVisual(target, organization)
  local visual = MZOrgMenuCommon.VisualFields(organization)
  for key, value in pairs(visual) do target[key] = value end
  return target
end

local function gradeDescription(organization)
  local grade = type(organization.grade) == 'table' and organization.grade or {}
  local label = tostring(grade.name or grade.code or 'Sem cargo')
  local level = tonumber(grade.level)
  return level and ('%s (nivel %d)'):format(label, level) or label
end

local function buildOverview(context)
  local organization = context.organization
  local overview = type(context.overview) == 'table' and context.overview or {}
  local rootId = 'mz_org:org:' .. organization.code .. ':root'
  local features = table.concat(organization.features or {}, ', ')
  if features == '' then features = 'Nenhum modulo autorizado' end

  return copyVisual({
    id = 'mz_org:org:' .. organization.code .. ':overview',
    title = 'Visao geral',
    subtitle = organization.name,
    menu = rootId,
    onExit = function() MZOrgMenuRequest.ClearContext('organization') end,
    options = {
      { title = 'Organizacao', description = organization.name, icon = 'building', readOnly = true },
      { title = 'Tipo', description = tostring(organization.type or ''), icon = 'info', readOnly = true },
      { title = 'Cargo atual', description = gradeDescription(organization), icon = 'shield', readOnly = true },
      {
        title = 'Status de servico',
        description = overview.isDuty and 'Em servico' or 'Fora de servico',
        icon = 'power',
        readOnly = true
      },
      {
        title = 'Membros',
        description = tostring(overview.memberCount or 0),
        icon = 'users',
        readOnly = true
      },
      {
        title = 'Conta organizacional',
        description = overview.hasSharedAccount and 'Disponivel' or 'Indisponivel',
        icon = 'briefcase',
        readOnly = true
      },
      { title = 'Modulos ativos', description = features, icon = 'layers', readOnly = true }
    }
  }, organization)
end

local function openRoot(context)
  local organization = context.organization
  local rootId = 'mz_org:org:' .. organization.code .. ':root'
  local operational = MZOrgMenuCommon.HasAnyCapability(organization, {
    'members.invite', 'members.remove', 'members.kick', 'members.promote', 'members.demote', 'manage.members',
    'account.deposit', 'account.withdraw', 'account.manage', 'manage.account',
    'goals.manage', 'manage.goals', 'recruitment.manage', 'manage.permissions'
  })
  local interface = type(Config.Interface) == 'table' and Config.Interface or {}
  operational = operational or (
    organization.supportsLeadership == true
    and
    interface.organizationLeadershipTransfer == true
    and MZOrgMenuCommon.HasCapability(organization, 'members.set_leader')
  )
  MZOrgMenuCommon.RegisterContext(buildOverview(context))

  local options = {
    {
      title = 'Visao geral',
      description = 'Resumo revalidado da organizacao.',
      icon = 'info',
      menu = 'mz_org:org:' .. organization.code .. ':overview'
    }
  }

  if MZOrgMenuCommon.HasFeature(organization, 'members') then
    options[#options + 1] = {
      title = 'Membros',
      description = 'Lista e acoes autorizadas sobre membros.',
      icon = 'users',
      onSelect = function() MZOrgOrganizationMembers.Open(context) end
    }
  end

  if MZOrgMenuCommon.HasFeature(organization, 'grades') then
    options[#options + 1] = {
      title = 'Cargos',
      description = MZOrgMenuCommon.HasCapability(organization, 'manage.permissions')
        and 'Hierarquia e gestao segura de cargos inferiores.'
        or 'Hierarquia e cargos em modo somente leitura.',
      icon = 'shield',
      onSelect = function() MZOrgOrganizationGrades.Open(context) end
    }
  end

  if MZOrgMenuCommon.HasFeature(organization, 'bank') then
    options[#options + 1] = {
      title = 'Financeiro',
      description = 'Saldo, extrato e movimentacoes autorizadas.',
      icon = 'wallet',
      onSelect = function() MZOrgOrganizationFinance.Open(context) end
    }
  end

  if MZOrgMenuCommon.HasFeature(organization, 'goals') then
    options[#options + 1] = {
      title = 'Metas',
      description = 'Progresso e criacao autorizada de metas.',
      icon = 'target',
      onSelect = function() MZOrgOrganizationGoals.Open(context) end
    }
  end

  if MZOrgMenuCommon.HasFeature(organization, 'recruitment') then
    options[#options + 1] = {
      title = 'Recrutamento',
      description = 'Candidaturas, aprovacoes e decisoes autorizadas.',
      icon = 'user-search',
      onSelect = function() MZOrgOrganizationRecruitment.Open(context) end
    }
  end

  if MZOrgMenuCommon.HasFeature(organization, 'logs') then
    options[#options + 1] = {
      title = 'Logs',
      description = 'Historico revalidado desta organizacao.',
      icon = 'history',
      onSelect = function() MZOrgOrganizationLogs.Open(context) end
    }
  end

  MZOrgMenuCommon.OpenContext(copyVisual({
    id = rootId,
    title = organization.presentation and organization.presentation.title or organization.name,
    subtitle = organization.name .. (operational and ' / operacional' or ' / somente leitura'),
    onExit = function() MZOrgMenuRequest.ClearContext('organization') end,
    options = options
  }, organization))
end

function MZOrgOrganizationMenu.Open(orgCode)
  orgCode = tostring(orgCode or '')
  if orgCode == '' then
    MZOrgMenuCommon.Notify('Organizacao invalida.', 'error')
    return
  end

  MZOrgMenuRequest.BeginContext(orgCode)
  MZOrgMenuRequest.RequestContextual('mz_org:server:getOrganizationMenuContext', {
    orgCode = orgCode
  }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Nao foi possivel abrir a organizacao.', 'error')
      return
    end
    local context = response.data
    if type(context.organization) ~= 'table' or context.organization.code ~= orgCode then return end
    MZOrgMenuRequest.SetContext(context.session or {}, context.organization)
    openRoot(context)
  end)
end
