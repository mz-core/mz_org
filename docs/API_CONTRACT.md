# MZ_ORG - Contrato com MZ_CORE

O `mz_org` é interface NUI. O `mz_core` é a fonte real de dados, permissões, organizações, membros, contas e logs.

## Regras

- O frontend nunca decide permissão real.
- O `source` confiável é sempre o `source` server-side.
- O frontend não envia `isOwner`, `source`, `permissions` ou `capabilities` como verdade.
- Ações futuras sempre devem chamar validação no server antes de executar.

## Capabilities revisadas

Capabilities usadas atualmente pelo painel e/ou core:

- `org.view`
- `members.invite`
- `members.kick`
- `members.remove`
- `members.promote`
- `members.demote`
- `manage.members`
- `account.view`
- `goals.view`
- `goals.manage`
- `manage.goals`
- `logs.view`
- `manage.permissions`
- `staff.panel.open`
- `staff.orgs.manage`
- `staff.logs.view`

`members.remove` e `manage.goals` foram adicionadas ao catalogo compartilhado do `mz_org` para alinhar com as validacoes atuais. Os seeds reais ainda podem precisar receber essas capabilities em cargos apropriados durante uma fase propria de balanceamento/permissoes.

## Exports usados do `mz_core`

- `HasGlobalPermission(source, permission)`
- `GetPlayerOrgContext(source)`
- `CanOrg(source, orgCode, capability)`
- `ListOrgs()`
- `GetOrgByCode(orgCode)`
- `ListOrgMembers(source, orgCode)`
- `ListLogs(source, filters)`
- `GetOrgAccount(source, orgCode)`
- `DepositOrgAccount(source, orgCode, amount, reason)`
- `WithdrawOrgAccount(source, orgCode, amount, reason)`
- `ListOrgAccountTransactions(source, orgCode, filters)`
- `GetOrgAccessModel(source, orgCode)`
- `InviteOrgMember(source, orgCode, targetSource, options)`
- `RemoveOrgMember(source, orgCode, targetCitizenId)`
- `PromoteOrgMemberSecure(source, orgCode, targetCitizenId)`
- `DemoteOrgMemberSecure(source, orgCode, targetCitizenId)`
- `ListOrgGoals(source, filters)`
- `GetOrgGoal(source, goalId)`
- `CreateOrgGoal(source, orgCode, payload)`

## Sessão esperada

```lua
{
  user = {
    source = 1,
    name = "Player",
    isOwner = true,
    globalPermissions = { "group.mz_owner" }
  },
  orgs = {
    {
      code = "police",
      name = "Polícia",
      type = "legal",
      grade = 3,
      gradeCode = "sargento",
      gradeName = "Sargento",
      capabilities = { "org.view" }
    }
  },
  modules = {
    "dashboard",
    "legal",
    "staff",
    "logs"
  }
}
```

## Callbacks NUI atuais

Todos retornam:

```lua
{ ok = true, data = ... }
{ ok = false, error = "mensagem" }
```

- `session:get`
- `orgs:list`
- `orgs:get`
- `members:list`
- `logs:list`
- `org-bank:get`
- `org-bank:transactions`
- `org-bank:deposit`
- `org-bank:withdraw`
- `recruitment:list`
- `recruitment:get`
- `goals:list`
- `goals:get`
- `goals:create`
- `org-access:get`
- `members:invite`
- `members:remove`
- `members:promote`
- `members:demote`

### Banco da organizacao

`org-bank:get` consulta saldo da conta compartilhada:

```lua
{ orgCode = "police" }
```

`org-bank:transactions` lista o extrato real:

```lua
{
  orgCode = "police",
  filters = {
    limit = 50,
    offset = 0,
    type = "deposit"
  }
}
```

`org-bank:deposit` e `org-bank:withdraw` aceitam somente:

```lua
{
  orgCode = "police",
  amount = 1000,
  reason = "opcional"
}
```

O frontend nunca envia `source`, `actorCitizenId`, `orgId`, `balanceBefore` ou `balanceAfter`. O `mz_org` usa o `source` real do evento server-side e chama os exports seguros:

```lua
exports['mz_core']:DepositOrgAccount(source, orgCode, amount, reason)
exports['mz_core']:WithdrawOrgAccount(source, orgCode, amount, reason)
exports['mz_core']:ListOrgAccountTransactions(source, orgCode, filters)
```

Permissoes server-side:

- owner ACE `group.mz_owner` pode operar;
- deposito exige `account.deposit` ou `account.manage`;
- saque exige `account.withdraw` ou `account.manage`;
- extrato usa a regra de visualizacao da conta, incluindo `account.view`.

Persistencia:

- saldo em `mz_org_accounts`;
- extrato em `mz_org_account_transactions`;
- logs/auditoria em `mz_logs` com acoes `org.account.deposit`, `org.account.withdraw` e bloqueios correspondentes.

Erros principais:

- `invalid_org`: organizacao invalida.
- `invalid_amount`: valor invalido.
- `player_not_loaded`: ator nao carregado no core.
- `insufficient_player_funds`: banco do player sem saldo para deposito.
- `insufficient_org_funds`: conta da org sem saldo para saque.
- `forbidden`: sem permissao.
- `deposit_failed` / `withdraw_failed`: falha operacional.
- `rate_limited`: cooldown simples no `mz_org`.

### Recrutamento read-only

`recruitment:list` recebe filtros seguros opcionais:

```lua
{
  orgCode = "police",
  status = "pending",
  type = "application",
  search = "nome",
  limit = 50,
  offset = 0
}
```

`recruitment:get` recebe:

```lua
{ id = "123", orgCode = "police" }
```

Campos esperados quando houver backend real:

```lua
{
  id = 123,
  orgCode = "police",
  type = "application",
  status = "pending",
  candidateName = "Player",
  candidateCitizenId = "ABC123",
  createdAt = "2026-05-13 12:00:00",
  updatedAt = "2026-05-13 12:00:00",
  message = "texto seguro",
  source = "future"
}
```

Nesta etapa nao foi encontrada fonte real de recrutamento no `mz_core`. O `mz_org` tenta reaproveitar exports futuros `ListOrgRecruitment(source, filters)` e `GetOrgRecruitment(source, id)` se existirem; caso contrario retorna lista/detalhe vazio de forma segura.

Permissao server-side:

- owner com `group.mz_owner`;
- staff com `staff.orgs.manage` ou `staff.panel.open`;
- membro/lider autorizado por `CanOrg(source, orgCode, 'members.invite')`, `CanOrg(source, orgCode, 'recruitment.view')` ou fallback `CanOrg(source, orgCode, 'org.view')`;
- player comum sem orgCode fica limitado a candidaturas proprias futuras, atualmente vazio seguro.

Aprovar, recusar e fluxo completo de candidatura continuam pendentes. A acao direta `members:invite` existe em contrato separado e exige validacao server-side, logs e rate limit.

### Metas read-only

`goals:list` recebe filtros seguros opcionais:

```lua
{
  orgCode = "police",
  status = "active",
  type = "weekly",
  search = "patrulha",
  limit = 50,
  offset = 0
}
```

`goals:get` recebe:

```lua
{ id = "1", orgCode = "police" }
```

Formato esperado de uma meta read-only:

```lua
{
  id = 1,
  orgCode = "police",
  title = "Patrulhamento semanal",
  description = "Realizar patrulhas preventivas",
  type = "weekly",
  status = "active",
  target = 20,
  progress = 8,
  progressPercent = 40,
  startsAt = "2026-05-13 00:00:00",
  endsAt = "2026-05-20 00:00:00",
  createdByName = "Player"
}
```

O `mz_core` possui tabela real `mz_org_goals` e exports read-only:

```lua
exports['mz_core']:ListOrgGoals(source, filters)
exports['mz_core']:GetOrgGoal(source, id)
```

Permissao server-side:

- owner com `group.mz_owner`;
- staff com `staff.orgs.manage` ou `staff.panel.open`;
- membro/lider autorizado por `CanOrg(source, orgCode, 'goals.view')`, `CanOrg(source, orgCode, 'goals.manage')` ou fallback `CanOrg(source, orgCode, 'org.view')`.

Editar, deletar, concluir, alterar progresso, ranking, recompensas e logs de metas continuam pendentes e precisam de validacao server-side.

### Criar meta

`goals:create` cria uma meta ativa com progresso inicial zero.

Payload aceito pela NUI:

```lua
{
  orgCode = "police",
  title = "Patrulhamento semanal",
  description = "Realizar patrulhas preventivas",
  type = "weekly",
  target = 20,
  startsAt = "2026-05-13",
  endsAt = "2026-05-20"
}
```

O `source` do autor e `createdBy` nunca vem do frontend. O `mz_org` usa o `source` real do evento server-side e chama:

```lua
exports['mz_core']:CreateOrgGoal(source, orgCode, payload)
```

Resposta de sucesso:

```lua
{
  ok = true,
  data = {
    id = 1,
    orgCode = "police",
    title = "Patrulhamento semanal",
    type = "weekly",
    status = "active",
    target = 20,
    progress = 0,
    progressPercent = 0
  }
}
```

Erros possiveis:

- `invalid_org`: organizacao invalida.
- `forbidden`: autor sem permissao.
- `invalid_title`: titulo ausente ou invalido.
- `invalid_description`: descricao invalida.
- `invalid_type`: tipo fora da whitelist.
- `invalid_target`: objetivo menor que 1 ou acima do limite.
- `invalid_dates`: datas invalidas ou fim anterior ao inicio.
- `create_failed`: falha ao salvar.

Validacoes server-side:

- org deve existir.
- autor precisa ser owner, staff autorizado, `CanOrg(source, orgCode, 'goals.manage')` ou fallback documentado `CanOrg(source, orgCode, 'manage.goals')`.
- tipos aceitos: `manual`, `weekly`, `monthly`, `collective`, `individual`.
- `target` fica entre 1 e 100000.
- `progress` inicial e sempre `0`.
- `status` inicial e sempre `active`.
- `createdBy` e definido pelo server/core.
- existe rate limit simples no `mz_org`.
- o `mz_core` registra auditoria com `MZLogService.createDetailed`.

Nao foram criadas nesta etapa: editar, deletar, concluir, alterar progresso, ranking, recompensa ou pagamento.

### Cargos, grades e capabilities read-only

`org-access:get` recebe:

```lua
{ orgCode = "police" }
```

O `mz_org` usa o export read-only do `mz_core`:

```lua
exports['mz_core']:GetOrgAccessModel(source, orgCode)
```

Formato seguro esperado:

```lua
{
  orgCode = "police",
  orgName = "Policia",
  type = "legal",
  baseCapabilities = {
    "org.view",
    "radio.use"
  },
  grades = {
    {
      level = 1,
      code = "soldado",
      name = "Soldado",
      salary = 1500,
      inheritsLevel = nil,
      inheritsCode = nil,
      capabilities = {
        "org.view"
      },
      directCapabilities = {
        "org.view"
      }
    }
  },
  playerOverrides = {
    {
      permission = "staff.panel.open",
      allow = true,
      expiresAt = nil
    }
  }
}
```

Origem real no `mz_core`:

- `mz_org_grades`: `level`, `code`, `name`, `salary`, `inherits_grade_id`.
- `mz_org_permissions`: capabilities base quando `grade_id` e nulo, e capabilities de grade quando `grade_id` aponta para uma grade.
- `mz_player_permissions`: overrides globais do player atual, retornados sem identifiers privados.

Permissao server-side:

- owner com `group.mz_owner`;
- staff com `staff.orgs.manage` ou `staff.panel.open`;
- membro/lider autorizado por `CanOrg(source, orgCode, 'manage.permissions')`, `CanOrg(source, orgCode, 'manage.members')` ou fallback `CanOrg(source, orgCode, 'org.view')`.

Criar, editar, deletar cargos, alterar capability, escolher grade manualmente fora do fluxo de convite e aplicar overrides continuam pendentes.

### Convidar/adicionar membro

`members:invite` e a primeira acao real do painel.

Payload aceito pela NUI:

```lua
{
  orgCode = "police",
  targetId = 12,
  gradeLevel = 1,
  gradeCode = "recruta"
}
```

`gradeLevel` e `gradeCode` sao opcionais. Se nenhum deles for enviado, o core mantem o comportamento original e usa a menor grade segura da organizacao.

O `source` do autor nunca vem do frontend. O `mz_org` usa o `source` real do evento server-side e chama:

```lua
exports['mz_core']:InviteOrgMember(source, orgCode, targetSource, options)
```

Resposta de sucesso:

```lua
{
  ok = true,
  data = {
    orgCode = "police",
    targetSource = 12,
    targetCitizenId = "ABC123",
    grade = 1,
    gradeCode = "recruta",
    gradeName = "Recruta"
  }
}
```

Erros possiveis:

- `invalid_target`: player alvo invalido ou offline.
- `invalid_org`: organizacao invalida.
- `already_member`: player ja e membro ativo da org.
- `forbidden`: autor sem permissao.
- `self_target`: autor tentando convidar a si mesmo.
- `invalid_grade`: grade enviada nao existe na org ou payload de grade invalido.
- `grade_not_allowed`: autor nao pode convidar para a grade escolhida.
- `grade_not_found`: org sem grade inicial segura.

Validacoes server-side:

- `targetSource` deve ser numero valido e online.
- `targetSource` nao pode ser igual ao autor.
- org deve existir.
- autor precisa ser owner, staff autorizado ou `CanOrg(source, orgCode, 'members.invite')`.
- se grade nao for enviada, grade inicial e a menor grade real da org.
- se grade for enviada, ela precisa existir na propria org.
- owner/staff autorizado pode escolher qualquer grade existente.
- membro comum so pode escolher grade abaixo da propria.
- a NUI nao envia grade livre; o seletor visual usa `org-access:get`, mas o server valida novamente.
- existe rate limit simples no `mz_org` para evitar spam.
- o `mz_core` registra auditoria de sucesso e tentativas bloqueadas com `MZLogService.createDetailed`, incluindo grade inicial, code e nome quando disponiveis.

Nao foram criadas na etapa de convite: editar cargo, editar permissao, convite offline ou input livre de grade. Remocao, promocao e rebaixamento ficam documentados nas secoes proprias.

### Promover e rebaixar membro

`members:promote` e `members:demote` alteram o cargo de um membro ativo para a proxima/anterior grade real da organizacao.

Payload aceito pela NUI:

```lua
{
  orgCode = "police",
  citizenid = "ABC123"
}
```

O `source` do autor nunca vem do frontend. O `mz_org` usa o `source` real do evento server-side e chama os wrappers seguros:

```lua
exports['mz_core']:PromoteOrgMemberSecure(source, orgCode, targetCitizenId)
exports['mz_core']:DemoteOrgMemberSecure(source, orgCode, targetCitizenId)
```

Os exports antigos `PromoteOrgMember(citizenid, orgCode, actor)` e `DemoteOrgMember(citizenid, orgCode, actor)` foram preservados para compatibilidade.

Resposta de sucesso:

```lua
{
  ok = true,
  data = {
    orgCode = "police",
    targetCitizenId = "ABC123",
    action = "promote",
    oldGrade = 1,
    newGrade = 2,
    oldGradeCode = "recruta",
    newGradeCode = "membro"
  }
}
```

Erros possiveis:

- `invalid_target`: citizenid invalido ou player inexistente.
- `invalid_org`: organizacao invalida.
- `not_member`: alvo nao e membro ativo da org.
- `forbidden`: autor sem permissao.
- `self_action`: autor tentando alterar o proprio cargo.
- `target_higher_or_equal`: cargo do alvo e igual ou superior ao autor.
- `promotion_above_actor`: promocao colocaria o alvo em cargo igual ou superior ao autor.
- `max_grade`: alvo ja esta na maior grade real.
- `min_grade`: alvo ja esta na menor grade real.
- `protected_target`: alvo esta em cargo protegido e o autor nao e owner/staff.
- `grade_not_found`: cargo atual nao foi encontrado.

Validacoes server-side:

- target deve existir e ser membro ativo da org.
- autor precisa ser owner, staff autorizado ou capability especifica.
- promover usa `members.promote` ou fallback temporario `manage.members`.
- rebaixar usa `members.demote` ou fallback temporario `manage.members`.
- a NUI nao escolhe grade; o core calcula a proxima/anterior grade pela lista real `mz_org_grades`.
- membro comum so altera cargo abaixo do seu.
- membro comum nao promove target para cargo igual ou superior ao proprio.
- owner/staff podem ignorar regra de hierarquia, mas self action continua bloqueada.
- existe rate limit simples no `mz_org` para evitar spam.
- o `mz_core` registra auditoria de sucesso e tentativas bloqueadas com `MZLogService.createDetailed`.

Nao foram criadas nesta etapa: escolha manual de grade, editar cargo, editar permissao, criar/deletar cargo ou qualquer acao financeira.

### Remover membro

`members:remove` remove um membro ativo da organizacao por `citizenid`.

Payload aceito pela NUI:

```lua
{
  orgCode = "police",
  citizenid = "ABC123"
}
```

O `source` do autor nunca vem do frontend. O `mz_org` usa o `source` real do evento server-side e chama:

```lua
exports['mz_core']:RemoveOrgMember(source, orgCode, targetCitizenId)
```

Resposta de sucesso:

```lua
{
  ok = true,
  data = {
    orgCode = "police",
    targetCitizenId = "ABC123",
    removed = true
  }
}
```

Erros possiveis:

- `invalid_target`: citizenid invalido ou player inexistente.
- `invalid_org`: organizacao invalida.
- `not_member`: alvo nao e membro ativo da org.
- `forbidden`: autor sem permissao.
- `self_remove`: autor tentando remover a si mesmo.
- `target_higher_or_equal`: cargo do alvo e igual ou superior ao autor.
- `protected_target`: alvo esta na grade maxima/protegida e o autor nao e owner.

Validacoes server-side:

- target deve existir e ser membro ativo da org.
- autor precisa ser owner, staff autorizado ou capability de remocao.
- a ordem de capability e `members.remove` futura, `members.kick` atual e `manage.members` como fallback de gestao.
- owner pode remover cargo protegido, mas nao pode remover a si mesmo.
- staff pode remover, exceto self e cargo protegido.
- membro da org so pode remover cargo abaixo do seu.
- existe rate limit simples no `mz_org` para evitar spam.
- o `mz_core` registra auditoria de sucesso e tentativas bloqueadas com `MZLogService.createDetailed`.

Nao foram criadas nesta etapa: editar cargo, editar permissao, escolher grade manualmente ou remocao offline.

## Comandos

- `/painel` / `/mzorg`: hub.
- `/org`: painel legal.
- `/gang`: painel ilegal.
- `/staff`: painel staff.
- `/vip`: painel VIP.
- `/business`: painel empresa.
- `/government`: painel governo.
- `/event`: painel eventos.

Comandos apenas definem o modo visual. Eles não concedem permissão.

## Ações futuras

Antes de qualquer mutação, validar:

- `source` real.
- org existente.
- membership, exceto owner autorizado.
- capability com `CanOrg`.
- payload sanitizado.
- rate limit.
- logs/auditoria.
