# MZ_ORG — Fase 0 de Segurança e Contratos

## Objetivo

Antes de iniciar a interface React/TypeScript/Vite, corrigir os limites de autorização, isolamento de dados, auditoria e contexto assíncrono que sustentam o painel.

Esta fase não redesenha a NUI. Ela estabiliza os contratos que a Frontend V2 consumirá.

## Decisão principal

A ordem obrigatória é:

1. corrigir autorização global e organizacional;
2. corrigir isolamento estrutural dos logs;
3. tornar auditoria de alterações de cargo obrigatória;
4. criar contrato de sessão V2;
5. criar envelope de requisição contextual;
6. validar tudo em runtime;
7. somente depois iniciar React/TypeScript/Vite.

## P0-A — Separação definitiva dos escopos de permissão

### Regra

Permissões `staff.*` são exclusivamente globais. Nunca podem ser concedidas, herdadas ou avaliadas como capability de organização.

Capabilities de organização são exclusivamente contextuais e sempre exigem um `orgCode` explícito.

### Alterações obrigatórias

- Remover de `mz_org/server/session.lua` o fallback de `HasGlobalPermission` para `HasPermission`.
- Aceitar permissão global somente por:
  - owner ACE configurado;
  - ACE global explícito;
  - `mz_core:HasGlobalPermission` com resultado booleano verdadeiro.
- Se `HasGlobalPermission` estiver indisponível, negar por padrão. Não tentar adivinhar por outro export.
- Alterar `canSetLeader()` para aceitar somente owner ou `HasGlobalPermission(..., 'staff.orgs.set_leader')`.
- Remover `CanOrg(..., 'staff.orgs.set_leader')`.
- Impedir criação/edição de cargos com qualquer capability iniciada por `staff.`.
- Impedir que seeds, herança, overrides ou dados legados promovam `staff.*` para o contexto organizacional.
- Registrar aviso de migração quando um dado legado contendo `staff.*` for encontrado, mas não conceder a permissão.

### Compatibilidade legada escolhida

`staff.orgs.set_leader` permanece como permissão global temporariamente para não quebrar ACEs e dados administrativos existentes.

Ela não será renomeada nesta fase. O que será eliminado é seu uso como capability organizacional.

### Proveniência

O contrato V2 deve informar a origem das permissões globais:

```json
{
  "permission": "staff.orgs.view",
  "source": "owner|ace|mz_core_global"
}
```

A frontend poderá usar isso para diagnóstico, mas nunca como autoridade final.

## P0-B — Logs isolados estruturalmente

### Regra

Logs de organização e logs globais são consultas diferentes.

Nenhum filtro por organização pode usar `LIKE`, busca textual em mensagem, JSON serializado ou correspondência parcial de código.

### Contratos recomendados

No `mz_core`, expor contratos separados:

```lua
ListOrgLogsSecure(src, orgCode, filters)
ListGlobalLogsSecure(src, filters)
```

`ListOrgLogsSecure` deve:

- validar `orgCode`;
- autorizar `logs.view` dentro daquela organização ou permissão Staff global apropriada;
- executar igualdade estrutural exata em coluna própria, por exemplo `WHERE org_code = ?`;
- nunca retornar registros sem o mesmo `org_code`;
- limitar paginação e filtros aceitos.

`ListGlobalLogsSecure` deve:

- exigir `staff.logs.view` ou owner;
- não ser reutilizado como fallback de logs organizacionais.

### DTO mínimo

Cada log deve possuir pelo menos:

- `id`;
- `scope`: `org` ou `global`;
- `orgCode`: obrigatório quando `scope=org`;
- `category`;
- `action`;
- `severity`;
- ator;
- alvo;
- `createdAt`;
- `meta` estruturado.

## P0-C — Auditoria obrigatória de promoção e rebaixamento

### Regra

Uma promoção ou um rebaixamento só é considerado concluído quando a alteração e o registro de auditoria forem confirmados.

A responsabilidade pertence ao `mz_core`, que é a autoridade sobre membros, cargos e persistência.

### Contrato esperado

`PromoteOrgMemberSecure` e `DemoteOrgMemberSecure` devem retornar:

```lua
true, {
  orgCode = 'police',
  targetCitizenId = 'ABC123',
  action = 'promote',
  oldGrade = 2,
  newGrade = 3,
  oldGradeCode = 'soldado',
  newGradeCode = 'sargento',
  auditId = 12345
}
```

### Requisitos

- Preferir alteração e auditoria na mesma transação SQL.
- Se a auditoria falhar, a alteração de cargo deve falhar ou sofrer rollback.
- O log deve conter ator, alvo, organização, cargo anterior, cargo novo, ação, data e motivo quando aplicável.
- `mz_org/server/members.lua` deve validar a presença de `auditId` e dos campos de before/after antes de responder sucesso.
- Não criar um segundo saldo, tabela de membros ou fonte paralela no `mz_org`.

## P0-D — Contrato de sessão V2

### Princípios

- contexto Staff e contexto de organização são separados;
- entrada em cada workspace é explicitamente autorizada pelo servidor;
- a sessão não entrega apenas uma lista genérica de módulos;
- cada organização possui capabilities e features próprias;
- Staff parcial vê somente os módulos globais efetivamente concedidos.

### Estrutura recomendada

```json
{
  "version": 2,
  "revision": "opaque-session-revision",
  "user": {
    "source": 1,
    "citizenid": "ABC123",
    "name": "Player",
    "isOwner": false
  },
  "entrypoints": {
    "hub": true,
    "staffWorkspace": false,
    "organizationWorkspaces": ["police", "mechanic"]
  },
  "global": {
    "permissions": [],
    "permissionGrants": [],
    "features": []
  },
  "organizations": [
    {
      "code": "police",
      "name": "Polícia",
      "type": "legal",
      "status": "active",
      "grade": {
        "level": 3,
        "code": "sargento",
        "name": "Sargento"
      },
      "capabilities": ["org.view", "members.view"],
      "features": ["overview", "members", "recruitment"],
      "entryAllowed": true,
      "readOnly": false
    }
  ],
  "staff": {
    "entryAllowed": false,
    "permissions": [],
    "features": []
  }
}
```

### Políticas fechadas

#### Access model

- Organização ativa: entrada exige membership/contexto válido e `org.view`.
- A presença do tipo da organização, sozinha, não autoriza nenhum módulo.
- Capability controla ação; feature controla existência funcional do módulo.
- A interface usa a interseção entre `features` e `capabilities`.

#### Staff parcial

- Não existe “é staff, então vê tudo”.
- `staffWorkspace.entryAllowed` exige ao menos uma feature Staff concedida.
- Cada rota Staff exige sua permissão global específica.
- Ausência de permissão significa rota inexistente no menu e bloqueio no servidor.

#### Organizações arquivadas

- Não aparecem no workspace comum do membro.
- Podem aparecer em listagem Staff para quem possui `staff.orgs.view`.
- São somente leitura para visualizadores.
- Reativação exige `staff.orgs.manage`.
- Não podem executar banco, recrutamento, metas ou mutações enquanto arquivadas.

#### Matriz de features

- Features são calculadas pelo servidor usando tipo/template, configuração e estado da organização.
- A frontend não deduz features apenas pelo tipo `legal`, `gang`, `business` etc.
- Tipos diferentes usam o mesmo workspace; o servidor informa quais módulos existem.

## P0-E — Envelope contextual de requisição

### Problema resolvido

Ao trocar rapidamente de organização, uma resposta antiga pode preencher a tela da organização nova.

### Envelope

Toda requisição V2 deve conter:

```json
{
  "requestId": "frontend-opaque-id",
  "sessionRevision": "revision",
  "context": {
    "kind": "organization",
    "key": "org:police",
    "orgCode": "police"
  },
  "payload": {}
}
```

Toda resposta deve ecoar:

```json
{
  "ok": true,
  "requestId": "frontend-opaque-id",
  "sessionRevision": "revision",
  "contextKey": "org:police",
  "data": {}
}
```

### Regras

- A frontend ignora resposta cuja `sessionRevision` ou `contextKey` não corresponde ao contexto atual.
- No React, usar query keys contendo o contexto, por exemplo `['members', sessionRevision, orgCode]`.
- Requisições substituídas devem ser canceladas com `AbortController` quando possível.
- Mutations devem invalidar apenas queries do mesmo contexto.
- O servidor continua validando o `orgCode`; o envelope não é prova de autorização.

## P0-F — Guarda central de entrada

Criar uma única função de resolução de entrada na sessão/servidor:

```lua
ResolvePanelEntry(src, requestedContext)
```

Resultados possíveis:

- hub autorizado;
- organização específica autorizada;
- Staff autorizado com features parciais;
- negado com código estável.

Comandos `/painel`, `/org`, `/gang`, `/staff` etc. podem continuar existindo por compatibilidade, mas todos devem abrir pelo mesmo fluxo e nunca obrigar uma rota sem autorização.

A NUI deve cair para o Hub ou apresentar acesso negado; nunca abrir Staff por fallback de `dashboard`.

## Critérios de aceite estáticos

- Nenhum `HasPermission` usado para construir permissões globais.
- Nenhum `CanOrg` recebe permissão iniciada por `staff.`.
- Nenhum cargo ou override aceita `staff.*`.
- Logs organizacionais usam igualdade exata em campo estrutural.
- Promoção e rebaixamento exigem `auditId`.
- Sessão V2 separa `global`, `staff` e `organizations`.
- Nenhuma entrada de workspace depende de fallback para `dashboard`.

## Matriz mínima de testes runtime

1. Jogador sem organização abre `/painel`: vê somente Hub permitido; não vê Staff.
2. Jogador comum executa `/staff`: acesso negado ou retorno seguro ao Hub.
3. Membro de organização sem capability de membros: não vê nem acessa membros.
4. Líder de uma organização não recebe nenhuma permissão `staff.*` global.
5. Cargo legado contendo `staff.orgs.set_leader`: permissão ignorada e aviso registrado.
6. Staff apenas com `staff.orgs.view`: lista organizações, mas não edita nem define líder.
7. Staff apenas com `staff.logs.view`: vê logs globais, mas não ganha gestão de organizações.
8. `orgCode=police` não retorna logs de `police2`, `police_old` ou mensagens contendo “police”.
9. Troca rápida `police -> mechanic`: resposta antiga de `police` não aparece em `mechanic`.
10. Promoção bem-sucedida retorna `auditId` e before/after.
11. Falha de auditoria impede a promoção/rebaixamento.
12. Organização arquivada não permite mutações.
13. Owner mantém acesso total, com servidor ainda validando o contexto.
14. Reinício de `mz_org` e `mz_core` não altera permissões nem duplica auditorias.

## Entregáveis esperados ao concluir a Fase 0

- alterações mínimas em `mz_core` e `mz_org`;
- migration somente se realmente necessária para `org_code` estrutural/auditoria;
- `SESSION_V2_CONTRACT_FINAL.md`;
- `PHASE_0_SECURITY_IMPLEMENTATION.md`;
- `PHASE_0_SECURITY_TEST_CHECKLIST.md`;
- relatório de compatibilidade legada;
- evidência dos testes estáticos;
- checklist runtime pendente, sem afirmar aprovação antes do teste no FiveM.

## Fora do escopo desta fase

- construir a interface React;
- redesenhar componentes visuais;
- remover a frontend legada;
- criar novos módulos de negócio;
- alterar economia, banco ou identidade fora dos contratos necessários;
- duplicar regras do `mz_core` no `mz_org`.
