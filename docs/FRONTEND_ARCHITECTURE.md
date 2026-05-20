# Arquitetura do frontend NUI

O `mz_org` usa NUI tradicional do FiveM com HTML, CSS e JavaScript puro. Nao existe etapa de build, Node, Vite ou React para rodar o painel.

## Estrutura

- `web/index.html`: carrega CSS e scripts na ordem correta.
- `web/style.css`: visual global do painel.
- `web/script.js`: boot principal pequeno.
- `web/core/state.js`: estado global controlado.
- `web/core/nui.js`: `fetchNui`, listeners de mensagens, abrir/fechar painel e recebimento de sessao.
- `web/core/router.js`: troca de painel/modulo, render principal e carregamentos read-only.
- `web/core/permissions.js`: regras visuais para escolher paineis/modulos permitidos.
- `web/core/ui.js`: helpers DOM/HTML, badges, cards, loading, empty e erro.
- `web/core/format.js`: formatadores de dinheiro, datas, numeros, tipos, cargos, CitizenID mascarado e labels amigaveis de capabilities.
- `web/services/*.js`: chamadas para callbacks NUI existentes. A maior parte e read-only; actions reais precisam estar documentadas e validadas no server.
- `web/panels/<contexto>/index.js`: definicoes e render contextual dos paineis.

## Navegacao por contexto

O frontend usa uma camada de contexto para separar a sidebar principal das secoes internas:

- `activeShell`: contexto principal aberto (`hub`, `legal`, `illegal`, `staff`, `vip`, `business`, `government`, `event`).
- `activeOrgCode`: org ativa dentro do contexto atual.
- `activeOrgType`: tipo normalizado da org ativa.
- `activeSection`: aba interna do contexto (`overview`, `members`, `grades`, `goals`, `bank`, `recruitment`, `logs`) e tambem as abas internas do Staff (`overview`, `orgs`, `logs`, `audit`, `actions`).

Na etapa atual, as abas internas foram aplicadas em `legal` (`/org`), `illegal` (`/gang`) e `staff` (`/staff`). Business, government, VIP e event continuam usando a renderizacao anterior e devem ser migrados depois, reaproveitando a mesma estrutura.

Em contexto de org/gang, chamadas de membros, cargos, banco, metas, recrutamento e logs devem usar sempre `activeOrgCode`. Logs dentro de org usam filtro `orgCode`; logs em Staff podem continuar como auditoria ampla quando permitido pelo servidor.

O header superior e contextual: no hub mostra `PAINEL GERAL / MZ Org`, em `/org` e `/gang` destaca a org ou faccao ativa e o cargo do jogador, e em `/staff` mostra o modo administrativo separado de qualquer org pessoal. O bloco interno desses contextos fica compacto, mantendo seletor, badges e abas internas sem repetir o mesmo titulo duas vezes.

## Staff dashboard

`/staff` usa `activeShell = 'staff'`, `activeOrgCode = null` e `activeSection` para as abas internas:

- `overview`: metricas e resumo administrativo, sem atalhos duplicados.
- `orgs`: lista de organizacoes retornadas por `orgs:list`, subview `Ver detalhes`, aba `Acoes` do detalhe, modal restrita `Criar organizacao` quando houver owner/`staff.orgs.create` e modal `Editar dados basicos` quando houver owner/`staff.orgs.manage`.
- `logs`: logs recentes retornados por `logs:list`, com filtros locais.
- `audit`: recorte local de eventos sensiveis dentro dos logs recentes.
- `actions`: orientacao para usar `Organizacoes > Ver detalhes > Acoes` e cards bloqueados para fases futuras.

O dashboard Staff reutiliza `orgs:list` e `logs:list` para leitura. Escritas reais atuais no Staff:

- `members:setLeader`: define lider/top grade por `orgCode` e `citizenid`, acionado pela aba `Acoes` do detalhe da org.
- `orgs:createFromTemplate`: cria org/faccao por templates seguros do servidor.
- `orgs:updateBasic`: edita somente nome, status e flags basicas da org selecionada.
- `orgs:createGrade` e `orgs:updateGradeBasic`: gerenciam dados basicos de cargos, sem editar permissoes.

As demais acoes administrativas aparecem como bloqueadas/placeholder. Nao ha editor livre de cargos/permissoes, exclusao de org ou gestao global de staff.

`Ver detalhes` em uma org usa estado proprio `staffOrgDetails` e carrega services existentes (`orgs:get`, `org-access:get`, `members:list`, `org-bank:*`, `goals:list`, `recruitment:list`, `logs:list`) sem mudar `activeOrgCode`. A subview possui abas `Resumo`, `Cargos`, `Membros`, `Banco`, `Metas`, `Recrutamento`, `Logs` e `Acoes`. A aba `Acoes` usa o orgCode da org selecionada; nao existe input manual de orgCode para lideranca. O modal `Editar dados basicos` usa estado proprio `staffEditOrgBasic` e nao permite alterar code, type, cargos ou permissoes. O modal de cargos usa `staffGradeModal`; criar envia `code`, mas editar nao altera `code` e nunca envia permissoes.

## Adicionar novo painel

1. Criar `web/panels/novo/index.js`.
2. Registrar `window.MZOrgPanels.novo` com `id`, `title`, `subtitle`, `initialModule`, `modules` e `render`.
3. Incluir o script em `web/index.html`.
4. Incluir o arquivo no `fxmanifest.lua` se o glob atual nao cobrir.
5. Criar comando Lua somente se o painel precisar abrir por comando proprio.

## Adicionar novo service

1. Criar `web/services/novo-service.js`.
2. Usar `window.MZOrgNui.callNuiData('callback:nome', payload)`.
3. Tratar `{ ok, data, error }`.
4. Lista vazia deve ser estado vazio, nao erro fatal.
5. Incluir o script em `web/index.html`.

## Regras de seguranca

- Frontend nao e seguranca.
- Botoes escondidos nao bloqueiam exploit.
- O frontend nunca deve aceitar `source` vindo da NUI como verdade.
- Toda acao de escrita futura precisa de validacao server-side.
- Acoes perigosas futuras devem validar `HasGlobalPermission`, `CanOrg`, rate limit e auditoria.
- Actions reais atuais: `members:invite`, `members:remove`, `members:promote`, `members:demote`, `members:setLeader`, `orgs:createFromTemplate`, `orgs:updateBasic`, `orgs:createGrade`, `orgs:updateGradeBasic`, `org-bank:deposit`, `org-bank:withdraw`, `recruitment:create/approve/reject/cancel` e `goals:create`.
- Nenhuma action deve enviar `source` ou `createdBy` como verdade.
- Acoes sensiveis de membros usam confirmacao inline no painel, sem `alert`, `prompt` ou janela externa do navegador.

## Polimento visual/UX

- A visao principal deve priorizar nome da org, cargo, membros, metas, banco e acoes disponiveis.
- Codigos internos, IDs e capabilities cruas ficam desativados na UI normal; se detalhes tecnicos voltarem em modo owner/debug, devem ficar colapsados e claramente separados.
- Capabilities exibidas ao jogador devem passar por labels amigaveis em `formatCapabilityLabel`.
- CitizenID completo nao deve aparecer em tabelas principais; use `maskCitizenId` e deixe o valor completo apenas no detalhe colapsado quando necessario.
## Staff: arquivamento e cargos inativos

- Acoes de arquivar/reativar org ficam no detalhe da org, aba `Acoes`.
- Acoes de desativar/reativar cargo ficam no detalhe da org, aba `Cargos`.
- O estado da confirmacao usa `state.staffArchiveModal`.
- O frontend envia somente `orgCode`, `gradeId` quando aplicavel e `reason`.
- `orgCode` vem sempre da org selecionada em `staffOrgDetails`; nao ha input manual para esta acao.
- Cargos desativados aparecem em modo read-only com badge/estado visual.
- Org arquivada fica somente consulta no detalhe Staff; o frontend bloqueia criar/editar cargos e definir lider ate reativar.
- Permissoes de cargo podem ser gerenciadas pelo modal controlado, sem campo livre.

## Staff: permissoes por cargo

- O modal de permissoes fica em `state.staffPermissionModal`.
- A tabela de cargos continua mostrando permissoes compactadas.
- O botao `Gerenciar permissoes` abre um modal controlado para o cargo selecionado.
- O modal nao possui campo livre de capability.
- A lista oficial vem de `format.getCapabilityCatalog()`.
- A UI oculta `staff.*` quando a org selecionada nao e tipo Staff.
- Permissoes diretas podem ser removidas; permissoes herdadas/base aparecem somente como leitura.
- O frontend envia somente `orgCode`, `gradeId`, `permission` e `reason`.
- O server continua sendo a fonte da verdade para allowlist, org ativa, grade ativa e permissoes sensiveis.
