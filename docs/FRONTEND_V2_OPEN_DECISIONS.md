# Decisões abertas para o frontend V2

> Fechamentos da Fase 0 (2026-07-21): permissao Staff global vem somente de owner, ACE explicito ou override global do core; `staff.*` organizacional e invalido; Staff parcial usa somente permissions/features explicitas; organizacao arquivada fica fora do workspace pessoal e bloqueia operacoes; features sao materializadas pelo servidor e tipo nao autoriza modulo. Os demais itens continuam abertos quando nao contrariados por essas politicas.

Data: 2026-07-21. Esta lista contém somente políticas que o código atual não resolve de forma confiável. Bugs confirmados e escolhas arquiteturais já decididas não são repetidos aqui.

## 1. Proveniência válida de permissões Staff globais

**Status: fechada na Fase 0.** Fontes validas: owner ACE, ACE global explicito e override global explicito do `mz_core`. Membership/cargo, inclusive da org tipo Staff, nao concede `staff.*`.

**O que o código resolve hoje:** `HasGlobalPermission` aceita somente owner ACE, ACE global explícita e override global explícito do `mz_core`. Capabilities provenientes de qualquer membership, inclusive tipo `staff`, são ignoradas para `staff.*`. A sessão preserva a provenance dos grants globais.

**Decisão aplicada:** membership organizacional não cria `staffContext`.

**Impacto atual:** decisão implementada; permanece necessário executar o checklist runtime.

## 2. Capability dedicada para visualizar cargos/access model

**O que o código resolve hoje:** `GetOrgAccessModel` aceita owner/Staff view-like ou capabilities amplas como `org.view`/`members.view` e aliases históricos (`mz_core/server/orgs/service.lua:230-235` e implementação do access model). O modelo expõe hierarquia, capabilities resolvidas e overrides.

**Decisão necessária:** se todo membro com `org.view` pode ver cargos/permissões ou se isso exige capability própria.

**Recomendação padrão:** criar semanticamente `grades.view` ou `org.access.view`; manter os guards atuais como alias temporário até backfill.

**Impacto:** alto. Define visibilidade da rota `org.grades`, conteúdo do detalhe Staff e migração de seeds/cargos.

## 3. Matriz de features comuns e específicas por tipo

**Status da base: fechado na Fase 0.** Tipo nao autoriza; o servidor materializa features. Baseline atual: overview/members/grades/goals/recruitment/logs e banco apenas com conta compartilhada. Features especiais futuras continuam sendo decisao de produto.

**O que o código resolve hoje:** `shared/menu_features.lua` materializa a matriz comum por tipo, flags, overrides e capabilities. Callbacks de membros, metas, banco, recrutamento e logs continuam genéricos por `orgCode`. Recursos rápidos ainda não possuem registry de integrações externas.

**Decisão necessária:** quais tipos suportam cada feature e quais features extras têm domínio real.

**Recomendação padrão:** começar comum com overview, members e grades; habilitar bank somente por `hasSharedAccount`; habilitar demais features apenas quando capability e suporte server-side existirem. Tratar storage/salary como features futuras até haver callback/contrato no `mz_org`. Não criar placeholder navegável.

**Impacto:** médio para o workspace comum e alto para recursos especiais. Bloqueia a Fase 6, não a leitura básica.

## 4. Política para jogador sem organização

**O que o código resolve hoje:** toda sessão recebe dashboard e, sem org, recebe também módulo `recruitment` (`server/session.lua:239`, `272-274`), mas não existe endpoint de candidatura pessoal/pública. O backend de recruitment exige org e capability de gestão.

**Decisão necessária:** o que o Hub oferece a esse jogador.

**Recomendação padrão:** Hub informativo com estado “sem vínculo”, fechar painel e instruções/atalhos externos já existentes; não mostrar recrutamento administrativo. Adicionar “minhas candidaturas” somente após contrato player-facing próprio.

**Impacto:** médio de produto/UX. Não bloqueia workspaces de organização/Staff, mas bloqueia a experiência final do `/painel` sem org.

## 5. Necessidade dos comandos por tipo

**O que o código resolve hoje:** `/vip`, `/business`, `/government` e `/event` apenas escolhem `initialModule/mode`; não concedem acesso nem oferecem domínio distinto (`client/main.lua:89-103`).

**Decisão necessária:** manter todos como atalhos, deprecar alguns ou concentrar entrada no `/painel`.

**Recomendação padrão:** manter aliases durante a migração para compatibilidade e medir uso. Após o corte, preservar apenas comandos com fluxo operacional frequente; os demais redirecionam ao Hub com contexto pré-selecionado antes de eventual depreciação anunciada.

**Impacto:** baixo técnico, médio de hábito dos jogadores. Não deve alterar callbacks.

## 6. Field-level access para Staff parcial

**Status: fechada na Fase 0.** Cada rota/acao exige permissao global explicita. `staff.orgs.view|manage`, `staff.logs.view`, `staff.members.*` e `staff.orgs.set_leader` nao funcionam como wildcards entre dominios.

**O que o código resolve hoje:** várias permissões view-like (`staff.orgs.view/manage/create/set_leader`) acabam permitindo leitura ampla de detalhe, membros, banco, metas, recrutamento e logs. O frontend atual carrega oito blocos ao abrir uma org (`router.js:1819-1838`). Não existe matriz explícita de campos por perfil.

**Decisão necessária:** o que um Staff com somente `staff.orgs.view` pode ver e se são necessárias capabilities como `staff.members.view`, `staff.bank.view` e `staff.recruitment.view`.

**Recomendação padrão:** `staff.orgs.view` mostra metadados básicos e contagens não sensíveis; membros identificáveis, saldo/extrato, candidaturas, capabilities e logs exigem permissões Staff dedicadas. `staff.orgs.create` e `staff.orgs.set_leader` não devem implicitamente conceder todos os blocos de leitura.

**Impacto:** crítico para privacidade e menor privilégio. Bloqueia detalhe Staff V2; pode exigir novos guards/contratos server-side explicitamente propostos, não presumidos como exports atuais.

## 7. Organizações arquivadas nos contextos pessoais

**Status: fechada na Fase 0.** Arquivadas ficam fora do workspace pessoal, sao metadados read-only para `staff.orgs.view`, bloqueiam operacoes e somente owner/`staff.orgs.manage` reativa.

**O que o código resolve hoje:** org pode ser arquivada/reativada, o frontend Staff trata arquivada como read-only e a sessão V2 omite organizações inativas dos contextos pessoais operacionais.

**Decisão necessária:** omitir, mostrar read-only ou permitir contexto normal para membros de org arquivada.

**Recomendação padrão:** omitir de entradas operacionais pessoais; opcionalmente listar no Hub em seção “arquivadas” read-only, sem loaders sensíveis. Staff continua acessando pelo StaffWorkspace conforme capability.

**Impacto:** alto para guards, sessão, invalidação após archive/reactivate e suporte ao jogador.

## 8. Contextos do owner

**O que o código resolve hoje:** owner recebe todos os módulos, mas `GetPlayerOrgContext` ainda representa memberships reais. Um owner sem membership não possui contextos pessoais apesar de poder listar todas as orgs administrativamente.

**Decisão necessária:** owner recebe todas as organizações em `contexts[]` ou navega por elas apenas no StaffWorkspace.

**Recomendação padrão:** `contexts[]` continua representando vínculos pessoais; owner consulta qualquer org somente via `staffContext`. Isso mantém “minha organização” separado de “administração”.

**Impacto:** médio. Afeta `defaultContextId`, Hub e semântica de membership, mas não exige novo poder server-side.

## 9. Identidade e mascaramento no detalhe operacional

**O que o código resolve hoje:** mutations usam `citizenid` e as tabelas tentam mascará-lo, mas não há política por rota/perfil para revelar o valor completo. Staff precisa do identificador em algumas ações, enquanto membros comuns podem não precisar.

**Decisão necessária:** onde o CitizenID completo pode ser exibido/copiado e por qual capability.

**Recomendação padrão:** listas sempre mascaradas; valor completo somente em ação que o exija, após capability específica e interação explícita. Nunca expor payload/meta bruto como substituto.

**Impacto:** médio de privacidade e operação. Bloqueia acabamento de members/recruitment e detalhe Staff, não o transporte server-side.

## Registro de decisão

Cada item deve ser fechado com: responsável, decisão, data, compatibilidade necessária, alterações de dados/guards e testes de aceite. Uma escolha diferente da recomendação precisa registrar o risco aceito. Itens 1 e 6 são bloqueadores de Staff; item 2 bloqueia a rota de cargos; item 7 bloqueia o comportamento final de archive/reactivate; os demais podem ser resolvidos antes da fase indicada no plano de migração.
