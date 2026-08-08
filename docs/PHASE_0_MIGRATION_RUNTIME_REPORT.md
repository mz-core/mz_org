# Relatorio runtime da migration da Fase 0

Status: preparado, nao executado. Decisao de migration runtime: pendente.

## Backup

Nao foi possivel confirmar um backup completo: nenhum banco/configuracao de staging ou referencia de backup foi encontrado no workspace. Nenhuma migration foi executada por este trabalho.

O runner exige o atestado:

```cfg
set mz_org_phase0_backup_confirmed "<backup-id-ou-caminho-verificado>"
```

Isso registra a confirmacao do operador, mas nao substitui a verificacao/restauracao de teste do backup.

## Bootstrap executado pelo mz_core

Todo restart do `mz_core` executa os `CREATE TABLE IF NOT EXISTS` para:

`mz_players`, `mz_player_accounts`, `mz_account_idempotency`, `mz_financial_outbox`, `mz_player_sessions`, `mz_org_types`, `mz_orgs`, `mz_org_grades`, `mz_org_permissions`, `mz_player_orgs`, `mz_player_permissions`, `mz_player_vehicles`, `mz_vehicle_world_state`, `mz_inventory_items`, `mz_player_hotbar`, `mz_org_accounts`, `mz_org_account_transactions`, `mz_org_goals`, `mz_org_recruitment`, `mz_logs` e `mz_world_drops`.

As migrations defensivas atualmente executadas verificam/adicionam:

- `mz_players.pos_x`, `pos_y`, `pos_z`, `heading`;
- `mz_inventory_items.instance_uid`;
- `mz_player_vehicles.metadata_json`;
- `mz_org_grades.active`;
- `mz_logs.org_code VARCHAR(64) NULL`;
- `mz_logs.audit_id VARCHAR(96) NULL`;
- `idx_mz_logs_org_code (org_code)`;
- `uq_mz_logs_audit_id (audit_id)` como UNIQUE;
- engine InnoDB de `mz_player_orgs` e `mz_logs`;
- backfill de `mz_logs.org_code` somente a partir de caminhos JSON estruturais conhecidos.

O bootstrap tambem valida a estrutura de subsistemas preexistentes, como o outbox financeiro. Portanto, o primeiro restart deve ser observado por inteiro, nao somente nas linhas da Fase 0.

## Idempotencia por construcao

- Tabelas: `CREATE TABLE IF NOT EXISTS`.
- Colunas: consulta `information_schema.columns` antes do `ALTER`.
- Indices: consulta `information_schema.statistics` antes do `ALTER`.
- Engine: `ALTER ... ENGINE=InnoDB` apenas quando a engine atual difere.
- Backfill: altera apenas rows com `org_code IS NULL`; valores ja preenchidos nao sao sobrescritos.
- Permissoes `staff.*`: somente SELECT/diagnostico; nenhuma row e removida.

Isto confirma idempotencia estatica, nao idempotencia runtime. A comprovacao runtime requer dois ciclos completos.

## Procedimento e registro

| Execucao | Comandos | Inicio/fim | Duracao | Mudancas | Warnings/erros | Resultado |
|---|---|---|---|---|---|---|
| Primeira | `restart mz_core`, aguardar prepare, `restart mz_org`, `mz_org_phase0_runtime preflight` | Pendente | Pendente | Pendente | Pendente | NAO EXECUTADA |
| Segunda | Repetir os mesmos comandos | Pendente | Pendente | Esperado: nenhuma coluna/indice/engine adicional | Pendente | NAO EXECUTADA |

## Consultas executadas pelo preflight

O comando abaixo coleta engine, colunas, indices, contagens de logs e quantidade de permissões legadas sem modificar dados:

```text
mz_org_phase0_runtime preflight
```

Campos a copiar do resultado `M07` para este relatorio:

| Metrica | Primeira execucao | Segunda execucao |
|---|---:|---:|
| Logs totais | Pendente | Pendente |
| Logs com `org_code` | Pendente | Pendente |
| Logs com `org_code = NULL` | Pendente | Pendente |
| Rows organizacionais `staff.*` | Pendente | Pendente |

## Riscos operacionais

- `ALTER TABLE ... ENGINE=InnoDB` pode bloquear tabelas grandes.
- O indice UNIQUE falhara se o banco ja contiver `audit_id` duplicado e nao nulo; auditar antes da janela.
- O backfill e idempotente, mas pode examinar muitas rows e deve ser medido.
- Nao remover colunas/indices automaticamente em rollback de emergencia.
