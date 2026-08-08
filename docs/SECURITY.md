# MZ_ORG - Segurança

> Fase 0 implementada em 2026-07-21. Runtime FiveM ainda precisa do checklist em `PHASE_0_SECURITY_TEST_CHECKLIST.md`.

Este documento define as regras de seguranca para o painel `mz_org`.

## Principio central

Frontend nao e seguranca.

A NUI pode ser inspecionada, manipulada e chamada manualmente. Qualquer player pode tentar disparar callbacks, adulterar payloads ou simular estados visuais. Portanto:

- Botao escondido nao bloqueia exploit.
- Sidebar filtrada nao concede nem remove permissao real.
- Comando que abre modulo nao concede permissao.
- `initialModule` e apenas preferencia visual.
- Dados enviados pelo frontend nunca devem ser tratados como verdade.

## Fonte de verdade

O `mz_core` deve ser a fonte real para:

- Player/session.
- Owner e permissoes globais.
- Orgs do player.
- Membros.
- Grades/cargos.
- Capabilities/permissoes.
- Conta/banco da org.
- Logs/auditoria.

O painel nunca deve aceitar `isOwner`, `permissions`, `capabilities`, `grade`, `orgs`, `source` ou `citizenid` enviados pelo frontend como verdade. A sessao deve vir do server/core.

Permissoes `staff.*` sao globais. Elas nunca sao capabilities de uma organizacao e nunca podem ser resolvidas por cargo, heranca, seed ou `CanOrg`.

## Permissao maxima

`group.mz_owner` e a permissao maxima para acoes criticas. Ela deve ser validada no server:

```lua
IsPlayerAceAllowed(source, 'group.mz_owner')
```

Mesmo owner deve gerar log/auditoria ao executar acao sensivel.

## Base para acoes de organizacao

Toda acao de organizacao deve usar uma validacao server-side equivalente a:

```lua
exports['mz_core']:CanOrg(source, orgCode, capability)
```

Essa validacao deve confirmar:

- `source` real do callback/evento.
- Player carregado.
- Org existente.
- Vinculo do player com a org, exceto owner.
- Grade/cargo ativo.
- Capability exigida.
- Restricoes de org protegida/trancada.
- Acesso privado de gang.

## Acoes sensiveis

Banco, cofre, cargos, permissoes, recrutamento, membros e logs exigem validacao forte.

Validacoes minimas:

- Nao confiar em valor de dinheiro enviado pelo frontend sem normalizar.
- Rejeitar valor negativo.
- Rejeitar zero quando zero nao fizer sentido.
- Bloquear saque acima do saldo.
- Bloquear alteracao de cargo igual ou superior sem permissao maxima.
- Bloquear player promovendo a si mesmo.
- Bloquear staff comum alterando dono/lider protegido.
- Bloquear player sem org tentando acessar gang privada.
- Bloquear lider de gang tentando acessar outra gang.
- Bloquear staff sem owner tentando mexer em org protegida.

## Auditoria

Acoes sensiveis devem gerar log em dois casos:

- Acao permitida e executada.
- Tentativa bloqueada.

O log deve conter ator, alvo, org, capability exigida, resultado e motivo da negacao quando houver.

Promocao e rebaixamento sao concluidos somente quando a mudanca de grade e o INSERT de auditoria confirmam a mesma transacao. Sucesso sem `auditId` e invalido.

## Comandos

Os comandos `/mzorg`, `/painel`, `/org`, `/gang`, `/staff`, `/vip`, `/business`, `/government` e `/event` apenas abrem a mesma NUI em um modo visual desejado. Eles nao concedem permissao.

O frontend pode cair para o primeiro modulo permitido quando o modulo inicial for negado, mas qualquer callback futuro deve repetir a validacao no server.

## Sessao

A sessao enviada ao frontend deve ser montada no server a partir do `mz_core`.

A sessao pode conter dados para UX, como modulos liberados e capabilities visuais, mas qualquer callback deve recomputar permissao real no server antes de executar acao.

A sessao V2 separa `global`, `organizations` e `staff`, possui `revision` opaca e resolve entrada por `ResolvePanelEntry`. `modules` existe apenas como compatibilidade derivada.

## Logs estruturais

Logs organizacionais usam coluna `org_code` e igualdade exata. Busca em mensagem, target ou JSON nunca delimita organizacao. Consulta global e consulta de org sao contratos separados e nao possuem fallback entre si.

## Organizacoes arquivadas

Organizacao arquivada nao entra no contexto pessoal e bloqueia banco, membros, cargos, metas, recrutamento, lideranca e demais mutations. Staff com `staff.orgs.view` ve somente metadados. No Staff Menu do Lote 4, arquivamento exige `staff.orgs.archive` e reativacao exige `staff.orgs.restore`; `staff.orgs.manage` permanece apenas como compatibilidade das rotas legadas e nao amplia silenciosamente o menu novo.
