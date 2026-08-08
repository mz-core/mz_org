# Checklist runtime — Lote 5

## Preparação

- [ ] Reiniciar `mz_core`, `mz_menu` e `mz_org` nesta ordem.
- [ ] Usar uma organização ativa com `org.view` e features variadas.
- [ ] Manter o console do cliente e servidor abertos.

## Entrada e navegação

- [ ] `/org` abre direto com uma organização e seletor com várias.
- [ ] `/painel` mantém o mesmo comportamento.
- [ ] Aliases exibem somente organizações do tipo solicitado.
- [ ] Organização arquivada ou vínculo removido é negado.
- [ ] Setas, Enter e Esc funcionam em todas as telas.
- [ ] Tema da organização permanece nos submenus e volta ao global ao fechar.

## Módulos

- [ ] Membros lista no máximo 25 por página e mostra navegação.
- [ ] Cargos mostra níveis e contagens coerentes.
- [ ] Capabilities dos cargos aparecem apenas para `manage.permissions`.
- [ ] Financeiro mostra saldo formatado e extrato, sem ações de depósito/saque.
- [ ] Metas mostra progresso, status e datas legíveis.
- [ ] Recrutamento mostra registros, sem botões de decisão ou convite.
- [ ] Logs contém somente eventos da organização atual.
- [ ] Features desabilitadas não aparecem na raiz e são negadas se o evento for disparado manualmente.

## Concorrência e segurança

- [ ] Abrir um módulo e trocar rapidamente de organização não renderiza a resposta anterior.
- [ ] Abrir dois módulos em sequência descarta a resposta do primeiro se ela chegar atrasada.
- [ ] Arquivar a organização com o menu aberto invalida a próxima leitura.
- [ ] Remover vínculo/capability com o menu aberto invalida a próxima leitura.
- [ ] Somente permissões `staff.*` não liberam módulos organizacionais.
- [ ] Não ocorre erro `Argument at index 1 was null` nas respostas.

## Comandos auxiliares

```text
/org
/painel
/gang
/business
/government
/vip
/event
```

Teste de contrato local:

```powershell
Set-Location mz_org
lua tests/organization_read_contract_harness.lua
```
