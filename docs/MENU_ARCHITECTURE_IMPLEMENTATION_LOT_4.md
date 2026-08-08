# Implementacao da arquitetura de menus - Lote 4

## Resultado

O Staff Menu do `mz_menu` passou a executar administracao basica e ciclo de vida de organizacoes. O corte permite criar, editar dados basicos, alterar tipo, configurar features, configurar aparencia, pre-visualizar localmente, arquivar e reativar.

Continuam fora do menu novo: membros, lideranca, cargos, capabilities organizacionais, banco, metas e recrutamento.

## Fronteiras

```text
mz_menu
  renderiza contexto, input, confirmacao e preview temporario
      |
mz_org client
  builders, drafts locais e descarte de respostas antigas
      |
mz_org server
  sessao, permissao exata, whitelist e regras de interface
      |
mz_core
  revisao duravel, persistencia oficial e transacao com auditoria
```

O cliente nunca envia `config_json`. O `mz_org` envia patches de dominio. O `mz_core` rele a organizacao, faz merge controlado, preserva outros dominios e persiste o JSON final.

## Permissoes do caminho novo

| Permissao | Escopo |
| --- | --- |
| `staff.orgs.view` | listar e inspecionar |
| `staff.orgs.create` | criar |
| `staff.orgs.edit` | dados basicos e tipo |
| `staff.orgs.archive` | arquivar |
| `staff.orgs.restore` | reativar |
| `staff.orgs.features` | features |
| `staff.orgs.appearance` | aparencia |

Owner possui todas. Nenhuma permissao e wildcard. Para operar uma organizacao existente pela interface, o usuario tambem precisa de `staff.orgs.view`, pois a leitura nao e concedida pela permissao de mutacao.

`staff.orgs.manage` continua reconhecida pela sessao legada e pelo overview, mas nao concede nenhuma acao do Lote 4.

## Menus

Raiz Staff:

- visao geral;
- criar organizacao, somente com `staff.orgs.create`;
- busca/listagens, somente com `staff.orgs.view`;
- logs, auditoria e diagnostico do Lote 3.

Organizacao ativa:

- resumo, lideranca, membros e cargos read-only;
- editar dados basicos;
- alterar tipo com previa de impacto;
- configurar features;
- configurar aparencia e preview;
- arquivar com confirmacao forte;
- logs e auditoria.

Organizacao arquivada:

- todas as leituras do Lote 3;
- nenhuma edicao comum;
- reativar, somente com permissao especifica.

## Endpoints adicionados

| Evento | Permissao |
| --- | --- |
| `mz_org:server:staffCreateOrganization` | `staff.orgs.create` |
| `mz_org:server:staffUpdateOrganizationBasic` | `staff.orgs.edit` |
| `mz_org:server:staffPreviewOrganizationType` | `staff.orgs.edit` |
| `mz_org:server:staffChangeOrganizationType` | `staff.orgs.edit` |
| `mz_org:server:staffUpdateOrganizationFeatures` | `staff.orgs.features` |
| `mz_org:server:staffUpdateOrganizationAppearance` | `staff.orgs.appearance` |
| `mz_org:server:staffArchiveOrganization` | `staff.orgs.archive` |
| `mz_org:server:staffRestoreOrganization` | `staff.orgs.restore` |

Nao existe dispatcher generico de mutacao.

## Mudancas aditivas no mz_core

### Schema

`mz_orgs.revision BIGINT UNSIGNED NOT NULL DEFAULT 1` foi adicionado. Updates oficiais incrementam a revisao no banco; o cliente nunca calcula a revisao.

### Exports

- `CreateStaffOrganization`;
- `UpdateStaffOrganizationBasic`;
- `ChangeStaffOrganizationType`;
- `UpdateStaffOrganizationFeatures`;
- `UpdateStaffOrganizationAppearance`;
- `ArchiveStaffOrganization`;
- `RestoreStaffOrganization`.

### Transacao

Criacao inclui organizacao, grades do template, capabilities oficiais, conta oficial com saldo zero quando o template exige shared account, e auditoria na mesma transacao. Nao existe movimentacao financeira. Updates usam `WHERE code = ? AND revision = ?`, incrementam a revisao e inserem `mz_logs.audit_id` na mesma transacao.

Se o INSERT de auditoria falhar, a transacao retorna falha e a alteracao e revertida. Sucesso sem `auditId` e recusado tambem pelo `mz_org`.

## Idempotencia

O `auditId` e deterministico para operacao, source, revisao de sessao e `requestId`. A constraint unica de `mz_logs.audit_id` impede repeticao concorrente. Retry identico devolve o resultado existente com `idempotent = true`; reutilizacao divergente nao executa nova mutacao.

## Invalidacao

Apos commit, o `mz_core` emite somente o evento server-side interno `mz_core:internal:organizationChanged`, atualiza os snapshots dos membros online e informa codigo, acao, revisao, auditId e source autor.

O `mz_org` invalida revisoes de sessao Staff e organizacionais afetadas. Outros clientes com menu aberto recebem fechamento seguro e precisam reabrir. O autor recebe primeiro a resposta confirmada e abre nova sessao/inspecao com o DTO efetivo.

## Integracoes verificadas

- `mz_houses`: exports antigos preservados; listagens filtram `active ~= false`. Existe cache proprio de grupos com TTL de 10 segundos, portanto uma referencia visual pode permanecer durante esse limite.
- `mz_garagem`: usa `GetPlayerOrgs`; snapshots de membros online sao recarregados apos mudanca.
- `mz_realestate`: usa `GetOrgByCode` e possui fallback SQL proprio. O fallback filtra `active = 1`; o export pode retornar metadata arquivada para leitura administrativa.
- `mz_bank`, `mz_economy` e `mz_phone`: nenhuma dependencia estatica direta dos exports de organizacao foi encontrada.
- saldo, memberships, lideranca e cargos existentes nao sao alterados por archive/restore/type.

Nenhum desses resources foi modificado neste lote.

## Compatibilidade

- 14 exports do `mz_menu` preservados;
- callbacks NUI legados preservados;
- `/staff` continua legado por padrao;
- `/stafforg`, `/org`, `/painel` e aliases mantidos;
- read models do Lote 3 mantidos;
- exports anteriores do `mz_core` mantidos;
- `config_json` de outros dominios preservado;
- nenhum React, Vite, TypeScript, TSX ou JSX.

## Arquivos principais

Client:

- `client/menu/staff_mutations.lua`;
- `client/menu/staff_features.lua`;
- `client/menu/staff_appearance.lua`.

Server:

- `server/menu_staff_mutations.lua`.

Core:

- `server/orgs/staff_mutations.lua`;
- `server/orgs/staff_mutation_repository.lua`.

Shared:

- `shared/menu_mutations.lua`;
- extensoes fechadas em `shared/menu_features.lua` e `shared/menu_profiles.lua`.

## Fora do escopo e Lote 5

Permanecem pendentes: definir/remover lider, membros, promocao/rebaixamento, cargos, capabilities, banco, metas, recrutamento, uploads, URLs de logos, hard delete e editor grafico avancado.

## Validacao estatica desta entrega

```text
FINAL STATIC PASS lua=44 node=6 diff=3 menu_exports=14 nui_callbacks=35
                  houses=20 garage=17 harness=25 forbidden=0
AUDIT PASS canorg_staff=0 haspermission=0 hard_delete=0 orgcode_like=0
           integral_config_payload=0 request_manager_bypass=0
```

Os contadores Lua/JavaScript incluem o worktree acumulado dos lotes anteriores. A aprovacao runtime continua condicionada ao checklist do Lote 4.
