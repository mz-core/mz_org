# MZ_ORG - Plano de teste integrado do MVP

## Objetivo

Validar o MVP do `mz_org` em jogo, com foco em estabilidade, isolamento de contexto, permissoes, UX, empty states, loading e logs. Este plano nao libera novas features: ele serve para testar o que ja existe e registrar regressos.

## Preparacao

No console do servidor:

```text
restart mz_core
restart mz_org
```

No jogo, testar os comandos:

```text
/painel
/org
/gang
/staff
```

Durante todos os testes:

- observar F8;
- confirmar que nao ha tela em branco sem mensagem;
- confirmar que nao ha loading infinito;
- confirmar que erros aparecem na UI;
- confirmar que o painel fecha e reabre normalmente.

## Smoke test

- [ ] Abrir `/painel`.
- [ ] Abrir `/org`.
- [ ] Abrir `/gang`.
- [ ] Abrir `/staff`.
- [ ] Fechar com botao `Fechar`.
- [ ] Fechar com `Esc`.
- [ ] Reabrir cada painel depois de fechar.
- [ ] Trocar abas internas em `/org`.
- [ ] Trocar abas internas em `/gang`.
- [ ] Trocar abas internas em `/staff`.
- [ ] Voltar ao hub por `/painel`.

Resultado esperado:

- painel sempre renderiza;
- sem erro F8;
- sem travamento de loading;
- contexto visual corresponde ao comando usado.

## Contexto e isolamento

- [ ] `/org` mostra somente organizacao legal/job.
- [ ] `/gang` mostra somente gang/faccao.
- [ ] `/staff` abre em modo administrativo e nao herda org ativa.
- [ ] Abrir `/org`, navegar por membros/banco/metas/recrutamento/logs.
- [ ] Abrir `/gang` em seguida e confirmar dados da gang.
- [ ] Abrir `/org` novamente e confirmar que dados da gang nao ficaram presos.
- [ ] Em `/org`, logs carregam com filtro da org legal ativa.
- [ ] Em `/gang`, logs carregam com filtro da gang ativa.
- [ ] Banco de `/org` nao mistura extrato da gang.
- [ ] Banco de `/gang` nao mistura extrato da org legal.

Resultado esperado:

- `activeOrgCode` acompanha o shell legal/gang;
- `/staff` usa `activeShell='staff'` e `activeOrgCode=null`;
- listas e extratos sempre pertencem ao contexto aberto.

## Membros

- [ ] Listar membros.
- [ ] Convidar por `citizenid` valido.
- [ ] Tentar convidar `citizenid` inexistente.
- [ ] Tentar convidar player que ja e membro.
- [ ] Tentar convidar a si mesmo.
- [ ] Selecionar grade inicial valida.
- [ ] Tentar grade nao permitida/top grade sem permissao.
- [ ] Promover membro.
- [ ] Rebaixar membro.
- [ ] Remover membro.
- [ ] Confirmar que promover/rebaixar/remover pedem segundo clique inline.
- [ ] Confirmar self-action bloqueada visualmente e no server.
- [ ] Confirmar loading limpa em sucesso e erro.

Resultado esperado:

- acoes usam `citizenid`;
- erros sao amigaveis;
- top grade continua protegido por owner/`members.set_leader`/`staff.orgs.set_leader`;
- nenhuma acao fica carregando indefinidamente.

## Banco

- [ ] Saldo carrega.
- [ ] Extrato carrega.
- [ ] Depositar valor valido.
- [ ] Depositar `0`.
- [ ] Depositar valor negativo.
- [ ] Depositar acima do saldo do player.
- [ ] Sacar valor valido.
- [ ] Sacar `0`.
- [ ] Sacar valor negativo.
- [ ] Sacar acima do saldo da org.
- [ ] Confirmar que extrato atualiza apos sucesso.
- [ ] Confirmar que modal fecha no sucesso.
- [ ] Confirmar que modal fica aberto no erro.
- [ ] Repetir em `/org` e `/gang`.

Resultado esperado:

- erros de saldo/valor/permissao sao claros;
- extrato real nao mistura org/gang;
- a NUI envia somente `orgCode`, `amount` e `reason`.

## Metas

- [ ] Listar metas.
- [ ] Criar meta valida.
- [ ] Criar meta com titulo vazio.
- [ ] Criar meta com target invalido.
- [ ] Criar meta com datas invalidas.
- [ ] Confirmar lista full width.
- [ ] Confirmar cards superiores.
- [ ] Repetir em `/org` e `/gang`.

Resultado esperado:

- criar/listar funciona;
- erros sao amigaveis;
- progresso/conclusao real continuam pendentes e nao sao prometidos como automacao ativa.

## Recrutamento

- [ ] Listar candidaturas.
- [ ] Criar candidatura com `citizenid` inexistente.
- [ ] Criar candidatura com `citizenid` valido.
- [ ] Tentar duplicada pendente.
- [ ] Aprovar candidatura.
- [ ] Confirmar que aprovacao vira membro real.
- [ ] Recusar candidatura.
- [ ] Cancelar/arquivar candidatura.
- [ ] Repetir em `/org` e `/gang`.
- [ ] Confirmar top grade protegida na aprovacao.
- [ ] Confirmar loading limpa em sucesso e erro.

Resultado esperado:

- candidaturas persistem por org ativa;
- duplicada pendente e bloqueada;
- status aparecem com label amigavel;
- aprovacao chama fluxo real de membro.

## Logs

- [ ] Logs da org ativa aparecem em `/org`.
- [ ] Logs da gang ativa aparecem em `/gang`.
- [ ] Logs de banco aparecem apos depositar/sacar.
- [ ] Logs de membros aparecem apos convite/promocao/rebaixamento/remocao.
- [ ] Logs de recrutamento aparecem apos criar/aprovar/recusar/arquivar.
- [ ] Logs de staff aparecem apos definir lider.
- [ ] Empty state aparece quando nao houver logs.
- [ ] Labels sao amigaveis.
- [ ] Nao ha payload bruto aberto por padrao.

Resultado esperado:

- logs respeitam permissao server-side;
- citizenids em listas aparecem mascarados quando exibidos;
- sem detalhes tecnicos crus na UI normal.

## Staff

- [ ] `/staff` abre para owner.
- [ ] Dashboard carrega.
- [ ] Aba `Visao geral` carrega.
- [ ] Aba `Organizacoes` lista orgs read-only.
- [ ] Clicar `Ver detalhes` em uma org.
- [ ] Confirmar abas do detalhe: `Resumo`, `Cargos`, `Membros`, `Banco`, `Metas`, `Recrutamento`, `Logs`.
- [ ] Confirmar que o detalhe nao mostra botoes de editar/salvar/excluir.
- [ ] Clicar `Voltar para organizacoes`.
- [ ] Com owner ou `staff.orgs.create`, abrir modal `Criar organizacao`.
- [ ] Criar gang com `type=gang`, `code=mafia_norte`, `name=Mafia Norte`.
- [ ] Confirmar que a nova org aparece na lista apos sucesso.
- [ ] Tentar criar org com codigo duplicado.
- [ ] Testar sem `staff.orgs.create` e confirmar bloqueio.
- [ ] Aba `Logs` lista logs recentes.
- [ ] Aba `Auditoria` mostra eventos sensiveis recentes ou empty state.
- [ ] Aba `Acoes administrativas` mostra `Definir lider`.
- [ ] Cards bloqueados nao disparam callback.
- [ ] Definir lider com `orgCode` e `citizenid` validos.
- [ ] Definir lider com `orgCode` invalido.
- [ ] Definir lider com `citizenid` invalido/inexistente.
- [ ] Testar sem `staff.orgs.set_leader` e confirmar bloqueio.
- [ ] Abrir `/org` e `/gang` depois de usar `/staff`.

Resultado esperado:

- Staff nao vira painel global completo;
- detalhes de org no Staff sao read-only;
- acoes reais do Staff sao `Criar organizacao` por template e `Definir lider`;
- criacao de org nao permite editor livre de cargos/permissoes nem tipo `staff`;
- `staff.panel.open` nao concede poder operacional;
- `staff.orgs.set_leader` controla o card de lideranca.

## Permissoes e seguranca

- [ ] Player comum nao ve botoes de acoes sem permissao.
- [ ] Server bloqueia acao forcada sem permissao.
- [ ] `account.deposit`/`account.withdraw` controlam banco.
- [ ] `goals.manage` controla criar meta.
- [ ] `recruitment.manage` ou fallback documentado controla recrutamento.
- [ ] `members.set_leader` controla top grade em contexto de org.
- [ ] `staff.orgs.set_leader` controla definir lider no Staff.
- [ ] `staff.panel.open` sozinho nao opera membros/banco/metas/lideranca.
- [ ] NUI nao envia `source` como verdade.

Resultado esperado:

- frontend ajuda na UX, mas server continua sendo a fonte de permissao real.

## Testes negativos

- [ ] Enviar `orgCode` vazio.
- [ ] Enviar `citizenid` vazio.
- [ ] Enviar valor bancario invalido.
- [ ] Forcar acao de membro contra si mesmo.
- [ ] Forcar top grade sem permissao.
- [ ] Forcar recrutamento duplicado.
- [ ] Forcar meta sem titulo.
- [ ] Trocar rapidamente entre `/org`, `/gang` e `/staff`.

Resultado esperado:

- erro amigavel;
- sem loading infinito;
- sem mistura de contexto;
- sem crash no F8.

## Regressões conhecidas a observar

- [ ] `/staff` com apenas `staff.orgs.view`: permissao de consulta server-side existe, mas abertura isolada do painel ainda e decisao pendente.
- [ ] VIP/business/government/event ainda nao tem a mesma navegacao interna completa de `/org` e `/gang`.
- [ ] Metas nao possuem progresso/conclusao real.
- [ ] Nao existe candidatura publica/player-facing.
- [ ] Nao existe gestao staff completa.
- [ ] Nao existe editor de cargos/permissoes.

## Resultado esperado do MVP

- `/painel`, `/org`, `/gang` e `/staff` abrem sem erro.
- Contexto legal/gang/staff fica isolado.
- Banco, membros e recrutamento funcionam com dados reais.
- Metas criam/listam sem prometer progresso real.
- Staff permanece seguro/read-only, exceto definir lider.
- Detalhes tecnicos brutos ficam fora da UI normal.
- F8 sem erro durante o fluxo principal.
