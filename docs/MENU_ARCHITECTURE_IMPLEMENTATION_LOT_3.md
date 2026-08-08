# Implementacao da arquitetura de menus - Lote 3

## Resultado

Foi adicionado o Staff Menu estrutural e somente leitura em `mz_menu`, separado do workspace organizacional. `/stafforg` resolve acesso no servidor, recebe somente modulos globais autorizados e revalida cada leitura.

## Componentes

### Client

- `client/menu/staff.lua`: entrada, perfil Staff, overview e raiz;
- `client/menu/staff_organizations.lua`: busca, filtros, paginacao, inspecao e diagnostico;
- `client/menu/staff_logs.lua`: logs e auditoria globais/organizacionais;
- `client/menu/request.lua`: o mesmo manager dos Lotes 1/2, agora com estados `staff` e `organization` separados.

### Server

- `server/menu_staff.lua`: resolver central, guards por modulo e endpoints explicitos;
- `server/session.lua`: revisao corrente consultavel para rejeitar requests Staff obsoletos.

### Shared

- `menu_profiles.lua`: informa a origem de cada valor visual;
- `menu_features.lua`: explica profile, override, dependencia, resultado e origem;
- `context.lua`: transporta tambem o modulo solicitado.

## Read models adicionados ao `mz_core`

O inventario mostrou que os exports anteriores nao permitiam cumprir dois requisitos sem duplicar repository no `mz_org`:

1. `ListOrgMembers` bloqueia arquivadas, corretamente para o workspace comum;
2. `GetOrgAccessModel` remove `staff.*`, corretamente para autorizacao, mas isso impede o diagnostico read-only.

Foram adicionados:

- `GetStaffOrgInspection(source, orgCode)`;
- `ListLegacyStaffOrgPermissions(source)`.

Ambos exigem owner ou `staff.orgs.view`. O primeiro permite leitura exata de uma organizacao arquivada sem liberar os endpoints comuns. O segundo apenas reporta capabilities legadas ignoradas.

O DTO de logs passou a expor `auditId` e aceitar filtros SQL estruturais exatos por acao, ator e auditId, alem de `auditOnly`. Sao mudancas aditivas; exports anteriores permanecem.

## Navegacao

```text
/stafforg
  -> resolveStaffMenuEntry
  -> Staff root
     -> overview
     -> search/list organizations
        -> inspect selected organization
           -> summary / leader / members / grades / features / appearance
           -> org logs / org audit, quando staff.logs.view
     -> global logs
     -> global audit
     -> legacy diagnostic
```

Todas as opcoes sao read-only ou abrem outra leitura. Nao existem eventos de escrita no caminho novo.

## Compatibilidade

- `/staff` continua legado por padrao;
- o alias novo exige `staffAliasCommandEnabled = true`;
- `/org`, `/painel` e aliases organizacionais nao foram alterados semanticamente;
- frontend, callbacks e controllers legados permanecem;
- 14 exports do `mz_menu` permanecem;
- exports publicos anteriores do `mz_core` permanecem;
- `mz_houses` continua usando a mesma API;
- nenhum React, Vite, TypeScript, JSX ou TSX foi criado.

## Ausencias conhecidas tratadas

O export geral `ListOrgs` nao oferece lideranca nem quantidade de membros por linha. Para evitar N+1 e nao carregar membros de todas as organizacoes, a listagem marca esses campos como `Sob demanda`. Ambos aparecem na inspecao exata da organizacao selecionada.

## Fora de escopo confirmado

Nao foram criados endpoints, options ou callbacks novos para criar, editar, arquivar, reativar, apagar, definir lideranca, alterar membros/cargos/capabilities/features/aparencia, movimentar dinheiro, gerir metas ou recrutamento.

