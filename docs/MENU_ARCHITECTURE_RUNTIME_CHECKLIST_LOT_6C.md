# Checklist runtime — Lote 6C

## Preparação

- [ ] Fazer backup do banco.
- [ ] Reiniciar `mz_core`, `mz_menu` e `mz_org`.
- [ ] Criar uma organização de teste com ao menos quatro níveis.
- [ ] Preparar um líder com `manage.permissions`, um gerente inferior e um membro comum.
- [ ] Garantir que nenhum cargo organizacional contenha `staff.*`.

## Visibilidade

- [ ] Membro comum vê cargos somente em leitura.
- [ ] Membro com `manage.permissions` vê **Criar cargo inferior**.
- [ ] Cargo igual ou superior abre sem ações.
- [ ] Cargo inferior abre com ações permitidas.
- [ ] Cargo inativo inferior aparece e oferece reativação.

## Criação e edição

- [ ] Criar cargo abaixo do nível do ator.
- [ ] Negar criação em nível igual ou superior ao ator.
- [ ] Negar código e nível duplicados.
- [ ] Editar nome, salário, prioridade e herança.
- [ ] Negar mover cargo para nível igual ou superior ao ator.
- [ ] Negar herança de nível igual ou superior.
- [ ] Negar alteração que inverta a relação com cargo dependente.
- [ ] Confirmar que código não é editável.

## Ciclo de vida

- [ ] Desativar cargo inferior vazio.
- [ ] Negar desativação de cargo com membros.
- [ ] Negar desativação do cargo próprio, igual, superior ou líder.
- [ ] Reativar cargo inferior.
- [ ] Confirmar ausência de hard delete.

## Capabilities

- [ ] Adicionar ao cargo inferior uma capability que o ator possui.
- [ ] Remover uma capability direta que o ator possui.
- [ ] Negar capability desconhecida.
- [ ] Negar capability que o ator não possui.
- [ ] Negar `staff.*`.
- [ ] Negar adição ou remoção de `members.set_leader`.
- [ ] Confirmar que capability herdada não aparece como remoção direta.

## Contexto e concorrência

- [ ] Disparar evento com `orgCode` divergente e confirmar recusa.
- [ ] Disparar resposta antiga após trocar de organização e confirmar descarte.
- [ ] Alterar revision e confirmar exigência de reabrir o menu.
- [ ] Arquivar organização e confirmar fail-closed.
- [ ] Confirmar atualização das capabilities de membros online após uma mudança.
- [ ] Confirmar logs de sucesso e `.blocked` com organização e ator corretos.

## Harness

```powershell
Set-Location D:\git-hub\repo_oficial\mz_org
lua tests/lot6c_contract_harness.lua .
```
