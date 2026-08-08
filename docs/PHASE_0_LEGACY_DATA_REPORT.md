# Relatorio de dados legados da Fase 0

Status: inventario preparado, contagens runtime pendentes.

## Estado observado

Nenhum MySQL/MariaDB ou staging estava ativo/acessivel nesta maquina. Por isso, nao ha contagem real de rows e nenhuma row foi alterada ou removida.

| Classe | Quantidade encontrada | Acao automatica |
|---|---:|---|
| `mz_logs.org_code IS NOT NULL` | Pendente | Nenhuma |
| `mz_logs.org_code IS NULL` | Pendente | Nenhuma fora do backfill estrutural do prepare |
| `mz_org_permissions.permission LIKE 'staff.%'` | Pendente | Nenhuma; rows somente diagnosticadas e ignoradas |
| `audit_id` duplicado nao nulo | Pendente; deve ser zero para criar indice UNIQUE | Nenhuma |

## Coleta reproduzivel

Depois do backup e do primeiro restart:

```text
mz_org_phase0_runtime preflight
```

O resultado `M07` fornece as tres primeiras contagens. Antes de uma migration que ainda nao possua o indice UNIQUE, executar no cliente SQL de staging:

```sql
SELECT audit_id, COUNT(*) AS total
FROM mz_logs
WHERE audit_id IS NOT NULL
GROUP BY audit_id
HAVING COUNT(*) > 1;
```

Consulta detalhada, somente leitura, das permissões legadas:

```sql
SELECT p.id, p.org_id, o.code AS org_code, p.grade_id, p.permission, p.allow
FROM mz_org_permissions p
LEFT JOIN mz_orgs o ON o.id = p.org_id
WHERE p.permission LIKE 'staff.%'
ORDER BY p.org_id, p.grade_id, p.permission;
```

Consulta dos logs ainda sem escopo estrutural:

```sql
SELECT id, scope, action, actor, target, created_at
FROM mz_logs
WHERE org_code IS NULL
ORDER BY id;
```

## Politica aplicada

- Rows organizacionais `staff.*` permanecem armazenadas, mas sao ignoradas na autorizacao, heranca, access model e Session V2.
- Elas nao serao apagadas por runner, bootstrap ou cleanup.
- Logs `org_code=NULL` sao tratados estruturalmente como globais e somente podem ser vistos por viewer global autorizado.
- O backfill nao usa `LIKE`, target textual nem substring para inferir a organizacao.
- Classificacao manual futura exige aprovacao separada, backup e trilha de auditoria.

## Cleanup do runner

O runner remove exclusivamente rows criadas pela propria execucao:

- logs com `audit_id` igual ao prefixo aleatorio `mztest_phase0_<run>`;
- logs com os tres `org_code` exatos da fixture;
- membership com `citizenid` aleatorio `mztest_*`;
- cargos e organizações pelos IDs/codigos criados.

Nenhuma row legada preexistente corresponde a esses identificadores exclusivos. O resultado `C01` confirma contagens remanescentes iguais a zero.
