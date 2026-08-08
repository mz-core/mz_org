# Estabilização de VIP e seeds — 2026-07-25

## Objetivo

Fechar o corte atual dos Lotes 1 a 6D antes de iniciar `mz_admin` ou integrações de garagem.

## Contrato de VIP

`vip` é um agrupamento de níveis de privilégio para benefícios futuros do servidor. Não possui líder, não participa de transferência de liderança e não administra sua própria membership. Atribuição e troca de nível ficam no domínio Staff.

Tipos com liderança:

- `job`;
- `gang`;
- `business`;
- `government`;
- `event`.

Tipos ausentes, desconhecidos, `vip` e `staff` falham fechado.

## Proteções implementadas

- `supportsLeadership` é publicado pelo `mz_core` e revalidado pelo `mz_org`;
- menus organizacional e Staff não exibem liderança para VIP;
- `CanOrg(..., 'members.set_leader')` retorna `false` para VIP;
- em VIP, somente `org.view`, `members.view`, `logs.view` e capabilities `vip.*` podem ser efetivas;
- convite, remoção, promoção, rebaixamento e gestão por membros VIP falham fechado;
- `SetOrgLeaderByCitizenId` e `TransferOrganizationLeadership` recusam VIP;
- novas concessões incompatíveis para VIP são recusadas;
- capability legada incompatível gravada em VIP não aparece como efetiva e não autoriza operação;
- remoção administrativa dessa capability legada continua possível;
- o maior grade VIP não é apresentado como líder.

Nenhum dado persistido foi apagado e nenhuma migration foi criada.

## Seeds

Os seeds padrão de `ambulance`, `mechanic` e `vip` agora incluem a leitura mínima necessária ao menu. O seed idempotente garante as permissões ausentes quando `mz_core` iniciar:

- `org.view`;
- `members.view`;
- demais leituras compatíveis com o perfil padrão de cada tipo.

O template de criação VIP não concede `members.set_leader`.

## Validação estática

Resultado local em 2026-07-25:

- `luac -p`: 61 arquivos (`mz_org`, `mz_menu` e os três Lua alterados do `mz_core`);
- `node --check`: 24 arquivos JavaScript de `mz_core`, `mz_menu` e `mz_org`;
- harnesses `phase0_security`, Lote 4, leitura organizacional e Lotes 6A–6D: PASS;
- consumidor `mz_houses`: 20 arquivos Lua válidos;
- nenhum `.tsx`, `.jsx`, `.ts` ou configuração Vite;
- nenhum whitespace final nos arquivos alterados;
- exports atuais do `mz_menu` preservados; o resource não foi alterado nesta estabilização.

Git não foi usado. Por essa restrição, `git diff --check` foi substituído por varredura direta de whitespace nos arquivos comparados com o backup local.

Comandos principais:

```powershell
lua mz_org/tests/phase0_security_harness.lua
lua mz_org/tests/lot4_contract_harness.lua mz_org
Push-Location mz_org; lua tests/organization_read_contract_harness.lua; Pop-Location
lua mz_org/tests/lot6a_contract_harness.lua mz_org
lua mz_org/tests/lot6b_contract_harness.lua mz_org
lua mz_org/tests/lot6c_contract_harness.lua mz_org
lua mz_org/tests/lot6d_contract_harness.lua mz_org
```

## Estado runtime conhecido

O operador informou em 2026-07-25:

- membership da organização `mafia` reconhecida;
- `/org` aberto corretamente como líder;
- happy path acompanhado da transferência de liderança concluído.
- atribuição de VIP pelo Staff concluída;
- `/vip` aberto corretamente sem liderança ou autogestão.
- diagnóstico `/mzorg_test vip` aprovado pelo operador para os negativos de liderança e gestão de membership; saída integral não anexada.

O escopo VIP desta estabilização foi aprovado pelo operador. Rollback, concorrência, compatibilidade e a matriz integral dos Lotes 1 a 6D continuam pendentes de execução acompanhada.

Após o smoke, o perfil seguro foi aplicado: `Config.Debug`, `Config.AllowDevMockSession`, `Config.DebugCommands` e os comandos de teste do `mz_menu` iniciam desabilitados. `Config.Interface.organizationLeadershipTransfer = false` permanece fail-closed e só deve ser habilitado temporariamente em ambiente de teste para executar a matriz do Lote 6D.

## Próxima ordem

1. executar a matriz runtime em ambiente descartável;
2. corrigir apenas falhas comprovadas;
3. inventariar contratos reais de `mz_admin`, garagem, `mz_interact` e duty;
4. desenhar o shell `/admin` com permissões Staff explícitas;
5. integrar garagem somente após definir autoridade, persistência, exports/eventos reais e ownership dos dados.

Não iniciar produção, VPS, migration destrutiva, exclusão de dados ou corte do frontend legado durante essa validação.
