# Checklist runtime — Lote 6B

## Preparação

- [ ] Fazer backup do banco.
- [ ] Reiniciar `mz_core`, `mz_menu` e `mz_org`.
- [ ] Preparar líder e membro comum em organizações de teste.
- [ ] Preparar cargos com capabilities diferentes.

## Visibilidade

- [ ] Membro com somente `org.view` vê todas as telas permitidas sem ações.
- [ ] Cada botão aparece somente com a capability correspondente.
- [ ] Permissões `staff.*` não mostram nem autorizam ações no `/org`.
- [ ] Organização arquivada não abre nem aceita evento manual.

## Membros

- [ ] Convidar CitizenID existente para cargo inferior.
- [ ] Negar convite para cargo igual/superior.
- [ ] Negar convite repetido e ação própria.
- [ ] Promover e confirmar `auditId`.
- [ ] Rebaixar e confirmar `auditId`.
- [ ] Negar manipulação de cargo igual ou superior.
- [ ] Remover membro inferior e atualizar jogador online.

## Financeiro

- [ ] Depositar e conferir banco pessoal, saldo organizacional, extrato e ledger.
- [ ] Sacar e conferir os mesmos quatro registros.
- [ ] Negar saldo insuficiente, valor negativo, decimal e acima do limite.
- [ ] Confirmar que `account.deposit` não concede saque.
- [ ] Confirmar que `account.withdraw` não concede depósito.

## Metas

- [ ] Criar meta com dados válidos.
- [ ] Confirmar organização, autor, motivo e datas.
- [ ] Negar HTML, URL, título vazio e objetivo inválido.
- [ ] Confirmar que não existem ações de progresso ou encerramento.

## Recrutamento

- [ ] Criar registro para CitizenID válido e cargo inferior.
- [ ] Aprovar e confirmar membership.
- [ ] Rejeitar registro pendente.
- [ ] Cancelar registro pendente.
- [ ] Negar decisão duplicada.
- [ ] Disparar ID de outra organização e confirmar `context_mismatch`.

## Concorrência

- [ ] Trocar de organização durante uma resposta e confirmar descarte.
- [ ] Alterar a organização em outro cliente e confirmar conflito de revisão.
- [ ] Repetir request concorrente e confirmar ausência de duplicação.
- [ ] Confirmar reabertura do menu com sessão nova após sucesso.

## Harness

```powershell
Set-Location D:\git-hub\repo_oficial\mz_org
lua tests/lot6b_contract_harness.lua .
```
