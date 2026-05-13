# MZ_ORG - Contrato com MZ_CORE

O `mz_org` é interface NUI. O `mz_core` é a fonte real de dados, permissões, organizações, membros, contas e logs.

## Regras

- O frontend nunca decide permissão real.
- O `source` confiável é sempre o `source` server-side.
- O frontend não envia `isOwner`, `source`, `permissions` ou `capabilities` como verdade.
- Ações futuras sempre devem chamar validação no server antes de executar.

## Exports usados do `mz_core`

- `HasGlobalPermission(source, permission)`
- `GetPlayerOrgContext(source)`
- `CanOrg(source, orgCode, capability)`
- `ListOrgs()`
- `GetOrgByCode(orgCode)`
- `ListOrgMembers(source, orgCode)`
- `ListLogs(source, filters)`
- `GetOrgAccount(source, orgCode)`

## Sessão esperada

```lua
{
  user = {
    source = 1,
    name = "Player",
    isOwner = true,
    globalPermissions = { "group.mz_owner" }
  },
  orgs = {
    {
      code = "police",
      name = "Polícia",
      type = "legal",
      grade = 3,
      gradeCode = "sargento",
      gradeName = "Sargento",
      capabilities = { "org.view" }
    }
  },
  modules = {
    "dashboard",
    "legal",
    "staff",
    "logs"
  }
}
```

## Callbacks NUI atuais

Todos retornam:

```lua
{ ok = true, data = ... }
{ ok = false, error = "mensagem" }
```

- `session:get`
- `orgs:list`
- `orgs:get`
- `members:list`
- `logs:list`
- `org-bank:get`
- `org-bank:transactions`

## Comandos

- `/painel` / `/mzorg`: hub.
- `/org`: painel legal.
- `/gang`: painel ilegal.
- `/staff`: painel staff.
- `/vip`: painel VIP.
- `/business`: painel empresa.
- `/government`: painel governo.
- `/event`: painel eventos.

Comandos apenas definem o modo visual. Eles não concedem permissão.

## Ações futuras

Antes de qualquer mutação, validar:

- `source` real.
- org existente.
- membership, exceto owner autorizado.
- capability com `CanOrg`.
- payload sanitizado.
- rate limit.
- logs/auditoria.
