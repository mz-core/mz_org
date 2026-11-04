# Implementacao da Fase 0 de seguranca

Status: codigo e harnesses estaticos concluidos. Runtime FiveM nao aprovado.

## Causas corrigidas

1. Permissao global agregava capabilities de qualquer organizacao.
2. `staff.*` podia existir em cargos, heranca, seeds e `CanOrg`.
3. Logs organizacionais eram delimitados por substring em `target`/JSON.
4. Promocao/rebaixamento confirmavam a mudanca sem auditoria obrigatoria.
5. Sessao legada misturava entrada, modulo e autorizacao.
6. Requests nao carregavam revisao/contexto e respostas antigas sobrescreviam a UI.

## Implementacao

### Permissoes

- `HasGlobalPermission` no core usa somente owner, ACE explicito ou permissao do cargo Staff ativo.
- `HasPermission` retorna falso para `staff.*` e nao e usado pela sessao global.
- `CanOrg` retorna falso para qualquer capability `staff.*`.
- Allowlist de cargo e catalogo compartilhado nao contem `staff.*`.
- Seed da organizacao Staff nao grava mais `staff.*` em cargos.
- Dados legados continuam persistidos para analise, mas sao filtrados em resolucao, heranca, access model e DTOs.
- Prepare imprime diagnostico de cada row legada `staff.*` encontrada.
- `staff.orgs.set_leader` foi preservada como nome global e removida de `CanOrg`.

### Logs

- `mz_logs` recebe `org_code` e `audit_id` estruturais.
- Backfill usa somente caminhos JSON exatos conhecidos.
- `ListOrgLogsSecure(source, orgCode, filters)` exige autorizacao e `WHERE org_code = ?`.
- `ListGlobalLogsSecure(source, filters)` exige owner ou `staff.logs.view` e usa `org_code IS NULL`.
- `ListLogs` permanece como dispatcher legado, sem fallback entre escopos.
- `mz_org/server/logs.lua` seleciona explicitamente o export pelo contexto.

### Auditoria de cargos

- `mz_org_members` e `mz_logs` usam tabelas InnoDB existentes.
- `updateMembershipGradeWithAudit` executa UPDATE e INSERT do log na mesma `MySQL.transaction.await`.
- Falha do INSERT/transaction retorna `audit_transaction_failed`; a mudanca sofre rollback.
- Retorno inclui `orgCode`, `targetCitizenId`, `action`, `oldGrade`, `newGrade`, `oldGradeCode`, `newGradeCode` e `auditId`.
- `mz_org/server/members.lua` rejeita sucesso sem todos os campos.

### Sessao e entrada

- Sessao V2 implementada com `version=2`, `revision`, user, entrypoints, global, organizations e staff separados.
- `ResolvePanelEntry` centraliza Hub, organizacao e Staff.
- Modulos legados sao derivados da V2.
- `/staff` negado retorna ao Hub no legado e nao usa dashboard como permissao do shell.

### Contexto assincrono

- `shared/context.lua` define parse/echo/verificacao do envelope.
- `client/main.lua` preserva `requestId`, `sessionRevision` e `contextKey`.
- `router.js` verifica chave/contexto antes de gravar org, banco, cargos, membros, metas, recrutamento, logs e detalhe Staff.
- Reset de contexto limpa flags de loading para nao bloquear a nova org.

### Hardening

- `server/security.lua` separa helpers globais e organizacionais e nega quando o core/export falha.
- Organizacoes arquivadas bloqueiam membro, cargo, banco, meta, recrutamento, lideranca e permissions mutations.
- Staff parcial nao ganha banco/metas/recrutamento/membros/logs por `staff.orgs.view|manage` sem permissao especifica.

## Migration idempotente

O prepare do `mz_core`:

1. cria `org_code` e `audit_id` no CREATE de instalacoes novas;
2. usa `information_schema` antes de `ALTER TABLE` em instalacoes existentes;
3. cria indices somente quando ausentes;
4. garante InnoDB para `mz_player_orgs` e `mz_logs`, requisito da transacao atomica;
5. faz backfill apenas onde `org_code IS NULL`;
6. nao apaga nem transforma rows legadas `staff.*`.

Nao foi criada tabela paralela de membro, identidade, permissao, saldo ou log.

## Compatibilidade

- Nomes dos 35 callbacks NUI foram mantidos.
- `ListLogs` permanece, mas despacha para contratos seguros.
- Promote/demote mantem nomes e aceita `options?` como quarto argumento.
- Sessao mantem aliases `orgs`, `modules`, `staffContext`, `sessionId` e `contractVersion`.
- Frontend legado permanece como `ui_page`.

## Evidencia estatica

Consultar o comando e a saida registrados em `PHASE_0_SECURITY_TEST_CHECKLIST.md`. Harness isolado: `tests/phase0_security_harness.lua`.
