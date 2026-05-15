# MZ_ORG - Plano de teste manual

Use este roteiro depois de `restart mz_core` e `restart mz_org`. Durante todos os testes, acompanhar F8 e console do servidor.

## Inicializacao

- [ ] `restart mz_core` conclui prepare sem erro.
- [ ] `restart mz_org` inicia sem erro.
- [ ] `web/index.html`, `style.css`, `script.js`, `web/core`, `web/services` e `web/panels` carregam pela NUI.
- [ ] F8 nao mostra erro de arquivo ausente.

## Permissoes

- [ ] Owner com `group.mz_owner` abre todos os paineis.
- [ ] Staff com `staff.panel.open` / `staff.orgs.manage` abre `/staff`.
- [ ] Player comum com org abre apenas contexto permitido.
- [ ] Player sem org cai no hub/recrutamento quando aplicavel.
- [ ] Nenhum teste usa `source` vindo do frontend como permissao.

## Comandos

- [ ] `/painel` abre hub.
- [ ] `/mzorg` abre hub/debug.
- [ ] `/org` abre painel legal quando permitido.
- [ ] `/gang` abre painel ilegal quando permitido.
- [ ] `/staff` abre painel staff quando permitido.
- [ ] `/vip`, `/business`, `/government`, `/event` abrem seus contextos ou caem no primeiro modulo permitido.
- [ ] ESC fecha a NUI.

## Orgs e contexto

- [ ] Sessao mostra nome do player.
- [ ] Sidebar mostra apenas modulos permitidos.
- [ ] Organizacoes retornam conforme permissao.
- [ ] Detalhe da org abre somente se `CanOrg(source, orgCode, 'org.view')` ou permissao global permitir.

## Membros

- [ ] `members:list` lista membros reais.
- [ ] Campos vazios aparecem como `-`, sem `undefined`.
- [ ] Dados sensiveis nao aparecem.

## Invite

- [ ] Convidar player online sem escolher grade usa menor grade segura.
- [ ] Convidar player online escolhendo grade permitida usa a grade escolhida.
- [ ] Tentar convidar a si mesmo retorna erro.
- [ ] Tentar convidar player offline/invalido retorna erro.
- [ ] Tentar convidar player ja membro retorna erro.
- [ ] Player sem permissao nao consegue convidar.
- [ ] Player comum nao consegue escolher grade igual/superior a propria.
- [ ] Payload adulterado com grade inexistente retorna erro.
- [ ] Lista de membros recarrega apos sucesso.
- [ ] Log `org.member.invite` ou `org.member.invite.blocked` e gerado.

## Remover membro

- [ ] Remover membro abaixo do cargo do autor funciona.
- [ ] Remover a si mesmo retorna erro.
- [ ] Remover membro inexistente/nao membro retorna erro.
- [ ] Remover cargo igual/superior sem owner/staff retorna erro.
- [ ] Player sem permissao nao remove.
- [ ] Lista de membros recarrega apos sucesso.
- [ ] Log `org.member.remove` ou `org.member.remove.blocked` e gerado.

## Promover/Rebaixar

- [ ] Promover membro abaixo do cargo do autor funciona.
- [ ] Rebaixar membro abaixo do cargo do autor funciona.
- [ ] Promover/rebaixar a si mesmo retorna erro.
- [ ] Promover cargo igual/superior sem owner/staff retorna erro.
- [ ] Promover acima do maximo retorna erro.
- [ ] Rebaixar abaixo do minimo retorna erro.
- [ ] Player sem permissao nao promove/rebaixa.
- [ ] Lista de membros recarrega apos sucesso.
- [ ] Logs `org.member.promote` / `org.member.demote` ou bloqueios sao gerados.

## Metas

- [ ] `goals:list` carrega metas reais da org.
- [ ] Criar meta valida funciona.
- [ ] Criar meta sem titulo retorna erro.
- [ ] Criar meta com target invalido retorna erro.
- [ ] Criar meta com data final anterior a inicial retorna erro.
- [ ] Player sem `goals.manage`/`manage.goals` nao cria.
- [ ] Lista recarrega apos sucesso.
- [ ] Log `org.goal.create` ou `org.goal.create.blocked` e gerado.
- [ ] Editar/deletar/concluir/progresso continuam indisponiveis.

## Logs

- [ ] `/staff` ou modulo Logs carrega logs conforme permissao.
- [ ] Player sem permissao nao ve logs administrativos.
- [ ] Logs nao exibem IP, license completa, tokens, inventario ou payload sensivel.

## Banco read-only

- [ ] Card Banco da Organizacao mostra saldo quando permitido.
- [ ] Sem permissao retorna erro amigavel.
- [ ] Extrato fica vazio seguro se export real nao existir.
- [ ] Nenhum botao de deposito/saque/transferencia executa acao.

## Cargos e capabilities

- [ ] `org-access:get` carrega grades/capabilities.
- [ ] Heranca e salario aparecem quando existirem.
- [ ] O seletor de grade do convite usa apenas grades retornadas por `org-access:get`.
- [ ] Editar cargos/permissoes continua indisponivel.

## Tentativas bloqueadas

- [ ] Payload NUI com `source` falso e ignorado.
- [ ] Org invalida retorna erro.
- [ ] Capability ausente retorna `forbidden`/mensagem amigavel.
- [ ] Rate limit bloqueia spam de invite/remove/promote/demote/goals:create.

## F8/console

- [ ] F8 sem erro vermelho apos abrir/fechar paineis.
- [ ] Console sem erro critico nos callbacks.
- [ ] Com `Config.DebugCommands == true`, `/mzorg_test <org>` imprime diagnostico sem alterar dados.
