# Auditoria de codigo do frontend V2

> Atualizacao Fase 0 (2026-07-21): os achados de permissao global, `CanOrg(staff.*)`, logs por substring, falta de auditoria de promote/demote, entrada Staff por dashboard e races cross-context foram corrigidos no codigo. Este documento preserva o diagnostico historico; o estado implementado esta em `PHASE_0_SECURITY_IMPLEMENTATION.md`. Runtime FiveM permanece pendente.

Data da auditoria: 2026-07-21. Escopo primario: `mz_org`; os exports efetivamente chamados foram conferidos no `mz_core` somente para validar o contrato e as garantias server-side. Nenhum codigo, SQL, migration ou callback foi alterado. O arquivo opcional `MZ_ORG_FRONTEND_REBUILD_ARCHITECTURE.md` nao foi encontrado nem na raiz do repositorio nem em `mz_org/docs/`.

## Resumo executivo

A frontend atual nao deve ser evoluida por reforma incremental. Ela mistura autorizacao visual, roteamento, estado remoto, estado de UI, templates HTML e binding de eventos em um unico roteador de 4.145 linhas, apoiado por um CSS de 3.458 linhas. A decisao recomendada e preservar o legado durante uma migracao paralela para React + TypeScript + Vite, manter os callbacks atuais por compatibilidade e introduzir primeiro uma sessao V2 server-authoritative.

Os dois indicios de exposicao do Staff foram confirmados. Toda sessao recebe `dashboard` (`server/session.lua:239`), `visibleModules()` injeta `dashboard` quando um painel nao tem modulos permitidos (`web/core/permissions.js:92-104`) e `canOpenPanel()` usa esse resultado (`web/core/permissions.js:107-115`). Portanto, um jogador comum ve o shell Staff na sidebar. `setActiveShell()` nao possui guarda (`web/core/router.js:208-229`) e e exportada em `web/core/router.js:4115`, logo a rota visual Staff pode ser ativada diretamente. O guard tardio de `renderStaffPage()` impede o conteudo Staff principal (`web/core/router.js:1638-1640`), mas nao impede o shell/header Staff nem o dashboard fallback. Isso e exposicao visual e confusao de contexto, nao uma autorizacao server-side.

Ha tambem riscos de backend/contrato que precisam ser contidos antes das mutations da V2:

- `mz_core` chama de global uma permissao que pode vir de qualquer org: `hasGlobalPermission()` cai em `hasPermission()` (`mz_core/server/orgs/service.lua:1002-1028`), e `hasPermission()` agrega todas as orgs do jogador. Isso faz `staff.*` funcionar como permissao global quando presente em um cargo de org.
- `staff.orgs.set_leader` e aceito por `CanOrg()` no wrapper e no core (`server/members.lua:140-149`; `mz_core/server/orgs/service.lua:260-264`), embora seja nomeado como permissao Staff global. O proprio allowlist de grades inclui `staff.*` (`mz_core/server/orgs/service.lua:294-301`). Novas inclusoes sao limitadas a org `staff` e owner (`mz_core/server/orgs/service.lua:341-352`), mas dados legados/seeds continuam semanticamente misturados.
- O filtro de logs por org usa `LIKE '%orgCode%'` em `target` ou JSON (`mz_core/server/logs/service.lua:250-253`) e o pos-filtro aceita tambem substring em `row.target` (`mz_core/server/logs/service.lua:379-385`). Um `orgCode` curto ou presente no target pode misturar logs de outra org.
- As promises do frontend nao carregam token de contexto/request. Uma resposta da org anterior pode sobrescrever o estado da org nova (`web/core/router.js:296-361`, `413-520`), e flags `loading` globais podem impedir o carregamento do novo contexto.

## Mapa real do frontend atual

| Camada | Implementacao real | Responsabilidade e problema |
| --- | --- | --- |
| Entrada CEF | `web/index.html` | Carrega 22 scripts globais em ordem manual; caminhos relativos sao compativeis com `ui_page 'web/index.html'`. |
| Boot | `web/script.js` | Registra paineis, listeners NUI e abre mock fora do FiveM. |
| Estado | `web/core/state.js` | Singleton mutavel com sessao, rotas, caches, dados remotos e 10+ modais/forms. |
| Permissoes visuais | `web/core/permissions.js` | Mistura modulo, painel, tipo de org e permissao; contem o fallback que expoe Staff. |
| Transporte NUI | `web/core/nui.js` | `fetch` para `https://${GetParentResourceName()}/callback`; sessao usa resposta assincrona fora do envelope normal. |
| Services | `web/services/*.js` | Wrappers pequenos e reaproveitaveis como referencia de payload, mas sem tipos, cancelamento ou validacao runtime. |
| Registry de paineis | `web/panels/**/index.js` | Oito definicoes quase vazias; legal/gang/business/government/VIP/event duplicam o conceito de workspace por tipo. |
| Roteador/render | `web/core/router.js` | 4.145 linhas: rotas, queries, mutations, HTML, modais, filtros, autorizacao visual e rebinding global. |
| UI/formatacao | `web/core/ui.js`, `format.js` | `escapeHtml` e formatadores sao uteis como referencia. `technicalDetails` foi desativado por stubs e existe typo `rrenderTechnicalDetails` (`ui.js:180-185`). |
| CSS | `web/style.css` | Arquivo monolitico com fundacao antiga + bloco "Base modular nova" a partir de `style.css:1105`; muitas tabelas e modais especificos. |

O estado confirma a sobreposicao apontada no briefing: `requestedPanel`, `activePanel`, `activeShell`, `currentContext`, `requestedInitialModule`, `activeModule`, `activeSection`, `activeOrgCode` e `activeOrgType` coexistem em `web/core/state.js:37-46`. Nao ha uma unica entidade `route` nem um unico `contextId`.

## Fluxo de abertura dos comandos

Todos os comandos sao client-side e nao consultam o servidor antes de dar foco ao CEF:

| Comando | Entrada visual | Linhas |
| --- | --- | --- |
| `/mzorg`, `/painel` | `openPanel('dashboard', 'hub')` | `client/main.lua:69-75` |
| `/org` | `openPanel('legal', 'legal')` | `client/main.lua:77-79` |
| `/gang` | `openPanel('gang', 'illegal')` | `client/main.lua:81-83` |
| `/staff` | `openPanel('staff', 'staff')` | `client/main.lua:85-87` |
| `/vip` | `openPanel('vip', 'vip')` | `client/main.lua:89-91` |
| `/business` | `openPanel('business', 'business')` | `client/main.lua:93-95` |
| `/government` | `openPanel('government', 'government')` | `client/main.lua:97-99` |
| `/event` | `openPanel('event', 'event')` | `client/main.lua:101-103` |

Fluxo comum:

1. `openPanel()` marca `isOpen`, chama `SetNuiFocus(true, true)` e, 100 ms depois, envia `{action='open', payload={initialModule, mode}}` (`client/main.lua:33-56`).
2. A NUI grava o entrypoint solicitado diretamente em `activePanel` e `activeShell`, limpa a sessao e renderiza loading (`web/core/nui.js:39-58`).
3. `session:get` responde imediatamente `{ok=true}`, mas a sessao chega depois pelo evento `mz_org:client:receiveSession`/mensagem `session:set` (`client/main.lua:110-113`, `247-252`).
4. `applyInitialModule()` valida somente o modulo solicitado; preserva `activePanel` como shell mesmo quando o modulo e negado (`web/core/router.js:193-201`). Em `/staff` negado, isso produz shell Staff + `dashboard` fallback.

O cliente abre qualquer entrypoint antes de conhecer `entryAllowed`. Isso nao concede poder no servidor, mas permite flash de tela, header incorreto, foco indevido e navegacao para empty/error states administrativos.

## Fluxo NUI ate o `mz_core`

Fluxo padrao de dados:

```text
React/JS service
  -> POST https://mz_org/<callback NUI> com JSON
  -> RegisterNUICallback no client
  -> TriggerServerEvent(eventName, requestId, payload)
  -> handler server usa source real, normaliza payload e chama export mz_core
  -> TriggerClientEvent(serverResponse, source, requestId, {ok,data|error})
  -> callback pendente do client
  -> response.json() no CEF
```

Referencias: `web/core/nui.js:18-36`, `client/main.lua:15-31`, `client/main.lua:115-245`, `server/permissions.lua:6-21` (padrao repetido nos handlers) e `client/main.lua:254-265`.

O timeout e de 5 s (`shared/config.lua:7`; `client/main.lua:21-30`). Requests nao sao cancelados ao fechar a NUI nem ao trocar org; respostas tardias ainda podem mutar estado. `session:get` e a excecao: nao usa `requestId`, nao retorna `data` no callback e depende de mensagem assincrona separada.

## Bugs confirmados

### Autorizacao visual e navegacao

1. **Shell Staff aparece para jogador comum.** `dashboard` existe em todas as sessoes (`server/session.lua:239`); `visibleModules('staff')` cai para dashboard (`permissions.js:100-102`); `canOpenPanel('staff')` recebe lista nao vazia (`permissions.js:107-115`); `visibleShells()` inclui Staff (`router.js:138-150`).
2. **Rota Staff ativavel diretamente.** `setActiveShell()` altera todos os campos sem `canOpenPanel`/capability (`router.js:208-229`) e e API global (`router.js:4115`). O binding confia no atributo DOM (`router.js:3854`).
3. **Entrypoint negado preserva shell solicitado.** `applyInitialModule()` troca o modulo, mas define `activeShell = activePanel` (`router.js:193-201`). Resultado: `/staff` comum mostra cabecalho Staff e dashboard fallback.
4. **Todas as abas internas de org aparecem sem capability.** `orgContextSections` e fixo (`router.js:52-60`) e `renderContextTabs()` mapeia tudo (`router.js:823-827`). Membros, Cargos, Metas, Banco, Recrutamento e Logs aparecem mesmo quando o backend recusara cada leitura.
5. **Todas as abas Staff aparecem sem capability especifica.** `staffSections` (`router.js:62-68`) e `staffOrgDetailTabs` (`router.js:79-88`) sao renderizados sem filtro (`router.js:1690-1694`, `1938-1941`).
6. **Acoes de membro recebem bypass visual amplo.** `isStaffAccess()` basta para mostrar convite/remocao/promocao/rebaixamento (`router.js:1196-1233`), embora Staff parcial possa nao ter `staff.orgs.manage` nem a capability daquela org. O servidor bloqueia, mas a UI promete poder inexistente.
7. **Criar meta da bypass visual a qualquer Staff.** `canCreateGoals()` retorna true para `isStaffAccess` (`router.js:3501-3510`), enquanto o servidor exige `staff.orgs.manage` ou capability da org.
8. **Acoes de recrutamento pendente nao sao filtradas por capability.** Os tres botoes sao sempre renderizados para item pending (`router.js:3246-3261`); apenas o servidor e o modal posterior barram a operacao.

### Estado, cache e concorrencia

1. **Race cross-context.** `loadOrgPanel()` inicia cinco promises independentes e escreve no mesmo `orgView` sem comparar o `code` capturado com o contexto atual (`router.js:296-361`). Trocar org antes da resposta mistura detalhe/membros/banco/extrato/cargos.
2. **Flags globais bloqueiam a nova org.** Se `membersLoading`/`logs.loading`/`goals.loading` ainda estiver true, a carga do contexto novo pode retornar cedo (`router.js:302`, `418`, `460`, `502`).
3. **Chaves inconsistentes.** `orgView.loadedKey` usa `activeModule:orgCode`; goals/recruitment usam `activePanel:orgCode`; logs usam `org:orgCode`/`global` (`router.js:301`, `417`, `459`, `501`). Isso reflete a duplicacao painel/modulo/shell.
4. **Troca de shell limpa apenas legal/illegal.** `setActiveShell()` chama `resetOrgPanelData()`/`resetContextLoads()` somente nesses dois shells (`router.js:217-226`). VIP/business/government/event podem reutilizar dados antigos enquanto `activeOrgCode` e zerado.
5. **Cache declarado e quase nao consumido.** `cache.orgs`, `cache.logs`, `cache.bank`, `cache.accessByOrg` existem (`state.js:99`), mas `accessByOrg` so recebe dados e nao e lido; `cache.bank` nao e usado.
6. **Fechar nao invalida requests.** `closePanel()` so muda `isOpen` e envia `close` (`nui.js:78-82`); promises continuam e chamam `render()`.
7. **Detalhe Staff tem a mesma race cross-org.** `openStaffOrgDetails()` dispara oito promises e, ao resolver, grava em `staffOrgDetails.data` sem confirmar que `details.orgCode` ainda e o `orgCode` capturado (`router.js:1768-1865`). Trocar rapidamente o alvo pode exibir o pacote completo da org anterior no detalhe atual.

### Backend e contratos

1. **Global x org conflado.** `HasGlobalPermission` aceita ACE, override e qualquer permissao resolvida em qualquer org (`mz_core/server/orgs/service.lua:1002-1028`). Nome e comportamento divergem.
2. **`staff.orgs.set_leader` aceito em `CanOrg`.** `server/members.lua:148` e `mz_core/server/orgs/service.lua:260-264`. A capability correta de org ja existe: `members.set_leader`.
3. **Filtro de logs nao e igualdade estrutural.** `LIKE` em JSON/target e substring no pos-filtro podem retornar log de outro `orgCode` (`mz_core/server/logs/service.lua:250-253`, `379-385`).
4. **Fallback `HasPermission` na sessao amplia a ambiguidade.** Se o export global falhar/retornar nil, `server/session.lua:184-195` chama `HasPermission`, que tambem agrega orgs.
5. **Falha de export mascarada como dado vazio.** Membros, access model, extrato, metas e logs retornam vazio seguro em diferentes falhas (`server/members.lua:189-203`; `server/permissions.lua:124-138`; `server/bank.lua:175-181`; `server/goals.lua:219-255`; `server/logs.lua:111-125`). Indisponibilidade e "sem dados" ficam indistinguiveis.
6. **Auditoria incompleta em membros.** `PromoteOrgMemberSecure` e `DemoteOrgMemberSecure` alteram membership sem `logDetailed` (`mz_core/server/orgs/service.lua:1383-1439`); falhas comuns de remove/promote/demote tambem nao chamam `logBlocked`. A documentacao diz o contrario.
7. **Rate limit somente em memoria e sem limpeza no `playerDropped`.** Buckets indexados por source existem em orgs, members, bank, recruitment e goals. Reuso de source pode herdar cooldown curto; tabelas crescem durante a vida do resource.
8. **`requestId` nao e validado no server.** E devolvido ao cliente como recebido. Nao concede acesso, mas eventos manuais podem gerar respostas sem correlacao ou colisao no proprio client.

## Callbacks manuais e bloqueios server-side

Todos os 35 callbacks NUI podem ser chamados manualmente pelo DevTools/CEF; esconder botoes nao e seguranca. `close` apenas fecha. `session:get` retorna a sessao do `source` real. Os outros 33 chegam aos handlers server-side.

- Reads de org/membros/access/banco/recrutamento/metas/logs validam `orgCode` e/ou delegam novamente ao core. Os detalhes estao inventariados em `FRONTEND_V2_API_INVENTORY.md`.
- Mutations de org exigem owner/`staff.orgs.create|manage` no wrapper e novamente no core.
- Mutations de membro, banco, recrutamento e metas dependem do core para a autorizacao final; forjar `orgCode`, `citizenid`, amount, grade ou id nao substitui o `source` real.
- `source`, actor e `createdBy` nao sao aceitos como autoridade em nenhum handler NUI. `targetId/targetSource` e aceito somente no convite quando `Config.AllowLegacyTargetSourceInvite == true`; o padrao seguro em `shared/config.lua` e `false`.
- `citizenid` vindo da NUI e um identificador de alvo, nao identidade do ator. O core verifica existencia/membership/hierarquia conforme a acao.

Nao foi encontrado handler de mutation que use `payload.orgCode` sem ao menos normalizacao e validacao de permissao no wrapper ou export seguro. O problema de mistura observado e principalmente frontend assincrono e filtro de logs por substring, nao um uso direto de `orgCode` como autorizacao.

## Resultado consolidado dos testes estaticos obrigatorios

| Verificacao | Resultado | Evidencia/conclusao |
| --- | --- | --- |
| Jogador comum ve shell Staff | **Sim** | `dashboard` universal + fallback de `visibleModules` faz `canOpenPanel('staff')` retornar true. |
| Rota Staff pode ser ativada diretamente | **Sim** | `setActiveShell()` nao tem guard e e exportada globalmente. O conteudo principal tem guard tardio, mas shell/header ja foram ativados. |
| Tabs sem capability | **Sim** | Todas as 7 tabs de org, 5 tabs Staff e 8 tabs do detalhe Staff sao arrays hard-coded renderizados sem filtro. |
| Callback manual ignora backend | **Nao, com ressalvas** | Os callbacks sao chamaveis, mas o `source` real e os exports seguros bloqueiam a maioria. Ressalvas criticas: permissao global contaminada por org, alias Staff em `CanOrg` e filtro de logs textual. |
| `staff.*` pode ser concedida/avaliada por org | **Sim** | Allowlist de grade inclui `staff.*`; `HasGlobalPermission` agrega orgs; `staff.orgs.set_leader` tambem passa por `CanOrg`. Novas gravacoes possuem restricoes, mas legado/seed continua relevante. |
| Resposta pode misturar `orgCode` | **Sim** | No frontend, races do org workspace e detalhe Staff; no backend, logs usam substring. Membros, banco, extrato, metas e recrutamento consultados com orgCode usam escopo/revalidacao no core e nao mostraram mistura estrutural equivalente. |
| Troca de contexto limpa tudo | **Nao** | Limpeza completa ocorre apenas em legal/illegal; requests nao sao cancelados e respostas nao verificam contexto capturado. |
| `orgCode` da NUI usado como autorizacao | **Nao diretamente** | E normalizado e revalidado por guard/export. Continua sendo input nao confiavel e nao pode virar contexto autorizado por si so. |
| `source`, ator ou `createdBy` confiado da NUI | **Nao** | Ator vem de `source` server-side. `citizenid` e identificador de alvo. `targetId` so permanece em um fallback legado explicitamente opt-in e desativado por padrao. |
| Mutation remota sem rate limit no wrapper | **Nao encontrada** | Todas as mutations atuais de org, membros, banco, recrutamento e metas possuem cooldown. Os buckets sao apenas em memoria e nao sao limpos por `playerDropped`. |
| Mutation sensivel sem auditoria prometida | **Sim** | Promote/demote seguros nao geram a auditoria descrita; alguns bloqueios comuns tambem nao sao registrados. |
| Layout garantido em 1280x720 | **Nao** | Ha scroll defensivo, mas breakpoints usam viewport, tabelas chegam a 850 px e tabs/modais paralelos nao possuem teste objetivo de container. |

## Layout e CSS em 1280x720

Em 1280x720 o painel mede 1232x672 (`style.css:85-93`) e mantem sidebar de 280 px, deixando cerca de 952 px para main antes de paddings. O scroll vertical central existe (`style.css:405-410`), mas ha riscos:

- tabelas globais usam `min-width:720px` (`style.css:664-667`); tabelas especificas usam 740, 760, 820 e 850 px (`style.css:1334-1344`, `1688-1698`, `1891-1901`, `1974-1983`, `2754-2765`), forçando scroll horizontal dentro de cards;
- sete abas de org e oito abas de detalhe Staff usam `flex-wrap`, aumentando a altura do header e empurrando conteudo em 672 px uteis (`style.css:1243-1268`, `2705-2725`);
- ha quatro implementacoes paralelas de modal com `position:absolute` e uma Staff com `position:fixed` (`style.css:1434-1451`, `1705-1722`, `1995-2012`, `3198-3215`), com stacks e comportamento de foco diferentes;
- a quebra de grids so ocorre por largura da viewport em 920 px (`style.css:3306-3457`), nao pela largura real do main apos a sidebar. Em viewport 1280, o media query nao ativa mesmo que o container de conteudo seja muito menor;
- o breakpoint de 760 px esconde a sidebar inteira sem oferecer navegacao substituta (`style.css:868-885`);
- `html/body/#app` e `.panel-shell` cortam overflow externo (`style.css:26-32`, `85-93`), portanto qualquer elemento que escape do scroll interno fica invisivel.

Conclusao: tabelas possuem scroll defensivo, mas o CSS nao e container-responsive e nao ha garantia objetiva para todos os modais/tabs em 1280x720. A V2 deve testar o container real de aproximadamente 952x608, nao apenas `window.innerWidth`.

## Codigo reaproveitavel

- Contratos de callback e nomes existentes em `client/main.lua`; devem ser mantidos por um adapter V2.
- Validacoes server-side e exports seguros de org/membros/banco/recrutamento/metas/logs, apos corrigir as lacunas descritas.
- Padrao `{ok=true,data}` / `{ok=false,error}` para todos os endpoints, normalizando tambem sessao.
- Conceitos de `escapeHtml`, formatacao, mascaramento e catalogo de labels; portar para funcoes TypeScript testaveis, nao copiar globals.
- Registry declarativo de features/painel como ideia; reconstruir com tipos e guards.
- Design tokens basicos do `:root`, revisados e divididos por foundations/components.
- Mock local como ideia, substituido por fixtures tipadas por cenario.

## Codigo a descartar depois do corte

- Renderizacao por strings e `app.innerHTML` (`router.js:530-541`).
- `bindEvents()` global/rebinding (`router.js:3849-4107`).
- O singleton mutavel e os nove campos de rota/contexto sobrepostos.
- Paineis separados por tipo de org e `shellModules`/`moduleShells` duplicados.
- Guards baseados em `session.modules` e fallback dashboard.
- Queries e mutations dentro do roteador.
- CSS monolitico e modais duplicados.
- Stubs/typos de UI (`rrenderTechnicalDetails`) e caches nao usados.
- Placeholders de VIP/event e cards "fase futura" que nao representam capability real.

## Lacunas de API

1. Sessao V2 com entrypoint validado, contexts por org, features e `staffContext` separado.
2. Semantica global genuina: export/servico que nao agregue capabilities de org para `staff.*`.
3. Capability dedicada para visualizar access model/cargos; hoje `org.view` e suficiente no core.
4. Endpoint/consulta de logs com coluna/index de `org_code` e igualdade, nao busca textual no JSON.
5. Respostas com `code`, `message`, `requestId` e `retryable`; hoje so ha string traduzida.
6. Revisao/endpoint de auditoria para promote/demote e tentativas bloqueadas.
7. Feature flags por org (`bank`, `storage`, `salary`, `recruitment`, `goals`, etc.) no contrato de sessao.
8. Opcional: endpoint agregado Staff por org, com field-level authorization, para evitar oito requests e tabs falsas.
9. Progresso/conclusao de metas ainda nao possui callback.
10. Politica de org arquivada na sessao e nas leituras.

## Divergencias entre documentacao e implementacao

| Documento/afirmacao | Implementacao real |
| --- | --- |
| `API_CONTRACT.md:40-69` lista exports usados | Omite `GetPlayer`, `GetPlayerSession`, `GetPlayerOrgs`, `HasPermission` e todos os exports posteriores de update/archive/grade permission. |
| Sessao documenta `gradeName` (`API_CONTRACT.md:81-90`) | `server/session.lua:120-127` nao envia `gradeName`; o frontend cai em `gradeCode`. |
| Set leader exige somente global (`API_CONTRACT.md:351-352`) | Wrapper e core tambem aceitam `CanOrg(..., 'staff.orgs.set_leader')`. |
| Promote/demote geram auditoria (`API_CONTRACT.md:886-887`) | Funcoes seguras nao registram logs de sucesso/bloqueio. |
| Resposta promote possui `action`, `oldGradeCode`, `newGradeCode` (`API_CONTRACT.md:839-852`) | Core retorna `oldGrade`, `newGrade`, `grade`, `gradeCode`, `gradeName`; nao retorna esses tres campos documentados. |
| Metas validam whitelist de tipo e datas (`API_CONTRACT.md:656-675`) | Core apenas limita strings e nao compara datas (`mz_core/server/orgs/service.lua:1658-1673`). |
| "Remocao offline" nao criada (`API_CONTRACT.md:950`) | Remocao usa citizenid + membership persistida e nao exige alvo online. |
| `FRONTEND_ARCHITECTURE.md:34-53` chama Staff de seguro | A abertura/rota tem fallback dashboard e tabs sem capability; o detalhe dispara todos os dominios. |
| `UX_NAVIGATION_PLAN.md:53` diz nao existir `activeOrgCode` | O arquivo e historico/stale; o estado atual possui nove campos sobrepostos. |
| `STAFF_PANEL_REVIEW.md:104-108` lista liberacao Staff | Omite `staff.orgs.view` e `staff.orgs.create`, que `buildModules()` considera via `staffAllowed` (`server/session.lua:231-262`). |
| `SECURITY_CONTEXT_REVIEW.md:195` diz que `recruitment.view/manage` nao existe no catalogo compartilhado | Ambas existem em `shared/capabilities.lua:24-26`. |
| Comentario do extrato diz export inexistente (`server/bank.lua:167-168`) | `ListOrgAccountTransactions` existe e e chamado na linha seguinte. |
| Cards dizem editor de permissions futuro (`router.js:2476`, `3092`) | Modal de permissions ja existe (`router.js:2111-2255`). |

## Matriz de severidade

| Severidade | Achado | Impacto | Evidencia principal |
| --- | --- | --- | --- |
| Critica | `HasGlobalPermission` agrega capabilities de qualquer org, inclusive `staff.*` | Escopo Staff/global pode ser concedido por dado de org/seed legado; afeta varios bypasses | `mz_core/server/orgs/service.lua:1002-1044` |
| Critica | Filtro de logs por substring/JSON | Possivel leitura de log de outro orgCode | `mz_core/server/logs/service.lua:250-253`, `379-385` |
| Alta | Shell Staff visivel/ativavel por jogador comum | Exposicao administrativa visual, confusao e superficie de ataque | `permissions.js:92-115`; `router.js:138-150`, `208-229` |
| Alta | Respostas assincronas misturam contexto | Dados de org A podem aparecer sob org B; mutation pode ser iniciada sobre percepcao errada | `router.js:296-361`, `413-520` |
| Alta | `staff.orgs.set_leader` aceito por org | Fronteira global/org inconsistente em acao sensivel | `server/members.lua:140-149`; core `service.lua:260-264` |
| Alta | Tabs e loads sem capability | Vazamento de nomes/estrutura visual, requests desnecessarios e UX enganosa; backend vira unico guard | `router.js:52-88`, `819-837`, `1690-1701`, `1819-1838` |
| Alta | Auditoria ausente em promote/demote | Mutations de hierarquia sem trilha prometida | core `service.lua:1383-1439` |
| Media | Sessao fora do envelope/request-response | Timeout e correlacao frageis; V2 precisa adapter especial | `client/main.lua:110-113`, `247-252` |
| Media | Falhas viram listas vazias | Operacao degradada parece dado legitimo | handlers citados acima |
| Media | CSS depende da viewport, nao do container | Overflow/empilhamento em 1280x720 e layouts com sidebar | `style.css:85-93`, `3306-3457` |
| Media | Debug ligado | Comandos/mock de desenvolvimento exigem perfil de producao separado; convite por source permanece desativado por flag independente | `shared/config.lua`; `server/members.lua` |
| Baixa | Caches mortos, comentarios/placeholders stale | Manutencao e documentacao enganosas | `state.js:99`; `bank.lua:167`; `router.js:2476` |
| Baixa | Typo/stub em UI | Codigo morto e API inconsistente | `web/core/ui.js:180-185` |

## Decisao de auditoria

A proposta arquitetural do briefing foi validada com um ajuste de ordem: antes de qualquer workspace V2, corrigir/definir a fronteira de permissao global, igualdade de `orgCode` nos logs e o contrato de sessao V2. Depois, construir um unico workspace de organizacao dirigido por `contextId + capabilities + features`, um workspace Staff separado e o Hub como seletor. A seguranca continua integralmente server-side; guards React apenas evitam exposicao e requests indevidos.
