# Frontend V2 — contrato de sessão e contexto

> Status (2026-07-21): proposta consolidada e implementada. O contrato normativo de runtime, incluindo aliases legados, esta em `SESSION_V2_CONTRACT_FINAL.md`. `version=2`, `revision`, `global`, `organizations` e `staff` separados estao ativos; runtime FiveM ainda nao foi aprovado.

## Objetivo

Este contrato substitui a inferência de acesso feita hoje pelo frontend. A sessão deve dizer, de forma explícita, quais contextos o jogador pode abrir, quais capacidades possui em cada organização e se existe um contexto global de Staff. O frontend usa essa informação para navegação e apresentação; o servidor continua sendo a autoridade em toda leitura e mutação.

O contrato proposto é versionado como `2` e pode ser entregue pelo callback existente `session:get` e pelo evento existente `session:set`. Não é necessário criar um novo callback para iniciar a migração.

## Regras normativas

1. `requestedEntry` representa a intenção de entrada (`hub`, `organization` ou `staff`), nunca uma autorização.
2. O servidor resolve `entryAllowed`, `denialReason` e `defaultContextId` usando a identidade real de `source`.
3. `contexts` contém somente organizações às quais o jogador pode acessar.
4. Cada organização possui seu próprio conjunto de `capabilities`; capacidades de uma organização não podem liberar outra.
5. `staffContext` contém apenas capacidades globais de Staff. Ele não deve ser derivado da soma das permissões dos cargos organizacionais.
6. `features` é derivado no servidor de tipo, estado e configuração da organização. Ele não substitui a validação de capacidade.
7. `modules` existe apenas durante a compatibilidade com o frontend legado. Não é fonte de autoridade na V2.
8. Códigos de organização recebidos por rotas ou callbacks são seletores. Toda operação deve revalidar o contexto no servidor.
9. Uma sessão nova invalida cache, requisições e estado derivados da sessão anterior.

## Tipos de referência

```ts
type EntryId = "hub" | "organization" | "staff";
type ContextId = `org:${string}` | "staff";

type FeatureState = {
  enabled: boolean;
  readOnly?: boolean;
  reason?: string;
};

type OrganizationFeatures = {
  overview: FeatureState;
  members: FeatureState;
  grades: FeatureState;
  goals: FeatureState;
  bank: FeatureState;
  recruitment: FeatureState;
  logs: FeatureState;
};

type OrganizationContext = {
  id: `org:${string}`;
  kind: "organization";
  organization: {
    code: string;
    name: string;
    type: "legal" | "illegal" | "vip" | "business" | "government" | "event" | string;
    status: "active" | "archived" | "inactive";
  };
  membership: {
    citizenId: string;
    grade: {
      id: number | null;
      level: number;
      code: string;
      name: string;
    };
    isPrimary: boolean;
    isDuty: boolean | null;
    joinedAt: string | null;
  };
  capabilities: string[];
  features: OrganizationFeatures;
};

type StaffContext = {
  id: "staff";
  kind: "staff";
  capabilities: string[];
  scope: {
    mode: "all" | "allowlist";
    orgCodes: string[];
  };
  features: {
    organizations: FeatureState;
    members: FeatureState;
    grades: FeatureState;
    bank: FeatureState;
    recruitment: FeatureState;
    goals: FeatureState;
    logs: FeatureState;
  };
};

type SessionV2 = {
  contractVersion: 2;
  sessionId: string;
  generatedAt: string;
  user: {
    serverId: number;
    citizenId: string;
    name: string;
    isOwner: boolean;
  };
  requestedEntry: {
    id: EntryId;
    command: string | null;
    requestedOrgCode: string | null;
  };
  entryAllowed: boolean;
  denialReason: "entry_not_allowed" | "context_not_found" | "session_unavailable" | null;
  defaultContextId: ContextId | null;
  contexts: OrganizationContext[];
  staffContext: StaffContext | null;
  compatibility: {
    modules: string[];
  };
};
```

`grade.name` é obrigatório na V2. O contrato atual documenta esse campo, mas o servidor não o entrega. `id`, `isDuty` e datas podem continuar nulos até que o core possua esses dados de forma confiável.

## Resolução da entrada

O cliente envia apenas a entrada solicitada:

```json
{
  "requestedEntry": "organization",
  "requestedOrgCode": "police",
  "command": "org"
}
```

O servidor aplica esta ordem:

1. carrega a identidade pelo `source` real;
2. monta os contextos organizacionais autorizados;
3. monta Staff somente a partir de Owner, ACE ou permissões globais dedicadas;
4. valida a entrada solicitada;
5. escolhe um `defaultContextId` acessível;
6. retorna a sessão inteira e emite `session:set` com o mesmo `sessionId`.

Regras recomendadas:

- `hub`: sempre permitido quando a sessão do jogador existe;
- `organization`: permitido quando há ao menos um contexto organizacional acessível; um `requestedOrgCode` inválido não deve ser usado como fallback silencioso;
- `staff`: permitido apenas quando `staffContext` não é nulo e possui ao menos uma feature visível;
- comando de tipo (`/gang`, `/vip` etc.): escolhe somente entre contextos daquele tipo; se não houver, nega a entrada;
- o frontend não abre o shell definitivo antes de receber `entryAllowed: true`.

## Semântica de capacidades e features

Capacidade responde **“este jogador pode executar esta ação neste contexto?”**. Feature responde **“este produto está disponível para esta organização?”**.

Exemplos:

- `features.bank.enabled = true` e ausência de `account.view`: banco existe, mas não deve aparecer para esse membro;
- `features.recruitment.enabled = false`: recrutamento não aparece, mesmo que um cargo legado ainda carregue uma permissão relacionada;
- `features.logs.readOnly = true`: a rota pode existir sem ações de mutação.

A rota fica visível somente quando a feature está habilitada e a capacidade mínima da rota está presente. O backend repete a validação usando `source` e o contexto alvo.

## Exemplos completos

### Jogador sem organização

```json
{
  "contractVersion": 2,
  "sessionId": "s:41:1721577600",
  "generatedAt": "2026-07-21T15:00:00Z",
  "user": { "serverId": 41, "citizenId": "CID041", "name": "Ana", "isOwner": false },
  "requestedEntry": { "id": "hub", "command": "mzorg", "requestedOrgCode": null },
  "entryAllowed": true,
  "denialReason": null,
  "defaultContextId": null,
  "contexts": [],
  "staffContext": null,
  "compatibility": { "modules": ["dashboard"] }
}
```

### Jogador com uma organização

```json
{
  "contractVersion": 2,
  "sessionId": "s:52:1721577601",
  "generatedAt": "2026-07-21T15:00:01Z",
  "user": { "serverId": 52, "citizenId": "CID052", "name": "Bruno", "isOwner": false },
  "requestedEntry": { "id": "organization", "command": "org", "requestedOrgCode": "police" },
  "entryAllowed": true,
  "denialReason": null,
  "defaultContextId": "org:police",
  "contexts": [
    {
      "id": "org:police",
      "kind": "organization",
      "organization": { "code": "police", "name": "Polícia", "type": "legal", "status": "active" },
      "membership": {
        "citizenId": "CID052",
        "grade": { "id": 3, "level": 2, "code": "officer", "name": "Oficial" },
        "isPrimary": true,
        "isDuty": true,
        "joinedAt": "2026-04-10T20:15:00Z"
      },
      "capabilities": ["org.view", "members.view", "goals.view", "account.view"],
      "features": {
        "overview": { "enabled": true },
        "members": { "enabled": true },
        "grades": { "enabled": true },
        "goals": { "enabled": true },
        "bank": { "enabled": true },
        "recruitment": { "enabled": true },
        "logs": { "enabled": true, "readOnly": true }
      }
    }
  ],
  "staffContext": null,
  "compatibility": { "modules": ["dashboard", "legal", "members", "goals", "bank"] }
}
```

### Jogador com múltiplas organizações

```json
{
  "contractVersion": 2,
  "sessionId": "s:63:1721577602",
  "generatedAt": "2026-07-21T15:00:02Z",
  "user": { "serverId": 63, "citizenId": "CID063", "name": "Carla", "isOwner": false },
  "requestedEntry": { "id": "hub", "command": "painel", "requestedOrgCode": null },
  "entryAllowed": true,
  "denialReason": null,
  "defaultContextId": "org:mechanic",
  "contexts": [
    {
      "id": "org:mechanic",
      "kind": "organization",
      "organization": { "code": "mechanic", "name": "Oficina Central", "type": "business", "status": "active" },
      "membership": {
        "citizenId": "CID063",
        "grade": { "id": 5, "level": 4, "code": "manager", "name": "Gerente" },
        "isPrimary": true,
        "isDuty": null,
        "joinedAt": null
      },
      "capabilities": ["org.view", "members.view", "members.invite", "goals.view", "goals.manage", "account.view"],
      "features": {
        "overview": { "enabled": true }, "members": { "enabled": true }, "grades": { "enabled": true },
        "goals": { "enabled": true }, "bank": { "enabled": true },
        "recruitment": { "enabled": true }, "logs": { "enabled": true, "readOnly": true }
      }
    },
    {
      "id": "org:ballas",
      "kind": "organization",
      "organization": { "code": "ballas", "name": "Ballas", "type": "illegal", "status": "active" },
      "membership": {
        "citizenId": "CID063",
        "grade": { "id": 2, "level": 1, "code": "member", "name": "Membro" },
        "isPrimary": false,
        "isDuty": null,
        "joinedAt": null
      },
      "capabilities": ["org.view", "members.view"],
      "features": {
        "overview": { "enabled": true }, "members": { "enabled": true }, "grades": { "enabled": true },
        "goals": { "enabled": true }, "bank": { "enabled": false, "reason": "disabled_for_type" },
        "recruitment": { "enabled": true }, "logs": { "enabled": true, "readOnly": true }
      }
    }
  ],
  "staffContext": null,
  "compatibility": { "modules": ["dashboard", "business", "illegal", "members", "goals", "bank"] }
}
```

### Staff parcial

```json
{
  "contractVersion": 2,
  "sessionId": "s:74:1721577603",
  "generatedAt": "2026-07-21T15:00:03Z",
  "user": { "serverId": 74, "citizenId": "CID074", "name": "Diego", "isOwner": false },
  "requestedEntry": { "id": "staff", "command": "staff", "requestedOrgCode": null },
  "entryAllowed": true,
  "denialReason": null,
  "defaultContextId": "staff",
  "contexts": [],
  "staffContext": {
    "id": "staff",
    "kind": "staff",
    "capabilities": ["staff.panel.open", "staff.orgs.view", "staff.logs.view"],
    "scope": { "mode": "all", "orgCodes": [] },
    "features": {
      "organizations": { "enabled": true, "readOnly": true },
      "members": { "enabled": false }, "grades": { "enabled": false }, "bank": { "enabled": false },
      "recruitment": { "enabled": false }, "goals": { "enabled": false },
      "logs": { "enabled": true, "readOnly": true }
    }
  },
  "compatibility": { "modules": ["dashboard", "staff", "staff.logs"] }
}
```

### Owner

```json
{
  "contractVersion": 2,
  "sessionId": "s:1:1721577604",
  "generatedAt": "2026-07-21T15:00:04Z",
  "user": { "serverId": 1, "citizenId": "OWNER001", "name": "Owner", "isOwner": true },
  "requestedEntry": { "id": "staff", "command": "staff", "requestedOrgCode": null },
  "entryAllowed": true,
  "denialReason": null,
  "defaultContextId": "staff",
  "contexts": [],
  "staffContext": {
    "id": "staff",
    "kind": "staff",
    "capabilities": ["*"],
    "scope": { "mode": "all", "orgCodes": [] },
    "features": {
      "organizations": { "enabled": true }, "members": { "enabled": true },
      "grades": { "enabled": true }, "bank": { "enabled": true },
      "recruitment": { "enabled": true }, "goals": { "enabled": true }, "logs": { "enabled": true }
    }
  },
  "compatibility": { "modules": ["dashboard", "staff", "staff.orgs", "staff.members", "staff.logs"] }
}
```

O exemplo de Owner omite contextos organizacionais por brevidade: o servidor pode fornecer todas as organizações como contextos acessíveis ou manter a navegação global exclusivamente em `staffContext`. A escolha está registrada nas decisões abertas.

## Ciclo de vida no frontend

Estados mínimos:

- `closed`: CEF sem foco;
- `resolving-session`: mostra apenas carregamento neutro e não monta workspace;
- `ready`: sessão válida e entrada autorizada;
- `denied`: mensagem de acesso negado e ação de fechar/voltar;
- `expired`: invalida queries e solicita uma nova sessão.

Ao receber `session:set` com outro `sessionId`, a V2 deve cancelar logicamente requisições em voo, limpar o cache do identificador anterior, resolver a rota novamente e nunca preservar um `contextId` que não exista na nova sessão.

## Compatibilidade com `session.modules`

Durante a transição, o servidor deriva `compatibility.modules` da V2. A direção inversa é proibida: a V2 não deve inferir contextos ou capacidades a partir dos módulos legados.

Etapas de retirada:

1. entregar V2 e `compatibility.modules` na mesma resposta;
2. fazer o legado ler somente `compatibility.modules` (com alias temporário no topo da resposta, se necessário);
3. registrar telemetria de clientes que ainda consultam `modules`;
4. remover o alias depois do corte definitivo do frontend legado;
5. manter `contractVersion` obrigatório e rejeitar versões desconhecidas com erro explícito.

## Critérios de aceite

- um jogador sem organização não vê nem abre Staff;
- um membro de duas organizações recebe capacidades independentes por contexto;
- uma permissão de cargo chamada `staff.*` não cria `staffContext`;
- uma entrada `/staff` negada não monta o shell Staff por um único frame;
- `grade.name` está presente em todos os contextos;
- troca de sessão invalida rotas e dados anteriores;
- todos os callbacks continuam validando `source` e organização, mesmo quando a UI oculta a ação.
