# Checklist runtime - Staff Menu Lote 3

## Preparacao

- [ ] Iniciar `mz_core`, `mz_menu` e `mz_org` sem erros.
- [ ] Confirmar `Config.Interface.staffMenu = true`.
- [ ] Confirmar `Config.MenuArchitecture.staffCommand = 'stafforg'`.
- [ ] Manter `staffAliasCommandEnabled = false` no primeiro teste.
- [ ] Preparar jogador comum, lider, cargo com `staff.*`, Staff parcial de orgs, Staff parcial de logs e owner.
- [ ] Preparar organizacoes ativas, arquivadas e codigos semelhantes, por exemplo `police` e `police_academy`.

## Entrada e autorizacao

- [ ] Jogador comum nao abre `/stafforg`.
- [ ] Lider organizacional nao abre `/stafforg`.
- [ ] Cargo contendo `staff.orgs.view` nao abre `/stafforg`.
- [ ] Owner abre e recebe todos os modulos.
- [ ] `staff.panel.open` recebe somente overview.
- [ ] `staff.orgs.view` recebe organizacoes e diagnostico, sem escrita.
- [ ] `staff.logs.view` recebe logs/auditoria globais e nao recebe organizacoes.
- [ ] `staff.orgs.manage` isolada nao libera listagem, logs ou outros dominios.
- [ ] Remover a permissao global e reconstruir a sessao; request antigo deve ser negado.

## Comandos e legado

- [ ] `/stafforg` abre o menu novo.
- [ ] `/staff` continua abrindo o shell legado em `hybrid`.
- [ ] Habilitar temporariamente `staffAliasCommandEnabled = true`; `/staff` passa ao menu novo.
- [ ] Desabilitar novamente e confirmar rollback sem migration.
- [ ] Validar `/org`, `/painel`, `/gang`, `/business`, `/government`, `/vip` e `/event`.

## Raiz Staff

- [ ] Conferir nome, identidade Staff/owner e permissoes globais.
- [ ] Conferir quantidades de ativas e arquivadas para quem possui `staff.orgs.view`.
- [ ] Staff sem `staff.orgs.view` ve contadores como restritos.
- [ ] Conferir lista de modulos e indicador `Somente leitura - Lote 3`.
- [ ] Confirmar tema Staff independentemente da organizacao visitada anteriormente.

## Listagem, filtros e busca

- [ ] Listar todas, ativas e arquivadas separadamente.
- [ ] Testar filtros `job`, `gang`, `business`, `government`, `vip` e `event`.
- [ ] Buscar por nome, codigo e ID estrutural.
- [ ] Confirmar que busca nao encontra conteudo presente somente em `config_json`.
- [ ] Navegar por mais de 20 resultados e conferir pagina anterior/proxima.
- [ ] Confirmar badge `Ativa`/`Arquivada` e identidade visual sanitizada.
- [ ] Confirmar que membros/lideranca aparecem como sob demanda na lista.

## Inspecao

- [ ] Inspecionar ativa e conferir resumo, lideranca, membros, cargos, features e aparencia.
- [ ] Inspecionar arquivada e conferir badge claro e somente leitura.
- [ ] Conferir total de membros/cargos com dados oficiais.
- [ ] Conferir cargo, grade, estado e data de entrada dos membros.
- [ ] Conferir capabilities organizacionais dos cargos.
- [ ] Capability `staff.*` aparece apenas como `Legado ignorado`.
- [ ] Confirmar que capability legada nunca aparece entre capabilities resolvidas.
- [ ] Conferir origem de cada feature e valor visual.
- [ ] Confirmar ausencia de editar, arquivar, reativar, promover, rebaixar, remover e definir lider.

## Logs e auditoria

- [ ] `staff.logs.view` abre logs globais com `orgCode` nulo.
- [ ] Dentro da inspecao autorizada, logs organizacionais usam codigo exato.
- [ ] `police` nunca recebe log de `police_academy`.
- [ ] Testar filtros exatos de categoria, acao, ator, periodo e auditId.
- [ ] Auditoria mostra somente registros com auditId.
- [ ] Logs organizacionais e globais nunca se misturam.
- [ ] Confirmar ausencia de apagar ou alterar logs.

## Diagnostico legado

- [ ] Conferir quantidade total de registros `staff.*` ignorados.
- [ ] Conferir organizacao, cargo, permission key, status e recomendacao.
- [ ] Confirmar que nenhum dado e removido ou migrado automaticamente.

## Concorrencia e contexto

- [ ] Ativar delay client da Fase 0 em 1500 ms.
- [ ] Abrir inspecao A e imediatamente B; resposta A deve ser descartada.
- [ ] Abrir logs de A e trocar para B; resposta A deve ser descartada.
- [ ] Fechar o Staff Menu durante uma leitura; nada deve reabrir.
- [ ] Gerar nova sessao enquanto submenu esta pendente; resposta antiga deve ser negada.
- [ ] Fechar Staff e abrir `/org`; tema Staff nao pode contaminar o tema organizacional.
- [ ] Fechar `/org` e abrir `/stafforg`; organizacao pessoal nao pode contaminar Staff.

## Compatibilidade

- [ ] Executar `/mz_menu_test` e `/mz_menu_theme_test`.
- [ ] Executar smoke de `mz_houses` com `OpenContext`, `InputDialog` e `AlertDialog`.
- [ ] Validar callbacks NUI legados do `mz_org`.
- [ ] Confirmar os 14 exports do `mz_menu`.
- [ ] Confirmar frontend legado funcional no modo `hybrid`.

## Evidencias

- [ ] Capturas de owner, Staff orgs-only, Staff logs-only e acesso negado.
- [ ] Capturas de ativa/arquivada e capability legada ignorada.
- [ ] Video da troca rapida A/B com delay.
- [ ] Logs server de sessao obsoleta e contexto divergente.
- [ ] Registrar build, data, responsavel e resultado do gate runtime.

