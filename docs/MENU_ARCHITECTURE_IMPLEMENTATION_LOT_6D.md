# Implementação — Lote 6D

## Resultado

O menu organizacional recebeu transferência segura de liderança como funcionalidade opt-in. O fluxo promove um membro atual ao cargo superior e move o líder anterior para o cargo sucessor em uma única transação auditada.

O gate inicia desabilitado:

```lua
Config.Interface.organizationLeadershipTransfer = false
```

Habilitar o gate não substitui `members.set_leader`.

## Componentes

### `mz_core`

- `server/orgs/repository.lua`: contagem de membros ativos/não expirados no cargo, identificação de líder apenas nos tipos suportados e transação dedicada com assertion de rollback.
- `server/orgs/service.lua`: revalidação do ator, tipo, capability, liderança única, alvo, hierarquia, revision e resposta segura.
- `server/orgs/exports.lua`: export explícito `TransferOrganizationLeadership`.

### `mz_org`

- `shared/config.lua`: gate opt-in.
- `shared/menu_organization_mutations.lua`: whitelist exclusiva do payload.
- `server/menu_organization_reads.lua`: estado visual seguro da ação.
- `server/menu_organization_operations.lua`: evento explícito, rate limit, in-flight, envelope, capability e exigência de `auditId`.
- `client/menu/organization_members.lua`: seleção de candidato, motivo e confirmação forte.
- `client/menu/organization.lua`: estado operacional condicionado ao gate.
- `shared/menu_profiles.lua`: contrato fail-closed dos tipos que suportam liderança.

### Teste

- `tests/lot6d_contract_harness.lua`: comportamento do service com dependências isoladas, sanitização e invariantes estruturais.

## Decisões

- o contrato Staff anterior foi preservado;
- `SetOrgLeaderByCitizenId` continua separado, mas também recusa VIP;
- VIP usa níveis de privilégio, sem líder, transferência ou gestão de membership por seus membros;
- em VIP, apenas leituras básicas e capabilities `vip.*` são efetivas;
- capabilities organizacionais legadas incompatíveis em VIP são ignoradas em leitura/autorização e podem ser removidas por Staff autorizado;
- nenhuma tabela ou coluna foi criada;
- liderança continua derivada do maior cargo ativo;
- múltiplos líderes não são corrigidos automaticamente;
- a organização primária dos jogadores é preservada;
- `staff.*`, ACE e owner não são fallback;
- a revision organizacional muda com a transferência;
- houve smoke parcial informado pelo operador para `/org` e happy path da Máfia; o checklist integral não foi executado nesta sessão.

## Compatibilidade

- exports anteriores do `mz_core` preservados;
- API do `mz_menu` não alterada;
- eventos e callbacks legados preservados;
- modo híbrido preservado;
- sem React, Vite, TypeScript, JSX ou TSX;
- nenhuma mudança de banco ou migration.

## Pendências

- checklist runtime acompanhado;
- perfil seguro aplicado em 2026-07-25: debug, mock de desenvolvimento e comandos de teste iniciam desabilitados;
- hardening transacional das mutações históricas que ainda auditam após a escrita;
- reparo Staff explícito para estado com zero/múltiplos líderes;
- quick integrations após inventário de contratos reais;
- hierarquia e atribuição de Staff em domínio separado;
- regressão completa antes de `mode = 'menu'`.
