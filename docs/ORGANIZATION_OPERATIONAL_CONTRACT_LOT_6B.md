# Contrato operacional da organização — Lote 6B

> Nota histórica: a troca de liderança permaneceu fora deste contrato e foi implementada posteriormente no Lote 6D. Consulte `ORGANIZATION_LEADERSHIP_TRANSFER_CONTRACT_LOT_6D.md`.

## Escopo

O menu `/org` executa mutações de membros, conta, metas e recrutamento conforme capabilities efetivas do cargo atual. O caminho não utiliza permissões globais Staff.

## Autorização

Toda mutação exige:

1. envelope, módulo e organização coerentes;
2. sessão organizacional corrente;
3. organização ativa e vínculo atual;
4. feature efetiva;
5. `organizationRevision` corrente;
6. capability presente no snapshot oficial do cargo;
7. confirmação de `CanOrg` no servidor;
8. revalidação final pelo export oficial de `mz_core`.

Owner ou Staff não recebem uma ação no `/org` apenas por autorização global. O jogador precisa pertencer à organização e possuir a capability organizacional no snapshot resolvido.

## Matriz de ações

| Ação | Capabilities aceitas |
| --- | --- |
| Convidar membro | `members.invite`, `manage.members` |
| Remover membro | `members.remove`, `members.kick`, `manage.members` |
| Promover | `members.promote`, `manage.members` |
| Rebaixar | `members.demote`, `manage.members` |
| Depositar | `account.deposit`, `account.manage`, `manage.account` |
| Sacar | `account.withdraw`, `account.manage`, `manage.account` |
| Criar meta | `goals.manage`, `manage.goals` |
| Gerenciar recrutamento | `recruitment.manage`, `members.invite`, `manage.members` |

## Hierarquia

- O ator não altera o próprio cargo.
- Cargo igual ou superior é protegido.
- Convites só oferecem cargos inferiores no cliente; o servidor recalcula.
- Promoção não pode alcançar ou ultrapassar o cargo do ator.
- Promoção e rebaixamento exigem `auditId` transacional.
- Troca de liderança permanece no Staff Menu.

## Conta

O menu não calcula saldo. Depósito e saque consomem os exports oficiais, que executam a transferência entre banco pessoal e conta organizacional, registram transação e ledger.

Valores devem ser inteiros entre 1 e 100.000.000 e possuir motivo.

## Metas

Este lote permite criar meta manual. Alterar progresso, encerrar ou cancelar continua fora do contrato.

## Recrutamento

Permite criar, aprovar, rejeitar e cancelar registros. Antes de uma decisão, o `mz_org` consulta o registro e confirma que seu `orgCode` corresponde ao contexto atual.

## Concorrência

Após sucesso, sessões afetadas são invalidadas e o menu reabre. O mesmo request concorrente é recusado enquanto estiver em execução.

## Fora do escopo

- gestão de cargos por líderes;
- troca de liderança pelo `/org`;
- atribuição e cargos de Staff;
- alteração direta de progresso de metas;
- hard delete.
