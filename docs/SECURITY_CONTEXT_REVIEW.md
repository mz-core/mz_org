# Auditoria de identidade, contexto, permissoes e seguranca

## Escopo

Esta revisao cobre `mz_core` e `mz_org` no estado atual dos arquivos. A auditoria original mapeou riscos e fases; depois dela foi implementada a fase financeira permitida: deposito, saque e extrato real da conta da organizacao, mantendo validacao server-side e sem aceitar `source` ou saldo final da NUI.

## Diagnostico executivo

- O identificador fixo real do personagem no `mz_core` e `citizenid`.
- O convite atual do painel usa `source`/ID online (`targetId`) e por isso e um fluxo online-only.
- Remover, promover e rebaixar ja usam `citizenid` no contrato NUI e no wrapper seguro do core.
- `/org` e `/gang` ja usam `activeOrgCode` no frontend para membros, banco, metas, cargos, recrutamento e logs.
- Banco de org agora usa callbacks `org-bank:deposit`, `org-bank:withdraw` e `org-bank:transactions`, sempre com `orgCode` ativo e `source` real no servidor.
- A UI ainda expoe detalhes tecnicos em blocos colapsados para qualquer usuario que consiga abrir a tela.
- A hierarquia de job/gang para lider comum esta parcialmente protegida.
- Staff atualmente recebe poderes amplos demais: `staff.panel.open` ja torna o ator "staff" em algumas acoes seguras do core.
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
- Nao ha export publico atual para buscar player offline por `citizenid`, embora `MZPlayerRepository.getByCitizenId(citizenid)` exista internamente.

Conclusao:

- Para UI/acoes de gestao, usar `citizenid`/passaporte como identificador principal.
- `source` deve ser tratado como dado de sessao, util para debug ou acoes estritamente online.
- Para validar player offline, o core precisa expor uma consulta segura por `citizenid` ou encapsular isso em um wrapper de convite/adicao por citizenid.

## Problema do convite por source

Fluxo atual:

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

Transicao recomendada:

1. Manter o callback NUI existente `members:invite`.
2. Alterar o payload para aceitar `citizenid` como principal.
3. Manter `targetId` apenas como fallback/debug temporario.
4. Criar no `mz_core` um wrapper seguro, por exemplo `InviteOrgMemberByCitizenId(source, orgCode, targetCitizenId, options)`.
5. Esse wrapper deve validar:
   - ator real pelo `source`;
   - org existente;
   - citizenid existente em `mz_players`;
   - se ja e membro ativo;
   - permissao/capability do ator;
   - hierarquia e grade inicial;
   - logs/auditoria.

Nao e recomendavel expor diretamente `AddMemberToOrg(citizenid, ...)` para NUI, porque ele e baixo nivel e nao concentra todas as validacoes de ator/hierarquia.

Convite offline:

- Curto prazo: `InviteOrgMemberByCitizenId` pode adicionar diretamente se o player existir.
- Medio prazo: criar fluxo real de candidatura/convite pendente, com aceite do jogador, expiração e auditoria.

## Vazamento tecnico no frontend

Itens encontrados na UI:

- `orgCode` e tipo interno em detalhes de org/recrutamento/metas/logs.
- `ID interno` da org em detalhes do resumo.
- `gradeCode`, `grade`, capabilities cruas em detalhes de membros/cargos/acesso.
- `citizenid` mascarado na linha principal, mas completo em `<details>`.
- IDs internos de metas em detalhes.
- Logs exibem acao tecnica, org e citizenids completos em detalhes.
- Staff possui bloco tecnico de modulo/acoes.

Classificacao recomendada:

- Jogador comum/lider: nao deve ver IDs internos, `orgCode`, `gradeCode`, capabilities cruas nem citizenid completo.
- Staff operacional: pode ver citizenid mascarado e contexto funcional, mas nao payloads brutos por padrao.
- Owner/debug: pode ver detalhes tecnicos colapsados.

Regra proposta:

- Criar helper visual `canSeeTechnicalDetails()` baseado em `isOwner` ou modo debug explicito.
- Para usuario normal, remover completamente `<details>` tecnicos.
- Para staff, mostrar apenas dados operacionais necessarios, preferindo mascaramento.
- Para owner/debug, manter detalhes colapsados.

## Contexto ativo e isolamento

O frontend atual ja tem:

- `activeShell`
- `activeOrgCode`
- `activeOrgType`
- `activeSection`

Chamadas auditadas:

- `members:list`, `members:invite`, `members:remove`, `members:promote`, `members:demote`: usam `selectedOrgCode()`, que prioriza `activeOrgCode`.
- `org-bank:get` e `org-bank:transactions`: carregadas por `loadOrgPanel()` com o code selecionado.
- `goals:list` e `goals:create`: usam filtros/payload com org ativa.
- `org-access:get`: usa org ativa.
- `recruitment:list`: recebe `filters.orgCode` quando ha org ativa.
- `logs:list`: dentro de `/org` e `/gang`, agora chama com `{ orgCode, limit }`.

Riscos restantes:

- As rotas antigas de `recruitment`, `goals` e `logs` ainda existem no router para compatibilidade/hub/staff.
- Se uma tela futura chamar esses modulos fora do contexto sem `activeOrgCode`, pode virar consulta ampla ou vazia.
- No server, `recruitment:list` permite player comum sem `orgCode` como futuro "minhas candidaturas"; isso deve ser separado visualmente de administracao de org.

Recomendacao:

- Em abas de contexto, exigir sempre `activeOrgCode`.
- Em Staff, deixar claro quando a consulta e global/admin.
- Em `/painel`, nao mostrar administracao de recrutamento de org; reservar para "minhas candidaturas" quando existir fluxo real.

## Recrutamento

Estado atual:

- `mz_org/server/recruitment.lua` tenta `ListOrgRecruitment` e `GetOrgRecruitment`.
- Nao foi encontrada implementacao real desses exports no `mz_core`.
- Sem export real, retorna lista vazia segura.
- Permissao aceita owner, `staff.orgs.manage`, `staff.panel.open`, `members.invite`, `recruitment.view` ou fallback `org.view`.

Comportamento desejado:

- Dentro de `/org`: filtrar pela organizacao legal ativa.
- Dentro de `/gang`: filtrar pela gang ativa.
- Dentro de `/painel`: futuramente mostrar apenas candidaturas pessoais do player.
- Dentro de `/staff`: se autorizado, permitir consulta/admin separada e identificada como modo staff.

Ponto de cuidado:

- A capability `recruitment.view/manage` aparece em seed, mas nao existe em `mz_org/shared/capabilities.lua`.

## Lideranca e top grade em job/gang

Protecoes existentes:

- Convite com grade escolhida: lider comum nao pode convidar para grade maior ou igual a propria.
- Remocao: membro comum nao remove cargo igual/superior.
- Remocao de cargo maximo: bloqueia qualquer ator que nao seja owner.
- Promover/rebaixar seguro:
  - bloqueia self action;
  - membro comum nao mexe em cargo igual/superior;
  - membro comum nao promove para grade igual/superior a propria;
  - demote de cargo maximo bloqueia nao owner/staff.

Riscos:

- `isStaffActor` hoje e verdadeiro para `staff.orgs.manage` ou `staff.panel.open`.
- Como `staff.panel.open` e permissao base da org staff, um Helper pode virar bypass amplo se tiver essa org/capability.
- Staff ator ignora hierarquia de job/gang nas checagens de convite/promocao/remocao, exceto alguns bloqueios de target protegido.
- Promover alguem ate top grade por staff amplo nao exige capability dedicada como `members.set_leader` ou `staff.orgs.set_leader`.

Regra proposta:

- Owner ACE `group.mz_owner`: pode tudo.
- Staff autorizado para lideranca: precisa capability dedicada, por exemplo `staff.orgs.set_leader`.
- Lider de org: gerencia somente abaixo dele.
- Promover/convidar para grade maxima exige `members.set_leader` ou `staff.orgs.set_leader`.
- `staff.panel.open` deve abrir painel, nao autorizar mutacoes amplas.
- `staff.orgs.manage` deve ser amplo, mas ainda pode ser subdividido para acoes sensiveis.

## Hierarquia staff

Seed atual da org staff:

- Helper level 1: `staff.report.view`.
- Moderador level 2: `staff.kick`, `staff.spectate`.
- Admin level 3: `staff.ban`, `staff.teleport`, `staff.orgs.manage`.
- Base da org staff: `staff.panel.open`.

Problemas:

- Staff e tratada como org comum para membership/cargos, mas as acoes seguras do core usam bypass por permissao global.
- `staff.panel.open` hoje conta como staff ator em convite/remocao/promocao de membros de org.
- Nao ha capabilities especificas para gerenciar staff como `staff.members.invite/remove/promote/demote`.
- Nao ha regra explicita documentada para Helper nao mexer em Moderador/Admin.

Regra proposta:

- Owner ACE e topo absoluto.
- Staff so mexe em staff abaixo do proprio level.
- Staff nao promove alguem para level igual/superior ao proprio.
- Staff nao remove/rebaixa cargo igual/superior.
- Recrutar/dispensar staff exige capability especifica:
  - `staff.members.invite`
  - `staff.members.remove`
  - `staff.members.promote`
  - `staff.members.demote`
  - `staff.staff.manage`

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

Usadas em seed/codigo mas ausentes ou nao padronizadas no catalogo:

- `recruitment.view`
- `recruitment.manage`
- `reports.approve`
- `manage.team`
- `highcommand`
- `command.full`
- `org.settings`
- `staff.panel.open`
- `staff.report.view`
- `staff.kick`
- `staff.spectate`
- `staff.ban`
- `staff.teleport`
- `staff.orgs.manage`
- `staff.logs.view`

Faltantes recomendadas:

- `members.set_leader`
- `staff.orgs.set_leader`
- `staff.members.invite`
- `staff.members.remove`
- `staff.members.promote`
- `staff.members.demote`
- `staff.staff.manage`

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
- `staff.orgs.manage`
- `staff.orgs.set_leader`
- `staff.members.invite`
- `staff.members.remove`
- `staff.members.promote`
- `staff.members.demote`
- `staff.staff.manage`
- `staff.logs.view`

## Plano de implementacao por fases

### Fase 1: UI e contexto sem backend critico

- Esconder detalhes tecnicos da UI normal.
- Mostrar detalhes completos somente para owner/debug.
- Garantir que aba de recrutamento e logs sempre recebam `activeOrgCode` em `/org` e `/gang`.
- Separar visualmente consultas globais de Staff.

### Fase 2: convite por citizenid/passaporte

- Adaptar `members:invite` para aceitar `citizenid`.
- Manter `targetId/source` apenas como fallback temporario/debug.
- Criar wrapper seguro no core para convite por citizenid.
- Atualizar UI para pedir passaporte/citizenid, nao ID online.

### Fase 3: lideranca/top grade

- Adicionar `members.set_leader` e `staff.orgs.set_leader`.
- Exigir capability dedicada para criar/promover/convidar top grade.
- Remover `staff.panel.open` como bypass de mutacao.

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
- Deposito exige owner ACE, `account.deposit` ou `account.manage`.
- Saque exige owner ACE, `account.withdraw` ou `account.manage`.
- Extrato usa permissao de visualizacao da conta.
- NUI envia somente `orgCode`, `amount` e `reason`.
- O servidor calcula ator, citizenid, saldos antes/depois, logs e extrato.

## Conclusao

A base atual esta bem encaminhada: `citizenid` ja e a chave real do core e a maior parte das operacoes sensiveis ja tem wrappers seguros. As prioridades de seguranca sao trocar o convite para `citizenid`, remover `staff.panel.open` como autorizador de mutacoes amplas e esconder detalhes tecnicos da UI comum.
