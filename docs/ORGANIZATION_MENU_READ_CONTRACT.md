# Contrato de leitura do menu organizacional

## Escopo

O menu organizacional novo consulta `mz_core` por meio do `mz_org` e permanece somente leitura neste lote. Os módulos disponíveis são `overview`, `members`, `grades`, `bank`, `goals`, `recruitment` e `logs`.

O `mz_menu` recebe somente contextos visuais. Ele não conhece organização, vínculo, cargo ou permissão.

## Envelope contextual

Toda leitura posterior à abertura usa:

```lua
{
  requestId = number,
  orgCode = string,
  _context = {
    requestId = number,
    sessionId = string,
    sessionRevision = string,
    contextKey = 'org:<orgCode>',
    orgCode = string,
    module = 'members|grades|bank|goals|recruitment|logs'
  }
}
```

O servidor exige igualdade entre os identificadores, contexto, organização e módulo. A revisão deve continuar sendo a revisão corrente da sessão.

## Revalidação

Cada leitura revalida, no servidor:

1. arquitetura e menu organizacional habilitados;
2. envelope contextual íntegro;
3. sessão e revisão correntes;
4. organização existente e ativa;
5. vínculo atual do jogador com a organização;
6. `org.view` efetivo para entrada;
7. feature efetiva do módulo, calculada com perfil, override, flags e capabilities oficiais;
8. autorização específica aplicada novamente pelo export seguro de `mz_core`.

Falhas são fechadas: nenhum módulo possui fallback permissivo. Capabilities `staff.*` são descartadas pelo resolvedor e nunca autorizam leitura organizacional.

## Dados expostos

- `members`: identidade operacional, cargo, liderança, serviço e datas públicas ao módulo.
- `grades`: hierarquia e contagem de membros. A lista de capabilities só é enviada com `manage.permissions`.
- `bank`: saldo e extrato paginado; não expõe ou executa depósito/saque.
- `goals`: progresso e datas, sem criação ou atualização.
- `recruitment`: registros e estado, sem aprovar, rejeitar ou convidar.
- `logs`: DTO sanitizado de logs restritos à organização.

Listagens usam páginas de 25 registros e offset limitado a 10000. Respostas que chegam após troca de organização, módulo, geração ou revisão são descartadas pelo request manager do cliente.

## Fora do contrato

Não fazem parte deste lote: mutações de membros, cargos, banco, metas ou recrutamento; settings organizacionais; atribuição de Staff; comandos operacionais de Staff.
