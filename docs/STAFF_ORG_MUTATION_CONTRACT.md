# Contrato de mutacoes Staff de organizacoes

## Autoridade

Toda mutacao percorre um endpoint explicito do `mz_org` e um export explicito do `mz_core`. Botao visivel, DTO anterior e permissao organizacional nao autorizam escrita.

As permissoes aceitas sao globais e exatas. Owner e a unica autoridade implicita. `staff.orgs.manage` nao e alias para nenhuma permissao nova.

## Envelope obrigatorio

```lua
{
  requestId = 42,
  organizationRevision = 7, -- ausente somente na criacao
  orgCode = 'mecanica_bennys',
  _context = {
    requestId = 42,
    sessionId = 's2:...',
    sessionRevision = 's2:...',
    contextKey = 'staff:organizations:org:mecanica_bennys',
    module = 'organizations',
    orgCode = 'mecanica_bennys'
  }
}
```

Criacao usa modulo/chave `create` e nao carrega revisao de organizacao.

O servidor compara requestId externo, requestId do payload e requestId contextual. Tambem exige sessao corrente, modulo, chave e orgCode exatos.

## DTOs whitelist

### Criacao

Aceita somente codigo, nome, tipo, estado, public/displayName/description/metadata aprovada, features, aparencia, motivo e contexto.

### Dados basicos

Aceita somente nome, `public.displayName`, `public.description`, `public.metadata.category`, `public.metadata.locale`, motivo e revisao.

### Tipo

Aceita somente targetType, confirmacao de descarte incompativel, motivo e revisao.

### Features

Aceita somente `overrides`, `remove`, motivo e revisao. Nomes fora do catalogo sao rejeitados.

### Aparencia

Aceita somente `overrides`, `remove`, `resetAll`, motivo e revisao.

### Ciclo de vida

Aceita somente motivo, revisao e, no archive, `confirmCode`.

ID, codigo, timestamps, memberships, lideranca, saldo, logs, auditoria, permissoes globais, campos internos e JSON integral nao sao editaveis.

## Concorrencia

Toda organizacao editavel retorna `organizationRevision`. A persistencia usa compare-and-swap no banco:

```sql
UPDATE mz_orgs
SET ..., revision = revision + 1
WHERE code = ? AND revision = ?
```

Ausencia ou divergencia retorna `invalid_revision` ou `conflict`. Nao existe last-write-wins silencioso.

## Idempotencia

Criacao, archive, restore e as demais mutacoes derivam um auditId estavel de operacao, source, sessao e requestId. O indice unico de `mz_logs.audit_id` e a verificacao posterior garantem primeira execucao vencedora.

## Auditoria

Cada registro contem:

- auditId;
- autor, source e citizenid;
- organizacao e acao;
- before e after;
- motivo e timestamp;
- sessao, requestId, contextKey e modulo.

Acoes:

- `org.create`;
- `org.update`;
- `org.type.change`;
- `org.features.update`;
- `org.appearance.update`;
- `org.archive`;
- `org.restore`.

Tentativas recusadas pela guarda de contexto/permissao ou pelo core geram `staff.org.mutation.blocked` sem auditId de sucesso. Esse log nao transforma a tentativa em mutacao concluida.

## Atomicidade e rollback

A mudanca e o INSERT em `mz_logs` fazem parte da mesma transacao. Falha da auditoria faz rollback. O adapter do `mz_org` ainda recusa qualquer resposta de sucesso sem auditId.

## Resposta

```lua
{
  ok = true,
  requestId = 42,
  sessionRevision = 's2:...',
  contextKey = 'staff:organizations:org:mecanica_bennys',
  orgCode = 'mecanica_bennys',
  module = 'organizations',
  data = {
    auditId = 'mzorg:...',
    idempotent = false,
    organization = {
      id = 10,
      code = 'mecanica_bennys',
      name = 'Mecanica Bennys',
      type = 'business',
      status = 'active',
      organizationRevision = 8
    }
  }
}
```

O cliente abre uma nova sessao e rele a inspecao. Respostas duplicadas, antigas ou de outro contexto sao descartadas.
