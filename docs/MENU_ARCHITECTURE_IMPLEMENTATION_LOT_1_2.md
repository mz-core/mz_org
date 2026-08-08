# Implementacao da arquitetura de menus - Lotes 1 e 2

## Resultado implementado

O corte entrega o tema por contexto no `mz_menu` e a primeira interface organizacional read-only do `mz_org`. O `mz_core` continua sendo a fonte de player, membership, organizacao, capabilities e membros. Nenhuma tabela ou autoridade paralela foi criada.

## Fronteiras

```text
mz_core
  dados, membership, capabilities e leitura oficial
      |
      v
mz_org server
  sessao V2, org ativa, revalidacao e DTO seguro
      |
      v
mz_org client/menu
  request contextual, seletor e builders read-only
      |
      v
mz_menu
  renderizacao, navegacao e tema
```

O `mz_menu` nao contem regras de organizacao. O `mz_org` nao persiste dados de dominio. Toda leitura usada pelo novo menu volta ao servidor.

## Lote 1 - `mz_menu`

- `theme` opcional e parcial em qualquer contexto;
- validacao `#RRGGBB`, posicao e largura 320-640;
- heranca pelo campo `menu`;
- `brand`, `headerIcon` e `badge` opcionais;
- restauracao do tema global ao fechar;
- defesa equivalente na NUI;
- teste `/mz_menu_theme_test` com sete perfis;
- nenhum export anterior removido.

O contrato detalhado esta em `mz_menu/docs/CONTEXT_THEME_CONTRACT.md`.

## Lote 2 - `mz_org`

### Feature flags

```lua
Config.Interface = {
  mode = 'hybrid',
  staffMenu = false,
  organizationMenu = true,
  legacyPanel = true,
  legacyCommands = true
}
```

No modo `hybrid`, `/org`, `/painel` e aliases organizacionais usam o menu novo. O comando de desenvolvimento e `/staff` continuam podendo abrir o legado enquanto as duas flags legadas estiverem ativas. No modo `menu`, o legado nao abre. `staffMenu = false` documenta que o Staff menu novo ainda nao existe.

### Perfis e features

`shared/menu_profiles.lua` concentra os perfis `job`, `gang`, `business`, `government`, `vip`, `event` e `staff`. O resolver aceita somente:

- perfil conhecido;
- cores `#RRGGBB`;
- icone do catalogo local;
- textos limitados;
- posicao conhecida;
- largura 320-640.

O resolver ja le `config.ui` vindo do snapshot oficial da organizacao, permitindo override visual seguro sem CSS arbitrario. Ele nao escreve `config_json`.

`shared/menu_features.lua` define a matriz unica de modulos. A resolucao server-side combina defaults do perfil, overrides booleanos, flags oficiais, status ativo e capabilities organizacionais. Entradas `staff.*` sao descartadas da matriz.

### Request manager contextual

`client/menu/request.lua` centraliza tanto requests do frontend legado quanto requests do novo menu. Para requests organizacionais ele registra:

- `requestId`;
- `sessionId`;
- `sessionRevision`;
- `contextKey`;
- `orgCode`;
- geracao local de navegacao.

Trocar seletor ou organizacao incrementa a geracao. Uma resposta atrasada, de revisao anterior ou de outro `orgCode` e removida sem atualizar ou reabrir menus. Fechar seletor, raiz ou submenu invalida o contexto.

### Fluxo de comandos

- `/org` e `/painel`: consultam a sessao no servidor sem filtro;
- um resultado: abre diretamente;
- varios resultados: abre o seletor;
- nenhum resultado ativo/autorizado: notifica e nao abre;
- organizacao arquivada: e rejeitada tanto na sessao quanto no endpoint de contexto;
- `/gang`, `/business`, `/government`, `/vip` e `/event`: aplicam somente filtro sobre `session.organizations` do jogador.

O tipo real da organizacao permanece separado do perfil visual escolhido por override.

### Telas entregues

- seletor de organizacoes;
- menu raiz organizacional;
- visao geral read-only;
- lista de membros read-only.

A visao geral apresenta organizacao, tipo, cargo, duty, quantidade de membros, disponibilidade de conta e features ativas. A lista de membros nao oferece callbacks de escrita.

### Revalidacao server-side

`server/menu_organization.lua` exige organizacao ativa, `org.view`, membership presente na sessao V2 e codigo exato. O total de membros vem de `ListOrgMembers`. A tela de membros reutiliza o controller existente, que agora falha fechado quando a leitura oficial nao esta disponivel e revalida organizacao ativa antes da capability.

## Compatibilidade

- dependency de `mz_menu` foi adicionada sem remover `mz_core` ou `oxmysql`;
- NUI, arquivos web, callbacks, controllers e comandos legados foram preservados;
- o request manager legado manteve o envelope contextual e o formato das respostas;
- a lista `legacyOrgs` continua traduzindo `job` para `legal` para o frontend antigo;
- nenhum export do `mz_core` foi alterado por este lote;
- nenhum arquivo React, Vite, TypeScript, JSX ou TSX foi criado.

## Fora do escopo confirmado

Nao foram iniciados:

- Staff menu novo, read-only ou operacional;
- convite, remocao, promocao ou rebaixamento pelo menu novo;
- mutacoes de cargos ou permissions;
- deposito, saque ou gestao de conta;
- mutacoes de metas ou recrutamento;
- editor/persistencia de override visual.

