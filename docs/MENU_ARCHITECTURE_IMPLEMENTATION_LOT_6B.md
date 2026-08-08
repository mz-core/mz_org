# Implementação — Lote 6B

> Nota de sucessão: a gestão de cargos pendente neste corte foi entregue no Lote 6C. A transferência de liderança foi entregue no Lote 6D com contrato próprio e gate opt-in.

## Resultado

O painel organizacional deixou de ser exclusivamente read-only quando o cargo possui capabilities de escrita:

- membros: convite, remoção, promoção e rebaixamento;
- financeiro: depósito e saque;
- metas: criação;
- recrutamento: criação, aprovação, rejeição e cancelamento.

Sem capability, os mesmos builders continuam somente leitura.

## Componentes

- `shared/menu_organization_mutations.lua`: whitelist e normalização.
- `server/menu_organization_operations.lua`: guarda contextual e endpoints.
- `client/menu/organization_members.lua`: membros e hierarquia.
- builders financeiro, metas e recrutamento estendidos.
- `menu_organization.lua`: autorização de mutação sem fallback Staff.

## Compatibilidade

Eventos legados continuam presentes. Os novos eventos usam prefixo `mz_org:server:organization*`. Exports oficiais do `mz_core` foram preservados.

## Pendência seguinte

Gestão de cargos por líderes foi entregue no Lote 6C com `manage.permissions` e exports organizacionais próprios. A transferência pelo `/org` foi isolada no Lote 6D; exports administrativos Staff continuam separados.
