# Checklist runtime - Lote 4

Status inicial: validacao estatica concluida; execucao FiveM/MySQL pendente.

## Preparacao

- [ ] Fazer backup do banco.
- [ ] Confirmar migration `mz_orgs.revision` e engines InnoDB de `mz_orgs`/`mz_logs`.
- [ ] Iniciar `mz_core`, `mz_menu` e `mz_org` nessa ordem.
- [ ] Manter `/staff` legado e usar `/stafforg` para o lote novo.
- [ ] Criar perfis separados para cada permissao global.

## Autorizacao

- [ ] Jogador comum nao abre nem dispara criacao.
- [ ] Cargo organizacional contendo `staff.*` nao concede acesso.
- [ ] `staff.orgs.view` mostra leitura e nenhuma escrita.
- [ ] `staff.orgs.create` isolada mostra somente criacao, sem listagem.
- [ ] `staff.orgs.edit` nao arquiva, reativa, altera features ou aparencia.
- [ ] `staff.orgs.archive` nao reativa.
- [ ] `staff.orgs.restore` nao arquiva.
- [ ] `staff.orgs.features` altera somente features.
- [ ] `staff.orgs.appearance` altera somente aparencia.
- [ ] `staff.orgs.manage` isolada nao amplia as acoes do menu novo.
- [ ] Owner recebe todas as acoes.

## Criacao

- [ ] Criar organizacao valida de cada tipo.
- [ ] Validar estado inicial ativo e arquivado.
- [ ] Confirmar grades/capabilities do template sem `staff.*`.
- [ ] Codigo duplicado e invalido sao rejeitados.
- [ ] Tipo `staff` e tipo desconhecido sao rejeitados.
- [ ] Payload com campo desconhecido/config_json e rejeitado.
- [ ] HTML, URL e CSS em textos/aparencia sao rejeitados.
- [ ] Nenhuma organizacao aparece antes da resposta de sucesso.
- [ ] Sucesso retorna auditId e revisao 1.

## Edicao e concorrencia

- [ ] Alterar nome/displayName/descricao/metadata aprovada.
- [ ] Confirmar que codigo, ID, timestamps e flags financeiras nao mudam.
- [ ] Abrir o mesmo DTO em dois clients; salvar A e confirmar conflito em B.
- [ ] Reabrir B e confirmar que o novo save funciona.
- [ ] Reenviar o mesmo requestId e confirmar uma unica mutacao/auditoria.
- [ ] Confirmar preservacao de dominio externo em config_json.

## Tipo

- [ ] Previa gang -> business lista impacto e tema.
- [ ] Override incompativel exige confirmacao de descarte.
- [ ] Cancelar previa nao altera banco.
- [ ] Tipo igual e rejeitado.
- [ ] Mudanca confirmada retorna auditId e incrementa revisao.

## Features

- [ ] Ver estados herdado/override/dependencia/nao aplicavel.
- [ ] Habilitar e desabilitar override conhecido.
- [ ] Restaurar feature remove a chave do JSON.
- [ ] Feature desconhecida e `staff.*` sao rejeitados.
- [ ] `bank = true` sem shared account e rejeitado.
- [ ] Feature nao aplicavel ao tipo e rejeitada.

## Aparencia e preview

- [ ] Editar cada campo permitido nos limites.
- [ ] Cor, position, width e icon invalidos sao rejeitados.
- [ ] Preview muda somente o contexto temporario.
- [ ] Cancelar/fechar preview restaura tema Staff/global.
- [ ] Preview de org A nao aparece na B.
- [ ] Restaurar propriedade remove somente aquela chave.
- [ ] Restaurar perfil completo nao grava defaults.
- [ ] Confirmar save, auditId e releitura efetiva.

## Arquivamento

- [ ] Confirmacao Sim/Nao sem codigo nao arquiva.
- [ ] Codigo divergente nao arquiva.
- [ ] Motivo e obrigatorio.
- [ ] Archive retorna auditId e incrementa revisao.
- [ ] Organizacao desaparece de `/org`, `/painel` e aliases.
- [ ] Sessao organizacional ja aberta e fechada/invalida.
- [ ] Membros, cargos, lider, saldo e historico permanecem.
- [ ] Banco/metas/recrutamento/membros recusam nova mutacao.
- [ ] `mz_houses` deixa de listar apos no maximo o TTL documentado de 10s.
- [ ] `mz_garagem` deixa de reconhecer membership ativa apos refresh.

## Reativacao

- [ ] Somente arquivada oferece reativacao.
- [ ] Tipo removido/invalido bloqueia.
- [ ] Feature/aparencia invalida bloqueia.
- [ ] Restore retorna auditId e incrementa revisao.
- [ ] Membership/lideranca/saldo nao mudam.
- [ ] Entrada comum volta somente depois do commit.

## Auditoria e rollback

- [ ] Conferir acoes `org.create`, `org.update`, `org.type.change`, `org.features.update`, `org.appearance.update`, `org.archive`, `org.restore`.
- [ ] Conferir autor/source/citizenid/org/before/after/motivo/sessao/request/contexto.
- [ ] Forcar falha de INSERT em ambiente descartavel e confirmar rollback da linha/revisao.
- [ ] Confirmar que resposta sem auditId e tratada como erro.

## Compatibilidade

- [ ] `/staff` legado continua abrindo legado.
- [ ] `/stafforg`, `/org`, `/painel` e aliases funcionam.
- [ ] Lote 3 continua listando logs/auditoria/diagnostico.
- [ ] Consumer `mz_houses` e exemplo `mz_menu` continuam sem erro.
- [ ] Rollback `hybrid -> legacy` nao exige migration de dados.

