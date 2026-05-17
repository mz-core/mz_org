# MZ_ORG - Contrato com MZ_CORE

O `mz_org` é interface NUI. O `mz_core` é a fonte real de dados, permissões, organizações, membros, contas e logs.

## Regras

- O frontend nunca decide permissão real.
- O `source` confiável é sempre o `source` server-side.
- O frontend não envia `isOwner`, `source`, `permissions` ou `capabilities` como verdade.
- Ações futuras sempre devem chamar validação no server antes de executar.

O MVP oculta detalhes tecnicos brutos na UI normal; CitizenID deve aparecer mascarado em listas.

## Capabilities revisadas

Catalogo oficial usado pelo `mz_org`/`mz_core`:

- Org geral: `org.view`.
- Membros: `members.view`, `members.invite`, `members.remove`, `members.promote`, `members.demote`, `members.set_leader`, `manage.members`.
- Banco: `account.view`, `account.deposit`, `account.withdraw`, `account.manage`.
- Metas: `goals.view`, `goals.manage`.
- Recrutamento: `recruitment.view`, `recruitment.manage`.
- Logs: `logs.view`.
- Staff/admin: `staff.panel.open`, `staff.orgs.view`, `staff.orgs.manage`, `staff.orgs.create`, `staff.orgs.set_leader`, `staff.members.invite`, `staff.members.remove`, `staff.members.promote`, `staff.members.demote`, `staff.staff.manage`, `staff.logs.view`.

Aliases legados mantidos por compatibilidade:

- `members.kick` continua fallback de `members.remove`.
- `manage.goals` continua fallback de `goals.manage`.
- `manage.account` continua fallback de `account.manage`.
- `manage.permissions` continua usado para consulta do modelo de acesso/cargos.

Regras importantes:

- `staff.panel.open` abre/identifica o painel staff, mas nao autoriza operacoes de membros, banco, metas ou lideranca por si so.
- `staff.orgs.view` permite consulta administrativa de orgs.
- `staff.orgs.manage` permite gestao comum, mas nao substitui `staff.orgs.set_leader`.
- Cargo maximo/top grade exige owner ACE `group.mz_owner`, `members.set_leader` ou `staff.orgs.set_leader`.

## Exports usados do `mz_core`

- `HasGlobalPermission(source, permission)`
- `GetPlayerOrgContext(source)`
- `CanOrg(source, orgCode, capability)`
- `ListOrgs()`
- `GetOrgByCode(orgCode)`
- `CreateOrgFromTemplate(source, payload)`
- `ListOrgMembers(source, orgCode)`
- `ListLogs(source, filters)`
- `GetOrgAccount(source, orgCode)`
- `DepositOrgAccount(source, orgCode, amount, reason)`
- `WithdrawOrgAccount(source, orgCode, amount, reason)`
- `ListOrgAccountTransactions(source, orgCode, filters)`
- `GetOrgAccessModel(source, orgCode)`
- `InviteOrgMember(source, orgCode, targetSource, options)`
- `InviteOrgMemberByCitizenId(source, orgCode, targetCitizenId, options)`
- `RemoveOrgMember(source, orgCode, targetCitizenId)`
- `PromoteOrgMemberSecure(source, orgCode, targetCitizenId)`
- `DemoteOrgMemberSecure(source, orgCode, targetCitizenId)`
- `SetOrgLeaderByCitizenId(source, orgCode, targetCitizenId, options)`
- `ListOrgGoals(source, filters)`
- `GetOrgGoal(source, goalId)`
- `CreateOrgGoal(source, orgCode, payload)`
- `CreateOrgRecruitment(source, orgCode, payload)`
- `ListOrgRecruitment(source, orgCode, filters)`
- `GetOrgRecruitment(source, recruitmentId)`
- `ApproveOrgRecruitment(source, recruitmentId, options)`
- `RejectOrgRecruitment(source, recruitmentId, reason)`
- `CancelOrgRecruitment(source, recruitmentId, reason)`

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
- `orgs:createFromTemplate`
- `members:list`
- `logs:list`
- `org-bank:get`
- `org-bank:transactions`
- `org-bank:deposit`
- `org-bank:withdraw`
- `recruitment:list`
- `recruitment:get`
- `recruitment:create`
- `recruitment:approve`
- `recruitment:reject`
- `recruitment:cancel`
- `goals:list`
- `goals:get`
- `goals:create`
- `org-access:get`
- `members:invite`
- `members:remove`
- `members:promote`
- `members:demote`
- `members:setLeader`

### Staff dashboard, criar org e definir lider

`/staff` possui um dashboard seguro/read-only com abas internas:

- `Visao geral`: metricas e resumo sem atalhos duplicados.
- `Organizacoes`: usa `orgs:list`, pode abrir `Ver detalhes` read-only e pode abrir o modal `Criar organizacao` para owner/`staff.orgs.create`.
- `Logs`: usa `logs:list`.
- `Auditoria`: filtra localmente eventos sensiveis dentro dos logs recentes.
- `Acoes administrativas`: mantem apenas a action real `Definir lider` e mostra cards bloqueados para fases futuras.

O dashboard reutiliza services existentes para leitura. A unica nova escrita desta fase e `orgs:createFromTemplate`, restrita a templates server-side. Nao ha CRUD global livre de orgs, gestao de staff, editor de cargos/permissoes, exclusao de org ou acoes financeiras globais.

#### Criar organizacao por template

Callback NUI:

```lua
orgs:createFromTemplate {
  type = "gang",
  code = "mafia_norte",
  name = "Mafia Norte",
  hasSalary = false,
  hasSharedAccount = true,
  hasStorage = true,
  reason = "opcional"
}
```

Export usado:

```lua
exports['mz_core']:CreateOrgFromTemplate(source, payload)
```

Regras:

- exige owner ACE `group.mz_owner` ou capability `staff.orgs.create`;
- `staff.panel.open`, `staff.orgs.view` e `staff.orgs.manage` sozinhos nao criam org;
- tipos permitidos: `job`, `gang`, `business`, `government`, `vip`, `event`;
- `staff` nao e criado nesta fase;
- a NUI nao envia grades nem permissoes;
- o core normaliza `code`, valida duplicidade, escolhe template server-side, cria org, grades padrao, permissoes padrao e conta compartilhada quando aplicavel;
- logs: `org.create` e `org.create.blocked`.

`staff.orgs.view` agora tambem permite abrir o modulo Staff para consulta. Isso nao concede escrita: criar org exige `staff.orgs.create` e definir lider exige `staff.orgs.set_leader`.

As abas do Staff sao read-only, exceto `Criar organizacao` por template e `Definir lider`. Cards bloqueados nao disparam callback.

#### Detalhes da organizacao no Staff

`/staff > Organizacoes > Ver detalhes` nao cria callback agregado novo. A subview reaproveita callbacks existentes de leitura por `orgCode`:

- `orgs:get`
- `org-access:get`
- `members:list`
- `org-bank:get`
- `org-bank:transactions`
- `goals:list`
- `recruitment:list`
- `logs:list`

Permissoes de consulta aceitas para essa visao:

- owner ACE `group.mz_owner`;
- `staff.orgs.view`;
- `staff.orgs.manage`;
- `staff.orgs.create`;
- `staff.orgs.set_leader`.

A visao e read-only e mostra resumo, cargos, membros, banco, metas, recrutamento e logs recentes sem expor payload tecnico bruto. CitizenID aparece mascarado em listas.

#### Definir lider

Callback NUI:

```lua
members:setLeader {
  orgCode = "mafia",
  citizenid = "VKWR5Y9Y",
  reason = "opcional"
}
```

Export usado:

```lua
exports['mz_core']:SetOrgLeaderByCitizenId(source, orgCode, targetCitizenId, {
  reason = "opcional"
})
```

Regras:

- a NUI envia somente `orgCode`, `citizenid` e `reason`;
- o `source` confiavel e o `source` real do evento/server;
- o core calcula a top grade real como a maior `level` em `mz_org_grades`;
- se o alvo ja for membro ativo da org, o core atualiza a grade para top grade;
- se o alvo nao for membro ativo, o core adiciona o player na top grade;
- funciona com alvo offline se o `citizenid` existir em `mz_players`;
- exige owner ACE `group.mz_owner` ou `staff.orgs.set_leader`;
- `staff.panel.open`, `staff.orgs.view` e `staff.orgs.manage` sem `staff.orgs.set_leader` nao autorizam a acao;
- esta fase mantem apenas essa action real no `/staff`; o restante do dashboard e read-only ou bloqueado para fase futura.

Erros esperados:

- `invalid_org`
- `invalid_target`
- `target_not_found`
- `forbidden`
- `top_grade_not_found`
- `set_leader_failed`
- `rate_limited`

Logs:

- sucesso: `org.member.set_leader`;
- bloqueio: `org.member.set_leader.blocked`.

### Recrutamento/candidaturas

Persistencia no core: tabela `mz_org_recruitment`, autocriada pelo `mz_core/server/prepare.lua`.

Status suportados:

- `pending`
- `approved`
- `rejected`
- `cancelled`

Callbacks:

```lua
-- listar candidaturas da org ativa
recruitment:list {
  orgCode = "police",
  status = "pending", -- opcional
  search = "VKWR", -- opcional
  limit = 50,
  offset = 0
}

-- criar registro de candidatura
recruitment:create {
  orgCode = "police",
  citizenid = "VKWR5Y9Y",
  desiredGradeLevel = 1, -- opcional
  note = "opcional"
}

-- aprovar
recruitment:approve {
  id = 123,
  gradeLevel = 1, -- opcional; sobrescreve a grade desejada
  note = "opcional"
}

-- recusar / arquivar
recruitment:reject { id = 123, reason = "opcional" }
recruitment:cancel { id = 123, reason = "opcional" }
```

Permissoes:

- visualizar: owner ACE ou `CanOrg(source, orgCode, 'recruitment.view'|'recruitment.manage'|'members.invite'|'manage.members')`;
- criar/aprovar/recusar/arquivar: owner ACE ou `CanOrg(source, orgCode, 'recruitment.manage'|'members.invite'|'manage.members')`;
- `staff.panel.open` nao concede poder operacional;
- top grade/lideranca continua exigindo owner ACE, `members.set_leader` ou `staff.orgs.set_leader`.

Regras de seguranca:

- o `source` usado e sempre o `source` real do evento server;
- a NUI nao envia actor, cargo real, permissao real nem `source` confiavel;
- o identificador do candidato e `citizenid`;
- criar candidatura valida se o `citizenid` existe em `mz_players`;
- apenas uma candidatura `pending` por `orgCode + citizenid`;
- aprovar chama o fluxo real de adicao por `citizenid`, cria membro na org ativa e muda o status para `approved`;
- recusar muda o status para `rejected`;
- arquivar muda o status para `cancelled`;
- nao existe aceite pelo player nesta fase.

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
- deposito exige `account.deposit` ou `account.manage` (`manage.account` segue como alias legado);
- saque exige `account.withdraw` ou `account.manage` (`manage.account` segue como alias legado);
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

Campos retornados:

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
  desiredGradeLevel = 1,
  desiredGradeCode = "recruta"
}
```

Permissao server-side:

- owner com `group.mz_owner`;
- membro/lider autorizado por `CanOrg(source, orgCode, 'recruitment.view')`, `CanOrg(source, orgCode, 'recruitment.manage')`, `CanOrg(source, orgCode, 'members.invite')` ou `CanOrg(source, orgCode, 'manage.members')`;
- staff global sem permissao na org ativa nao aprova nem recusa recrutamento;
- player comum sem `orgCode` nao tem fluxo publico nesta fase.

Aprovar, recusar e arquivar usam os exports reais do `mz_core`; aprovar adiciona o candidato como membro real da org ativa.

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
- staff com `staff.orgs.view` ou `staff.orgs.manage`;
- membro/lider autorizado por `CanOrg(source, orgCode, 'goals.view')`, `CanOrg(source, orgCode, 'goals.manage')` ou fallback `CanOrg(source, orgCode, 'org.view')`.

Editar, deletar, concluir, alterar progresso, ranking, recompensas e logs de metas continuam pendentes e precisam de validacao server-side.

### Progresso e conclusao de metas - plano futuro

Ainda nao foi implementado callback de progresso/conclusao. Opcoes recomendadas:

- Progresso manual: lider/staff autorizado atualiza `progress` por callback futuro `goals:updateProgress`, com validacao por `source`, org ativa, capability e logs.
- Progresso por membro: cada membro registra contribuicoes individuais em tabela propria, permitindo ranking e auditoria por pessoa.
- Progresso automatico: outros resources chamam export/event seguro no `mz_core`, por exemplo prisao efetuada, patrulha iniciada ou atendimento concluido.

Recomendacao de MVP:

1. Comecar com progresso manual seguro.
2. Depois adicionar contribuicoes por membro.
3. Por ultimo integrar progresso automatico por exports/events.

Conclusao de meta deve ser calculada no servidor quando `progress >= target` ou acionada por staff/lider autorizado, sempre com log de auditoria e sem recompensa/pagamento automatico nesta fase.

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
- staff com `staff.orgs.view` ou `staff.orgs.manage`;
- membro/lider autorizado por `CanOrg(source, orgCode, 'manage.permissions')`, `CanOrg(source, orgCode, 'manage.members')` ou fallback `CanOrg(source, orgCode, 'org.view')`.

Criar, editar, deletar cargos, alterar capability, escolher grade manualmente fora do fluxo de convite e aplicar overrides continuam pendentes.

### Convidar/adicionar membro

`members:invite` e a primeira acao real do painel.

Payload aceito pela NUI:

```lua
{
  orgCode = "police",
  citizenid = "ABC123",
  gradeLevel = 1,
  gradeCode = "recruta"
}
```

`citizenid` e o identificador fixo principal do `mz_core` nesta fase. `gradeLevel` e `gradeCode` sao opcionais. Se nenhum deles for enviado, o core mantem o comportamento original e usa a menor grade segura da organizacao.

O `source` do autor nunca vem do frontend. O `mz_org` usa o `source` real do evento server-side e chama:

```lua
exports['mz_core']:InviteOrgMemberByCitizenId(source, orgCode, targetCitizenId, options)
```

O callback ainda aceita `targetId` apenas como fallback de debug quando `Config.Debug` esta ativo no `mz_org`; a UI normal nao envia source/ID online.

Resposta de sucesso:

```lua
{
  ok = true,
  data = {
    orgCode = "police",
    targetCitizenId = "ABC123",
    grade = 1,
    gradeCode = "recruta",
    gradeName = "Recruta"
  }
}
```

Erros possiveis:

- `invalid_target`: citizenid invalido.
- `target_not_found`: citizenid nao encontrado em `mz_players`.
- `invalid_org`: organizacao invalida.
- `already_member`: player ja e membro ativo da org.
- `forbidden`: autor sem permissao.
- `self_target`: autor tentando convidar a si mesmo.
- `invalid_grade`: grade enviada nao existe na org ou payload de grade invalido.
- `grade_not_allowed`: autor nao pode convidar para a grade escolhida.
- `leader_permission_required`: convite para cargo maximo exige permissao de lideranca.
- `grade_not_found`: org sem grade inicial segura.

Validacoes server-side:

- `targetCitizenId` deve existir em `mz_players`.
- `targetCitizenId` nao pode ser o citizenid do autor.
- org deve existir.
- autor precisa ser owner, staff autorizado ou `CanOrg(source, orgCode, 'members.invite')`.
- se grade nao for enviada, grade inicial e a menor grade real da org.
- se grade for enviada, ela precisa existir na propria org.
- top grade e a grade com maior `level` da org.
- convite direto para top grade exige owner ACE `group.mz_owner`, `members.set_leader` ou `staff.orgs.set_leader`.
- `staff.panel.open` nao autoriza convite para lideranca/cargo maximo.
- membro comum so pode escolher grade abaixo da propria.
- a NUI nao envia grade livre; o seletor visual usa `org-access:get`, mas o server valida novamente.
- existe rate limit simples no `mz_org` para evitar spam.
- o `mz_core` registra auditoria de sucesso e tentativas bloqueadas com `MZLogService.createDetailed`, incluindo grade inicial, code e nome quando disponiveis.

O convite por `citizenid` consegue adicionar players offline desde que ja exista registro em `mz_players`; nao foi criado fluxo persistido de convite pendente/aceite. Nao foram criadas nesta etapa: editar cargo, editar permissao ou input livre de grade. Remocao, promocao e rebaixamento ficam documentados nas secoes proprias.

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
- `leader_permission_required`: promocao/rebaixamento envolvendo cargo maximo exige permissao de lideranca.
- `max_grade`: alvo ja esta na maior grade real.
- `min_grade`: alvo ja esta na menor grade real.
- `grade_not_found`: cargo atual nao foi encontrado.

Validacoes server-side:

- target deve existir e ser membro ativo da org.
- target nao pode ser o proprio autor; nesse caso o core retorna `self_action`.
- autor precisa ser owner, staff autorizado ou capability especifica.
- promover usa `members.promote` ou fallback temporario `manage.members`.
- rebaixar usa `members.demote` ou fallback temporario `manage.members`.
- a NUI nao escolhe grade; o core calcula a proxima/anterior grade pela lista real `mz_org_grades`.
- top grade e a grade com maior `level` da org.
- promover alguem para top grade exige owner ACE `group.mz_owner`, `members.set_leader` ou `staff.orgs.set_leader`.
- rebaixar alguem que esta em top grade exige owner ACE `group.mz_owner`, `members.set_leader` ou `staff.orgs.set_leader`.
- membro comum so altera cargo abaixo do seu.
- membro comum nao promove target para cargo igual ou superior ao proprio.
- staff com `staff.orgs.manage` pode gerenciar membros, mas nao altera lideranca/top grade sem `staff.orgs.set_leader`.
- `staff.panel.open` nao autoriza mutacao de lideranca.
- owner pode tudo, mas self action continua bloqueada.
- existe rate limit simples no `mz_org` para evitar spam.
- o `mz_core` registra auditoria de sucesso e tentativas bloqueadas com `MZLogService.createDetailed`.
- a UI oculta os botoes de promover/rebaixar/remover na linha do proprio usuario e mostra badge `Voce`; se a acao for forcada, o server continua bloqueando e a UI limpa o loading no `finally`.

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
- `leader_permission_required`: remover cargo maximo exige permissao de lideranca.
- `protected_target`: alvo esta na grade maxima/protegida e o autor nao tem permissao adequada.

Validacoes server-side:

- target deve existir e ser membro ativo da org.
- target nao pode ser o proprio autor; nesse caso o core retorna `self_remove`.
- autor precisa ser owner, staff autorizado ou capability de remocao.
- a ordem de capability e `members.remove` futura, `members.kick` atual e `manage.members` como fallback de gestao.
- remover top grade exige owner ACE `group.mz_owner`, `members.set_leader` ou `staff.orgs.set_leader`.
- staff com `staff.orgs.manage` pode remover membros, mas nao remove top grade sem `staff.orgs.set_leader`.
- `staff.panel.open` nao autoriza mutacao de lideranca.
- owner pode remover cargo protegido, mas nao pode remover a si mesmo.
- membro da org so pode remover cargo abaixo do seu.
- existe rate limit simples no `mz_org` para evitar spam.
- o `mz_core` registra auditoria de sucesso e tentativas bloqueadas com `MZLogService.createDetailed`.
- a UI oculta o botao de remover na linha do proprio usuario; se a acao for forcada, o server continua bloqueando e a UI limpa o loading no `finally`.

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
