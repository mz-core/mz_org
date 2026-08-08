# Contrato de leitura do Staff Menu

## Escopo e autoridade

O Staff Menu e um contexto global separado do menu organizacional. Ele usa o perfil visual `staff`, nunca o tema da organizacao selecionada, e nao aceita capabilities organizacionais como autorizacao.

Origens aceitas para `staff.*`:

1. owner ACE;
2. ACE global explicito;
3. override global confirmado por `mz_core:HasGlobalPermission`.

Cargo, membership, heranca e `CanOrg` nao podem abrir ou ampliar o Staff Menu.

## Comandos

| Comando | Comportamento |
| --- | --- |
| `/stafforg` | Entrada primaria do novo menu. Sempre resolve acesso no servidor. |
| `/staff` | Permanece legado por padrao. So aponta ao menu novo com `staffAliasCommandEnabled = true`. |

Configuracao:

```lua
Config.MenuArchitecture = {
  enabled = true,
  staffMenuEnabled = true,
  staffCommand = 'stafforg',
  staffAliasCommandEnabled = false,
  legacyStaffCommandEnabled = true,
  pageSize = 20
}
```

## Matriz de modulos

| Modulo | Permissao global | Owner |
| --- | --- | --- |
| `overview` | Qualquer permissao Staff global relevante | Sim |
| `organizations` | `staff.orgs.view` | Sim |
| `logs` | `staff.logs.view` | Sim |
| `audit` | `staff.logs.view` | Sim |
| `legacy` | `staff.orgs.view` | Sim |

`staff.orgs.manage`, `staff.orgs.create`, `staff.orgs.set_leader` e `staff.members.*` nao funcionam como wildcard de leitura neste lote. Podem identificar o usuario como Staff no overview, mas nao liberam outro dominio.

## Transporte contextual

Toda leitura posterior a entrada envia:

```lua
{
  requestId = 123, -- argumento de transporte
  _context = {
    sessionId = 's2:...',
    sessionRevision = 's2:...',
    contextKey = 'staff:organizations:org:police',
    module = 'organizations',
    orgCode = 'police'
  }
}
```

O servidor exige revisao atual, igualdade entre `sessionId` e `sessionRevision`, modulo exato, chave de contexto exata e `orgCode` exato quando aplicavel. O client ainda compara kind, geracao, revisao, modulo, chave e organizacao antes de entregar a resposta ao builder.

Estados `staff` e `organization` possuem geracoes separadas no mesmo request manager. Somente um kind fica ativo. Fechar o menu invalida a geracao Staff e elimina a organizacao selecionada.

## Endpoints

| Evento | Modulo | Permissao | Entrada principal | Saida |
| --- | --- | --- | --- | --- |
| `mz_org:server:resolveStaffMenuEntry` | entrada | qualquer Staff relevante | nenhuma | `StaffEntryDTO` |
| `mz_org:server:staffListOrganizations` | organizations | `staff.orgs.view` | filtros/pagina | `OrganizationPageDTO` |
| `mz_org:server:staffGetOrganization` | organizations | `staff.orgs.view` | `orgCode` exato | `StaffOrganizationInspectionDTO` |
| `mz_org:server:staffListGlobalLogs` | logs | `staff.logs.view` | filtros/offset | logs globais |
| `mz_org:server:staffListOrgLogs` | logs | `staff.logs.view` + contexto de inspecao | `orgCode` exato | logs da org |
| `mz_org:server:staffListGlobalAudit` | audit | `staff.logs.view` | filtros/offset | auditoria global |
| `mz_org:server:staffListOrgAudit` | audit | `staff.logs.view` + contexto de inspecao | `orgCode` exato | auditoria da org |
| `mz_org:server:staffListLegacyDiagnostics` | legacy | `staff.orgs.view` | pagina | capabilities ignoradas |

Existe ainda o export server `ResolveStaffMenuEntry(source)` para integracoes internas.

## DTO de entrada

```lua
{
  session = { sessionId, revision },
  contextKey = 'staff:root',
  user = { name, serverId, isOwner, identity },
  permissions = { 'staff.orgs.view' },
  modules = { 'overview', 'organizations', 'legacy' },
  counts = { activeOrganizations, archivedOrganizations, restricted },
  readOnly = true,
  presentation = StaffProfile
}
```

Somente modulos autorizados sao enviados.

## Listagem e busca

- pagina inicial: 1;
- tamanho padrao: 20;
- tamanho maximo: 25;
- filtros de estado: `all`, `active`, `archived`;
- tipos: `job`, `gang`, `business`, `government`, `vip`, `event`;
- busca: nome, codigo ou ID estrutural;
- a busca usa campos estruturais do DTO oficial, nunca `config_json`;
- membros e lideranca nao sao carregados para toda a lista; aparecem como `Sob demanda` e sao resolvidos somente na inspecao selecionada.

## Inspecao

`GetStaffOrgInspection` e um read model oficial e aditivo do `mz_core`. Ele permite Staff autorizado consultar organizacao ativa ou arquivada e retorna:

- metadados e config decodificada;
- lideranca identificavel;
- membros da organizacao selecionada;
- cargos ativos e inativos;
- capabilities organizacionais resolvidas sem `staff.*`;
- capabilities legadas `staff.*` separadas, com status `ignored`.

O `mz_org` acrescenta a explicacao de features e aparencia, pois essas sao regras da interface.

## Features e aparencia

Cada feature informa default do perfil, override, dependencia, resultado e origem. Organizacao arquivada tem resultado efetivo desabilitado por `organization_status`.

Cada campo de aparencia informa valor sanitizado e origem: tipo, perfil, override da organizacao ou default do `mz_org`. A tela nunca usa esse tema no cabecalho Staff; ele e apenas inspecionado.

## Logs e auditoria

> Sucessão de interface em 2026-07-27: logs e auditoria globais passaram para `/admin → Logs administrativos`. Os eventos globais abaixo permanecem registrados para compatibilidade, mas não são mais montados no root de `/stafforg`. A inspeção Staff de cada organização continua usando os endpoints organizacionais deste contrato.

Consultas globais usam `org_code IS NULL`. Consultas de organizacao usam `org_code = ?`. Nao existe fallback entre os escopos.

Filtros do caminho Staff:

- categoria/escopo exato;
- acao exata;
- ator estrutural exato;
- data inicial/final;
- `auditId` exato;
- somente registros com `auditId`, na auditoria.

O caminho Staff organizacional nao envia o filtro legado `search`; portanto nao usa busca em JSON ou correspondencia parcial. `auditId` passou a fazer parte do DTO aditivo de logs do core. A nova visualizacao global do `mz_admin` possui contrato próprio e aceita `search` sanitizado.

## Arquivadas

Arquivadas aparecem somente na listagem Staff autorizada, recebem badge `Arquivada` e usam o read model Staff. Os endpoints organizacionais comuns continuam bloqueando-as. Nenhuma opcao de reativar, editar ou remover e montada.

## Diagnostico legado

O diagnostico lista organizacao, cargo, permission key, valor armazenado, status `ignored` e recomendacao. Ele nao remove, corrige ou migra registros.
