# Inventario de API para o frontend V2

> Atualizacao Fase 0 (2026-07-21): `logs:list` agora despacha para `ListOrgLogsSecure` ou `ListGlobalLogsSecure`; promote/demote aceitam `options?` e exigem `auditId`; `session:get` retorna sessao V2 correlacionada e ainda emite `session:set`. Nomes NUI foram preservados. Consulte `SESSION_V2_CONTRACT_FINAL.md` e `API_CONTRACT.md`.

Data: 2026-07-21. Fonte de verdade: handlers em `client/main.lua` e `server/*.lua`, conferidos contra os exports reais de `mz_core`. Este inventario cobre os 35 callbacks NUI registrados hoje.

## Convencoes reais

Exceto `session:get`, callbacks de dados seguem:

```ts
type NuiOk<T> = { ok: true; data: T };
type NuiError = { ok: false; error: string };
type NuiResult<T> = NuiOk<T> | NuiError;
```

`close` retorna `{ok:true}` sem `data`. `session:get` tambem retorna imediatamente `{ok:true}`, mas o dado chega fora dessa resposta, por `SendNUIMessage({action:'session:set', payload: session})`. O client gera `requestId`, aguarda `mz_org:client:serverResponse` e aplica timeout de 5 s (`client/main.lua:15-31`, `254-265`).

Classificacao:

- **read**: sem mudanca de dominio;
- **mutation**: escrita operacional comum;
- **sensitive**: escrita administrativa, financeira ou de hierarquia;
- contexto **org**: capability deve ser resolvida para o `orgCode` alvo;
- contexto **staff/global**: permissao nao deve depender de uma org pessoal;
- contexto **local**: somente CEF/client.

## Shell e sessao

| NUI | Evento server / handler | Tipo | Payload atual | Response atual | Export `mz_core` | Permissao esperada | Contexto | Problema | Compatibilidade V2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `close` | nenhum; `client/main.lua:105-108` | mutation local | ignorado | `{ok:true}` | nenhum | painel aberto localmente | local | Nao invalida requests pendentes. | Manter nome; V2 deve cancelar queries e limpar estado efemero. |
| `session:get` | `mz_org:server:requestSession`; `server/session.lua:421-426` | read | ignorado hoje | ACK `{ok:true}`; sessao chega em `session:set` | `GetPlayer`, `GetPlayerSession`, `GetPlayerOrgContext` -> fallback `GetPlayerOrgs`, `HasGlobalPermission` -> fallback `HasPermission` | source real; owner ACE e permissoes calculadas | global + orgs | Nao recebe entrypoint; resposta fora do envelope; `GetPlayerSession` e lido mas ignorado; `modules` global. | Preservar callback e mensagem durante transicao; aceitar `{requestedEntry}` e retornar/emitir contrato V2 versionado. |

## Organizacoes e cargos Staff

| NUI | Evento server / handler | Tipo | Payload atual | Response `data` atual | Export `mz_core` | Permissao usada | Contexto | Problema | Compatibilidade V2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `orgs:list` | `mz_org:server:listOrgs`; `server/orgs.lua:310-313` | read | vazio/ignorado | `OrgSummary[]` | `ListOrgs()`; para nao-Staff usa `GetPlayerOrgContext`/`GetPlayerOrgs` | owner ou global `staff.orgs.view/manage/create/set_leader` ve tudo; demais veem somente contextos proprios | staff ou org | Um endpoint tem semantica dual; permissao "global" pode vir de org. | Manter; adapter V2 separa `staff.listOrganizations` de contexts da sessao. |
| `orgs:get` | `mz_org:server:getOrg`; `server/orgs.lua:315-337` | read | `{orgCode}` | `OrgSummary` normalizado ou erro | `GetOrgByCode(orgCode)`; guard `CanOrg` | owner/Staff view-like ou `CanOrg(orgCode,'org.view')` | staff ou org | `org.view` permite detalhe basico; resposta nao declara features. | Manter payload; tipar retorno e exigir que `orgCode` venha do context registry. |
| `orgs:createFromTemplate` | `mz_org:server:createOrgFromTemplate`; `server/orgs.lua:339-400` | sensitive | `{type|orgType, code|orgCode, name, hasSalary, hasSharedAccount, hasStorage, reason?}` | objeto retornado pelo core, normalmente `{org, template,...}` | `CreateOrgFromTemplate(source,payload)` | owner ou global `staff.orgs.create` | staff/global | Response nao tem schema fechado; rate limit por source; depende da semantica global ambigua. | Nome/payload preservados; V2 valida schema e invalida lista/contextos apos sucesso. |
| `orgs:updateBasic` | `mz_org:server:updateOrgBasic`; `server/orgs.lua:402-458` | sensitive | `{orgCode,name,status,hasSalary,hasSharedAccount,hasStorage,reason?}` | objeto do core, normalmente `{org,before,after}` | `UpdateOrgBasicInfo(source,orgCode,payload)` | owner ou global `staff.orgs.manage` | staff/global | UI e backend chamam `inactive` de status e tambem possuem archive separado; contrato de retorno aberto. | Preservar; V2 trata status/arquivamento como estados distintos ate decisao. |
| `orgs:createGrade` | `mz_org:server:createGrade`; `server/orgs.lua:522-560` | sensitive | `{orgCode,code,name,level,salary,priority?,inheritsLevel?,reason?}` | `{grade,before?,after?}`/objeto core | `CreateOrgGrade(source,orgCode,payload)` | owner ou global `staff.orgs.manage`; core protege top grade | staff/global | Capability de gerenciar grade nao e dedicada; response aberta. | Preservar; route/action guard por `staff.orgs.manage`. |
| `orgs:updateGradeBasic` | `mz_org:server:updateGradeBasic`; `server/orgs.lua:562-599` | sensitive | `{orgCode,gradeId,name,level,salary,priority?,inheritsLevel?,reason?}` | `{grade,before,after}`/objeto core | `UpdateOrgGradeBasic(source,orgCode,gradeId,payload)` | owner ou global `staff.orgs.manage`; core protege top grade | staff/global | `gradeId` e number no server, service aceita truthy generico; response aberta. | Preservar; normalizar ID e refetch access model. |
| `orgs:archive` | `mz_org:server:archiveOrg`; `server/orgs.lua:601-619` | sensitive | `{orgCode,reason?}` | `{org,before,after}`/objeto core | `ArchiveOrg(source,orgCode,reason)` | owner ou global `staff.orgs.manage` | staff/global | Politica de contexts arquivados nao definida. | Preservar; invalidar sessao/contexts se a org ativa for arquivada. |
| `orgs:reactivate` | `mz_org:server:reactivateOrg`; `server/orgs.lua:621-639` | sensitive | `{orgCode,reason?}` | `{org,before,after}`/objeto core | `ReactivateOrg(source,orgCode,reason)` | owner ou global `staff.orgs.manage` | staff/global | Mesma lacuna de politica de arquivamento. | Preservar; refetch org/lista/sessao. |
| `orgs:disableGrade` | `mz_org:server:disableGrade`; `server/orgs.lua:641-661` | sensitive | `{orgCode,gradeId,reason?}` | `{grade,before,after}`/objeto core | `DisableOrgGrade(source,orgCode,gradeId,reason)` | owner ou global `staff.orgs.manage`; core bloqueia top/in-use | staff/global | Nao ha capability dedicada. | Preservar; refetch access model e membros. |
| `orgs:reactivateGrade` | `mz_org:server:reactivateGrade`; `server/orgs.lua:663-683` | sensitive | `{orgCode,gradeId,reason?}` | `{grade,before,after}`/objeto core | `ReactivateOrgGrade(source,orgCode,gradeId,reason)` | owner ou global `staff.orgs.manage` | staff/global | Nao ha capability dedicada. | Preservar; refetch access model. |
| `orgs:addGradePermission` | `mz_org:server:addGradePermission`; `server/orgs.lua:685-707` | sensitive | `{orgCode,gradeId,permission,reason?}` | `{gradeId,permission,permissions,before,after}` | `AddOrgGradePermission(source,orgCode,gradeId,permission,reason)` | owner ou global `staff.orgs.manage`; `staff.*` exige owner e org staff no core | staff/global | Allowlist inclui permissoes Staff e aliases; fronteira global/org continua misturada. | Preservar; catalogo V2 deve marcar scope e alias; nunca campo livre. |
| `orgs:removeGradePermission` | `mz_org:server:removeGradePermission`; `server/orgs.lua:709-731` | sensitive | `{orgCode,gradeId,permission,reason?}` | `{gradeId,permission,permissions,before,after}` | `RemoveOrgGradePermission(source,orgCode,gradeId,permission,reason)` | igual ao anterior | staff/global | Remocao grava allow false; inherited/base nao e removivel por este fluxo. | Preservar; UI distingue direct/inherited/base. |

`OrgSummary` normalizado pelo `mz_org` contem `code,name,type,is_public,requiresWhitelist,hasSalary,hasSharedAccount,hasStorage,active,status,locked,protected,memberCount,playerRole,grade,gradeCode` (`server/orgs.lua:220-246`).

## Membros e lideranca

| NUI | Evento server / handler | Tipo | Payload atual | Response `data` atual | Export `mz_core` | Permissao usada | Contexto | Problema | Compatibilidade V2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `members:list` | `mz_org:server:listMembers`; `server/members.lua:169-204` | read | `{orgCode}` | `Member[]` | `ListOrgMembers(source,orgCode)` | wrapper: owner/global Staff view-like ou `CanOrg('org.view')`; core tambem aceita `members.view` | org ou staff | Falha de export vira `[]`; UI carrega mesmo sem capability; docs omitem `members.view`. | Preservar; query key obrigatoria `['context',contextId,'members']`. |
| `members:invite` | `mz_org:server:inviteMember`; `server/members.lua` | mutation | `{orgCode,citizenid|targetCitizenId|passport,gradeLevel?,gradeCode?}`; fallback legado opt-in aceita `{targetId|targetSource}` | `{orgCode,targetCitizenId,targetName,grade,gradeLevel,gradeCode,gradeName}` | `InviteOrgMemberByCitizenId`; opt-in `InviteOrgMember` | owner, global `staff.members.invite`, ou `CanOrg('members.invite'|'manage.members')`; hierarquia/top grade no core | org | Fallback por source desativado por padrao; UI V2 nunca o envia. | Preservar callback e manter `Config.AllowLegacyTargetSourceInvite=false` em producao. |
| `members:remove` | `mz_org:server:removeMember`; `server/members.lua:271-307` | sensitive | `{orgCode,citizenid}` | `{orgCode,targetCitizenId,removed:true}` | `RemoveOrgMember(source,orgCode,citizenid)` | owner/global `staff.orgs.manage` ou `members.remove|members.kick|manage.members`; hierarquia no core | org | Sucesso auditado, mas bloqueios comuns nao; docs dizem remocao offline ausente, embora funcione por membership persistida. | Preservar; confirmacao e refetch atomico. |
| `members:promote` | `mz_org:server:promoteMember`; `server/members.lua:309-353` | sensitive | `{orgCode,citizenid}` | `{orgCode,targetCitizenId,oldGrade,newGrade,grade,gradeCode,gradeName}` | `PromoteOrgMemberSecure` (nome escolhido dinamicamente) | owner/global `staff.orgs.manage` ou `members.promote|manage.members`; top grade dedicado | org | Core nao audita sucesso/bloqueio; docs descrevem campos inexistentes. | Preservar; corrigir auditoria antes de liberar na V2. |
| `members:demote` | `mz_org:server:demoteMember`; `server/members.lua:309-357` | sensitive | `{orgCode,citizenid}` | mesmo formato de promote | `DemoteOrgMemberSecure` (dinamico) | owner/global `staff.orgs.manage` ou `members.demote|manage.members`; top grade dedicado | org | Core nao audita sucesso/bloqueio. | Preservar; mesma condicao de liberacao. |
| `members:setLeader` | `mz_org:server:setOrgLeader`; `server/members.lua:359-411` | sensitive | `{orgCode,citizenid|targetCitizenId,reason?}` | `{orgCode,targetCitizenId,targetName,oldGrade*,grade,gradeLevel,gradeCode,gradeName,topGrade*}` | `SetOrgLeaderByCitizenId(source,orgCode,citizenid,{reason})` | owner, `HasGlobalPermission('staff.orgs.set_leader')` **ou** `CanOrg(orgCode,'staff.orgs.set_leader')` | staff/global (hoje contaminado por org) | Usa permissao Staff como capability de org; acao de maior impacto. | Preservar somente como adapter; remover caminho `CanOrg(staff.*)` apos migracao de dados/aliases. |

`Member` normalizado: `{citizenid,name,orgCode,grade,gradeCode,gradeName,isLeader,isDuty,joinedAt,lastSeen,status}` (`server/members.lua:151-166`).

## Banco

| NUI | Evento server / handler | Tipo | Payload atual | Response `data` atual | Export `mz_core` | Permissao usada | Contexto | Problema | Compatibilidade V2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `org-bank:get` | `mz_org:server:getOrgBank`; `server/bank.lua:129-156` | read | `{orgCode}` | `{orgCode,balance,currency,canView}` | `GetOrgAccount(source,orgCode)` | owner; global Staff view-like; ou `account.view|org.view` no core | org ou staff | `org.view` permite ver saldo; policy pode ser ampla demais. | Preservar; feature `bank` + capability `account.view`. |
| `org-bank:transactions` | `mz_org:server:listOrgBankTransactions`; `server/bank.lua:158-182` | read | `{orgCode,filters?:{limit,offset,type,status,search}}` | `Transaction[]` do core | `ListOrgAccountTransactions(source,orgCode,filters)` | mesma visualizacao da conta | org ou staff | `status/search` sao aceitos pelo wrapper mas ignorados pelo core; falha de export vira `[]`; comentario diz export inexistente. | Preservar campos usados (`limit,offset,type`); deprecar os demais ou implementar. |
| `org-bank:deposit` | `mz_org:server:depositOrgBank`; `server/bank.lua:184-217` | sensitive | `{orgCode,amount,reason?}` | `{orgCode,balance,currency,transactionId}` | `DepositOrgAccount(source,orgCode,amount,reason)` | owner ou `account.deposit|account.manage|manage.account` | org | Cooldown compartilhado com saque; UI pode liberar para Staff sem capability em alguns contextos. | Preservar; mutation invalida account+transactions. |
| `org-bank:withdraw` | `mz_org:server:withdrawOrgBank`; `server/bank.lua:219-252` | sensitive | `{orgCode,amount,reason?}` | `{orgCode,balance,currency,transactionId}` | `WithdrawOrgAccount(source,orgCode,amount,reason)` | owner ou `account.withdraw|account.manage|manage.account` | org | Operacao financeira; sem idempotency key no contrato NUI. | Preservar inicialmente; V2 deve impedir double-submit e propor idempotencia backend antes de retries automaticos. |

`Transaction` real do core contem `id,orgId,orgCode,type,amount,balanceBefore,balanceAfter,actorCitizenId,actorName,reason,createdAt`.

## Recrutamento

| NUI | Evento server / handler | Tipo | Payload atual | Response `data` atual | Export `mz_core` | Permissao usada | Contexto | Problema | Compatibilidade V2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `recruitment:list` | `mz_org:server:listRecruitment`; `server/recruitment.lua:212-242` | read | `{orgCode,status?,type?,search?,limit?,offset?}` | `Recruitment[]` | `ListOrgRecruitment(source,orgCode,filters)` | owner/global Staff view-like ou `recruitment.view|recruitment.manage|members.invite|manage.members` | org ou staff | `type` e normalizado no wrapper, mas ignorado pelo core. | Preservar; orgCode/context obrigatorio. |
| `recruitment:get` | `mz_org:server:getRecruitment`; `server/recruitment.lua:244-273` | read | `{id,orgCode}` | `Recruitment` | `GetOrgRecruitment(source,id)` | preguard no orgCode informado e revalidacao pelo org da row no core | org | `orgCode` serve apenas ao preguard; core usa org real. Service frontend nao envia orgCode (`recruitment-service.js:18-22`), entao a chamada normal e negada. | Corrigir V2 para sempre enviar context orgCode sem renomear callback. |
| `recruitment:create` | `mz_org:server:createRecruitment`; `server/recruitment.lua:275-316` | mutation | `{orgCode,citizenid|targetCitizenId|passport,desiredGradeLevel|gradeLevel?,desiredGradeCode|gradeCode?,note?}` | `Recruitment` | `CreateOrgRecruitment(source,orgCode,payload)` | owner ou `recruitment.manage|members.invite|manage.members` | org | `desiredGradeLevel` nao e normalizado no wrapper, mas core valida. | Preservar; payload tipado e context-bound. |
| `recruitment:approve` | `mz_org:server:approveRecruitment`; `server/recruitment.lua:318-345` | sensitive | `{id,gradeLevel?,gradeCode?,note?}` | `{recruitment,member}` | `ApproveOrgRecruitment(source,id,options)` | core resolve row e exige manage na org real | org | Nao envia orgCode; seguro no core, mas dificulta query key/UX e confirmacao contextual. | Preservar; V2 inclui context local e verifica response org antes de atualizar cache. |
| `recruitment:reject` | `mz_org:server:rejectRecruitment`; `server/recruitment.lua:347-369` | sensitive | `{id,reason|note?}` | `Recruitment` | `RejectOrgRecruitment(source,id,reason)` | core resolve row e exige manage na org real | org | Mesmo ponto de contexto implicito. | Preservar; invalidar lista do context ativo. |
| `recruitment:cancel` | `mz_org:server:cancelRecruitment`; `server/recruitment.lua:371-393` | sensitive | `{id,reason|note?}` | `Recruitment` | `CancelOrgRecruitment(source,id,reason)` | core resolve row e exige manage na org real | org | Mesmo ponto de contexto implicito. | Preservar. |

`Recruitment` normalizado: `{id,orgCode,type,status,candidateName,candidateCitizenId,targetName,targetCitizenId,desiredGradeLevel,desiredGradeCode,note,decisionNote,createdAt,updatedAt,reviewedAt,message,source:null}` (`server/recruitment.lua:162-183`).

## Metas

| NUI | Evento server / handler | Tipo | Payload atual | Response `data` atual | Export `mz_core` | Permissao usada | Contexto | Problema | Compatibilidade V2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `goals:list` | `mz_org:server:listGoals`; `server/goals.lua:204-234` | read | `{orgCode,status?,type?,search?,limit?,offset?}` | `Goal[]` | `ListOrgGoals(source,filters)` | owner/global Staff view-like ou `goals.view|goals.manage|org.view` na org | org ou staff | Sem orgCode, Staff view-like pode consultar global; falha vira `[]`. | Preservar; V2 org workspace sempre envia orgCode; Staff usa endpoint/route explicito. |
| `goals:get` | `mz_org:server:getGoal`; `server/goals.lua:236-260` | read | `{id,orgCode}` | `Goal` ou `{}` | `GetOrgGoal(source,id)` | preguard no orgCode e core revalida org real | org | Service frontend envia apenas id (`goal-service.js:10-14`), entao chamada normal e negada; not found/export failure vira `{}`. | V2 sempre envia orgCode; manter nome. |
| `goals:create` | `mz_org:server:createGoal`; `server/goals.lua:262-313` | mutation | `{orgCode,title,description?,type?,target,startsAt?,endsAt?}` | `Goal` | `CreateOrgGoal(source,orgCode,payload)` | owner/global `staff.orgs.manage` ou `goals.manage|manage.goals` | org | UI libera qualquer Staff; core nao implementa whitelist de tipo nem validacao/ordem de datas descritas nos docs. | Preservar callback; bloquear V2 ate alinhar validacoes documentadas. |

`Goal`: `{id,orgCode,title,description,type,status,target,progress,progressPercent,startsAt,endsAt,createdByName,priority}` (`server/goals.lua:173-201`). Nao existem callbacks de editar, progresso, concluir ou excluir.

## Logs e modelo de acesso

| NUI | Evento server / handler | Tipo | Payload atual | Response `data` atual | Export `mz_core` | Permissao usada | Contexto | Problema | Compatibilidade V2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `logs:list` | `mz_org:server:listLogs`; `server/logs.lua` | read | `{orgCode?,category?,severity?,search?,dateFrom?,dateTo?,limit?,offset?}` | `Log[]` | org: `ListOrgLogsSecure(source,orgCode,filters)`; global: `ListGlobalLogsSecure(source,filters)` | global: owner ou `staff.logs.view`; org: owner, `staff.logs.view` ou `CanOrg('logs.view')` | org ou staff/global | Fase 0 concluida: escopo por `org_code = ?`; global usa `org_code IS NULL`; falha de export e erro, sem fallback. | Nome NUI preservado; envelope V2 recomendado. |
| `org-access:get` | `mz_org:server:getOrgAccess`; `server/permissions.lua:109-139` | read | `{orgCode}` | `{orgCode,orgName,type,baseCapabilities,grades}` | `GetOrgAccessModel(source,orgCode)` | core: owner/Staff view-like ou `org.view|members.view` | org ou staff | Nao ha capability dedicada para ver cargos/permissoes; falha vira modelo vazio. | Preservar; route guard provisoria e decisao aberta para capability dedicada. |

`Log` normalizado: `{id,createdAt,category,action,severity,orgCode,actorName,actorCitizenId,targetName,targetCitizenId,message,reason,meta}`. O `meta` e sanitizado no core, mas o filtro de scoping precisa ser corrigido.

O access model normaliza grades como `{id,level,code,name,salary,priority,active,inheritsGradeId,inheritsLevel,inheritsCode,capabilities,directCapabilities}`.

## Todos os exports do `mz_core` efetivamente chamados

Sao 42 nomes distintos chamados diretamente pelo `mz_org` apos a Fase 0. `ListLogs` permanece export compativel no core, mas o wrapper usa os dois contratos seguros novos.

| Export | Onde `mz_org` chama |
| --- | --- |
| `GetPlayer` | `server/session.lua:370` |
| `GetPlayerSession` | `server/session.lua:371` (resultado nao usado) |
| `GetPlayerOrgContext` | `server/session.lua:372`; `server/orgs.lua:273`; debug `server/main.lua:81` |
| `GetPlayerOrgs` | fallback `server/session.lua:374`; `server/orgs.lua:276` |
| `HasPermission` | fallback `server/session.lua:190` |
| `HasGlobalPermission` | sessao `server/session.lua:186`; guards em `server/orgs.lua:256-269`, `members.lua:121-148`, `recruitment.lua:103-115`, `goals.lua:111-145`; debug `server/main.lua:75-79` |
| `CanOrg` | guards em `server/orgs.lua:307`, `members.lua:137/148`, `recruitment.lua:119-146`, `goals.lua:131-157`; debug `server/main.lua:84-88` |
| `ListOrgs` | `server/orgs.lua:289` |
| `GetOrgByCode` | `server/orgs.lua:329` |
| `CreateOrgFromTemplate` | `server/orgs.lua:373` |
| `UpdateOrgBasicInfo` | `server/orgs.lua:436` |
| `CreateOrgGrade` | `server/orgs.lua:544` |
| `UpdateOrgGradeBasic` | `server/orgs.lua:584` |
| `ArchiveOrg` | `server/orgs.lua:612` |
| `ReactivateOrg` | `server/orgs.lua:632` |
| `DisableOrgGrade` | `server/orgs.lua:654` |
| `ReactivateOrgGrade` | `server/orgs.lua:676` |
| `AddOrgGradePermission` | `server/orgs.lua:700` |
| `RemoveOrgGradePermission` | `server/orgs.lua:724` |
| `GetOrgAccessModel` | `server/permissions.lua:118` |
| `ListOrgMembers` | `server/members.lua:183`; debug `server/main.lua:90` |
| `InviteOrgMemberByCitizenId` | `server/members.lua:244` |
| `InviteOrgMember` | debug fallback `server/members.lua:246` |
| `RemoveOrgMember` | `server/members.lua:291` |
| `PromoteOrgMemberSecure` | nome dinamico em `server/members.lua:328-329` |
| `DemoteOrgMemberSecure` | nome dinamico em `server/members.lua:328-329` |
| `SetOrgLeaderByCitizenId` | `server/members.lua:393` |
| `GetOrgAccount` | `server/bank.lua:138` |
| `ListOrgAccountTransactions` | `server/bank.lua:169` |
| `DepositOrgAccount` | `server/bank.lua:206` |
| `WithdrawOrgAccount` | `server/bank.lua:241` |
| `ListOrgRecruitment` | `server/recruitment.lua:221` |
| `GetOrgRecruitment` | `server/recruitment.lua:259` |
| `CreateOrgRecruitment` | `server/recruitment.lua:303` |
| `ApproveOrgRecruitment` | `server/recruitment.lua:333` |
| `RejectOrgRecruitment` | `server/recruitment.lua:362` |
| `CancelOrgRecruitment` | `server/recruitment.lua:386` |
| `ListOrgGoals` | `server/goals.lua:213` |
| `GetOrgGoal` | `server/goals.lua:251` |
| `CreateOrgGoal` | `server/goals.lua:296` |
| `ListOrgLogsSecure` | `server/logs.lua` quando `orgCode` esta presente |
| `ListGlobalLogsSecure` | `server/logs.lua` quando `orgCode` esta ausente |

## Aliases e consolidacao sem quebra

| Canonica proposta | Aliases atuais | Estrategia |
| --- | --- | --- |
| `members.remove` | `members.kick`, `manage.members` | Resolver aliases server-side por uma tabela versionada; sessao V2 publica somente canonica e, durante transicao, `legacyCapabilities` opcional. |
| `members.invite` / `members.promote` / `members.demote` | `manage.members` | Nao transformar `manage.members` em wildcard no frontend; expandir no servidor para capabilities efetivas por context. |
| `account.manage` | `manage.account` | Publicar `account.manage`; aceitar alias nos handlers existentes ate migrar seeds/dados. |
| `goals.manage` | `manage.goals` | Mesmo padrao. |
| capability dedicada a access model | `org.view`, `members.view`, historico `manage.permissions` | Manter guards atuais no adapter; introduzir a nova capability apenas depois de backfill/politica. |
| `members.set_leader` para lideranca dentro da org | `staff.orgs.set_leader` via `CanOrg` | `staff.orgs.set_leader` fica somente em `staffContext`; manter alias temporario com telemetria e remover apos migracao. |

O frontend V2 nao deve inferir aliases. O servidor deve entregar a lista efetiva canonica por contexto e continuar aceitando payloads/callbacks antigos ate o corte.
