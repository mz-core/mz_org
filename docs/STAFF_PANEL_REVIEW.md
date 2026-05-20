# Revisao do painel Staff

## Escopo desta revisao

Esta analise cobre o estado atual do `/staff` no `mz_org`, consultando o `mz_core` apenas para confirmar exports, permissoes e validacoes server-side. Nenhuma alteracao funcional foi feita nesta etapa.

Objetivo: entender o que o Staff mostra hoje, quais callbacks usa, quais permissoes exige, quais acoes ja existem e como evoluir o painel em fases seguras.

## Atualizacao - Fase criar org por template

Depois da analise original, o `/staff` recebeu uma acao segura e limitada na aba `Organizacoes`: `Criar organizacao`.

Caracteristicas:

- permissao exigida: owner ACE `group.mz_owner` ou `staff.orgs.create`;
- tipos permitidos: `job`, `gang`, `business`, `government`, `vip`, `event`;
- tipo `staff` segue bloqueado para fase futura;
- a criacao usa templates server-side no `mz_core`, sem aceitar grades/permissoes vindas da NUI;
- callback NUI: `orgs:createFromTemplate`;
- export do core: `CreateOrgFromTemplate(source, payload)`;
- logs: `org.create` e `org.create.blocked`;
- os atalhos seguros duplicados da visao geral foram compactados; a navegacao principal agora fica nas abas internas.

Continuam bloqueados: editor livre de cargos/permissoes, edicao avancada de org, excluir org, gestao global de staff e painel staff global completo.

## Atualizacao - Detalhes de organizacao e acoes limitadas

`/staff > Organizacoes` agora possui `Ver detalhes` no lugar do placeholder `Detalhe futuro`.

A subview mostra, sempre em modo consulta:

- resumo da organizacao;
- cargos/grades e permissoes por cargo;
- membros com CitizenID mascarado;
- banco resumido e ultimos movimentos;
- metas recentes;
- recrutamento recente;
- logs recentes da org;
- aba `Acoes`, com `Definir lider` quando houver owner/`staff.orgs.set_leader` e cards futuros bloqueados.

Implementacao:

- nao foi criado callback agregado novo;
- a UI reaproveita callbacks/services existentes por `orgCode`;
- o detalhe usa estado proprio `staffOrgDetails` e nao muda `activeOrgCode` dos shells `/org` ou `/gang`;
- `Definir lider` usa `staffOrgDetails.orgCode`, sem campo manual de `orgCode`;
- `Editar dados basicos` permite alterar somente nome, status publico/privado/inativo e flags operacionais com `staff.orgs.manage`;
- a aba global `Acoes administrativas` foi compactada para orientar o uso de `Organizacoes > Ver detalhes > Acoes`;
- `staff.orgs.view` agora tambem libera abertura do modulo Staff para consulta, mantendo acoes de escrita separadas por capabilities fortes.

Continuam inexistentes nesta tela: editar codigo/tipo da org, editar cargo/permissao, excluir org, adicionar/remover membro global, operar banco e aprovar/recusar recrutamento pelo Staff.

## Como o `/staff` abre hoje

O comando fica em `mz_org/client/main.lua`:

```lua
RegisterCommand(Config.Commands.Staff, function()
  openPanel('staff', 'staff')
end, false)
```

`Config.Commands.Staff` esta definido como `staff` em `mz_org/shared/config.lua`.

O client envia para a NUI:

```js
{
  action: 'open',
  payload: {
    initialModule: 'staff',
    mode: 'staff'
  }
}
```

No frontend, `web/core/nui.js` recebe esse payload e define:

- `requestedPanel = 'staff'`;
- `activePanel = 'staff'`;
- `activeShell = 'staff'`;
- `activeOrgCode = null`;
- `activeOrgType = null`;
- `activeSection = 'overview'`;
- `requestedInitialModule = 'staff'`.

Depois a NUI chama `session:get`, o server responde com a sessao real e `MZOrgRouter.applyInitialModule()` tenta manter `activeModule = 'staff'` se a sessao puder visualizar esse modulo. Se nao puder, cai para o primeiro modulo permitido.

Conclusao: `/staff` usa `activeShell = staff` e nao reaproveita automaticamente `activeOrgCode` de `/org` ou `/gang`.

## Quem consegue abrir `/staff`

A sessao e montada em `mz_org/server/session.lua`.

Owner:

- `group.mz_owner` recebe `staff.orgs.view`, `staff.orgs.manage`, `staff.orgs.set_leader`, `staff.staff.manage`, `staff.members.*`, `staff.players.manage` e `staff.logs.view`.
- Owner sempre recebe modulo `staff`.

Nao-owner:

- `buildGlobalPermissions()` coleta permissoes por ACE direta ou por `mz_core:HasGlobalPermission`.
- Se o player tiver org do tipo `staff`, a sessao tambem adiciona `staff.panel.open`.
- `buildModules()` libera o modulo `staff` se houver:
  - `staff.panel.open`;
  - `staff.orgs.manage`;
  - `staff.orgs.set_leader`;
  - `staff.logs.view`;
  - ou owner.

Nuance encontrada:

- `staff.orgs.view` aparece em `globalPermissions`, permite consulta administrativa em callbacks como `orgs:list` e agora tambem entra na condicao de abertura do modulo Staff.
- Isso continua seguro porque `staff.orgs.view` nao autoriza escritas como criar org, definir lider, editar cargos/permissoes ou operar banco.

Seed atual da org staff no `mz_core/server/seed/default_orgs.lua`:

- base: `staff.panel.open`;
- Helper: `staff.orgs.view`, `staff.report.view`;
- Moderador: `staff.kick`, `staff.spectate`;
- Admin: `staff.logs.view`, `staff.orgs.manage`, `staff.orgs.set_leader`, alem de outras permissoes staff.

## O que o painel Staff mostra hoje

O painel fica registrado em `mz_org/web/panels/staff/index.js`:

- `id = 'staff'`;
- `title = 'Staff'`;
- `subtitle = 'Consulta administrativa, orgs e auditoria.'`;
- `initialModule = 'staff'`;
- `modules = ['staff', 'orgs', 'logs', 'settings']`;
- render principal: `MZOrgRouter.renderStaffPage()`.

`renderStaffPage()` mostra:

- heading `Staff / Area administrativa`;
- badge de acesso (`OWNER`, `STAFF`, etc.);
- cards superiores de metricas administrativas;
- abas internas `Visao geral`, `Organizacoes`, `Logs`, `Auditoria` e `Acoes administrativas`;
- lista de organizacoes com `Criar organizacao` por template quando houver owner/`staff.orgs.create`;
- subview `Organizacoes > Ver detalhes` com abas de consulta e aba `Acoes`;
- aba `Acoes` dentro do detalhe da org, onde fica `Definir lider` quando houver owner/`staff.orgs.set_leader`;
- aba global `Acoes administrativas` compactada, sem formulario global de lideranca.

O visual da acao de lideranca no detalhe usa classes CSS proprias:

- `.staff-leader-card`;
- `.staff-set-leader-form`;
- `.staff-set-leader-hint`;
- `.staff-leader-wide`;
- `.staff-leader-actions`.

## Dados e callbacks usados pelo Staff

Leitura:

- `session:get`: monta sessao real.
- `orgs:list`: lista orgs visiveis para a sessao.
- `orgs:get`: consulta uma org especifica quando permitido.
- `logs:list`: consulta logs permitidos.

Escrita:

- `orgs:createFromTemplate`: cria org/faccao por template seguro.
- `orgs:updateBasic`: altera somente nome, status e flags basicas da org selecionada.
- `orgs:createGrade`: cria grade/cargo basico na org selecionada.
- `orgs:updateGradeBasic`: edita nome, level, salario, prioridade e heranca de grade.
- `members:setLeader`: define lider/top grade na org selecionada pelo detalhe Staff.

Callbacks gerais existentes tambem podem ser usados em outros shells:

- membros: listar, convidar, remover, promover, rebaixar;
- banco: saldo, extrato, deposito e saque;
- recrutamento: listar, criar, aprovar, recusar e arquivar;
- metas: listar, obter e criar;
- cargos/acesso: `org-access:get`.

Ponto importante: esses callbacks existem no resource, mas o `/staff` atual nao oferece um CRUD global completo por UI. As escritas expostas sao limitadas: criar organizacao por template, editar dados basicos, gerenciar dados basicos de cargos e definir lider dentro do detalhe da org selecionada.

## Acoes existentes no `/staff`

Leitura:

- navegar para `Organizacoes` e carregar `orgs:list`;
- abrir `Ver detalhes` de uma org e consultar dados por `orgCode`;
- navegar para `Logs` e carregar `logs:list`;
- visualizar o card de estado administrativo.

Escrita:

- criar organizacao por template server-side;
- editar dados basicos da org selecionada;
- criar/editar dados basicos de cargos da org selecionada;
- definir lider/top grade da org selecionada no detalhe usando `citizenid`.

Bloqueado/futuro:

- editar codigo/tipo ou deletar orgs;
- editar capabilities/permissoes de cargos;
- excluir/desativar cargos sem suporte seguro no schema;
- adicionar/remover/promover/rebaixar membros globalmente por painel staff;
- mexer em banco de qualquer org pelo Staff;
- gerenciar staff/hierarquia staff;
- painel global de recrutamento.

## Avaliacao da acao "Definir lider"

Estado atual: seguro para a fase minima proposta e melhor integrado ao detalhe da organizacao.

Frontend:

- A acao aparece em `/staff > Organizacoes > Ver detalhes > Acoes`.
- O card funcional aparece somente para owner ou para quem tem `staff.orgs.set_leader` em `globalPermissions`.
- Se nao tiver essa permissao, aparece um card bloqueado/read-only dentro do detalhe.
- Nao ha mais campo manual de `orgCode`; o codigo vem de `staffOrgDetails.orgCode`, isto e, da org selecionada.
- O formulario envia apenas:
  - `citizenid`;
  - `reason`.
- `member-service.js` chama `members:setLeader` com `orgCode` selecionado internamente, `citizenid` e `reason`.
- Nao envia `source`, `actorCitizenId`, cargo, permissao, `gradeLevel` ou `gradeId`.

Server `mz_org`:

- `mz_org/server/members.lua` usa `local src = source`.
- Normaliza `orgCode`, `citizenid` e `reason`.
- Aplica rate limit simples de 2 segundos.
- Checa permissao antes de chamar o core:
  - owner ACE; ou
  - `HasGlobalPermission(src, 'staff.orgs.set_leader')`; ou
  - `CanOrg(src, orgCode, 'staff.orgs.set_leader')`.
- Traduz erros para mensagens amigaveis.

Core `mz_core`:

- Export `SetOrgLeaderByCitizenId(source, orgCode, targetCitizenId, options)` chama `MZOrgService.setLeaderByCitizenId`.
- O core calcula a top grade real usando a maior `level` da org.
- O alvo e buscado por `citizenid` em `mz_players`, podendo estar offline.
- Se o alvo ja for membro ativo, atualiza para top grade.
- Se nao for membro ativo, cria membership ativa na top grade.
- Define a membership como primaria para o tipo da org.
- Recarrega player online quando aplicavel.
- Gera log de sucesso `org.member.set_leader`.
- Gera log de bloqueio `org.member.set_leader.blocked`.

Restricoes confirmadas:

- `staff.panel.open` nao autoriza definir lider.
- `staff.orgs.view` nao autoriza definir lider.
- `staff.orgs.manage` nao autoriza definir lider sem `staff.orgs.set_leader`.
- Staff nao-owner nao pode setar a si mesmo como lider; owner pode para teste/admin.

## Mistura de contexto pessoal com administrativo

O `/staff` nao usa `activeOrgCode` de `/org` ou `/gang`; ao abrir, zera `activeOrgCode` e usa shell administrativo.

As abas de `Organizacoes` e `Logs` sao consultas administrativas/permitidas pela sessao, nao a org pessoal ativa. A tela deixa claro que e `Area administrativa`, mas ainda pode melhorar visualmente com:

- label persistente `Modo administrativo`;
- destaque maior para a diferenca entre "minhas orgs" e "consulta staff";
- filtros claros em logs globais.

Risco baixo atual: `Definir lider` usa a org selecionada no detalhe Staff, sem depender de org pessoal ativa nem de input manual de `orgCode`.

## Dashboard Staff atual

Status apos a Fase Staff 1: implementado como dashboard seguro/read-only.

O Staff agora possui:

- cards superiores de organizacoes, membros, logs recentes e acoes sensiveis;
- abas internas `Visao geral`, `Organizacoes`, `Logs`, `Auditoria` e `Acoes administrativas`;
- consulta de orgs via `orgs:list`;
- consulta de logs via `logs:list`;
- auditoria sensivel filtrada localmente dos logs recentes;
- criacao de org por template na aba `Organizacoes`;
- detalhes por org com abas de consulta e aba `Acoes`;
- edicao limitada de dados basicos por org com `staff.orgs.manage`;
- criacao/edicao limitada de cargos basicos com `staff.orgs.manage`;
- cards bloqueados para acoes futuras;
- `Definir lider` movido para `Organizacoes > Ver detalhes > Acoes`.
- cards bloqueados sem handler de acao real.
- confirmacoes de acoes de membros fora do Staff feitas inline, sem janela externa do navegador.

Nao foram criados callbacks novos, tabelas novas, CRUD global de orgs, gestao de staff ou editor de cargos/permissoes.

## Riscos encontrados

- `staff.orgs.manage` e amplo para gestao comum em alguns callbacks server-side; a UI do Staff nao expande isso em CRUD global, mas futuras telas precisam tomar cuidado.
- `staff.orgs.view` permite consulta server-side e abre o modulo Staff em modo consulta.
- O frontend ainda possui services/actions gerais de membros, banco, metas e recrutamento; qualquer nova UI staff deve evitar reaproveitar botoes de mutacao sem uma permissao forte dedicada.
- O router ainda chama helper de detalhes tecnicos em orgs/logs, mas `web/core/ui.js` hoje retorna vazio para `technicalDetails()`. Se esses detalhes forem reativados depois, `orgCode`, tipos internos e citizenids devem ficar sob owner/debug ou mascaramento adequado.
- ACEs diretas para permissoes staff, alem do owner, continuam sendo aceitas pelo core como compatibilidade; a politica recomendada e reservar ACE para owner e usar cargos/capabilities internas para staff comum.
- Nao ha hierarquia staff completa para impedir Helper/Moderador de mexer em cargos staff superiores em uma fase futura de gestao de staff.

## O que nao deve ser liberado ainda

- CRUD global de orgs.
- Editor de cargos e capabilities.
- Gestao de staff.
- Adicionar/remover/promover/rebaixar membros de qualquer org pelo Staff sem fase propria.
- Acoes financeiras globais por org.
- Painel global de recrutamento.
- Mudanca de top grade/lideranca sem `staff.orgs.set_leader`.
- Qualquer action que aceite `source`, actor, permissao, cargo ou grade vindos da NUI como verdade.

## Roadmap seguro

### Fase Staff 1 - Dashboard/Auditoria

Status: implementada no frontend.

- Visual do `/staff` refinado como dashboard.
- Resumo de organizacoes visiveis.
- Logs recentes.
- Auditoria sensivel filtrada localmente.
- Acoes sensiveis bloqueadas.
- Unica action de escrita mantida: definir lider.
- Reaproveita `orgs:list` e `logs:list`.
- Sem backend novo.

### Fase Staff 2 - Consulta detalhada de org

- Selecionar uma org por lista/filtro.
- Ver membros read-only.
- Ver cargos/capabilities read-only.
- Ver banco resumido read-only.
- Ver metas/recrutamento resumidos read-only.
- Ainda sem acoes perigosas globais.
- Pode precisar revisar callbacks atuais para leitura staff-safe por org arbitraria.

### Fase Staff 3 - Gestao administrativa limitada

- Adicionar membro por `citizenid`.
- Remover membro.
- Promover/rebaixar de forma limitada.
- Exigir permissoes fortes e especificas, preferencialmente `staff.members.*`.
- Logs fortes em toda tentativa.
- Continuar exigindo `staff.orgs.set_leader` para top grade.

### Fase Staff 4 - Gestao de staff

- Adicionar/remover/promover/rebaixar staff.
- Criar hierarquia staff explicita.
- Staff so mexe abaixo do proprio nivel.
- Owner ACE acima de tudo.
- Permissoes dedicadas: `staff.staff.manage` e/ou `staff.members.*`.

## Layout futuro recomendado

```txt
STAFF / Administracao

Topo:
- Organizacoes
- Membros totais
- Logs recentes
- Acoes sensiveis

Abas internas:
Visao geral | Organizacoes | Logs | Auditoria | Acoes administrativas

Visao geral:
- resumo do servidor/orgs
- ultimos logs
- alertas

Organizacoes:
- lista de orgs/gangs
- filtros por tipo
- botao "ver detalhes"
- detalhe com abas de consulta e Acoes limitadas

Logs:
- logs recentes
- filtros por org, categoria e severidade

Acoes administrativas:
- orientacao para usar Organizacoes > Ver detalhes > Acoes
- outras acoes futuras bloqueadas

Dentro do detalhe da organizacao:
- Definir lider
- acoes futuras bloqueadas por org
```

## Dependencias para a proxima implementacao

Da para evoluir as proximas fases majoritariamente reaproveitando os dados atuais, mas qualquer escrita nova deve ter permissao forte e validacao server-side:

- `orgs:list` ja fornece lista de orgs visiveis;
- `orgs:get` e `org-access:get` ja sustentam a consulta do detalhe;
- `logs:list` ja fornece auditoria permitida;
- `session:get` ja traz owner/permissoes/modulos;
- `members:setLeader` ja existe para a acao de lideranca dentro do detalhe.

Pode precisar de callback novo apenas se quiser numeros agregados precisos, como membros totais por todas as orgs sem carregar org por org.

Nao ha necessidade de tabela nova para o dashboard/auditoria inicial.

Para Fase Staff 2, talvez seja necessario criar callbacks read-only staff-safe para:

- detalhes completos de uma org selecionada;
- membros por org arbitraria;
- banco resumido por org;
- metas/recrutamento resumidos por org.

Antes de qualquer mutacao futura, criar exports/callbacks novos dedicados e seguros, em vez de reaproveitar atalhos de baixo nivel.

## Recomendacao imediata

Proxima etapa ideal: testar a Fase Staff 1 no jogo e, depois, planejar a Fase Staff 2 de consulta detalhada de org sem acoes perigosas.

Nao implementar ainda:

- CRUD de orgs;
- editor de cargos/permissoes;
- gestao completa de membros;
- gestao de staff;
- banco administrativo global;
- recrutamento global.

## Atualizacao: arquivamento seguro

O detalhe Staff da organizacao agora permite operacoes de ciclo de vida sem exclusao fisica:

- `/staff > Organizacoes > Ver detalhes > Acoes` mostra `Arquivar organizacao` quando ativa e `Reativar organizacao` quando inativa.
- Arquivar apenas altera `active = 0`; reativar volta para `active = 1`.
- Historico, membros, banco, metas, recrutamento e logs permanecem intactos.
- `/staff > Organizacoes > Ver detalhes > Cargos` mostra cargos ativos e desativados.
- Cargo ativo sem membros e que nao seja top grade pode ser desativado.
- Cargo desativado pode ser reativado.
- Cargo com membros e top grade continuam bloqueados.
- Permissao exigida: owner ACE ou `staff.orgs.manage`.
- Nao foi criado editor livre de permissoes nem exclusao permanente.

## Atualizacao: permissoes por cargo

O detalhe Staff agora permite gerenciar permissoes diretas de cargos de forma controlada:

- Entrada: `/staff > Organizacoes > Ver detalhes > Cargos > Gerenciar permissoes`.
- A tabela continua compacta; permissoes seguem visiveis em resumo.
- O modal mostra permissoes diretas removiveis e permissoes herdadas/base apenas como consulta.
- Adicao usa catalogo oficial agrupado, sem campo livre.
- Staff comum nao consegue inserir `staff.*` em org comum.
- `members.set_leader` continua protegido por owner ou `staff.orgs.set_leader`.
- Org arquivada e cargo inativo bloqueiam edicao.
- Nao ha gestao staff global, ACE, permissao por player ou editor livre.
