# Auditoria de identidade, contexto, permissoes e seguranca

> Atualização de 2026-07-26: as seções históricas sobre Staff devem ser lidas junto do contrato atual em `mz_core/docs/STAFF_HIERARCHY_CONTRACT.md`. Membership da organização legada `staff` não concede `staff.*`; os cargos globais persistentes usam `staff.roles.manage` e permissões granulares de comandos.

## Escopo

Esta revisao cobre `mz_core` e `mz_org` no estado atual dos arquivos. A auditoria original mapeou riscos e fases; depois dela foram implementadas a fase financeira permitida e a migracao do convite principal para `citizenid`, mantendo validacao server-side e sem aceitar `source` da NUI.

## Diagnostico executivo

- O identificador fixo real do personagem no `mz_core` e `citizenid`.
- O convite principal do painel agora usa `citizenid`; `targetId/source` ficou apenas como fallback legado opt-in, desativado por padrao no `mz_org`.
- Remover, promover e rebaixar ja usam `citizenid` no contrato NUI e no wrapper seguro do core.
- `/org` e `/gang` ja usam `activeOrgCode` no frontend para membros, banco, metas, cargos, recrutamento e logs.
- Banco de org agora usa callbacks `org-bank:deposit`, `org-bank:withdraw` e `org-bank:transactions`, sempre com `orgCode` ativo e `source` real no servidor.
- Recrutamento agora usa `mz_org_recruitment`, `activeOrgCode` e `citizenid`; aprovar candidatura chama o fluxo real de adicionar membro.
- A UI normal desativa detalhes tecnicos brutos; tabelas principais usam labels amigaveis e CitizenID mascarado.
- A hierarquia de job/gang para lider comum esta parcialmente protegida.
- `staff.panel.open` nao autoriza mais mutacoes de membros/lideranca; `staff.orgs.manage` segue amplo para gestao comum.
- `staff.panel.open` tambem nao autoriza criar, aprovar, recusar ou arquivar candidaturas.
- `group.mz_owner` esta corretamente como poder maximo, mas o codigo ainda aceita ACEs para outras permissoes globais.

## Identidade fixa do player

O identificador fixo recomendado para o painel e `citizenid`.

No `mz_core`:

- `MZPlayerService.loadPlayer(source)` busca o player por license.
- Se nao existir row, gera `citizenid` com `MZUtils.generateCitizenId()`.
- O `citizenid` e salvo em `mz_players`.
- Contas usam `mz_player_accounts.citizenid`.
- Sessoes usam `mz_player_sessions.citizenid`, mas tambem guardam `source` temporario.
- Organizacoes usam `mz_player_orgs.citizenid`.
- Cache online usa `MZCache.playersByCitizenId[citizenid]`.

Exports atuais relacionados:

- `GetPlayer(source)`: player online por source.
- `GetPlayerByCitizenId(citizenid)`: player online em cache por citizenid.
- `GetSourceByCitizenId(citizenid)`: source atual se estiver online.
- Nao ha export publico generico para buscar player offline por `citizenid`, mas o convite seguro encapsula essa consulta internamente com `MZPlayerRepository.getByCitizenId(citizenid)`.

Conclusao:

- Para UI/acoes de gestao, usar `citizenid`/passaporte como identificador principal.
- `source` deve ser tratado como dado de sessao, util para debug ou acoes estritamente online.
- Para validar player offline, o core precisa expor uma consulta segura por `citizenid` ou encapsular isso em um wrapper de convite/adicao por citizenid.

## Convite por citizenid

Fluxo anterior:

- Frontend chama `members:invite` com `{ orgCode, targetId, gradeLevel?, gradeCode? }`.
- `mz_org/server/members.lua` normaliza `targetId` como source online.
- O server chama `exports['mz_core']:InviteOrgMember(src, orgCode, targetId, options)`.
- O core valida `targetPlayer = MZPlayerService.getPlayer(targetSource)`.
- Se o alvo estiver offline, falha como `invalid_target`.

Riscos:

- `source` muda a cada conexao.
- Um lider pode errar o ID online e convidar outro jogador.
- Nao serve para convite offline.
- O fluxo visual incentiva uso de um identificador efemero em vez do passaporte/citizenid.

Estado implementado:

1. O callback NUI existente `members:invite` foi mantido.
2. O payload principal agora e `{ orgCode, citizenid, gradeLevel?, gradeCode? }`.
3. `targetId` permanece apenas como fallback legado temporario, explicitamente opt-in por `Config.AllowLegacyTargetSourceInvite`; o padrao e `false`.
4. O `mz_core` expoe `InviteOrgMemberByCitizenId(source, orgCode, targetCitizenId, options)`.
5. Esse wrapper valida:
   - ator real pelo `source`;
   - org existente;
   - citizenid existente em `mz_players`;
   - se ja e membro ativo;
   - permissao/capability do ator;
   - hierarquia e grade inicial;
   - logs/auditoria.

Nao e recomendavel expor diretamente `AddMemberToOrg(citizenid, ...)` para NUI, porque ele e baixo nivel e nao concentra todas as validacoes de ator/hierarquia.

Convite offline:

- Curto prazo implementado: `InviteOrgMemberByCitizenId` adiciona diretamente se o player existir em `mz_players`, mesmo offline.
- Medio prazo: criar fluxo real de candidatura/convite pendente, com aceite do jogador, expiração e auditoria.

## Recrutamento por citizenid

Estado implementado nesta fase:

1. `mz_core/server/prepare.lua` autocriou a tabela `mz_org_recruitment`.
2. O repository persiste candidaturas por `org_code`, `target_citizenid`, status e auditoria de criacao/revisao.
3. Os exports seguros sao:
   - `CreateOrgRecruitment(source, orgCode, payload)`
   - `ListOrgRecruitment(source, orgCode, filters)`
   - `GetOrgRecruitment(source, recruitmentId)`
   - `ApproveOrgRecruitment(source, recruitmentId, options)`
   - `RejectOrgRecruitment(source, recruitmentId, reason)`
   - `CancelOrgRecruitment(source, recruitmentId, reason)`
4. `mz_org/server/recruitment.lua` usa sempre `local src = source`.
5. O frontend envia `orgCode` da org ativa e campos funcionais, mas o servidor recarrega ator, permissoes, org, candidato e grade.

Permissoes:

- visualizar: owner ACE ou `recruitment.view`, `recruitment.manage`, `members.invite`, `manage.members` na org ativa;
- gerenciar: owner ACE ou `recruitment.manage`, `members.invite`, `manage.members` na org ativa;
- top grade segue protegido por owner ACE, `members.set_leader` ou `staff.orgs.set_leader`.

Garantias:

- uma candidatura pendente por `orgCode + citizenid`;
- `citizenid` precisa existir em `mz_players`;
- candidato ja membro ativo e bloqueado;
- aprovar muda status para `approved` e cria membro real;
- recusar muda status para `rejected`;
- arquivar muda status para `cancelled`;
- logs gerados: `org.recruitment.create`, `org.recruitment.approve`, `org.recruitment.reject`, `org.recruitment.cancel` e bloqueios equivalentes.

Nao implementado nesta fase:

- candidatura publica/player-facing;
- aceite por notificacao do jogador;
- painel staff global de recrutamento.

## Vazamento tecnico no frontend

Estado final do MVP:

- Tabelas principais usam `maskCitizenId`.
- Labels de capabilities passam por `formatCapabilityLabel`.
- Labels de logs passam por `formatActionLabel` quando aplicavel.
- Colunas avancadas vazias foram removidas.
- O helper `technicalDetails()` permanece desativado na UI normal.

Classificacao recomendada:

- Jogador comum/lider: nao deve ver IDs internos, `orgCode`, `gradeCode`, capabilities cruas nem citizenid completo.
- Staff operacional: pode ver citizenid mascarado e contexto funcional, mas nao payloads brutos por padrao.
- Owner/debug: pode ver detalhes tecnicos colapsados.

Regra proposta para fase futura:

- Criar helper visual `canSeeTechnicalDetails()` baseado em `isOwner` ou modo debug explicito.
- Para usuario normal, manter detalhes tecnicos fora da tela.
- Para staff, mostrar apenas dados operacionais necessarios, preferindo mascaramento.
- Para owner/debug, manter detalhes colapsados.

## Contexto ativo e isolamento

O frontend atual ja tem:

- `activeShell`
- `activeOrgCode`
- `activeOrgType`
- `activeSection`

Chamadas auditadas:

- `members:list`, `members:invite`, `members:remove`, `members:promote`, `members:demote`: usam `selectedOrgCode()`, que prioriza `activeOrgCode`. O convite envia `citizenid`, nao source online.
- `org-bank:get` e `org-bank:transactions`: carregadas por `loadOrgPanel()` com o code selecionado.
- `goals:list` e `goals:create`: usam filtros/payload com org ativa.
- `org-access:get`: usa org ativa.
- `recruitment:list`: recebe `filters.orgCode` quando ha org ativa.
- `logs:list`: dentro de `/org` e `/gang`, agora chama com `{ orgCode, limit }`.

Riscos restantes:

- As rotas antigas de `recruitment`, `goals` e `logs` ainda existem no router para compatibilidade/hub/staff.
- Se uma tela futura chamar esses modulos fora do contexto sem `activeOrgCode`, pode virar consulta ampla ou vazia.
- No server, `recruitment:list` exige `orgCode` contextual nesta fase; um futuro "minhas candidaturas" deve ser endpoint separado.

Recomendacao:

- Em abas de contexto, exigir sempre `activeOrgCode`.
- Em Staff, nao ha painel global de recrutamento nesta fase.
- Em `/painel`, nao mostrar administracao de recrutamento de org; reservar para "minhas candidaturas" quando existir fluxo real.

## Recrutamento

Estado atual:

- `mz_org/server/recruitment.lua` usa `ListOrgRecruitment`, `GetOrgRecruitment`, `CreateOrgRecruitment`, `ApproveOrgRecruitment`, `RejectOrgRecruitment` e `CancelOrgRecruitment`.
- Os exports reais ficam no `mz_core` e persistem em `mz_org_recruitment`.
- Permissao aceita owner, `recruitment.view`/`recruitment.manage` e fallbacks de gestao de membros na org ativa.

Comportamento desejado:

- Dentro de `/org`: filtrar pela organizacao legal ativa.
- Dentro de `/gang`: filtrar pela gang ativa.
- Dentro de `/painel`: futuramente mostrar apenas candidaturas pessoais do player.
- Dentro de `/staff`: painel global de recrutamento fica pendente para fase futura.

Ponto de cuidado:

- A capability `recruitment.view/manage` aparece em seed, mas nao existe em `mz_org/shared/capabilities.lua`.

## Lideranca e top grade em job/gang

Protecoes implementadas:

- `/staff` agora tem dashboard seguro com abas internas de visao geral, organizacoes, logs, auditoria e acoes administrativas bloqueadas/limitadas.
- `/staff` possui uma acao minima para definir lider por `orgCode` e `citizenid`, sem CRUD global de orgs.
- O export seguro `SetOrgLeaderByCitizenId(source, orgCode, targetCitizenId, options)` calcula a maior grade no core.
- Se o alvo ja for membro ativo, a grade e atualizada para a top grade; se nao for membro ativo, e adicionado na top grade.
- A acao exige owner ACE ou `staff.orgs.set_leader`; `staff.panel.open`, `staff.orgs.view` e `staff.orgs.manage` nao bastam.
- Convite com grade escolhida: lider comum nao pode convidar para grade maior ou igual a propria.
- Remocao: membro comum nao remove cargo igual/superior.
- Top grade e a grade com maior `level` da org.
- Convite direto para top grade exige owner ACE, `members.set_leader` ou `staff.orgs.set_leader`.
- Promocao para top grade exige owner ACE, `members.set_leader` ou `staff.orgs.set_leader`.
- Rebaixar/remover top grade exige owner ACE, `members.set_leader` ou `staff.orgs.set_leader`.
- Promover/rebaixar seguro:
  - bloqueia self action;
  - membro comum nao mexe em cargo igual/superior;
  - membro comum nao promove para grade igual/superior a propria;
  - demote de cargo maximo bloqueia quem nao tem permissao dedicada.

Riscos remanescentes:

- `staff.orgs.manage` ainda e amplo para acoes comuns de membros.
- Staff ator ainda ignora parte da hierarquia de job/gang quando possui permissao de gestao, mas nao altera top grade sem `staff.orgs.set_leader`.
- Exports legados de baixo nivel continuam preservados para compatibilidade e devem ser usados apenas por recursos confiaveis.

Regra atual:

- Owner ACE `group.mz_owner`: pode tudo.
- Staff autorizado para lideranca precisa `staff.orgs.set_leader`.
- Lider de org: gerencia somente abaixo dele.
- Promover/convidar/rebaixar/remover grade maxima exige `members.set_leader` ou `staff.orgs.set_leader`.
- `staff.panel.open` abre painel, mas nao autoriza mutacoes de membros nem lideranca.
- `staff.orgs.manage` continua amplo para gestao comum, mas nao basta para top grade.
- `staff.orgs.view` segue documentado como permissao de consulta server-side; a abertura do painel por essa permissao isolada fica como decisao pendente.

## Criacao de org por template no Staff

Estado implementado:

- `/staff`, aba `Organizacoes`, pode abrir `Criar organizacao` somente para owner ou `staff.orgs.create`.
- Callback NUI: `orgs:createFromTemplate`.
- Export seguro no core: `CreateOrgFromTemplate(source, payload)`.
- Tipos permitidos: `job`, `gang`, `business`, `government`, `vip`, `event`.
- Tipo `staff` continua bloqueado/fase futura.

Garantias:

- o `source` confiavel e o source real do evento/server;
- a NUI envia somente tipo, codigo, nome, opcoes booleanas basicas e motivo;
- a NUI nao envia grades, permissoes, actor, source, orgId ou creator;
- o core normaliza `code` para lowercase e permite apenas letras, numeros, `_` e `-`;
- o core valida org duplicada antes de criar;
- templates de grades e permissoes ficam hardcoded no server;
- `staff.panel.open`, `staff.orgs.view` e `staff.orgs.manage` sozinhos nao autorizam a criacao;
- logs gerados: `org.create` e `org.create.blocked`.

Limites mantidos:

- sem editor livre de cargos/permissoes;
- sem excluir org;
- sem editor avancado de org existente;
- sem painel staff global completo.

## Detalhes de org no Staff

Estado implementado:

- `/staff > Organizacoes` troca o placeholder `Detalhe futuro` por `Ver detalhes`.
- A tela de detalhe fica dentro do shell Staff e nao altera `activeOrgCode` de `/org` ou `/gang`.
- A consulta usa `orgCode` e callbacks existentes de leitura: org, access model, membros, banco, metas, recrutamento e logs.
- Nenhuma action de editar/salvar/excluir foi criada.

Permissoes aceitas para leitura administrativa:

- owner ACE `group.mz_owner`;
- `staff.orgs.view`;
- `staff.orgs.manage`;
- `staff.orgs.create`;
- `staff.orgs.set_leader`.

Garantias:

- `source` continua vindo do evento/server;
- `orgId` vindo da NUI nao e usado;
- CitizenID aparece mascarado;
- payload tecnico bruto nao e exibido;
- banco e recrutamento no Staff ficam read-only;
- cards de edicao de org, cargos, permissoes, membros e banco continuam inexistentes/bloqueados.

Atualizacao de lideranca no detalhe:

- `Definir lider` agora fica em `/staff > Organizacoes > Ver detalhes > Acoes`;
- a tela nao pede `orgCode` manual;
- o `orgCode` usado vem do detalhe selecionado (`staffOrgDetails.orgCode`);
- a NUI continua sem enviar `gradeId`, `gradeLevel`, `source`, actor ou permissoes;
- o callback existente `members:setLeader` e o export seguro do core continuam fazendo a validacao forte.

Atualizacao de dados basicos no detalhe:

- `Editar dados basicos` fica em `/staff > Organizacoes > Ver detalhes > Acoes`;
- callback NUI: `orgs:updateBasic`;
- export do core: `UpdateOrgBasicInfo(source, orgCode, payload)`;
- permissao exigida: owner ACE `group.mz_owner` ou `staff.orgs.manage`;
- `staff.panel.open`, `staff.orgs.view`, `staff.orgs.create` e `staff.orgs.set_leader` nao autorizam essa escrita;
- campos permitidos: `name`, `status`, `hasSalary`, `hasSharedAccount`, `hasStorage` e `reason`;
- campos proibidos: `code`, `type`, cargos, grades, permissoes, membros, banco, metas, recrutamento e logs;
- o core traduz `status` para as colunas reais `is_public` e `active`, sem criar tabela ou coluna nova;
- logs gerados: `org.update_basic` e `org.update_basic.blocked`, com before/after basico e motivo.

Gerenciamento basico de cargos no detalhe:

- fica em `/staff > Organizacoes > Ver detalhes > Cargos`;
- callbacks NUI: `orgs:createGrade` e `orgs:updateGradeBasic`;
- exports do core: `CreateOrgGrade(source, orgCode, payload)` e `UpdateOrgGradeBasic(source, orgCode, gradeId, payload)`;
- permissao exigida: owner ACE `group.mz_owner` ou `staff.orgs.manage`;
- criar ou mover cargo acima da top grade atual tambem exige owner ou `staff.orgs.set_leader`;
- `code` so e aceito na criacao; update nao altera code;
- o server valida org real, grade real, conflitos de `code`/`level`, salario, heranca e ciclo;
- permissoes/capabilities diretas podem ser gerenciadas em modal controlado por allowlist oficial;
- o schema atual de `mz_org_grades` possui `active`, usado para desativar/reativar cargo sem DELETE fisico;
- logs gerados: `org.grade.create`, `org.grade.update`, `org.grade.create.blocked` e `org.grade.update.blocked`.

## Hierarquia staff

Estado implementado:

- Staff Supremo/Owner ACE e topo absoluto, com nível virtual e fora do banco;
- cargos padrão persistentes: Suporte 100, Moderador 300, Administrador 700 e Gerente Staff 900;
- Staff administra somente cargos e atribuições estritamente inferiores;
- Staff não altera a própria atribuição nem concede permissão que não possui;
- membership da organização legada `staff` não concede autoridade global;
- gerenciar cargos e atribuições exige:
  - `staff.roles.manage`
- operar membros de organizações exige a permissão específica:
  - `staff.members.invite`
  - `staff.members.remove`
  - `staff.members.promote`
  - `staff.members.demote`

## ACE owner

`Config.OwnerAce = 'group.mz_owner'` em `mz_org`.

No `mz_core`, `HasGlobalPermission`:

- Se permission for owner ace ou `group.mz_owner`, valida ACE owner.
- Se owner ACE for true, retorna true para qualquer permissao.
- Para outras permissoes, tambem verifica `IsPlayerAceAllowed(source, permission)`.
- Depois verifica permissao interna via org/capability.

Risco/politica:

- Se o servidor atribuir ACEs como `staff.orgs.manage`, isso bypassa o sistema interno.
- Pela regra desejada, ACE deve ficar reservado para o dono (`group.mz_owner`).
- Staff comum deve receber poderes por cargos/capabilities internas do `mz_core`.

Recomendacao:

- Fase futura: restringir ACE direto somente ao owner, ou manter ACE staff apenas em modo compatibilidade explicitamente documentado.

## Capabilities existentes e faltantes

Existem no catalogo compartilhado:

- `org.view`
- `members.invite`
- `members.kick`
- `members.remove`
- `members.promote`
- `members.demote`
- `members.set_leader`
- `members.suspend`
- `account.view/deposit/withdraw/transfer/manage`
- `storage.*`
- `vehicle.*`
- `goals.view`
- `goals.manage`
- `logs.view`
- `boss.actions`
- `manage.members`
- `manage.permissions`
- `manage.account`
- `manage.goals`

Lista histórica que motivou a padronização:

- `recruitment.view`
- `recruitment.manage`
- `reports.approve`
- `manage.team`
- `highcommand`
- `command.full`
- `org.settings`
- `staff.panel.open`
- `staff.teleport`
- `staff.orgs.manage`
- `staff.orgs.set_leader`
- `staff.logs.view`

Implementadas para a fase Staff:

- `staff.members.invite`
- `staff.members.remove`
- `staff.members.promote`
- `staff.members.demote`
- `staff.roles.manage`

Duplicidades a padronizar:

- `members.kick` vs `members.remove`.
- `manage.members` vs `members.invite/promote/demote/remove`.
- `goals.manage` vs `manage.goals`.
- `account.manage` vs `manage.account`.

Catalogo minimo recomendado:

Org/gang:

- `org.view`
- `members.view`
- `members.invite`
- `members.remove`
- `members.promote`
- `members.demote`
- `members.set_leader`
- `manage.members`
- `goals.view`
- `goals.manage`
- `account.view`
- `logs.view`
- `recruitment.view`
- `recruitment.manage`

Staff:

- `staff.panel.open`
- `staff.orgs.view`
- `staff.orgs.manage`
- `staff.orgs.set_leader`
- `staff.members.invite`
- `staff.members.remove`
- `staff.members.promote`
- `staff.members.demote`
- `staff.roles.manage`
- `staff.logs.view`

Aliases legados mantidos:

- `members.kick` permanece fallback de `members.remove`.
- `manage.goals` permanece fallback de `goals.manage`.
- `manage.account` permanece fallback de `account.manage`.
- `manage.permissions` permanece para consulta do modelo de cargos/permissoes.

Regra revisada: `staff.panel.open` identifica/libera o painel staff, mas nao autoriza operacoes de membros, banco, metas ou lideranca sem uma capability especifica de consulta/gestao.

## Plano de implementacao por fases

### Fase 1: UI e contexto sem backend critico

- Esconder detalhes tecnicos da UI normal.
- Mostrar detalhes completos somente para owner/debug.
- Garantir que aba de recrutamento e logs sempre recebam `activeOrgCode` em `/org` e `/gang`.
- Separar visualmente consultas globais de Staff.

### Fase 2: convite por citizenid/passaporte

- Status: implementada.
- `members:invite` aceita `citizenid` como principal.
- `targetId/source` permanece apenas como fallback legado opt-in, desativado por padrao.
- Wrapper seguro no core: `InviteOrgMemberByCitizenId`.
- UI pede CitizenID/passaporte, nao ID online.

### Fase 3: lideranca/top grade

- Status: implementada para invite/promote/demote/remove e acao minima staff de definir lider.
- `members.set_leader` e `staff.orgs.set_leader` adicionadas ao catalogo.
- Top grade definido como maior `level` da org.
- Capability dedicada exigida para criar/promover/rebaixar/remover top grade.
- `staff.panel.open` removido como bypass de mutacao de membros/lideranca.

### Fase 4: hierarquia staff completa

- Criar capabilities staff de membros.
- Aplicar regra de level para staff.
- Garantir que Helper/Moderador/Admin so mexam abaixo do proprio nivel.

### Fase 5: recrutamento real

- Criar fluxo persistido de candidatura/convite.
- Separar "minhas candidaturas" de "gestao de recrutamento".
- Adicionar aceite/recusa, expiracao, logs e rate limit.

### Fase financeira implementada: banco da org

- `mz_core` autoc cria `mz_org_account_transactions`.
- Deposito exige owner ACE, `account.deposit` ou `account.manage` (`manage.account` segue como alias legado).
- Saque exige owner ACE, `account.withdraw` ou `account.manage` (`manage.account` segue como alias legado).
- Extrato usa permissao de visualizacao da conta.
- NUI envia somente `orgCode`, `amount` e `reason`.
- O servidor calcula ator, citizenid, saldos antes/depois, logs e extrato.

## Conclusao

A base atual esta bem encaminhada: `citizenid` ja e a chave real do core, o convite principal ja usa esse identificador, top grade/lideranca ja exige capability dedicada e a maior parte das operacoes sensiveis ja tem wrappers seguros. As proximas prioridades de seguranca sao completar a hierarquia staff, revisar exports legados de baixo nivel e esconder detalhes tecnicos da UI comum.

## Arquivamento e desativacao segura

Status: implementado para Staff com `staff.orgs.manage` ou owner ACE.

- Organizacao arquivada usa `mz_orgs.active = 0`; reativacao usa `active = 1`.
- Cargo desativado usa `mz_org_grades.active = 0`; reativacao usa `active = 1`.
- Nao ha DELETE fisico em orgs, grades, membros, banco, metas, recrutamento ou logs.
- `/staff` pode consultar orgs e cargos arquivados/desativados com badge visual.
- `/org` e `/gang` deixam de receber orgs arquivadas no contexto normal do player.
- Cargos desativados nao entram nas listas normais de grades ativas.
- Desativar cargo bloqueia cargo com membros ativos e cargo maximo/top grade.
- Org arquivada fica somente consulta no detalhe Staff; a acao permitida e reativar.
- Payloads NUI aceitos sao apenas `orgCode`, `gradeId` quando aplicavel e `reason`; `source`, ator, permissao, `delete=true`, `orgId`, cargos ou capabilities livres sao ignorados/nao aceitos.
- Logs de sucesso: `org.archive`, `org.reactivate`, `org.grade.disable`, `org.grade.reactivate`.
- Logs de bloqueio usam o mesmo nome com sufixo `.blocked`.

## Permissoes por cargo

Status: implementado no Staff, dentro de `Organizacoes > Ver detalhes > Cargos`.

- A UI nao tem campo livre para capability.
- A lista visual vem de catalogo oficial agrupado.
- O server tem allowlist propria e rejeita qualquer permissao fora dela.
- A NUI envia somente `orgCode`, `gradeId`, `permission` e `reason`.
- O server valida `source` real, ator carregado, org ativa, grade ativa e grade pertencente a org.
- Permissoes `staff.*` sao bloqueadas para org comum.
- Em org tipo `staff`, permissao `staff.*` exige owner nesta fase.
- `members.set_leader` exige owner ou `staff.orgs.set_leader`.
- Cargos inativos e orgs arquivadas nao aceitam edicao de permissoes.
- Remover permissao usa `allow = 0` e nao depende de DELETE fisico.
- Logs de sucesso: `org.grade.permission.add` e `org.grade.permission.remove`.
- Logs de bloqueio usam `.blocked` com motivo e contexto.
