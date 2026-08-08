# Contrato de ciclo de vida de organizacoes

## Criacao

Codigo e identificador estrutural, normalizado para minusculas e restrito a `^[a-z0-9][a-z0-9_-]*$`, com 2 a 48 caracteres. Depois da criacao ele nao e editavel no Lote 4.

Tipos aceitos: job, gang, business, government, vip e event. O tipo `staff` nunca e organizacao operacional criada pelo menu.

A criacao exige resumo e confirmacao explicita. O commit inclui organizacao, grades/capabilities do template e auditoria. Nenhum membership ou lider e criado automaticamente.

## Arquivamento

Archive e soft state (`active = 0`). Exige:

- `staff.orgs.archive` ou owner;
- organizacao ativa;
- revisao corrente;
- motivo;
- digitacao exata do codigo;
- contexto Staff valido.

O commit preserva membros, grades, capabilities, saldo, logs, historico e lideranca. `config.lifecycle` registra ultimo autor, motivo e timestamp; a trilha completa permanece em `mz_logs`.

Depois do commit:

- snapshots dos membros online sao recarregados;
- sessoes Staff e organizacionais afetadas sao invalidadas;
- menus comuns deixam de receber a organizacao;
- endpoints organizacionais existentes continuam fail-closed;
- nenhuma movimentacao financeira ocorre.

## Reativacao

Restore exige `staff.orgs.restore`, revisao, motivo e organizacao arquivada. Antes do commit o core confirma:

- tipo ainda existente e permitido;
- features conhecidas/aplicaveis;
- dependencias atendidas;
- propriedades conhecidas de aparencia validas.

Restore nao altera membros, lideranca, cargos, saldo ou permissoes globais.

## Mudanca de tipo

Tipo e operacao independente de edicao basica. A previa informa defaults que mudam, tema herdado e overrides incompativeis. O servidor recalcula antes de persistir.

Flags financeiras/storage existentes nao sao alteradas por mudanca de tipo neste lote. Features nao aplicaveis ficam indisponiveis e overrides incompativeis exigem descarte confirmado.

## Auditoria

Create, archive e restore retornam auditId. A alteracao de estado e a auditoria compartilham transacao. Sem auditoria nao existe sucesso.

## Hard delete

Nao existe endpoint, export ou opcao de hard delete no Lote 4.

