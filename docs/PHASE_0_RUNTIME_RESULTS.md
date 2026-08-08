# Resultados runtime da Fase 0

Decisao atual: **NAO APROVADA**.

Data da preparacao: 2026-07-21 (America/Sao_Paulo).

## Ambiente encontrado

- Workspace: `D:/git-hub/repo_oficial`.
- Processo FXServer/FiveM/txAdmin: nao encontrado.
- Processo MySQL/MariaDB: nao encontrado.
- Listeners 30120, 40120 e 3306: nao encontrados.
- `server.cfg` de staging: nao encontrado.
- Backup completo verificavel: nao fornecido/encontrado.
- Conexao com players/perfis de teste: indisponivel.

Consequentemente, nenhum resultado abaixo foi marcado PASS com base apenas em analise estatica.

## Resultado do runner nesta maquina

Nao executado: o runner depende do runtime FiveM e `oxmysql`. O arquivo passou em `luac -p`, mas isso nao constitui evidencia runtime.

Resultado runtime completo: **0 executados, 0 PASS, 0 FAIL, 45 NAO EXECUTADOS**.

## Registro dos testes obrigatorios

| # | Cenario | Preparacao/acao | Esperado | Obtido | Status | Evidencia | Cleanup |
|---:|---|---|---|---|---|---|---|
| 1 | Comum sem staffContext | Player comum + session | `staffContext=nil` | Runtime ausente | NAO EXECUTADO | Sem player/FiveM | N/A |
| 2 | Comum sem modulos Staff | Player comum + `/staff` | Negado/Hub | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 3 | Lider sem Staff global | Lider + session | Zero `staff.*` global | Runtime ausente | NAO EXECUTADO | Sem perfil | N/A |
| 4 | Cargo legado `staff.*` | Row real + reload | Ignorado | Banco ausente | NAO EXECUTADO | Sem DB | N/A |
| 5 | `staff.orgs.view` read-only | Perfil granular | Edicao negada | Runtime ausente | NAO EXECUTADO | Sem perfil | N/A |
| 6 | `staff.orgs.set_leader` isolado | Perfil granular | Apenas lideranca | Runtime ausente | NAO EXECUTADO | Sem perfil | N/A |
| 7 | `staff.logs.view` isolado | Perfil granular | Sem admin org | Runtime ausente | NAO EXECUTADO | Sem perfil | N/A |
| 8 | Staff parcial | Grants conhecidos | Features exatas | Runtime ausente | NAO EXECUTADO | Sem perfil | N/A |
| 9 | Owner | Owner conectado | Autorizado | Runtime ausente | NAO EXECUTADO | Sem player | N/A |
| 10 | Criar logs similares | Runner database | Fixtures criadas | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 11 | Consultar ambas orgs | Exports seguros | Tabelas retornadas | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 12 | Isolamento exato | Comparar IDs | Sem colisao | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 13 | Global fora de org | Consultas org | Ausente | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 14 | Org fora do global | Consulta global | Ausente/forbidden | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 15 | Legado NULL | Consultas global/org | Apenas global autorizado | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 16 | Promocao auditada | Probe cargo 1->2 | Before/after/auditId/log | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 17 | Rebaixamento auditado | Probe cargo 2->1 | Before/after/auditId/log | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 18 | Falha de auditoria | Audit ID duplicado | Transacao falha | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 19 | Rollback de cargo | Ler membership | Cargo preservado | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 20 | Sem alteracao sem audit | Contar rows | Consistencia | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 21 | Unicidade audit_id | Indice + duplicata | Rejeicao | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 22 | Arquivada nao abre | Guard + NUI | `org_archived` | Runtime ausente | NAO EXECUTADO | Sem FiveM | Runner faria cleanup |
| 23 | Membro nao muta arquivada | Endpoints reais | Todos negados | Runtime ausente | NAO EXECUTADO | Sem player | Dados dedicados |
| 24 | Staff sem permissao | Abrir arquivada | Negado | Runtime ausente | NAO EXECUTADO | Sem perfil | N/A |
| 25 | Staff autorizado read-only | Abrir detalhe | Somente leitura | Runtime ausente | NAO EXECUTADO | Sem perfil | N/A |
| 26 | Endpoint bloqueia arquivada | `CreateOrgGoal` fixture | `org_archived` | DB ausente | NAO EXECUTADO | Sem oxmysql | Runner faria cleanup |
| 27 | Abrir A | NUI real | A ativo | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 28 | Request A atrasada | Latencia artificial | Pendente | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 29 | Trocar para B | NUI real | Contexto muda | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 30 | Descartar resposta A | Liberar resposta | Descartada | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 31 | Revision antiga | Reenviar envelope | Rejeitado | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 32 | Estado nao contaminado | Inspecionar UI | Sem dados antigos | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 33 | contextKey cruzado | Enviar A em B | Fail-closed | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 34 | Sem mutation cruzada | Inspecionar server/UI | Nenhum efeito | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 35 | Novo sessionId | Fechar/reabrir | ID/revision novos | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 36 | 35 callbacks | Regressao completa | Sem critica | Runtime ausente | NAO EXECUTADO | Sem NUI | Dados de teste dedicados |
| 37 | Abrir/fechar painel | Comandos/ESC | Normal | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 38 | Foco NUI | Abrir/fechar | Foco correto | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 39 | Hub | Player comum | Funcional | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 40 | Workspace org | Membro | Funcional/autorizado | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 41 | Workspace Staff | Staff/owner | Features exatas | Runtime ausente | NAO EXECUTADO | Sem NUI | N/A |
| 42 | Comandos | Executar inventario | Preservados | Runtime ausente | NAO EXECUTADO | Sem FiveM | Dados dedicados |
| 43 | Exports legados | Consumidores reais | Compativeis | Runtime ausente | NAO EXECUTADO | Consumidores nao ativos | Dados dedicados |
| 44 | targetSource off | Preflight/convite | Rejeitado | Runtime ausente | NAO EXECUTADO | Sintaxe/config apenas | N/A |
| 45 | `Config.Debug=false` | Restart + regressao | Sem quebra necessaria | Runtime ausente | NAO EXECUTADO | Sem FiveM | Restaurar config staging |

## Validacao local do artefato

- Runner server-only adicionado ao manifest.
- Nenhum `RegisterNetEvent`, `RegisterNUICallback`, `AddEventHandler` ou `TriggerClientEvent` foi adicionado pelo runner/probe.
- Ativacao automatica: inexistente.
- Escrita sem staging + convar + atestado: bloqueada.
- Probe transacional aceita chamadas somente do recurso `mz_org`.
- Escopo do probe: somente `citizenid`, `orgCode` e `auditId` com prefixos `mztest_*`.
- `luac -p` do runner e probe: aprovado.
- Teste Node do envelope A→B: `CONTEXT_ENVELOPE_STALE_DISCARD=true`.
- Sintaxe de todos os Lua alterados: `CHANGED_LUA_SYNTAX_OK=22`.
- Sintaxe de todo o JavaScript atual de `mz_org/web`: `ALL_ORG_JS_SYNTAX_OK=23`.
- Matrizes checklist/resultados: 45 linhas cada.
- Callbacks NUI preservados: 35.

## Decisao

**NAO APROVADA EM RUNTIME.** Motivo: ambiente runtime, banco, backup e players de staging indisponiveis; os 45 testes permanecem por executar.
