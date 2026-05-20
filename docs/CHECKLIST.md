# MZ_ORG - Checklist

## Base

- [x] Resource separado `mz_org` dependente do `mz_core`.
- [x] NUI HTML/CSS/JS puro.
- [x] Sem Node/Vite/React na versao final.
- [x] `_v0_reference` removida da entrega atual.
- [x] `fxmanifest.lua` apontando para `web/index.html`.

## Comandos e modos

- [x] `/mzorg` abre hub geral.
- [x] `/painel` abre hub geral.
- [x] `/org` abre painel legal.
- [x] `/gang` abre painel ilegal.
- [x] `/staff` abre painel staff.
- [x] `/vip` abre painel VIP.
- [x] `/business` abre painel empresa.
- [x] `/government` abre painel governo.
- [x] `/event` abre painel eventos.

## Integracao com `mz_core`

- [x] Sessao real com `GetPlayerOrgContext`.
- [x] Permissao global com `HasGlobalPermission`.
- [x] Validacao por org com `CanOrg`.
- [x] Membros read-only com `ListOrgMembers`.
- [x] Logs read-only com `ListLogs`.
- [x] Banco read-only com `GetOrgAccount`.
- [x] Modelo de acesso read-only com `GetOrgAccessModel`.
- [x] Convite seguro por `citizenid` com `InviteOrgMemberByCitizenId`.
- [x] Recrutamento persistido com `mz_org_recruitment`.
- [x] Exports seguros de recrutamento no `mz_core`.

## Frontend read-only

- [x] Painel hub.
- [x] Painel legal.
- [x] Painel ilegal/gang.
- [x] Painel staff.
- [x] Placeholders VIP/business/government/event.
- [x] Orgs read-only.
- [x] Membros read-only.
- [x] Logs read-only.
- [x] Banco read-only.
- [x] Banco da organizacao com deposito, saque e extrato real.
- [x] Recrutamento real com criar, listar, aprovar, recusar e arquivar.
- [x] Metas read-only com fallback seguro.
- [x] Criar meta com validacao server-side.
- [x] Polimento UX da aba Metas com cards no topo, modal de criacao e lista full width.
- [x] Cargos/grades/capabilities read-only.
- [x] Convidar/adicionar membro por citizenid/passaporte com validacao server-side.
- [x] Selecionar grade inicial ao convidar com validacao server-side.
- [x] Remover membro com validacao server-side.
- [x] Promover/rebaixar membro com validacao server-side.
- [x] Auto-acao de membro bloqueada: UI oculta acoes no proprio usuario e server retorna `self_action`/`self_remove`.
- [x] Loading de acoes de membro limpo em erro/sucesso com `finally`.
- [x] Protecao de top grade/lideranca com `members.set_leader` e `staff.orgs.set_leader`.
- [x] `staff.panel.open` removido como autorizador de convite/promocao/remocao de lideranca.
- [x] `/staff` com acao minima para definir lider por `orgCode` e `citizenid`.
- [x] Export seguro `SetOrgLeaderByCitizenId` com top grade calculado no server.
- [x] `/staff` com criacao segura de org/faccao por template server-side.
- [x] Export seguro `CreateOrgFromTemplate` com capability `staff.orgs.create`.
- [x] Atalhos seguros duplicados do dashboard Staff compactados em favor das abas internas.
- [x] Auditoria/padronizacao de capabilities, seed e aliases legados.
- [x] Polimento visual/UX: dados tecnicos colapsados, capabilities traduzidas e listas mais limpas.
- [x] Navegacao por contexto com abas internas implementada para `/org` e `/gang`.
- [x] Header superior contextual destacando org/gang ativa e cargo, com abas internas sem titulo duplicado.
- [x] Auditoria de identidade, contexto, permissoes e seguranca documentada em `docs/SECURITY_CONTEXT_REVIEW.md`.
- [x] Analise do `/staff` realizada e documentada em `docs/STAFF_PANEL_REVIEW.md`.
- [x] Fase Staff 1 implementada: dashboard seguro/read-only com abas, orgs, logs, auditoria e acoes bloqueadas.
- [x] Staff Organizacoes com `Ver detalhes` read-only por orgCode.
- [x] Detalhe Staff mostra resumo, cargos, membros, banco, metas, recrutamento e logs sem editor.
- [x] `Definir lider` movido para `/staff > Organizacoes > Ver detalhes > Acoes`.
- [x] Formulario global de `Definir lider` com orgCode manual removido/compactado.
- [x] Staff Detalhe permite editar somente dados basicos da org com `staff.orgs.manage`.
- [x] Export seguro `UpdateOrgBasicInfo` e callback `orgs:updateBasic` para nome/status/flags.
- [x] Staff Detalhe Cargos permite criar/editar dados basicos de grades com `staff.orgs.manage`.
- [x] Exports seguros `CreateOrgGrade` e `UpdateOrgGradeBasic` sem editor livre de permissoes.
- [x] Arquivamento seguro de organizacao implementado sem DELETE fisico.
- [x] Desativacao/reativacao segura de cargo implementada com coluna `active`.
- [x] Cargo com membros e cargo maximo protegidos contra desativacao.
- [x] Editor controlado de permissoes por cargo implementado sem campo livre.
- [x] Allowlist server-side bloqueia capability fora do catalogo oficial.
- [x] `staff.*` bloqueado em org comum e `members.set_leader` protegido.
- [x] Revisao final do MVP: contexto, UX, detalhes tecnicos, empty states, loading e docs.

## Frontend HTML/CSS/JS modular

- [x] `script.js` reduzido para boot principal.
- [x] Core separado em `web/core/`.
- [x] Services read-only separados em `web/services/`.
- [x] Paineis registrados em `web/panels/`.
- [x] Documentado onde criar novos paineis e services.
- [x] Analise de navegacao/UX por contexto documentada em `docs/UX_NAVIGATION_PLAN.md`.

## Revisao e hardening

- [x] Callbacks NUI revisados.
- [x] Eventos server revisados para uso de `source` real.
- [x] Capabilities usadas pelo painel revisadas.
- [x] Sanitizacao de payloads de logs reforcada.
- [x] Plano de teste manual criado em `docs/TEST_PLAN.md`.
- [x] Plano de teste integrado do MVP criado em `docs/MVP_TEST_PLAN.md`.

## Pendente

- [ ] Testes reais em jogo seguindo `docs/MVP_TEST_PLAN.md`.
- [ ] Corrigir bugs encontrados durante testes reais.
- [ ] Replicar navegacao interna por abas para VIP, empresa, governo e eventos.
- [x] Refinar navegacao administrativa do Staff com dashboard seguro/read-only.
- [ ] Manter painel staff global completo como fase futura.
- [x] Editor controlado de permissoes por cargo.
- [ ] Editor livre de permissoes e permissoes globais por player continuam fase futura.
- [ ] Excluir cargos continua fase futura; desativacao segura ja existe.
- [ ] Excluir organizacao continua fase futura; arquivamento seguro ja existe.
- [x] Fase 1 seguranca: detalhes tecnicos brutos ocultos/desativados na UI normal.
- [ ] Fase futura seguranca: modo owner/debug explicito para detalhes tecnicos completos.
- [x] Fase 2 seguranca: migrar convite principal de source online para citizenid/passaporte.
- [x] Fase 3 seguranca: proteger top grade/lideranca com capability dedicada.
- [ ] Fase 4 seguranca: implementar hierarquia staff completa.
- [ ] Remocao futura de aliases legados (`members.kick`, `manage.goals`, `manage.account`) depois de migracao completa.
- [x] Fase 5 seguranca: implementar recrutamento/candidatura real persistido.
- [ ] Cofre/bau read-only.
- [ ] Garagem read-only.
- [x] Recrutamento real persistido.
- [x] Aprovar candidato.
- [x] Recusar candidato.
- [x] Convidar player por fluxo de candidatura.
- [ ] Cooldown de candidatura.
- [x] Logs de recrutamento.
- [ ] Metas reais persistidas.
- [ ] Editar meta.
- [ ] Deletar meta.
- [ ] Concluir meta.
- [ ] Alterar progresso de meta.
- [ ] Ranking de metas.
- [ ] Recompensas de metas.
- [ ] Logs de metas.
- [x] Criar cargo.
- [x] Editar cargo.
- [x] Desativar/reativar cargo sem DELETE fisico.
- [ ] Deletar cargo.
- [x] Alterar capability direta de cargo via catalogo oficial.
- [x] Editar dados basicos de org existente.
- [x] Arquivar/reativar org sem DELETE fisico.
- [ ] Excluir org.
- [ ] Overrides individuais editaveis.
- [ ] Logs de alteracoes de cargos/permissoes.
- [ ] Escolher grade manualmente ao promover/rebaixar.
- [x] Convite direto por citizenid para player ja existente em `mz_players`.
- [ ] Convite pendente/offline com aceite do jogador.
- [ ] Logs detalhados no painel para acoes de membro.
- [ ] Rate limit avancado para acoes de membro.
- [ ] Acoes financeiras.
- [ ] Edicao de grades/capabilities.
- [ ] Auditoria completa das acoes futuras.
- [ ] Rate limit para acoes futuras.
- [ ] Teste visual final em jogo apos polimentos.
- [ ] Release package.
