# Proposta de arquitetura do frontend V2

> Gate Fase 0 (2026-07-21): implementado estaticamente. Permissoes globais foram separadas, `CanOrg(staff.*)` bloqueado, logs estruturais criados, auditoria de cargo transacional, sessao V2 e envelope contextual entregues. A validacao runtime do checklist continua obrigatoria antes de iniciar React/Vite.

Data: 2026-07-21. Este documento propõe a reconstrução; ele não altera o frontend, callbacks, SQL ou outros resources.

## Decisão

Construir uma aplicação paralela em **React + TypeScript + Vite**, sem reformar progressivamente o roteador legado. O código atual em `web/` permanece executável até o corte. A V2 terá três workspaces explícitos:

1. **Hub**: resolve a entrada e seleciona um contexto; não carrega dados administrativos.
2. **OrganizationWorkspace**: uma única implementação para `legal/job`, `gang`, `business`, `government`, `vip` e `event`.
3. **StaffWorkspace**: contexto global separado, sem reutilizar implicitamente a organização pessoal do jogador.

Tipo de organização será metadado do contexto e entrada para um feature registry, não uma rota principal nem uma cópia de painel. A UI usa capabilities para apresentação; o servidor continua autorizando todas as leituras e mutations com o `source` real.

## Stack

| Área | Escolha | Motivo no contexto do `mz_org` |
| --- | --- | --- |
| UI | React, React DOM | Composição por componente, ciclo de vida previsível e eliminação de `innerHTML`/rebinding global. |
| Linguagem | TypeScript em modo estrito | Tipar os 35 callbacks, sessão, rotas, features e envelopes. |
| Build | Vite | Build estático simples; `base: './'` gera caminhos relativos adequados a deployment embutido. |
| Estado remoto | TanStack Query | Cache por chave contextual, invalidação dirigida e estados distintos de loading/error/data. |
| Validação runtime | Zod ou validador equivalente centralizado | TypeScript não valida JSON em runtime; respostas NUI precisam falhar de forma explícita quando divergirem. |
| Estado de UI | React Context + `useReducer`, estado local de componente | O domínio atual não justifica Redux/Zustand; uma máquina pequena de sessão/rota evita nove campos sobrepostos. |
| Estilo | CSS Modules + tokens CSS globais | Escopo por componente, sem runtime CSS-in-JS e sem novo monólito. |
| Testes | Vitest + Testing Library; teste de viewport com Playwright/Chromium; smoke dentro do FiveM | Cobre guards, contratos, interação e o comportamento real de CEF. |

Versões devem ser fixadas em lockfile quando a implementação começar. Mutations financeiras não terão retry automático.

## Fronteiras de confiança

```text
NUI/React (não confiável)
  -> callback tipado, JSON validado
client Lua (transporte/correlação; não autoriza)
  -> evento server com source implícito
server mz_org (normaliza e aplica guard de entrada/domínio)
  -> export real existente do mz_core
mz_core (autoridade de identidade, capability, hierarquia, persistência e auditoria)
```

- `orgCode`, `citizenid`, IDs, valores e filtros vindos da NUI são seletores/dados não confiáveis.
- `source`, ator, `createdBy`, saldo anterior, cargo efetivo e capabilities nunca vêm da NUI como autoridade.
- Route guards evitam exposição e chamadas inúteis; não substituem guards server-side.
- `staffContext` não pode ser criado pela união das capabilities das organizações comuns.

## Modelo de workspaces

### Hub

O Hub mostra apenas entradas presentes no contrato V2:

- cards para `contexts[]` organizacionais;
- card Staff somente quando `staffContext` existe;
- empty state definido para jogador sem organização;
- estado neutro de acesso negado para entrypoint solicitado e não permitido.

O Hub não usa `session.modules` e não dispara banco, membros, logs ou metas.

### OrganizationWorkspace

A rota sempre contém um `contextId` do formato `org:<code>`. O workspace recebe a organização, membership, capabilities e features daquele contexto. Trocar contexto substitui o `contextId`, cancela/abandona as queries antigas e fecha modais.

Rotas comuns propostas:

- `org.overview`
- `org.members`
- `org.grades`
- `org.goals`
- `org.bank`
- `org.recruitment`
- `org.logs`

`organization.type` altera rótulos, ícones e features registradas. Não cria outro router, store ou service.

### StaffWorkspace

O Staff usa `contextId = 'staff'` e apenas `staffContext.capabilities`. Rotas iniciais:

- `staff.overview`
- `staff.organizations`
- `staff.organization.detail`
- `staff.logs`
- `staff.audit`

O detalhe de uma organização selecionada no Staff é um alvo administrativo (`selectedOrgCode` local à rota), não uma troca silenciosa para um contexto pessoal. Cada bloco do detalhe precisa de capability/feature Staff própria ou política de field-level access definida.

## Route registry

O registry é a única fonte de navegação. Não existem arrays independentes para sidebar, tabs e loaders.

```ts
type RouteId =
  | "hub"
  | "org.overview"
  | "org.members"
  | "org.grades"
  | "org.goals"
  | "org.bank"
  | "org.recruitment"
  | "org.logs"
  | "staff.overview"
  | "staff.organizations"
  | "staff.organization.detail"
  | "staff.logs"
  | "staff.audit";

type RouteDefinition = {
  id: RouteId;
  workspace: "hub" | "organization" | "staff";
  label: string;
  feature?: string;
  anyCapabilities?: string[];
  allCapabilities?: string[];
  sensitivity: "read" | "mutation" | "sensitive";
  component: React.LazyExoticComponent<React.ComponentType>;
};
```

Exemplo: `org.bank` exige `features.bank.enabled` e ao menos `account.view|account.deposit|account.withdraw|account.manage`. As ações dentro da rota têm guards mais específicos. `staff.organizations` nunca consulta capabilities da organização pessoal.

Rotas não serão baseadas em URL do navegador. Um reducer/memory route state evita dependência de history/reload e caminhos inválidos no CEF. O estado mínimo é:

```ts
type AppRoute = {
  routeId: RouteId;
  contextId: `org:${string}` | "staff" | null;
  params: Record<string, string>;
};
```

## Guards

Toda navegação passa, na ordem, por:

1. sessão `contractVersion === 2` válida;
2. `entryAllowed` para a entrada inicial;
3. workspace compatível com o `contextId`;
4. contexto ainda presente na sessão atual;
5. feature habilitada;
6. capabilities mínimas da rota;
7. capability específica da ação, quando houver mutation.

Falha não faz fallback para `dashboard`. O resultado é uma rota segura conhecida (`hub` ou `denied`) e nenhum loader protegido é executado. O mesmo guard alimenta sidebar, tabs, deep navigation e comandos programáticos.

## Camada NUI tipada

Um mapa único liga nome, request e response. Os nomes atuais são preservados.

```ts
type NuiContract = {
  "orgs:get": { request: { orgCode: string }; response: OrgSummary };
  "members:list": { request: { orgCode: string }; response: Member[] };
  "org-bank:withdraw": {
    request: { orgCode: string; amount: number; reason?: string };
    response: OrgAccountMutation;
  };
  // Demais entradas vêm do FRONTEND_V2_API_INVENTORY.md.
};

type NuiResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: string; code?: string; requestId?: string };

async function callNui<K extends keyof NuiContract>(
  name: K,
  payload: NuiContract[K]["request"],
  options?: { signal?: AbortSignal },
): Promise<NuiContract[K]["response"]>;
```

Responsabilidades da camada:

- resolver `GetParentResourceName()` apenas no adapter FiveM;
- serializar somente JSON;
- aplicar timeout e transformar falhas em `NuiError` tipado;
- validar o envelope e `data` em runtime;
- anexar `sessionId/contextId` local à operação para descartar respostas obsoletas;
- nunca decidir autorização por texto de erro;
- manter adapter específico para a sessão legada assíncrona até ela retornar pelo envelope normal.

Abortar `fetch` no CEF não cancela o trabalho já enviado ao server Lua. Por isso, cancelamento de query deve ser combinado com chave contextual e descarte de resposta por `sessionId/contextId`.

## Queries, mutations e invalidação

Chaves sempre incluem sessão e contexto:

```ts
["session", sessionId]
["org", sessionId, contextId, "summary"]
["org", sessionId, contextId, "members", filters]
["org", sessionId, contextId, "bank"]
["org", sessionId, contextId, "bank-transactions", filters]
["staff", sessionId, "organizations", filters]
["staff", sessionId, "organization", orgCode, "logs", filters]
```

Política:

- `enabled` só fica true depois que route guard e contexto passam;
- `refetchOnWindowFocus: false`, pois foco do CEF muda durante o jogo;
- `networkMode: 'always'`, pois NUI é transporte local e não deve depender de `navigator.onLine`;
- reads podem ter no máximo um retry apenas para falha transitória classificada;
- mutations têm `retry: false`, botão travado durante envio e confirmação para ações sensíveis;
- saque/deposito não recebem retry nem optimistic update enquanto não houver idempotency key server-side;
- sucesso invalida somente as chaves do contexto afetado;
- troca de sessão executa `cancelQueries()` e `removeQueries()` do `sessionId` anterior;
- trocar organização fecha formulários/modais e não copia dados anteriores como placeholder.

Exemplos de invalidação:

| Mutation | Invalidar após sucesso |
| --- | --- |
| invite/remove/promote/demote | members, access/summary e sessão quando membership do próprio ator puder mudar |
| depósito/saque | bank e bank-transactions do mesmo contexto |
| criar meta | goals e overview do mesmo contexto |
| recrutamento approve | recruitment, members e overview da org retornada |
| archive/reactivate org | lista Staff, detalhe Staff e sessão/contextos |
| alterar grade/permissão | access model, members e detalhe Staff |

## Estado remoto versus estado de UI

| Estado remoto (TanStack Query) | Estado de UI (reducer/local) |
| --- | --- |
| sessão, organizações, membros, banco, extrato, cargos, metas, recrutamento e logs | NUI aberta, rota, contexto escolhido, sidebar, tab visual, filtros ainda não aplicados, modal e campos de formulário |

Dados retornados pelo servidor não são copiados para um singleton mutável. Formulários recebem snapshot inicial e fazem reset ao mudar `contextId` ou fechar.

## Feature registry

Features são disponibilidade do produto, não autorização do usuário.

```ts
type OrganizationFeatureId =
  | "overview" | "members" | "grades" | "goals"
  | "bank" | "recruitment" | "logs";

type FeatureDefinition = {
  id: OrganizationFeatureId;
  defaultEnabled: boolean;
  supportedTypes?: string[];
  minimumCapabilities: string[];
};
```

O servidor materializa `features` na sessão com base em tipo, status e flags reais (`hasSharedAccount`, `hasSalary`, `hasStorage`). O frontend registry fornece componente, label e capability mínima, mas não reinterpreta flags ausentes. Uma feature precisa estar habilitada **e** ter capability de leitura/ação.

Plugins de tipo podem adicionar cards ou rotas secundárias sem bifurcar o workspace:

```text
features/common/*
features/legal/*
features/gang/*
features/business/*
features/government/*
features/vip/*
features/event/*
```

Até a matriz de features ser decidida, apenas features sustentadas pelos callbacks atuais entram na V2.

## Estrutura de pastas

```text
web-v2/
  package.json
  pnpm-lock.yaml
  tsconfig.json
  vite.config.ts
  index.html
  src/
    app/
      App.tsx
      bootstrap.tsx
      route-registry.ts
      route-guard.ts
      session-machine.ts
    contracts/
      nui-contract.ts
      session-v2.ts
      schemas/
    nui/
      client.ts
      five-m-transport.ts
      browser-mock-transport.ts
      errors.ts
    queries/
      keys.ts
      organizations.ts
      members.ts
      bank.ts
      recruitment.ts
      goals.ts
      logs.ts
    workspaces/
      hub/
      organization/
      staff/
    features/
      registry.ts
      common/
      legal/
      gang/
      business/
      government/
      vip/
      event/
    components/
      layout/
      navigation/
      feedback/
      data-display/
      forms/
    styles/
      tokens.css
      reset.css
      globals.css
    mocks/
      fixtures/
      handlers.ts
    test/
  dist/
```

## Design tokens e responsividade

Tokens mínimos:

- cor semântica: surface, text, muted, border, accent, success, warning, danger;
- escala de espaço de 4 px;
- radius, shadow, typography e z-index nomeados;
- tamanhos de controle mínimos e focus ring visível;
- dimensões do shell por `clamp()`/container, não por largura fixa duplicada.

Baseline obrigatório: **1280x720**. Nesse viewport, o shell máximo de 1232x672 deixa cerca de 952 px de main com sidebar aberta. Layouts devem responder à largura do container (`@container`) e não apenas a `window.innerWidth`.

- sidebar colapsável com navegação substituta, nunca simplesmente escondida;
- tabs com overflow horizontal controlado ou menu “mais”, sem aumentar indefinidamente o header;
- tabelas dentro de scroll region com primeira coluna/ações utilizáveis;
- modal limitado ao container, header/actions fixos e body rolável;
- nenhuma ação essencial abaixo de uma área cortada;
- teste visual nos tamanhos 1280x720, 1366x768 e 1920x1080, com sidebar aberta/fechada e escala 100%.

## Tratamento de erros

Modelo V2 desejado:

```ts
type AppError = {
  kind: "validation" | "forbidden" | "not-found" | "rate-limit" | "timeout" | "unavailable" | "unknown";
  code: string;
  message: string;
  retryable: boolean;
  requestId?: string;
};
```

Enquanto o backend retornar apenas strings, um adapter conserva a mensagem e usa `code = 'LEGACY_ERROR'`; decisões de segurança não dependem dela. Lista vazia só é empty state quando a resposta foi `{ok:true,data:[]}`. Timeout/export indisponível é erro, não lista vazia.

Erros de bloco no detalhe Staff permanecem locais ao bloco; erro de sessão ou contexto invalida o workspace. Mutations mostram resultado junto à ação e preservam o formulário quando a correção pelo usuário for possível.

## Estratégia de mocks

Fixtures tipadas obrigatórias:

- jogador sem org;
- uma org com acesso mínimo;
- múltiplas orgs com capabilities diferentes;
- Staff parcial read-only;
- owner;
- org arquivada;
- resposta atrasada da org A após troca para org B;
- forbidden, timeout, rate limit e export indisponível;
- payload inválido para cada família de callback.

O mock implementa a mesma interface de transporte, não condicionais espalhados pelos componentes. Testes de contrato validam fixtures com os mesmos schemas das respostas reais.

## Build e integração FiveM

1. Vite usa `base: './'` e saída estática em `web-v2/dist`.
2. Nenhum asset depende de `/` absoluto, CDN ou servidor Node em produção.
3. `index.html`, chunks, CSS, fontes e imagens gerados entram no `files` do `fxmanifest.lua` quando a fase de fundação for implementada.
4. `ui_page` continua apontando para o legado durante a construção. Para canário, um bootstrap estático versionado escolhe legado/V2 e tem default legado; a forma exata deve ser validada no CEF antes de produção.
5. O artefato de deploy inclui `dist`; `vite dev/preview` serve apenas para desenvolvimento.
6. Source maps de produção ficam fora do packfile público ou são gerados apenas em artefato interno.
7. O build falha se houver path absoluto ou arquivo referenciado ausente.

FiveM exige um único `ui_page` e que seus arquivos/dependências estejam no packfile. NUI callbacks devem sempre responder para não deixar `fetch` pendurado. Referências oficiais: [Fullscreen NUI](https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/), [NUI callbacks](https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/), [resource manifest](https://docs.fivem.net/docs/scripting-reference/resource-manifest/) e [Vite `base`](https://vite.dev/config/shared-options#base).

## Limites de tamanho e responsabilidade

- componente de tela: alvo até 250 linhas; acima disso extrair seções;
- hook/query/service: alvo até 150 linhas e uma família de domínio;
- arquivo de contrato/registry: alvo até 200 linhas por domínio;
- função: alvo até 50 linhas, sem render + fetch + mutation no mesmo corpo;
- CSS Module: alvo até 250 linhas; tokens e reset não contam como componente;
- nenhum arquivo de produção acima de 500 linhas sem ADR e justificativa;
- nenhum barrel exporta internals entre features;
- dependência permitida: workspace -> feature -> shared; features não importam workspaces.

Esses limites são gates de revisão, não cortes mecânicos que gerem fragmentação artificial.

## Alternativas consideradas

| Alternativa | Decisão |
| --- | --- |
| Continuar refatorando JS/CSS atual | Rejeitada: preserva singleton, render por string, router de 4.145 linhas e estados sobrepostos; risco de regressão durante uso. |
| Um app React separado por tipo de org | Rejeitada: duplica banco/membros/metas/guards e perpetua tipo como painel. |
| Reutilizar `session.modules` como autorização V2 | Rejeitada: é global, perde org scope e contém fallback de dashboard. |
| Redux/Zustand para todo estado | Adiada: Query já cobre estado remoto e reducer cobre sessão/rota. Introduzir store apenas se métricas de complexidade demonstrarem necessidade. |
| React Router com BrowserRouter | Rejeitada para a primeira fase: URL/history não agrega valor à NUI e cria risco de paths/reload no CEF. Um registry tipado + reducer é suficiente. |
| CSS-in-JS/Tailwind | Não escolhido inicialmente: CSS Modules e tokens atendem escopo, build estático e inspeção sem adicionar runtime/DSL. |
| Trocar todos os callbacks junto com o frontend | Rejeitada: aumenta blast radius. A V2 usa adapters e mantém nomes existentes. |

## Pré-condições para liberar mutations V2

1. resolver a origem/proveniência de permissões globais para que org comum não conceda `staff.*`;
2. remover `CanOrg(orgCode, 'staff.orgs.set_leader')` da autorização final após compatibilidade/migração de dados;
3. tornar o filtro de logs por org estrutural e estrito;
4. completar auditoria de promote/demote e tentativas bloqueadas;
5. entregar e testar o contrato de sessão V2;
6. decidir capability para access model e política de Staff parcial;
7. provar isolamento de cache/respostas em troca rápida de contexto.

Até esses gates passarem, a V2 pode avançar no Hub e em leitura de organização, mas não deve liberar Staff sensível, banco ou mutations de hierarquia.
