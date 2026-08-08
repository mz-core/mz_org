MZOrgOrganizationGoals = MZOrgOrganizationGoals or {}

local function open(context, offset)
  MZOrgOrganizationCommon.Request(context, 'goals', 'mz_org:server:organizationListGoals', {
    offset = offset or 0
  }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Nao foi possivel consultar as metas.', 'error')
      return
    end

    local options = {}
    local operational = MZOrgMenuCommon.HasAnyCapability(context.organization, { 'goals.manage', 'manage.goals' })
    if operational then
      options[#options + 1] = {
        title = 'Criar meta',
        description = 'Cria uma meta manual para a organizacao.',
        icon = 'plus',
        onSelect = function()
          local values = MZOrgMenuCommon.InputDialog('Criar meta', {
            { type = 'input', label = 'Titulo', required = true },
            { type = 'textarea', label = 'Descricao' },
            { type = 'number', label = 'Objetivo', required = true },
            { type = 'input', label = 'Tipo', default = 'manual' },
            { type = 'date', label = 'Inicio' },
            { type = 'date', label = 'Termino' },
            { type = 'textarea', label = 'Motivo', required = true }
          })
          if type(values) ~= 'table' then return end
          local valid, normalized = MZOrgOrganizationMutations.SanitizeGoal({
            title = values[1], description = values[2], target = tonumber(values[3]),
            type = values[4], startsAt = values[5], endsAt = values[6], reason = values[7]
          })
          if not valid then MZOrgMenuCommon.Notify('Dados da meta invalidos: ' .. tostring(normalized), 'error') return end
          if not MZOrgMenuCommon.Confirm('Criar meta?', ('%s\nObjetivo: %s'):format(normalized.title, tostring(normalized.target))) then return end
          MZOrgOrganizationCommon.Mutate(context, 'mz_org:server:organizationCreateGoal', normalized)
        end
      }
    end
    for _, item in ipairs(response.data.items or {}) do
      options[#options + 1] = {
        title = tostring(item.title or 'Meta'),
        description = ('%s%% / %s'):format(tostring(item.progressPercent or 0), tostring(item.status or 'sem status')),
        icon = 'target',
        metadata = {
          { label = 'Progresso', value = ('%s de %s'):format(tostring(item.progress or 0), tostring(item.target or 0)) },
          { label = 'Tipo', value = item.type or '-' },
          { label = 'Inicio', value = MZOrgMenuCommon.FormatDateTime(item.startsAt) },
          { label = 'Termino', value = MZOrgMenuCommon.FormatDateTime(item.endsAt) },
          { label = 'Descricao', value = item.description or 'Nao informada' }
        },
        readOnly = true
      }
    end
    MZOrgOrganizationCommon.Empty(options, 'Nenhuma meta encontrada', 'target')
    MZOrgOrganizationCommon.AddPagination(options, response.data.pagination, function(nextOffset) open(context, nextOffset) end)
    MZOrgOrganizationCommon.Open(
      context, 'goals', 'Metas',
      context.organization.name .. (operational and ' / operacional' or ' / somente leitura'),
      options
    )
  end)
end

function MZOrgOrganizationGoals.Open(context)
  open(context, 0)
end
