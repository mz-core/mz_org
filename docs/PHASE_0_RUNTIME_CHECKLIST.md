# Checklist executavel de runtime da Fase 0

Status do documento: pronto para execucao em staging. Nenhum teste runtime foi executado neste workspace.

## Guardas obrigatorios

1. Criar e verificar um backup completo fora do banco que sera testado.
2. Guardar o identificador, caminho ou hash do backup no registro da execucao.
3. Confirmar que o servidor e exclusivamente de staging.
4. Conectar um player owner ou com `staff.logs.view`; anotar seu server ID.
5. Ativar o runner somente durante a janela de teste:

```cfg
set mz_org_phase0_environment "staging"
set mz_org_phase0_backup_confirmed "<backup-id-ou-caminho-verificado>"
set mz_org_phase0_runtime_runner 1
setr mz_org_phase0_client_delay_enabled 0
setr mz_org_phase0_response_delay_ms 0
```

O valor de `mz_org_phase0_backup_confirmed` e um atestado do operador. O runner nao consegue provar que o arquivo existe em outro host; ele apenas impede fixtures sem esse atestado.

## Ordem de inicializacao e restart

```text
ensure oxmysql
ensure mz_core
ensure mz_org
```

Nos ciclos de migration, a ordem obrigatoria e:

```text
restart mz_core
restart mz_org
```

Nunca reiniciar `mz_org` antes de o prepare do `mz_core` terminar com sucesso.

## Comandos do runner

Todos os comandos abaixo sao executados no console do servidor. Tentativas vindas de player sao bloqueadas.

```text
mz_org_phase0_runtime status
mz_org_phase0_runtime preflight
mz_org_phase0_runtime database <owner-ou-staff-logs-source>
mz_org_phase0_runtime session <player-source> <hub|staff|org-code>
mz_org_phase0_runtime all <owner-ou-staff-logs-source>
```

`database` cria somente fixtures com prefixos `mztest_*`, nao toca em contas/saldos e executa cleanup por IDs/codigos exatos mesmo se houver excecao. Uma execucao concorrente e bloqueada.

Ao terminar:

```text
set mz_org_phase0_runtime_runner 0
```

## Evidencia padrao

Para cada teste, registrar no `PHASE_0_RUNTIME_RESULTS.md`: numero, preparacao, acao, esperado, obtido, PASS/FAIL, linhas do runner/console, screenshot quando aplicavel e cleanup.

## Matriz dos 45 testes

| # | Cenario e preparacao | Acao reproduzivel | Resultado esperado | Evidencia/cleanup |
|---:|---|---|---|---|
| 1 | Player comum conectado, sem ACE/global Staff | `session <source> hub` e abrir `/painel` | `staffContext=nil` | JSON S02; fechar painel |
| 2 | Mesmo player | Inspecionar `modules` e abrir `/staff` | Nenhum modulo Staff; entrada negada/Hub | JSON S02 e captura NUI |
| 3 | Lider organizacional sem grant global | `session <source> <org>` | Capabilities da org, zero `staff.*` global | JSON S02 |
| 4 | Cargo de staging contendo row legada `staff.*` | Reconectar/recarregar e executar `session` | Row diagnosticada, mas sem Staff | Console migration e JSON; nao apagar row |
| 5 | Perfil somente `staff.orgs.view` | Abrir lista/detalhe e tentar editar | Leitura permitida, edicao negada server-side | Respostas NUI e log de bloqueio |
| 6 | Perfil somente `staff.orgs.set_leader` | Definir lider e tentar outras mutations | Apenas lideranca autorizada | Respostas server; reverter lider de teste |
| 7 | Perfil somente `staff.logs.view` | Consultar logs e tentar administrar org | Logs permitidos, administracao negada | Runner 10-15 e respostas NUI |
| 8 | Staff parcial com grants conhecidos | `session <source> staff` | Somente features correspondentes | JSON `permissionGrants/features` |
| 9 | Owner conectado | `session <source> staff` e fluxos permitidos | Owner autorizado | JSON S02 e respostas NUI |
| 10 | Backup atestado e viewer conectado | `database <source>` | Dois logs `mztest_police_*`/sufixo `2` criados | PASS 10; cleanup C01 |
| 11 | Fixtures do teste 10 | Runner chama os dois exports seguros | Ambas consultas retornam tabelas | PASS 11 |
| 12 | Fixtures do teste 10 | Comparar IDs retornados | Nenhuma colisao entre codigos semelhantes | PASS 12 |
| 13 | Log global da fixture | Consultar cada org | Global ausente | PASS 13 |
| 14 | Logs das duas orgs | Consultar global com viewer autorizado; repetir com comum manualmente | Orgs ausentes; comum recebe `forbidden` | PASS 14 + resposta manual |
| 15 | Row legado com `org_code=NULL` e JSON contendo org | Consultas global e org | Aparece apenas no global autorizado | PASS 15; cleanup C01 |
| 16 | Membership `mztest_*` no cargo 1 | Probe transacional para cargo 2 | Cargo anterior/novo, auditId e row confirmados | PASS 16; cleanup C01 |
| 17 | Membership agora no cargo 2 | Probe transacional para cargo 1 | Mesmos campos confirmados | PASS 17; cleanup C01 |
| 18 | Audit ID bloqueador exclusivo | Probe tenta reutilizar audit ID | INSERT falha controladamente | PASS 18 |
| 19 | Apos teste 18 | Consultar membership | Cargo anterior preservado | PASS 19 |
| 20 | Apos teste 18 | Contar rows e membership | Nenhuma mudanca sem nova auditoria | PASS 20 |
| 21 | Indice aplicado | Inspecionar `non_unique` e rejeicao duplicada | Unicidade efetiva | PASS 21 |
| 22 | Org arquivada `mztest_*` | Guard runtime e tentativa de abrir workspace | `org_archived`; nao monta workspace comum | PASS 22 + captura NUI |
| 23 | Membro de org arquivada dedicada | Tentar invite/remove/promote/demote/banco/meta/recruitment | Todas as mutations negadas | Respostas server; nenhum dado criado |
| 24 | Staff sem grants relevantes | Tentar abrir org arquivada | Acesso negado | Sessao/NUI |
| 25 | Staff explicitamente autorizado para leitura | Abrir detalhe arquivado | Somente metadados read-only | NUI e respostas de mutations negadas |
| 26 | Fixture arquivada | Runner chama `CreateOrgGoal` server-side | `org_archived` independentemente do frontend | PASS 26 |
| 27 | Player com acesso a A e B | Abrir A | Contexto A ativo | Captura NUI |
| 28 | Ativar `setr mz_org_phase0_client_delay_enabled 1` e `setr mz_org_phase0_response_delay_ms 3000`, reconectar o cliente | Disparar read de A | Request A permanece pendente por 3s | Network/console |
| 29 | Teste 28 pendente | Trocar para B | Contexto/revisao mudam | Captura NUI |
| 30 | Resposta A liberada | Observar estado | Resposta A descartada | Console/captura; sem dado A em B |
| 31 | Com atraso de 3s ativo, iniciar read e fechar/reabrir o painel antes da resposta | Aguardar a resposta com `sessionRevision` anterior | Retorno vira `stale_context` e nao e aplicado | Network/console |
| 32 | Apos teste 31 | Inspecionar store/UI | Nenhum estado antigo aplicado | Captura |
| 33 | Contexto B ativo | Enviar `contextKey` de A | Fail-closed | Resposta correlacionada |
| 34 | Apos teste 33 | Verificar tela e server | Sem dado/mutation cruzada | Console e captura |
| 35 | Sessao aberta | Anotar sessionId, fechar/reabrir e executar `session` | Novo sessionId/revision | Dois JSON S02 |
| 36 | Matriz de payloads em `API_CONTRACT.md` | Exercitar cada um dos 35 callbacks | Sem regressao critica | Planilha/captura por callback |
| 37 | NUI fechada | Abrir e fechar pelos comandos/ESC | Ciclo normal | Video curto |
| 38 | NUI aberta/fechada | Verificar mouse/teclado | Foco adquirido e liberado | Video curto |
| 39 | Player comum | Abrir Hub | Hub funcional | Captura |
| 40 | Membro autorizado | Abrir workspace da org | Dados e capabilities corretos | Captura/respostas |
| 41 | Staff parcial e owner | Abrir Staff | Features exatas por perfil | Capturas e S02 |
| 42 | Perfis adequados | Testar `/mzorg`, `/painel`, `/org`, `/gang`, `/staff`, `/vip`, `/business`, `/government`, `/event`, `mzorg_test` quando habilitado | Comandos preservados e fail-closed | Console/captura |
| 43 | Inventariar consumidores reais | Exercitar exports legados listados no contrato | Assinaturas preservadas; sem fallback inseguro | Logs dos recursos consumidores |
| 44 | Config padrao | `preflight` e tentativa de convite por source | Flag false e convite rejeitado | PASS 44 + resposta NUI |
| 45 | Perfil de staging espelhando producao | Definir `Config.Debug=false`, restart core/org e repetir 1, 9, 35-44 | Funcionalidades necessarias intactas | Resultado da regressao; restaurar config de staging se preciso |

Depois dos testes 27-34, desligar o atraso e reconectar o cliente:

```text
setr mz_org_phase0_client_delay_enabled 0
setr mz_org_phase0_response_delay_ms 0
```

## Ciclo de migration duas vezes

1. Capturar hora inicial e console.
2. `restart mz_core`; aguardar `prepare` concluido; `restart mz_org`.
3. Executar `mz_org_phase0_runtime preflight`; guardar resultado e duracao observada.
4. Repetir exatamente o passo 2.
5. Reexecutar `preflight` e comparar schema/contagens.
6. Nao remover rows `staff.*` e nao corrigir logs `NULL` durante essa medicao.

## Criterio de parada

Qualquer FAIL de autorizacao, isolamento, transacao, arquivamento, contexto ou regressao critica interrompe a aprovacao. Corrigir somente a causa, repetir o teste e seus vizinhos de regressao e documentar ambos os resultados.
