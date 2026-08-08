# Plano de migração do frontend V2

> Progresso (2026-07-21): Fase 0 implementada em codigo, migration e harnesses isolados. Runtime FiveM nao foi aprovado e permanece gate para a Fase 1. Nenhum scaffold React/Vite foi criado.

Data: 2026-07-21. Objetivo: migrar sem renomear/remover callbacks existentes, sem big bang e com rollback verificável em cada fase.

## Regras gerais

- `web/` permanece como legado operacional até o gate de corte.
- `web-v2/` nasce paralelo; nenhuma fase apaga o legado.
- segurança continua server-side; cada callback manualmente chamável deve permanecer protegido.
- `session.modules` só existe como compatibilidade e nunca autoriza a V2.
- cada release tem flag/default que permite voltar ao legado com restart controlado do resource.
- uma fase só avança quando seus critérios objetivos e smoke runtime passam.
- mudanças necessárias no `mz_core`, SQL ou migrations são workstream separado; este plano não as executa nesta auditoria.

## Baseline antes de mudar código

Congelar artefatos de evidência:

- inventário dos 35 callbacks e 41 exports em `FRONTEND_V2_API_INVENTORY.md`;
- fixtures das cinco sessões de `FRONTEND_V2_SESSION_CONTRACT.md`;
- gravações/screenshots em 1280x720 dos nove comandos;
- resultados esperados para chamadas manuais autorizadas e negadas;
- amostra de logs por duas orgs com códigos semelhantes;
- checklist de start/restart do resource e foco NUI.

Rollback global: o artefato anterior do resource e o `ui_page` legado devem continuar disponíveis durante toda a migração.

## Fase 0 — contenção do legado e gates de segurança

### Escopo

- congelar features visuais no legado;
- corrigir o fallback visual que inclui Staff por causa de `dashboard`;
- guardar `setActiveShell`, entrypoints e tabs pela mesma política visual;
- impedir loaders de tabs não autorizadas;
- limpar estado/caches e descartar respostas quando contexto mudar/fechar;
- manter `Config.AllowLegacyTargetSourceInvite=false` em producao; o fallback por source e opt-in independente de `Config.Debug`;
- corrigir a autorização “global” para não agregar `staff.*` de org comum;
- tornar o filtro de logs por `orgCode` estrito;
- completar auditoria das mutations de hierarquia antes de expô-las na V2.

As correções de UI são contenção, não reforma visual. As alterações de core são pré-requisitos de segurança e precisam de revisão própria; não estão autorizadas por este documento.

### Compatibilidade

Nenhum nome de callback/event/export muda. Aliases continuam aceitos pelo backend.

### Checklist runtime

- jogador sem org: `/staff` não mostra shell/header Staff;
- chamada direta a `setActiveShell('staff')` resulta em denied/hub;
- tabs sem capability não aparecem e não disparam requests;
- forjar `orgCode` em todos os reads/mutations retorna forbidden/not found conforme contrato;
- cargo de org comum contendo `staff.*` não abre Staff nem autoriza listagem global;
- `staff.orgs.set_leader` em org comum não define líder;
- logs da org `pol` não retornam registros de `police` por substring;
- troca rápida A -> B nunca renderiza A em B;
- fechar durante request não reabre nem muda estado visível;
- restart do resource restaura foco/fechamento corretamente.

### Aprovação objetiva

- zero falhas nos casos acima;
- evidência server-side de bloqueio para callbacks manuais;
- nenhum callback removido;
- logs de promote/demote e bloqueios sensíveis presentes;
- revisão de segurança aprovada antes de qualquer mutation V2.

### Rollback

Reverter apenas o lote de contenção e restaurar o artefato legado anterior. Se a correção global afetar consumidores externos, manter V2/Staff desabilitados até uma estratégia de compatibilidade ser aprovada; não restaurar semanticamente o bypass como solução permanente.

## Fase 1 — contrato de sessão V2

### Escopo

- estender `session:get`/eventos existentes sem renomeá-los;
- aceitar `requestedEntry`, comando e `requestedOrgCode` como intenção;
- retornar `contractVersion`, `sessionId`, `user`, `entryAllowed`, `defaultContextId`, `contexts[]`, `staffContext` e `compatibility.modules`;
- manter `modules` no topo, se o legado exigir, como alias temporário derivado da V2;
- validar entrada no servidor antes de montar o workspace solicitado;
- garantir `grade.name`, capabilities por org e features por org;
- separar Staff por proveniência global estrita.

### Sequência segura de abertura

1. comando cria uma intenção de entrada;
2. client solicita sessão usando o evento existente estendido;
3. servidor resolve `entryAllowed` pelo `source` real;
4. somente a sessão autorizada é entregue à NUI;
5. a UI monta o workspace permitido ou uma tela neutra de denied, nunca o shell solicitado como fallback.

O callback `session:get` permanece disponível para refresh/recovery. Durante compatibilidade, o legado pode manter o fluxo assíncrono; a V2 usa um adapter até a resposta ser normalizada.

### Checklist runtime

- validar os cinco exemplos de sessão;
- `/org`, `/gang` e comandos de tipo negam quando não existe contexto compatível;
- `/staff` só permite quando `staffContext` existe;
- duas orgs entregam capabilities independentes;
- mudar grade/permissão e refazer sessão altera apenas o contexto afetado;
- uma permissão `staff.*` em org comum não cria `staffContext`;
- sessão inválida/indisponível não dá foco em shell administrativo;
- legado continua abrindo com `modules` compatível.

### Aprovação objetiva

- schema runtime aceita 100% dos cenários válidos e rejeita fixtures inválidas;
- nenhum campo global é inferido no frontend;
- todos os entrypoints têm teste allow/deny;
- snapshot de `modules` legado permanece compatível.

### Rollback

Desabilitar emissão/consumo V2 e voltar ao formato legado mantendo os campos adicionais ignoráveis. Como callbacks não foram renomeados, o rollback não exige alterar a NUI antiga.

## Fase 2 — fundação V2

### Escopo

- criar `web-v2/` com React/TypeScript/Vite;
- implementar transporte NUI tipado, schemas, error model, query client, route registry e guards;
- implementar Hub, denied, loading e error boundaries sem domínio;
- criar tokens, shell e navegação responsiva;
- criar mocks/fixtures e testes de isolamento;
- preparar build `base: './'` e packfile;
- introduzir seletor de frontend com **default legado** para canário; validar sua forma no CEF antes de usá-lo em produção.

Nenhum callback de domínio é reescrito nesta fase.

### Checklist runtime

- build abre sem servidor Node e sem asset 404 no console CEF;
- `GetParentResourceName()` resolve callbacks no resource real;
- Escape fecha e devolve foco;
- abrir/fechar 20 vezes não duplica listeners;
- 1280x720 não corta navegação, denied ou mensagens;
- seletor abre legado por default e V2 apenas para allowlist/canário;
- erro/timeout de sessão é recuperável sem reload do resource.

### Aprovação objetiva

- build limpo e determinístico a partir do lockfile;
- testes de route guard e transporte passam;
- zero paths absolutos em assets gerados;
- bundle e CSS dentro do orçamento definido pela equipe antes da implementação;
- rollback para legado comprovado no mesmo artefato.

### Rollback

Alterar a flag/default do bootstrap para legado e reiniciar `mz_org`. `web-v2/` pode permanecer empacotado, mas inativo.

## Fase 3 — workspace de organização read-only

### Escopo

Migrar nesta ordem:

1. overview;
2. membros;
3. cargos/access model;
4. metas;
5. banco e extrato;
6. recrutamento;
7. logs.

Cada rota entra separadamente e só usa callbacks atuais de leitura. Legal, gang, business, government, VIP e event usam o mesmo workspace. Feature e capability controlam rota e loader.

### Checklist runtime por rota

- usuário com capability vê e carrega dados;
- usuário sem capability não vê rota e chamada programática não executa query;
- forjar callback continua bloqueado no servidor;
- troca A -> B com respostas artificialmente atrasadas não mistura dados;
- voltar para A usa cache de A, nunca cache global;
- org sem conta compartilhada mostra feature indisponível, não erro genérico;
- erro de um bloco Staff/read não se transforma em lista vazia;
- tabelas, tabs e empty/error states funcionam em 1280x720.

### Aprovação objetiva

- paridade funcional read-only com callbacks inventariados;
- zero dependência de `session.modules`;
- zero branch de layout por painel principal de tipo;
- teste de concorrência passa para cada família de query;
- auditoria visual aprovada em três viewports.

### Rollback

Flag por rota/feature retorna o usuário ao workspace legado. Nenhuma mutation ou dado persistido foi introduzido, portanto rollback é apenas de frontend.

## Fase 4 — mutations de organização

### Escopo

Liberar em lotes independentes:

1. criar/revisar recrutamento;
2. convidar/remover membro;
3. promover/rebaixar membro;
4. criar meta;
5. depósito;
6. saque.

Cada lote implementa confirmation, capability da ação, double-submit lock, erro tipado e invalidações específicas. Depósito/saque ficam por último e sem retry/optimistic update.

### Checklist runtime por mutation

- sucesso atualiza apenas o contexto alvo;
- double click produz no máximo uma mutation de UI;
- timeout não dispara retry automático;
- forbidden mantém dados anteriores e exibe erro local;
- trocar contexto durante envio não mostra sucesso no contexto novo;
- mutation forjada com org/ID/citizenid diferente é revalidada pelo core;
- rate limit e auditoria são observáveis;
- banco confere saldo e transaction id antes/depois;
- promote/demote respeitam self, hierarquia e top grade.

### Aprovação objetiva

- matriz allow/deny por capability passa;
- cada sucesso e tentativa sensível tem log esperado;
- nenhum callback novo substitui ou remove o existente;
- reconciliação após mutation vem de refetch server-side;
- lote financeiro aprovado com teste de falha/timeout e sem duplicidade observada.

### Rollback

Desabilitar a feature flag da mutation e manter a rota read-only ou voltar a rota ao legado. Como contratos existentes são usados, não há migração de dados a desfazer.

## Fase 5 — workspace Staff

### Escopo

Ordem obrigatória:

1. overview sem dados sensíveis;
2. lista de organizações;
3. detalhe read-only com field-level authorization;
4. logs/auditoria global;
5. criar/editar/arquivar organização;
6. criar/editar/desativar cargo e permissões;
7. definir líder.

Não reutilizar `isStaffAccess` como bypass universal. Cada rota, bloco e ação usa capability Staff específica e policy decidida em `FRONTEND_V2_OPEN_DECISIONS.md`.

### Checklist runtime

- Staff parcial vê somente rotas/blocos autorizados;
- `staff.orgs.view` isolado não mostra banco, membros completos ou ações sem política explícita;
- organização pessoal nunca vira alvo administrativo automaticamente;
- mudar org no detalhe Staff não altera `contexts[]` pessoais;
- oito requests paralelos do detalhe são cancelados/descartados ao trocar alvo;
- criar/editar/arquivar e cargo/permissão respeitam org arquivada e allowlist;
- `staff.*` não pode ser inserida em org comum;
- definir líder exige a permissão global estrita e gera auditoria.

### Aprovação objetiva

- testes por perfil (viewer, manager, creator, leader manager, logs viewer, owner) passam;
- nenhuma capability organizacional comum concede rota Staff;
- todo bloco sensível tem field-level policy documentada;
- todas as ações sensíveis possuem confirmação, rate limit e auditoria;
- pen-test manual de callback não encontra bypass cross-org/global.

### Rollback

Desabilitar `staffContext.features` ou o workspace Staff V2 inteiro. Staff retorna ao legado apenas se os guards de contenção da Fase 0 continuarem ativos; caso contrário, o entrypoint deve ficar negado, não inseguro.

## Fase 6 — recursos específicos por tipo

### Escopo

- aplicar a matriz decidida de features por tipo;
- adicionar cards/rotas específicas como plugins do OrganizationWorkspace;
- revisar necessidade de `/vip`, `/business`, `/government` e `/event`;
- manter callbacks comuns e criar contrato novo apenas quando existir domínio server-side real.

Não criar tela placeholder como evidência de feature. Uma rota específica precisa de dados, capability, estado vazio, erro e owner server-side definidos.

### Checklist runtime

- cada tipo mostra somente features suportadas;
- comando de tipo sem contexto é negado/explicado sem fallback;
- mesma feature comum tem comportamento idêntico entre tipos;
- plugin específico não importa internals de outro tipo;
- feature desligada não dispara callback;
- 1280x720 permanece dentro do baseline.

### Aprovação objetiva

- matriz tipo x feature aprovada e coberta por testes;
- nenhuma duplicação de workspace/router/store por tipo;
- zero placeholder navegável sem contrato real.

### Rollback

Desligar somente o plugin/feature específica; o workspace comum permanece.

## Fase 7 — corte do legado

### Pré-condições

- todas as rotas necessárias têm paridade e aprovação runtime;
- métricas de erros/timeout/forbidden do canário estão dentro do limite definido;
- decisões abertas bloqueantes foram fechadas;
- Staff e logs passaram revisão de segurança;
- artefato V2 e rollback legado foram testados no mesmo build/release.

### Corte gradual

1. V2 para equipe interna/owner;
2. V2 para Staff parcial;
3. V2 para amostra de jogadores por contexto;
4. V2 default com legado disponível;
5. V2 única após janela de estabilidade;
6. remover assets/globals legados somente em release posterior.

### Checklist runtime

- todos os comandos resolvem entrypoint corretamente;
- jogador sem org, multi-org, Staff parcial e owner passam smoke completo;
- restart de `mz_org` com NUI aberta fecha/recupera foco;
- não há 404, erro JS não tratado ou request pendente;
- callbacks antigos continuam respondendo durante a janela anunciada;
- rollback foi exercitado, não apenas documentado.

### Aprovação objetiva

- zero bug crítico/alto aberto de autorização, isolamento ou perda financeira;
- zero dependência V2 de `modules` por telemetria/busca estática;
- paridade aprovada pelos responsáveis de organização e Staff;
- janela de canário concluída sem regressão bloqueante;
- runbook de rollback executável em um restart do resource.

### Rollback

Voltar o seletor/default para legado e reiniciar o resource. Não apagar `web-v2/`, não reverter dados e não renomear callbacks. Se o incidente for de segurança compartilhada no backend, desabilitar a feature afetada em ambos os frontends até a correção.

## Matriz resumida de gates

| Gate | Bloqueia |
| --- | --- |
| Proveniência global de `staff.*` | sessão V2 Staff, todas as rotas Staff e mutations administrativas |
| Filtro estrito de logs | logs de org e Staff na V2 |
| Auditoria promote/demote | mutations de hierarquia |
| Sessão V2 validada | qualquer workspace V2 em runtime |
| Capability/policy de access model | rota de cargos e detalhe Staff |
| Idempotência/estratégia de timeout financeiro | retries; depósito/saque podem entrar apenas sem retry e com reconciliação explícita |
| Matriz de features por tipo | plugins especiais, não o workspace comum read-only |

## Definição de concluído da migração

A migração só termina quando `ui_page` usa a V2, o legado não recebe tráfego, os callbacks antigos ainda cumprem a janela de compatibilidade definida, `session.modules` não é lido pela V2 e todos os perfis/entrypoints passam o checklist runtime. Remover `web/` é uma limpeza posterior e separada do corte funcional.
