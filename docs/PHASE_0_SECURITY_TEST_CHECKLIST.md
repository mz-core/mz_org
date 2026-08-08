# Checklist de testes da Fase 0

Status: validacoes estaticas executadas. Runtime FiveM pendente; nao aprovado.

## Harness isolado executado

Comando, a partir de `D:/git-hub/repo_oficial`:

```powershell
lua mz_org/tests/phase0_security_harness.lua
```

Resultado exato:

```text
PASS 01 - membro comum nunca recebe staff.* global
PASS 02 - cargo legado com staff.* e ignorado
PASS 03 - staff.orgs.view nao permite editar organizacao
PASS 04 - staff.logs.view nao permite administrar organizacao
PASS 05 - staff.orgs.set_leader global permite somente definir lideranca
PASS 06 - logs police nao retornam police2
PASS 07 - falha de auditoria cancela promocao
PASS 08 - resposta contextual antiga e identificavel e descartavel
PASS 09 - organizacao arquivada bloqueia mutacoes
PASS 10 - owner continua autorizado
RESULT executed=10 passed=10 failed=0
```

## Validacoes estaticas

- [x] zero fallback `HasGlobalPermission -> HasPermission` em `mz_org/server/session.lua`;
- [x] zero `CanOrg(..., 'staff.*')` no codigo Lua de `mz_org` e `mz_core`;
- [x] `staff.*` removido da allowlist, catalogo e seed organizacionais;
- [x] legado `staff.*` filtrado em resolucao, heranca e access model;
- [x] logs de org usam `org_code = ?` e nao usam target/JSON para delimitar escopo;
- [x] promote/demote exigem `auditId` no wrapper;
- [x] sessao V2 separa `global`, `organizations` e `staff`;
- [x] Staff nao depende de fallback `dashboard`;
- [x] Lua alterado passou em `luac -p`;
- [x] JavaScript alterado passou em `node --check`;
- [x] migration possui checks de coluna/indice e backfill condicionado;
- [x] nenhuma tabela paralela de saldo ou membership criada.

## Checklist runtime FiveM obrigatorio

### Inicializacao e migration

- [ ] Fazer backup do banco.
- [ ] Reiniciar `oxmysql`, `mz_core` e `mz_org` em ambiente de staging.
- [ ] Confirmar `mz_core` ready e ausencia de erro no prepare.
- [ ] Confirmar colunas `mz_logs.org_code` e `mz_logs.audit_id`.
- [ ] Confirmar indices `idx_mz_logs_org_code` e `uq_mz_logs_audit_id`.
- [ ] Confirmar engine InnoDB em `mz_player_orgs` e `mz_logs`.
- [ ] Reiniciar novamente e confirmar que migration nao duplica coluna/indice nem altera rows ja migradas.
- [ ] Registrar todas as linhas `[migration][staff-permission]` para saneamento posterior.

### Permissoes e entrada

- [ ] Player sem org abre `/painel`: somente Hub.
- [ ] Player comum executa `/staff`: Hub/acesso negado, sem flash Staff.
- [ ] Cargo com `staff.orgs.manage` legado nao cria Staff.
- [ ] ACE `staff.orgs.view` lista metadados, mas nao edita.
- [ ] ACE `staff.logs.view` abre logs globais, mas nao cria/edita org.
- [ ] ACE `staff.orgs.set_leader` define lider, mas nao acessa banco, metas, recrutamento ou edicao.
- [ ] Owner continua acessando os fluxos autorizados.

### Logs

- [ ] Criar logs para `police`, `police2`, `police_old` e log global.
- [ ] Consultar `police`: somente `org_code='police'`.
- [ ] Consultar logs globais: nenhum log de org.
- [ ] Remover/indisponibilizar o export seguro em staging: consulta deve falhar, nunca retornar global como fallback.

### Auditoria

- [ ] Promover membro e conferir retorno completo com `auditId`.
- [ ] Conferir row de `mz_logs` com ator, alvo, org, before/after, timestamp e motivo.
- [ ] Rebaixar e repetir.
- [ ] Forcar falha de INSERT de auditoria em staging e confirmar que grade nao muda.
- [ ] Repetir request e confirmar que nao cria auditoria duplicada pelo `mz_org`.

### Arquivamento

- [ ] Arquivar org e confirmar que some dos contextos pessoais.
- [ ] Tentar invite/remove/promote/demote/setLeader: todos negados.
- [ ] Tentar deposito/saque, criar meta e recrutamento: todos negados.
- [ ] `staff.orgs.view` acessa somente metadados read-only.
- [ ] Reativacao funciona somente com owner/`staff.orgs.manage`.

### Contexto assincrono

- [ ] Abrir `police`, introduzir latencia e trocar para `mechanic`.
- [ ] Confirmar que detalhe, membros, banco, extrato, cargos, metas, recrutamento e logs de `police` nao aparecem em `mechanic`.
- [ ] Repetir no detalhe Staff entre duas orgs.
- [ ] Fechar/reabrir a NUI durante request e confirmar que a revisao antiga nao e aplicada.

### Regressao

- [ ] Executar todos os 35 callbacks pelo fluxo normal.
- [ ] Confirmar `/org`, `/gang`, `/business`, `/government`, `/vip` e `/event` como atalhos, sem forcar contexto negado.
- [ ] Confirmar deposito/saque sem retry automatico ou duplicacao.
- [ ] Confirmar que o frontend legado carrega e fecha normalmente.

## Evidencia a guardar

- console do prepare/restart;
- SQL das colunas/indices;
- payloads de sessao de cada perfil;
- audit IDs de promote/demote;
- screenshots/gravacao das trocas rapidas;
- resultado de cada checkbox com data, build e tester.
