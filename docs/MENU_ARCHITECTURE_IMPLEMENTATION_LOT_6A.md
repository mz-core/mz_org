# Implementação — Lote 6A

> Nota de sucessão: Lotes 6B e 6C entregaram as operações organizacionais e a gestão de cargos previstas abaixo. O Lote 6D adicionou transferência pelo `/org` em contrato separado. Este documento preserva o escopo histórico Staff do Lote 6A.

## Resultado

A inspeção de organização do `/stafforg` passou a oferecer:

- definição de liderança;
- convite por CitizenID;
- remoção, promoção e rebaixamento;
- criação e edição de cargos;
- desativação e reativação de cargos;
- adição e remoção de capabilities diretas.

As opções são montadas por permissão global exata. Organizações arquivadas permanecem somente leitura, exceto pela reativação já existente.

## Componentes

- `client/menu/staff_operations.lua`: builders e formulários operacionais.
- `server/menu_staff_operations.lua`: guarda contextual, revisão, DTO e chamadas oficiais.
- `shared/menu_mutations.lua`: sanitização de membros, cargos e capabilities.
- `server/menu_staff.lua`: ações efetivas no DTO da sessão/inspeção.

## Compatibilidade

Nenhum evento legado foi removido. Os exports do `mz_core` foram reutilizados sem alteração de assinatura. O painel legado continua controlado pelas feature flags atuais.

## Pendências

O sistema de cargos de Staff continua separado e ainda não foi implementado. Operações de líderes, banco, metas, recrutamento, cargos e transferência organizacional foram entregues posteriormente nos Lotes 6B, 6C e 6D.
