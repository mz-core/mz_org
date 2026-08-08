# Compatibilidade legada da Fase 0

## Mantido

- `web/index.html` continua sendo o `ui_page`.
- Nenhum arquivo React/Vite foi criado.
- Todos os nomes de callback NUI permanecem.
- Comandos `/mzorg`, `/painel`, `/org`, `/gang`, `/staff`, `/vip`, `/business`, `/government` e `/event` permanecem.
- DTO legado de sessao (`user`, `orgs`, `modules`) permanece derivado da V2.
- Exports legados `ListLogs`, `PromoteOrgMemberSecure` e `DemoteOrgMemberSecure` permanecem com os mesmos nomes.

## Alteracoes intencionais

- `session:get` agora usa o mesmo request/response correlacionado dos demais callbacks e ainda emite `session:set`.
- `/staff` sem autorizacao nao monta o shell Staff; cai no Hub seguro.
- `dashboard` nao serve mais como fallback para abrir paineis diferentes do Hub.
- `staff.*` em cargo/seed/heranca e ignorado. Administradores devem usar ACE explicito ou override global.
- `staff.orgs.manage` nao substitui `staff.members.*`, `staff.logs.view` nem capabilities de banco/metas/recrutamento.
- `staff.orgs.set_leader` autoriza apenas o fluxo de lideranca.
- Logs globais e organizacionais sao consultas separadas.
- Org arquivada bloqueia operacoes, ainda que um cliente legado tente chama-las.

## Contratos alterados de forma compativel

```lua
PromoteOrgMemberSecure(source, orgCode, targetCitizenId, options?)
DemoteOrgMemberSecure(source, orgCode, targetCitizenId, options?)
```

O quarto argumento e opcional. Respostas antigas continuam com `grade`, `gradeCode` e `gradeName`, acrescidas de:

- `action`;
- `oldGradeCode`;
- `newGradeCode`;
- `auditId`.

`ListLogs(source, filters)` permanece, mas somente despacha:

- com `filters.orgCode`: `ListOrgLogsSecure`;
- sem `filters.orgCode`: `ListGlobalLogsSecure`.

Nao existe fallback global para erro da consulta organizacional.

## Dados legados `staff.*`

Rows existentes em `mz_org_permissions` nao sao apagadas automaticamente. Elas:

1. sao listadas no diagnostico do prepare;
2. nao entram em permissions/capabilities efetivas;
3. nao aparecem no access model organizacional;
4. nao podem ser recriadas pelo editor/exports de cargo.

Essa escolha torna a migration reversivel e permite auditoria manual antes de eventual limpeza de dados.

## Rollback operacional

O codigo pode ser revertido junto, mas as colunas nullable `mz_logs.org_code` e `mz_logs.audit_id` sao aditivas e podem permanecer sem afetar consumidores antigos. Nao remover colunas durante rollback de emergencia.

## Incompatibilidades de seguranca aceitas

Clientes/resources que dependiam de um cargo organizacional para conceder `staff.*` deixam de receber esse poder. Isso e uma correcao de fronteira de autorizacao, nao um comportamento a preservar.

Resources que esperavam `staff.orgs.manage` como wildcard de membros/banco/metas/recrutamento precisam declarar a permissao global especifica ou usar uma capability da organizacao alvo.
