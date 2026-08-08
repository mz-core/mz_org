# Checklist runtime — Lote 6A

## Preparação

- [ ] Fazer backup do banco.
- [ ] Reiniciar `mz_core`, `mz_menu` e `mz_org` nesta ordem.
- [ ] Usar `/stafforg`; manter o painel legado disponível.
- [ ] Preparar identidades separadas para cada permissão global.
- [ ] Confirmar que todas também possuem `staff.orgs.view`.

## Permissões

- [ ] `staff.orgs.set_leader` mostra somente liderança.
- [ ] `staff.members.invite` mostra somente adicionar membro.
- [ ] `staff.members.remove` mostra somente remoção.
- [ ] `staff.members.promote` mostra somente promoção.
- [ ] `staff.members.demote` mostra somente rebaixamento.
- [ ] `staff.orgs.manage` mostra somente operações de cargos deste lote.
- [ ] Permissão de escrita sem `staff.orgs.view` não abre a inspeção.
- [ ] Jogador comum e líder sem Staff continuam negados.

## Membros

- [ ] Adicionar CitizenID válido em cargo ativo.
- [ ] Negar CitizenID inexistente, repetido e o próprio ator.
- [ ] Promover um nível e confirmar `auditId`.
- [ ] Rebaixar um nível e confirmar `auditId`.
- [ ] Negar promoção máxima e rebaixamento mínimo.
- [ ] Negar ação contra hierarquia protegida.
- [ ] Remover membro e confirmar atualização do jogador online.

## Liderança

- [ ] Definir membro atual como líder.
- [ ] Confirmar cargo mais alto e organização primária.
- [ ] Negar alteração sem `staff.orgs.set_leader`.
- [ ] Confirmar que nenhum `staff.*` foi concedido ao líder.

## Cargos

- [ ] Criar cargo com nível, salário e herança válidos.
- [ ] Negar código ou nível duplicado.
- [ ] Editar nome, nível, salário, prioridade e herança.
- [ ] Negar herança própria e ciclo.
- [ ] Negar desativação do cargo mais alto.
- [ ] Negar desativação de cargo com membros.
- [ ] Desativar e reativar cargo vazio.

## Capabilities

- [ ] Adicionar capability oficial.
- [ ] Remover capability direta.
- [ ] Negar capability inexistente.
- [ ] Negar qualquer `staff.*`, inclusive por evento manual.
- [ ] Confirmar atualização dos snapshots dos membros online.

## Concorrência

- [ ] Abrir o mesmo DTO em dois clientes e alterar a organização em um deles.
- [ ] Confirmar conflito no segundo cliente.
- [ ] Disparar duas vezes o mesmo request enquanto a primeira execução está ativa.
- [ ] Confirmar ausência de mutação duplicada.
- [ ] Confirmar que o menu reabre com uma sessão nova após sucesso.

## Teste estático local

```powershell
Set-Location D:\git-hub\repo_oficial\mz_org
lua tests/lot6a_contract_harness.lua .
```
