# Checklist runtime - menus Lotes 1 e 2

Este checklist exige servidor FiveM com `oxmysql`, `mz_core`, `mz_menu` e `mz_org` iniciados nessa ordem logica. As validacoes runtime nao sao substituidas pelos checks estaticos.

## Preparacao

- [ ] Confirmar `ensure mz_core`, `ensure mz_menu` e `ensure mz_org` sem erro no console.
- [ ] Confirmar `Config.Interface.mode = 'hybrid'`.
- [ ] Confirmar `organizationMenu = true`, `staffMenu = false`, `legacyPanel = true` e `legacyCommands = true`.
- [ ] Usar contas de teste com zero, uma e multiplas memberships.
- [ ] Incluir memberships dos tipos `job`, `gang`, `business`, `government`, `vip` e `event`.
- [ ] Preparar uma organizacao arquivada e duas organizacoes ativas A/B.
- [ ] Manter o console client F8 e o console server visiveis.

## `mz_menu`

- [ ] Executar `/mz_menu_test` e validar o fluxo legado completo.
- [ ] Executar `/mz_menu_theme_test`.
- [ ] Abrir os sete perfis e conferir cor principal, secundaria, posicao, largura, icone, marca e badge.
- [ ] Em cada perfil, abrir o submenu e conferir heranca integral.
- [ ] Fechar um perfil e abrir `/mz_menu_test`; confirmar que o tema global voltou.
- [ ] Testar contexto com `accent = 'red'`; confirmar fallback sem CSS injetado.
- [ ] Testar `position = 'bottom'`; confirmar fallback.
- [ ] Testar larguras 100 e 2000; confirmar normalizacao para 320 e 640.
- [ ] Testar `OpenContext`, `OpenMenu`, `RegisterContext`, `ShowContext`, `CloseContext`, `InputDialog`, `AlertDialog`, `Confirm` e `Notify` de um consumidor existente.

## Entradas organizacionais

- [ ] Jogador sem organizacao: `/org` e `/painel` negam sem abrir NUI/menu vazio.
- [ ] Jogador com uma organizacao: `/org` abre diretamente a raiz correta.
- [ ] Jogador com varias organizacoes: `/org` abre seletor e cada item abre seu contexto exato.
- [ ] `/painel` apresenta o mesmo comportamento organizacional de `/org`.
- [ ] `/gang` mostra somente memberships `gang`.
- [ ] `/business` mostra somente memberships `business`.
- [ ] `/government` mostra somente memberships `government`.
- [ ] `/vip` mostra somente memberships `vip`.
- [ ] `/event` mostra somente memberships `event`.
- [ ] Alias sem membership correspondente nega sem cair em outra organizacao.
- [ ] Organizacao arquivada nao aparece no seletor e uma tentativa direta e negada pelo servidor.

## Tema e override

- [ ] Cada tipo abre com label, icone, badge e cores do perfil esperado.
- [ ] Configurar manualmente um `config_json.ui` valido em ambiente de teste e recarregar o contexto; conferir override.
- [ ] Usar cor, posicao, largura, icone e profile invalidos; confirmar fallback seguro do perfil real.
- [ ] Confirmar que override visual nao altera `organization.type`, capabilities ou features calculadas.

## Visao geral e membros

- [ ] Visao geral mostra nome, tipo, cargo, duty, total de membros, conta e features.
- [ ] Comparar o total com `mz_player_orgs`/contrato oficial do core.
- [ ] Abrir membros e conferir somente membros do `orgCode` selecionado.
- [ ] Conferir nome, cargo, lideranca, CitizenID e duty.
- [ ] Confirmar que nenhum item oferece convite, remocao, promocao, rebaixamento ou edicao.
- [ ] Remover `org.view`/`members.view`, reconstruir a sessao e confirmar negacao server-side.
- [ ] Arquivar a organizacao entre a raiz e a abertura de membros; confirmar erro fechado.
- [ ] Parar `mz_core` em ambiente controlado; confirmar erro, nunca lista vazia tratada como sucesso.

## Concorrencia e envelope contextual

- [ ] Ativar `setr mz_org_phase0_client_delay_enabled 1`.
- [ ] Definir `setr mz_org_phase0_response_delay_ms 1500`.
- [ ] Abrir A e imediatamente abrir B; confirmar que resposta de A nao reabre nem preenche B.
- [ ] Abrir membros de A e trocar para B antes da resposta; confirmar descarte.
- [ ] Abrir membros e fechar o menu antes da resposta; confirmar que nada reabre.
- [ ] Repetir alternancia A/B dez vezes e inspecionar ausencia de mistura no console.
- [ ] Restaurar os convars de delay ao final.

## Legado e rollback

- [ ] Em `hybrid`, validar `/mzorg` e `/staff` no frontend legado conforme autorizacao antiga.
- [ ] Confirmar que todos os callbacks NUI legados ainda respondem.
- [ ] Mudar temporariamente para `mode = 'legacy'`; `/org`, `/painel` e aliases devem usar o painel antigo.
- [ ] Mudar para `mode = 'menu'`; o painel legado nao deve abrir.
- [ ] Retornar para `hybrid` sem migration ou alteracao de banco.

## Seguranca e escopo

- [ ] Confirmar que membership `staff` nao concede entrada Staff global.
- [ ] Confirmar que capability `staff.*` nao aparece em `organization.capabilities` nem habilita feature.
- [ ] Confirmar que jogador sem membership nao abre organizacao mesmo conhecendo o codigo.
- [ ] Confirmar que payload client adulterado com outro `orgCode` e negado.
- [ ] Confirmar ausencia de botoes mutaveis no menu novo.
- [ ] Confirmar que nenhum resource React/Vite/TypeScript foi iniciado.

## Evidencias a registrar

- [ ] Capturas dos sete temas e da heranca.
- [ ] Capturas dos cenarios zero/uma/multiplas organizacoes.
- [ ] Logs server das negacoes de capability e organizacao arquivada.
- [ ] Video curto da troca A/B com delay.
- [ ] Resultado do smoke de `mz_houses` ou consumidor equivalente.
- [ ] Data, build, responsavel e resultado final do gate runtime.

