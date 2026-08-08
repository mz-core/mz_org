# Contrato de transferência de liderança organizacional — Lote 6D

## Escopo

O menu `/org` pode transferir a liderança entre dois membros atuais da mesma organização. A funcionalidade é opt-in e inicia desabilitada:

```lua
Config.Interface.organizationLeadershipTransfer = false
```

O gate não concede autorização. Quando habilitado, o ator ainda precisa da capability organizacional exata `members.set_leader`.

O contrato de liderança existe somente para os tipos:

- `job`;
- `gang`;
- `business`;
- `government`;
- `event`.

`vip` representa níveis de privilégio e não possui líder. Sua membership e seu nível são administrados pelo Staff, não pelos próprios VIPs. `staff` também não usa este contrato. Tipo ausente ou desconhecido falha fechado.

## Separação do contrato Staff

O export administrativo `SetOrgLeaderByCitizenId` permanece separado. Ele continua atendendo ao Staff com `staff.orgs.set_leader` e pode promover ou adicionar um cidadão somente em tipos que suportam liderança. Para VIP, retorna `leadership_not_supported`.

A transferência organizacional usa um contrato separado:

```lua
exports['mz_core']:TransferOrganizationLeadership(
  source,
  orgCode,
  targetCitizenId,
  {
    organizationRevision = 7,
    reason = 'Sucessão aprovada'
  }
)
```

Evento contextual do `mz_org`:

```text
mz_org:server:organizationTransferLeadership
```

Nenhuma permissão `staff.*`, ACE ou owner autoriza esse caminho. O `mz_core` consulta membership e capabilities organizacionais diretamente no banco.

## Precondições

- organização existente, ativa e na revision esperada;
- tipo da organização com suporte explícito a liderança;
- ator carregado, membro ativo e não expirado;
- cargo do ator ativo e com `members.set_leader` efetiva;
- ator ocupando sozinho o maior cargo ativo;
- alvo diferente do ator;
- alvo existente, membro ativo e não expirado da mesma organização;
- cargo do alvo ativo e estritamente inferior;
- existência de um cargo sucessor ativo imediatamente abaixo do maior cargo;
- motivo textual obrigatório.

Zero ou múltiplos membros no maior cargo produzem falha fechada. O reparo permanece responsabilidade do Staff.

## Unidade transacional

`transferOrganizationLeadershipWithAudit` executa uma única transação:

1. reserva o `auditId` e insere a auditoria na transação;
2. executa uma assertion SQL das precondições; falha força colisão do mesmo `auditId`;
3. move o líder anterior para o cargo sucessor e o alvo para o maior cargo no mesmo `UPDATE`;
4. incrementa `mz_orgs.revision`;
5. executa uma assertion SQL do estado final;
6. força erro de unicidade e rollback integral se qualquer assertion falhar.

Depois do commit, o repository confirma:

- cargo final do líder anterior;
- cargo final do novo líder;
- revision incrementada;
- presença do `auditId`.

A organização primária de cada jogador não é alterada. No domínio atual, liderança e organização primária são conceitos independentes. O comportamento administrativo antigo continua separado.

## Auditoria

Ação:

```text
org.member.transfer_leadership
```

O registro contém:

- ator e alvo;
- organização;
- revision anterior e posterior;
- líder anterior e seu novo cargo;
- novo líder e seu cargo anterior;
- cargo superior;
- cargo sucessor;
- motivo;
- `auditId`;
- indicação de que primary membership não foi alterada.

Sucesso sem `auditId` é inválido.

## Resposta segura

```lua
{
  action = 'transfer_leadership',
  auditId = 'leadership:...',
  organizationRevision = 8,
  previousLeader = {
    citizenid = 'CID_OLD',
    name = 'Líder anterior',
    fromGrade = { id = 3, level = 3, code = 'leader', name = 'Líder' },
    toGrade = { id = 2, level = 2, code = 'manager', name = 'Gerente' }
  },
  newLeader = {
    citizenid = 'CID_NEW',
    name = 'Novo líder',
    fromGrade = { id = 2, level = 2, code = 'manager', name = 'Gerente' },
    toGrade = { id = 3, level = 3, code = 'leader', name = 'Líder' }
  },
  topGrade = {},
  successorGrade = {},
  primaryMembershipChanged = false
}
```

## Erros estáveis

- `feature_disabled`;
- `leadership_not_supported`;
- `invalid_revision`;
- `organization_revision_conflict`;
- `invalid_reason`;
- `org_archived`;
- `not_member`;
- `forbidden`;
- `self_transfer`;
- `actor_grade_inactive`;
- `actor_not_leader`;
- `leader_state_invalid`;
- `multiple_leaders_detected`;
- `top_grade_not_found`;
- `successor_grade_not_found`;
- `target_not_found`;
- `target_not_active_member`;
- `target_grade_inactive`;
- `target_already_leader`;
- `target_higher_or_equal`;
- `audit_transaction_failed`;
- `rate_limited`;
- `operation_in_progress`.

## Concorrência e sessão

- `organizationRevision` é validada no `mz_org`, novamente no `mz_core` e dentro da transação;
- a revision é incrementada no commit;
- request simultâneo com o mesmo envelope é bloqueado por `IN_FLIGHT`;
- existe cooldown por ação;
- sessões da organização são invalidadas;
- snapshots dos dois jogadores online são recarregados;
- respostas antigas, cross-org ou de outro módulo continuam descartadas pelo request manager.

## Fora do escopo

- reparar automaticamente zero ou múltiplos líderes;
- adicionar não membro como líder;
- alterar primary membership;
- transferir por edição comum de cargo;
- gestão de cargos ou permissões Staff;
- converter níveis VIP em uma hierarquia de liderança;
- quick integrations;
- migrations ou novo schema;
- remoção do frontend legado.
