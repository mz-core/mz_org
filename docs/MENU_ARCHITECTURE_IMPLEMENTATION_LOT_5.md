# Implementação — Lote 5

## Resultado

O painel acessado por `/org`, `/painel` e aliases filtrados passou a oferecer os módulos read-only autorizados pelo perfil da organização:

- membros paginados;
- cargos e hierarquia;
- saldo e extrato financeiro;
- metas e progresso;
- recrutamento;
- logs da organização.

Os builders do cliente foram separados por módulo. O servidor concentra apenas o contrato comum de autorização em `menu_organization.lua` e mantém as consultas/DTOs em `menu_organization_reads.lua`.

## Autoridades preservadas

- `mz_core`: organizações, memberships, cargos, capabilities, conta, metas, recrutamento e logs.
- `mz_org`: regras de entrada, feature/capability, envelope e DTOs da interface.
- `mz_menu`: apresentação e navegação.

Nenhuma tabela, saldo, membership ou sistema de permissão paralelo foi criado.

## Compatibilidade

Os eventos, arquivos e callbacks do painel legado permanecem presentes. O endpoint inicial do menu organizacional foi preservado. Os novos eventos têm prefixo `mz_org:server:organization*` e não substituem exports de `mz_core`.

## Segurança

O servidor captura `source` antes de operações assíncronas, valida sessão/contexto/módulo, recalcula a organização do jogador e aplica DTOs com campos explícitos. O cliente continua descartando respostas de contexto antigo.

O módulo de cargos não envia `playerOverrides`; capabilities do cargo só são visíveis com `manage.permissions`.

## Escopo não iniciado

Este lote não adiciona mutações organizacionais. A operação de Staff já existente não foi ampliada para gestão de Staff ou comandos de Staff.
