# Checklist runtime — Lote 6D

Estado desta execução: **VIP APROVADO PELO OPERADOR; LOTE 6D GERAL PARCIAL**.

Em 2026-07-25, o operador informou que `/org` abriu corretamente para o líder da organização `mafia` e que o happy path acompanhado da transferência passou. Também informou que atribuiu VIP pelo Staff, abriu `/vip`, confirmou a ausência de liderança/autogestão e aprovou o diagnóstico negativo de capabilities executado por `/mzorg_test vip`. O agente não recebeu o log integral dessa execução e não executou nem observou os cenários restantes. FXServer, MySQL, Docker, VPS, banco local e staging não foram iniciados nem acessados por esta validação estática.

## Preparação acompanhada

- [ ] Usar ambiente local/staging descartável, nunca produção.
- [ ] Confirmar backup verificável do banco de teste.
- [ ] Preparar organização exclusiva com pelo menos três cargos ativos.
- [ ] Preparar líder atual, sucessor e membro inferior com identidades descartáveis.
- [ ] Confirmar apenas um membro ativo/não expirado no cargo superior.
- [ ] Habilitar `Config.Interface.organizationLeadershipTransfer = true` somente no ambiente de teste.
- [ ] Reiniciar `mz_core`, `mz_menu` e `mz_org` de forma controlada.
- [ ] Manter o frontend legado disponível para regressão.

## Gate e autorização

- [x] VIP não exibe ação de liderança no `/vip` nem no detalhe Staff. Confirmado pelo operador em 2026-07-25.
- [x] `CanOrg(vip, members.set_leader)` retorna `false`. Aprovado pelo operador via `/mzorg_test vip` em 2026-07-25; log integral não anexado.
- [x] `CanOrg(vip, members.invite|remove|promote|demote|manage.members)` retorna `false`. Aprovado pelo operador via `/mzorg_test vip` em 2026-07-25; log integral não anexado.
- [ ] Capability futura `vip.*` explicitamente concedida continua efetiva.
- [ ] `SetOrgLeaderByCitizenId` e `TransferOrganizationLeadership` retornam `leadership_not_supported` para VIP.
- [ ] Remoção administrativa de `members.set_leader` legada em VIP continua possível sem concedê-la novamente.
- [ ] Gate desabilitado oculta e recusa a ação.
- [ ] Gate habilitado sem `members.set_leader` recusa a ação.
- [ ] Owner/ACE/`staff.orgs.set_leader` sem capability organizacional não autoriza `/org`.
- [ ] `members.set_leader` sem membership atual não autoriza.
- [ ] Organização arquivada falha fechada.

## Alvo e hierarquia

- [ ] Self-transfer é recusada.
- [ ] CitizenID inexistente é recusado.
- [ ] Não membro da organização é recusado.
- [ ] Membro inativo é recusado.
- [ ] Membership expirada é recusada.
- [ ] Cargo inativo do alvo é recusado.
- [ ] Alvo no cargo superior é recusado.
- [ ] Organização sem cargo sucessor é recusada.

## Estado de liderança

- [ ] Ator fora do cargo superior é recusado.
- [ ] Zero membros no cargo superior falha fechado.
- [ ] Dois ou mais membros no cargo superior falham fechado.
- [ ] Nenhum reparo automático ou rebaixamento em massa ocorre.

## Sucesso transacional

- [ ] Informar motivo válido e confirmar a ação.
- [ ] Novo líder recebe o maior cargo.
- [ ] Líder anterior recebe o cargo ativo imediatamente inferior.
- [ ] Nenhum outro membro muda de cargo.
- [ ] Primary membership dos dois jogadores permanece igual.
- [ ] `mz_orgs.revision` incrementa uma vez.
- [ ] Um único log `org.member.transfer_leadership` é criado.
- [ ] Resposta contém `auditId`, líderes e cargos corretos.
- [ ] Snapshots dos dois jogadores online são atualizados.
- [ ] Sessões afetadas são invalidadas e `/org` reabre com dados atuais.

## Falha e rollback

- [ ] Induzir falha na auditoria em fixture descartável.
- [ ] Confirmar que nenhum dos dois cargos mudou.
- [ ] Induzir conflito de revision.
- [ ] Confirmar ausência de mudança parcial e de log de sucesso.
- [ ] Disparar duas solicitações concorrentes.
- [ ] Confirmar um único commit.

## Contexto

- [ ] Enviar `orgCode` divergente.
- [ ] Enviar `contextKey` divergente.
- [ ] Enviar módulo divergente.
- [ ] Reutilizar revision antiga.
- [ ] Trocar rapidamente da organização A para B.
- [ ] Confirmar descarte de resposta atrasada de A.

## Compatibilidade

- [ ] `SetOrgLeaderByCitizenId` continua operando no Staff Menu para tipos com liderança.
- [ ] Transferência Staff não ganha regras do `/org`.
- [ ] Frontend legado continua abrindo pelas flags existentes.
- [ ] `mz_menu` restaura o tema após fechar.
- [ ] Consumidor `mz_houses` continua funcional.

## Registro

Para cada cenário, registrar data/hora, ambiente, configuração, identidades anonimizadas, esperado, observado, PASS/FAIL, evidência e cleanup.

Não marcar esta checklist como aprovada com base em harness ou análise estática.
