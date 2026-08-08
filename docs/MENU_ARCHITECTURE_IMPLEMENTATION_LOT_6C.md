# Implementação — Lote 6C

> Nota de sucessão: a transferência de liderança sugerida ao final deste lote foi implementada no Lote 6D, com gate opt-in, `members.set_leader` e auditoria transacional.

## Resultado

O módulo de cargos da organização deixou de ser apenas leitura para membros cujo cargo possui `manage.permissions`.

Foram adicionadas ações compartilhadas para:

- criar cargo inferior;
- editar dados de cargo inferior;
- desativar cargo inferior vazio;
- reativar cargo inferior;
- adicionar capability própria;
- remover capability direta própria.

## Separação de responsabilidades

- `mz_menu` continua somente visual.
- `mz_org` valida contexto, sanitiza payloads e monta a interface.
- `mz_core` revalida membership, capability, hierarquia, herança e persistência.
- Os exports Staff existentes não foram enfraquecidos.

## Arquivos centrais

- `mz_core/server/orgs/service.lua`: modo organizacional privado e regras de hierarquia.
- `mz_core/server/orgs/exports.lua`: seis exports organizacionais explícitos.
- `shared/menu_organization_mutations.lua`: sanitização fail-closed de cargos.
- `server/menu_organization_operations.lua`: seis endpoints contextuais.
- `server/menu_organization_reads.lua`: salário, prioridade e capabilities diretas no DTO autorizado.
- `client/menu/organization_grades.lua`: builder operacional compartilhado.

## Compatibilidade

- API administrativa antiga do `mz_core` foi preservada.
- Staff continua usando seus próprios eventos e permissões globais.
- Membros sem `manage.permissions` continuam vendo o módulo em modo leitura.
- Frontend e callbacks legados permanecem presentes.
- Nenhum arquivo React, Vite, TypeScript, JSX ou TSX foi criado.

## Próxima entrega sugerida

Recursos rápidos continuam pendentes de inventário de integrações reais. A transferência foi concluída no Lote 6D. A hierarquia de Staff permanece um domínio separado.
