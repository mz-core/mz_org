MZOrgOrganizationFinance = MZOrgOrganizationFinance or {}

local function open(context, offset)
  MZOrgOrganizationCommon.Request(context, 'bank', 'mz_org:server:organizationGetFinance', {
    offset = offset or 0
  }, function(response)
    if not response or response.ok ~= true or type(response.data) ~= 'table' then
      MZOrgMenuCommon.Notify(response and response.error or 'Nao foi possivel consultar o financeiro.', 'error')
      return
    end

    local data = response.data
    local account = type(data.account) == 'table' and data.account or {}
    local options = {
      {
        title = 'Saldo atual',
        description = MZOrgMenuCommon.FormatMoney(account.balance, account.currency),
        icon = 'wallet',
        readOnly = true
      }
    }
    local organization = context.organization
    local canDeposit = MZOrgMenuCommon.HasAnyCapability(organization, { 'account.deposit', 'account.manage', 'manage.account' })
    local canWithdraw = MZOrgMenuCommon.HasAnyCapability(organization, { 'account.withdraw', 'account.manage', 'manage.account' })
    local function accountAction(kind)
      local deposit = kind == 'deposit'
      local values = MZOrgMenuCommon.InputDialog(deposit and 'Depositar na conta' or 'Sacar da conta', {
        { type = 'number', label = 'Valor', required = true, description = 'Valor inteiro entre 1 e 100.000.000.' },
        { type = 'textarea', label = 'Motivo', required = true }
      })
      if type(values) ~= 'table' then return end
      local valid, normalized = MZOrgOrganizationMutations.SanitizeAccount({
        amount = tonumber(values[1]), reason = values[2]
      })
      if not valid then MZOrgMenuCommon.Notify('Valor ou motivo invalido.', 'error') return end
      if not MZOrgMenuCommon.Confirm(deposit and 'Confirmar deposito?' or 'Confirmar saque?', (
        'Valor: %s\nMotivo: %s'
      ):format(MZOrgMenuCommon.FormatMoney(normalized.amount, account.currency), normalized.reason)) then return end
      MZOrgOrganizationCommon.Mutate(
        context,
        deposit and 'mz_org:server:organizationDeposit' or 'mz_org:server:organizationWithdraw',
        normalized
      )
    end
    if canDeposit then
      options[#options + 1] = {
        title = 'Depositar',
        description = 'Transfere do banco pessoal para a organizacao.',
        icon = 'arrow-down',
        onSelect = function() accountAction('deposit') end
      }
    end
    if canWithdraw then
      options[#options + 1] = {
        title = 'Sacar',
        description = 'Transfere da organizacao para o banco pessoal.',
        icon = 'arrow-up',
        onSelect = function() accountAction('withdraw') end
      }
    end
    for _, item in ipairs(data.items or {}) do
      local deposit = item.type == 'deposit'
      options[#options + 1] = {
        title = deposit and 'Entrada' or 'Saida',
        description = MZOrgMenuCommon.FormatMoney(item.amount, account.currency) .. ' / ' .. MZOrgMenuCommon.FormatDateTime(item.createdAt),
        icon = deposit and 'arrow-down' or 'arrow-up',
        metadata = {
          { label = 'Responsavel', value = item.actorName or item.actorCitizenId or 'Sistema' },
          { label = 'Motivo', value = item.reason or 'Nao informado' },
          { label = 'Saldo anterior', value = MZOrgMenuCommon.FormatMoney(item.balanceBefore, account.currency) },
          { label = 'Saldo posterior', value = MZOrgMenuCommon.FormatMoney(item.balanceAfter, account.currency) }
        },
        readOnly = true
      }
    end
    MZOrgOrganizationCommon.AddPagination(options, data.pagination, function(nextOffset) open(context, nextOffset) end)
    MZOrgOrganizationCommon.Open(
      context, 'bank', 'Financeiro',
      context.organization.name .. ((canDeposit or canWithdraw) and ' / operacional' or ' / saldo e extrato'),
      options
    )
  end)
end

function MZOrgOrganizationFinance.Open(context)
  open(context, 0)
end
