# Plano de navegacao e UX do MZ_ORG

## Diagnostico atual

O `mz_org` ja abre como NUI HTML/CSS/JS puro e os callbacks existentes estao suficientes para a etapa atual. O problema principal nao esta no backend: esta na organizacao visual e no estado do frontend.

Hoje existem dois conceitos misturados na mesma sidebar:

- Contextos grandes: Painel, Organizacao legal, Gang, Staff, VIP, Empresa, Governo e Evento.
- Secoes internas de uma organizacao: Recrutamento, Metas e Logs.

Dentro do modulo de organizacao (`legal`, `gang`, `business`, `government`, `vip`, `event`), a tela tambem empilha muitas areas ao mesmo tempo: resumo, acesso, cargos, banco, extrato, membros e convite. Isso funciona, mas vira uma pagina longa e confusa quando o player tem mais de um contexto ou quando o staff/owner tambem pode ver modulos administrativos.

## Comandos atuais

Os comandos em `client/main.lua` apenas abrem a NUI com `initialModule` e `mode`. Eles nao concedem permissao.

| Comando | initialModule | mode atual | Intencao |
| --- | --- | --- | --- |
| `/mzorg` | `dashboard` | `hub` | Hub geral de desenvolvimento/entrada |
| `/painel` | `dashboard` | `hub` | Painel geral do personagem |
| `/org` | `legal` | `legal` | Contexto de organizacao legal/job |
| `/gang` | `gang` | `illegal` | Contexto de gang/faccao |
| `/staff` | `staff` | `staff` | Contexto administrativo |
| `/vip` | `vip` | `vip` | Contexto VIP |
| `/business` | `business` | `business` | Contexto de empresa |
| `/government` | `government` | `government` | Contexto de governo |
| `/event` | `event` | `event` | Contexto de evento |

O payload enviado para a NUI e:

```js
{
  action: 'open',
  payload: {
    initialModule: '...',
    mode: '...'
  }
}
```

## Sessao atual

`session:get` retorna uma sessao com:

- `user.source`
- `user.name`
- `user.isOwner`
- `user.globalPermissions`
- `orgs[]` com `code`, `name`, `type`, `grade`, `gradeCode`, `gradeName` e `capabilities`
- `modules[]`

Nao existe hoje um campo explicito `currentPanel`, `currentContext`, `activeOrgCode` ou `isStaff`. O frontend infere staff por `modules`/`globalPermissions` e escolhe a org ativa pelo modulo/painel atual.

Isso e suficiente para o painel pessoal. Para visao administrativa de owner/staff sobre qualquer org, o frontend deve usar os callbacks existentes de listagem, como `orgs:list`, em uma area staff/admin separada.

## Roteamento frontend atual

O estado principal atual usa:

- `activePanel`: painel/contexto visual aberto (`hub`, `legal`, `illegal`, `staff`, etc.).
- `activeModule`: item ativo da sidebar (`legal`, `gang`, `recruitment`, `goals`, `logs`, etc.).
- `orgView.selectedByPanel`: memoriza uma org selecionada por tipo.

`selectedOrgCode()` escolhe a org ativa com base em `activeModule`. Quando o modulo e um contexto de org (`legal`, `gang`, `vip`, `business`, `government`, `event`), isso funciona bem.

O risco aparece quando `activeModule` e uma secao geral (`recruitment`, `goals`, `logs`):

- `goals` e `recruitment` tentam usar o painel atual para buscar orgs compativeis.
- `logs` carrega atualmente sem `orgCode` e filtra localmente depois.
- No `hub`, as secoes podem ficar sem contexto claro ou virar uma consulta ampla demais para owner/staff.

## Riscos encontrados

- Metas, logs e recrutamento aparecem como modulos paralelos, mas na pratica deveriam ser abas da org ativa.
- A pagina `/org` empilha muitas secoes e fica pesada para uso real.
- Um player com job e gang pode ver menus parecidos e perder clareza sobre qual banco/metas/membros esta olhando.
- Staff/owner pode alternar entre visao pessoal e administrativa sem uma demarcacao forte.
- Logs em contexto de org deveriam buscar por `orgCode` ativo; hoje a pagina de logs carrega com `{ limit: 100 }` e so filtra localmente.
- `/painel` pode mostrar modulos demais para quem deveria ver primeiro um portal de contextos, nao uma lista tecnica de modulos.
- Owner pode ver tudo, mas isso nao deve significar misturar org pessoal com modo administrativo.

## Recrutamento contextual implementado

A aba `Recrutamento` agora fica dentro do contexto `/org` ou `/gang` e usa sempre `activeOrgCode`.

Fluxo visual:

- cards superiores mostram pendentes, aprovados e acao `Novo candidato`;
- `Novo candidato` abre modal com CitizenID, grade desejada e observacao;
- a lista mostra nome, CitizenID mascarado, status, cargo desejado, data e acoes;
- candidaturas pendentes permitem aprovar, recusar ou arquivar;
- aprovar abre confirmacao com grade inicial e nota opcional;
- recusar/arquivar pedem motivo opcional.

Isolamento:

- `/org` lista e altera somente candidaturas da organizacao legal ativa;
- `/gang` lista e altera somente candidaturas da gang ativa;
- nao foi criado painel staff global de recrutamento nesta fase.

## Proposta de navegacao

Separar o painel em duas camadas:

1. Sidebar principal para contextos grandes.
2. Abas internas no topo do conteudo para secoes do contexto ativo.

Sidebar principal proposta:

- Painel
- Organizacao
- Gang
- Staff
- VIP
- Empresa
- Governo
- Evento

Abas internas para contextos de organizacao:

- Visao geral
- Membros
- Cargos
- Metas
- Banco
- Recrutamento
- Logs
- Ajustes

Exemplo visual:

```txt
[Sidebar]
Painel
Organizacao
Gang
Staff
VIP
Empresa
Governo
Evento

[Topo do conteudo]
Policia Militar
Cargo: Sargento
Contexto: Organizacao legal

[Abas internas]
Visao geral | Membros | Cargos | Metas | Banco | Recrutamento | Logs
```

## Estado frontend sugerido

Adicionar uma camada explicita de contexto e secao:

```js
state.activeShell = 'legal';       // hub, legal, illegal, staff, vip, business, government, event
state.activeOrgCode = 'police';    // org ativa no contexto atual
state.activeOrgType = 'legal';     // legal, gang, vip, business, government, event
state.activeSection = 'overview';  // overview, members, grades, goals, bank, recruitment, logs, settings
state.adminMode = false;           // true apenas em staff/admin
```

`activeShell` substitui a ideia de usar a sidebar para tudo. `activeSection` substitui `recruitment`, `goals` e `logs` como modulos soltos dentro de contextos de org.

## Regras por comando

`/painel`

- Abre `activeShell = 'hub'`.
- Mostra cards dos contextos liberados.
- Nao deve carregar banco/metas/membros automaticamente.
- Para player comum sem org, mostra estado limpo de entrada/recrutamento futuro.
- Para owner, mostra todos os contextos como atalhos, com indicacao clara de modo administrativo quando entrar em Staff.

`/org`

- Abre `activeShell = 'legal'`.
- Seleciona a primeira org do tipo `legal/job` do player.
- Define `activeSection = 'overview'`.
- Se houver mais de uma org legal, mostra seletor no topo.
- Nao deve cair automaticamente em gang, staff ou outro contexto.

`/gang`

- Abre `activeShell = 'illegal'`.
- Seleciona a primeira org do tipo `gang`.
- Define `activeSection = 'overview'`.
- Mostra somente dados da gang ativa.

`/staff`

- Abre `activeShell = 'staff'`.
- Define `adminMode = true`.
- Mostra area administrativa separada: visao admin, orgs, logs e avisos.
- Nao deve usar automaticamente a org pessoal como se fosse o alvo administrativo.

`/vip`, `/business`, `/government`, `/event`

- Abrem seus respectivos shells.
- Selecionam a primeira org do tipo correspondente.
- Usam as mesmas abas internas quando houver dados de org.
- Se nao houver vinculo daquele tipo, mostram empty state especifico, nao fallback para outro tipo.

## Regras para multiplas orgs

Player com job + gang:

- `/org` abre somente job/legal.
- `/gang` abre somente gang.
- `/painel` mostra os dois cards para alternar.
- Banco, metas, membros e logs sempre usam `activeOrgCode` do shell atual.

Player com duas jobs legais:

- `/org` abre legal e mostra seletor de org no topo.
- Ao trocar a org ativa, recarrega membros, cargos, metas, banco, recrutamento e logs daquela org.

Player staff + gang:

- `/staff` abre modo administrativo.
- `/gang` abre a gang pessoal.
- O header deve deixar claro se esta em "Modo administrativo" ou "Minha gang".

Owner:

- `/painel` mostra todos os contextos liberados.
- `/staff` e a area correta para consulta ampla/admin.
- `/org` ainda deve abrir contexto legal; se o owner nao tiver org legal pessoal, pode mostrar seletor administrativo usando `orgs:list` em etapa futura, mas com label claro de modo admin.

Player comum sem permissao:

- Nao deve ver areas administrativas soltas.
- Deve ver hub limpo e estados vazios amigaveis.

## Separacao por orgCode

Todas as chamadas de dados de contexto devem usar a org ativa:

- `members:list`
- `members:invite`
- `members:remove`
- `members:promote`
- `members:demote`
- `org-bank:get`
- `org-bank:transactions`
- `goals:list`
- `goals:create`
- `logs:list`
- `org-access:get`
- `recruitment:list`

O backend atual ja aceita `orgCode` nas chamadas principais. A proxima fase deve garantir que o frontend nunca chame dados de uma aba de org sem `activeOrgCode`, exceto em areas explicitamente administrativas.

Ponto de atencao: `logs:list` aceita filtros com `orgCode` no server, mas a tela atual chama `listLogs({ limit: 100 })`. Em abas internas de uma org, deve chamar `listLogs({ orgCode: activeOrgCode, limit: 100 })`. Na area Staff, pode continuar usando consulta ampla quando autorizado.

## Conteudo por aba

Visao geral:

- Nome da org.
- Tipo amigavel.
- Cargo do jogador.
- Total de membros.
- Metas ativas.
- Saldo quando permitido.
- Atalhos para abas importantes.

Membros:

- Convite compacto.
- Lista de membros.
- Cargo, status e entrada.
- Acoes: convidar, promover, rebaixar e remover.

Cargos:

- Hierarquia.
- Salario.
- Heranca.
- Permissoes traduzidas.
- Detalhes tecnicos colapsados.

Metas:

- Cards de resumo no topo: metas ativas, progresso geral e criar meta.
- Criar meta quando permitido por modal interna.
- Lista de metas full width abaixo dos cards.
- Progresso, alvo, periodo e status.

Banco:

- Saldo da org ativa.
- Extrato da org ativa.
- Aviso discreto para acoes financeiras ainda indisponiveis.

Recrutamento:

- Candidaturas/convites da org ativa.
- Empty state limpo quando nao houver dados.

Logs:

- Auditoria filtrada pela org ativa.
- Detalhes tecnicos colapsados.

Ajustes:

- Reservado para configuracoes futuras.
- Nao deve aparecer para quem nao tiver permissao.

## Mudancas minimas recomendadas para proxima fase

1. Criar `activeSection` e `activeOrgCode` no state.
2. Transformar a sidebar em seletor de `activeShell`, nao de cada modulo interno.
3. Criar renderer de abas internas.
4. Quebrar `renderOrgPanelPage()` em secoes: overview, members, grades, goals, bank, recruitment e logs.
5. Reaproveitar os mesmos renderers para legal, gang, business, government, vip e event.
6. Garantir que todas as chamadas de org usem `activeOrgCode`.
7. Fazer `logs:list` receber `orgCode` nas abas de org.
8. Manter Staff como area administrativa separada.
9. Manter contratos NUI atuais, sem callbacks novos.

## Necessidade de backend

Nao parece necessario mexer no backend para a reorganizacao principal. Os callbacks atuais ja cobrem sessao, orgs, membros, banco, metas, logs, recrutamento e cargos.

Possiveis necessidades futuras, apenas se a UX administrativa de owner exigir:

- Retornar uma org administrativa padrao para owner sem org pessoal.
- Ou reaproveitar `orgs:list` no frontend para popular seletor admin, sem callback novo.

Para esta fase de UX, a recomendacao e nao alterar backend.

## Ordem de implementacao recomendada

1. Refatorar somente estado/roteador frontend para `activeShell`, `activeOrgCode` e `activeSection`.
2. Ajustar sidebar para mostrar apenas contextos.
3. Criar abas internas reutilizaveis.
4. Migrar `/org` e `/gang` primeiro, validando job + gang no mesmo personagem.
5. Migrar business/government/vip/event reaproveitando componentes.
6. Separar logs de org e logs staff/admin.
7. Revisar estados vazios e labels finais.
8. Testar no FiveM com `/painel`, `/org`, `/gang`, `/staff` e troca de org ativa.

## Status da primeira implementacao

Implementado no frontend para os contextos iniciais:

- `activeShell`, `activeOrgCode`, `activeOrgType` e `activeSection`.
- Sidebar principal por contexto.
- Abas internas para `/org` (`legal`) e `/gang` (`illegal`).
- Header superior contextual: no hub mostra `MZ Org`, em `/org` e `/gang` mostra nome da org/faccao ativa e cargo.
- Header interno de contexto compactado com seletor, badges e abas imediatamente abaixo, sem repetir o titulo principal.
- Logs de org/gang carregados com filtro `orgCode`.
- Membros, cargos, banco, metas e recrutamento usando a org ativa.

Ainda pendente:

- Replicar a estrutura de abas para VIP, empresa, governo e eventos.
- Refinar uma navegacao interna propria para Staff/admin.
