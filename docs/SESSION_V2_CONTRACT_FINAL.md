# Contrato final de sessao V2

Status: implementado estaticamente na Fase 0. Validacao runtime no FiveM permanece obrigatoria.

## Autoridade e versao

O contrato e construido por `mz_org/server/session.lua` a partir da identidade e dos contextos retornados pelo `mz_core`. A NUI informa somente a entrada desejada. Nenhum campo recebido da NUI concede acesso.

Campos de versao obrigatorios:

- `version = 2`;
- `contractVersion = 2`, alias temporario para consumidores do contrato anterior;
- `revision`, identificador opaco renovado a cada construcao;
- `sessionId`, alias temporario de `revision`.

Uma nova `revision` invalida rotas, caches e respostas da anterior.

## Estrutura

```ts
type PermissionGrant = {
  permission: string;
  source: "owner" | "ace" | "mz_core_global";
};

type OrganizationContext = {
  id: `org:${string}`;
  kind: "organization";
  code: string;
  name: string;
  type: "legal" | "gang" | "business" | "government" | "vip" | "event" | string;
  status: "active" | "archived" | "inactive";
  grade: { id: number | null; level: number; code: string; name: string };
  membership: {
    citizenId: string | null;
    grade: { id: number | null; level: number; code: string; name: string };
    isPrimary: boolean;
    isDuty: boolean;
    joinedAt: string | null;
  };
  capabilities: string[];
  features: string[];
  entryAllowed: boolean;
  readOnly: boolean;
  flags: { hasSalary: boolean; hasSharedAccount: boolean; hasStorage: boolean };
};

type StaffContext = {
  id: "staff";
  kind: "staff";
  entryAllowed: true;
  permissions: string[];
  capabilities: string[]; // alias temporario
  features: string[];
  readOnly: boolean;
};

type SessionV2 = {
  version: 2;
  contractVersion: 2;
  revision: string;
  sessionId: string;
  generatedAt: string;
  user: {
    source: number;
    serverId: number;
    name: string;
    citizenid: string | null;
    citizenId: string | null;
    isOwner: boolean;
    globalPermissions: string[]; // legado
  };
  requestedEntry: {
    id: "hub" | "organization" | "staff";
    command: string | null;
    requestedOrgCode: string | null;
    requestedType: string | null;
  };
  entryAllowed: boolean;
  denialReason: "entry_not_allowed" | "context_not_found" | null;
  defaultContextId: `org:${string}` | "staff" | null;
  entrypoints: {
    hub: true;
    staffWorkspace: boolean;
    organizationWorkspaces: string[];
  };
  global: {
    permissions: string[];
    permissionGrants: PermissionGrant[];
    features: string[];
  };
  organizations: OrganizationContext[];
  contexts: OrganizationContext[]; // alias temporario
  staff: StaffContext | null;
  staffContext: StaffContext | null; // alias temporario
  compatibility: { modules: string[] };
  orgs: unknown[]; // DTO legado derivado da V2
  modules: string[]; // alias legado derivado da V2
};
```

## Resolucao de entrada

`ResolvePanelEntry(source, requestedContext)` e a guarda central. Ela usa o `source` real e retorna a sessao resolvida, sem confiar em `requestedContext` como autorizacao.

- Hub: permitido para uma sessao valida.
- Organizacao: exige membership/contexto ativo e `org.view` revalidado no core.
- Staff: exige ao menos uma feature Staff derivada de permissao global real.
- Tipo da organizacao apenas filtra contextos; nao concede rota nem capability.
- Contexto solicitado inexistente retorna `context_not_found`.
- Entrada negada nunca recebe o modulo legado `staff`.

## Permissoes globais

As unicas origens aceitas sao:

1. owner ACE configurado;
2. ACE global explicito da permissao;
3. `mz_core:HasGlobalPermission` retornando booleano `true` por override global explicito.

Falha, ausencia ou retorno `nil` do export resulta em negacao. Membership, cargo, heranca e permissao organizacional `staff.*` nao criam contexto Staff.

## Organizacoes e features

Somente organizacoes ativas com membership valido e `org.view` entram em `organizations`. Organizacoes arquivadas nao entram no workspace pessoal.

Features atuais materializadas pelo servidor:

- comuns: `overview`, `members`, `grades`, `goals`, `recruitment`, `logs`;
- `bank`: somente quando `hasSharedAccount` e verdadeiro.

Feature informa existencia funcional. Capability informa autorizacao. A frontend deve exigir ambas.

## Staff parcial

Features Staff sao derivadas somente de permissoes globais especificas:

- `overview`: owner ou `staff.panel.open`;
- `organizations`: `staff.orgs.view|manage|create|set_leader`;
- `logs`: `staff.logs.view`;
- `members`: uma das `staff.members.*`;
- `players`: uma das permissões granulares `staff.players.*`;
- `staff`: `staff.roles.manage`.

Ter uma feature nao autoriza todas as acoes dentro dela. Cada endpoint revalida sua permissao especifica.

## Compatibilidade legada

`orgs`, `modules` e `user.globalPermissions` sao derivados da V2. A direcao inversa e proibida. O legado nao pode criar Staff por fallback de `dashboard`.

## Transporte contextual V2

Request:

```json
{
  "version": 2,
  "requestId": "frontend-opaque-id",
  "sessionRevision": "s2:41:1721577600:1",
  "context": { "kind": "organization", "key": "org:police", "orgCode": "police" },
  "payload": { "orgCode": "police" }
}
```

Response:

```json
{
  "ok": true,
  "requestId": "frontend-opaque-id",
  "sessionRevision": "s2:41:1721577600:1",
  "contextKey": "org:police",
  "data": {}
}
```

O bridge Lua preserva e ecoa os metadados, mas envia somente `payload` ao handler de dominio. O envelope nunca substitui a autorizacao server-side. `MZOrgContext.IsResponseCurrent` permite identificar resposta obsoleta.

## Codigos de negacao

- `invalid_source`;
- `session_unavailable`;
- `entry_not_allowed`;
- `context_not_found`.

## Aceite runtime pendente

O contrato nao e considerado aprovado em producao ate executar os cenarios de `PHASE_0_SECURITY_TEST_CHECKLIST.md` dentro do FiveM.
