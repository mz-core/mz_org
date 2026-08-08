# Worklog — Lote 6D

## Etapa 1 — reconhecimento e baseline

Data local: 2026-07-24.

Estado confirmado:

- Lotes 1 a 6C implementados estaticamente.
- `SetOrgLeaderByCitizenId` permanece um contrato administrativo Staff e não atende à transferência organizacional.
- liderança continua derivada do maior cargo ativo; nenhuma tabela ou coluna nova é necessária;
- `members.set_leader` já existe no catálogo e nos templates superiores;
- runtime permanece não aprovado e não será executado nesta sessão.

Validações executadas antes das alterações:

- `luac -p`: 13 arquivos Lua centrais aprovados;
- `node --check`: 24 arquivos JavaScript aprovados;
- `phase0_security_harness.lua`: 10/10;
- `lot4_contract_harness.lua`: 25/25;
- `organization_read_contract_harness.lua`: OK;
- `lot6a_contract_harness.lua`: OK;
- `lot6b_contract_harness.lua`: OK;
- `lot6c_contract_harness.lua`: OK.

Backup verificado:

`D:\git-hub\repo_oficial\_local_backups\mz_org_lot6d_20260724_000344`

Arquivos existentes previstos no backup: 19, todos conferidos por SHA-256.

Próximo passo: implementar o contrato transacional dedicado no `mz_core` e a rota contextual opt-in no `mz_org`.

## Etapa 2 — implementação do contrato e da interface

Arquivos tocados:

- `mz_core/server/orgs/repository.lua`;
- `mz_core/server/orgs/service.lua`;
- `mz_core/server/orgs/exports.lua`;
- `mz_org/shared/config.lua`;
- `mz_org/shared/menu_organization_mutations.lua`;
- `mz_org/server/menu_organization_reads.lua`;
- `mz_org/server/menu_organization_operations.lua`;
- `mz_org/client/menu/organization_members.lua`;
- `mz_org/client/menu/organization.lua`;
- `mz_org/tests/lot6d_contract_harness.lua`.

Contratos implementados:

- export explícito `TransferOrganizationLeadership`;
- evento explícito `mz_org:server:organizationTransferLeadership`;
- gate `Config.Interface.organizationLeadershipTransfer = false`;
- troca atômica entre líder atual e sucessor com incremento de revision;
- auditoria `org.member.transfer_leadership` com `auditId`;
- assertion transacional que força rollback se o estado final não corresponder à troca;
- revalidação direta de membership, expiração, cargo ativo, capability, liderança única e alvo;
- preservação de `SetOrgLeaderByCitizenId` para Staff;
- preservação da organização primária dos dois membros.

Validações da etapa:

- `luac -p`: 9 arquivos Lua de implementação aprovados;
- primeira execução de sintaxe do harness: falhou por aspas escapadas no próprio teste;
- correção localizada aplicada;
- segunda execução: `lot6d_contract_harness: OK`.

Próximo passo: documentar o contrato, preparar checklist runtime e reconciliar roadmap/checklists históricos.

## Etapa 3 — documentação e reconciliação

Documentos criados:

- `docs/ORGANIZATION_LEADERSHIP_TRANSFER_CONTRACT_LOT_6D.md`;
- `docs/MENU_ARCHITECTURE_IMPLEMENTATION_LOT_6D.md`;
- `docs/MENU_ARCHITECTURE_RUNTIME_CHECKLIST_LOT_6D.md`.

Documentos reconciliados:

- plano geral da arquitetura;
- roadmap;
- checklist geral;
- contrato de API;
- permissões do `mz_core`;
- decisões abertas do frontend V2;
- notas históricas dos Lotes 6A, 6B e 6C.

Decisões registradas:

- runtime permanece `NÃO EXECUTADO`;
- `Config.Debug = true` permanece risco de implantação;
- templates atuais já contêm `members.set_leader`, portanto o gate local é necessário;
- primary membership não é alterada pela transferência organizacional;
- auditoria histórica não transacional permanece dívida fora do Lote 6D;
- quick integrations e hierarquia Staff continuam fora do escopo.

Próximo passo: executar regressão estática completa, revisar whitespace/contratos e consolidar o relatório.

## Etapa 4 — validação final

Revisão adicional:

- a assertion transacional foi endurecida para não depender de SQL strict mode;
- auditoria é reservada primeiro;
- precondição inválida tenta reutilizar o mesmo `auditId` e força rollback;
- estado final inválido usa a mesma estratégia;
- nenhuma segunda tentativa corretiva foi necessária nessa revisão.

Resultados:

- `luac -p`: 10/10 arquivos Lua alterados/criados;
- `phase0_security_harness.lua`: 10/10;
- `lot4_contract_harness.lua`: 25/25;
- `organization_read_contract_harness.lua`: OK;
- `lot6a_contract_harness.lua`: OK;
- `lot6b_contract_harness.lua`: OK;
- `lot6c_contract_harness.lua`: OK;
- `lot6d_contract_harness.lua`: OK;
- `node --check`: 24/24 JavaScript;
- `mz_houses`: 20/20 arquivos Lua em `luac -p`;
- exports `mz_menu`: 21 encontrados, sendo 14 client e 7 server; nenhum arquivo do resource foi alterado;
- React/Vite/TypeScript/JSX/TSX: zero arquivos;
- whitespace final nos 25 arquivos tocados: zero;
- fallback Staff/ACE na rota de transferência: ausente;
- fallback global no service do core: ausente;
- export Staff `SetOrgLeaderByCitizenId`: preservado;
- backup: 20 arquivos existentes, todos presentes e verificáveis;
- arquivos novos: 5.

Runtime:

`NÃO EXECUTADO — execução autônoma sem ambiente runtime autorizado.`

Nenhum FXServer, MySQL, Docker, VPS, banco local ou staging foi iniciado ou acessado.

## Adendo de estabilização — 2026-07-25

Estado posterior ao registro histórico acima:

- o operador informou sucesso no `/org` da organização `mafia` e no happy path acompanhado da transferência;
- o escopo VIP foi aprovado: atribuição pelo Staff, `/vip` sem liderança/autogestão e capabilities administrativas negadas;
- liderança foi restringida a `job`, `gang`, `business`, `government` e `event`;
- seeds mínimos de leitura de `ambulance`, `mechanic` e `vip` foram corrigidos;
- `Config.Debug`, mock de desenvolvimento e comandos de teste iniciam desabilitados;
- `mzcore_identity_debug` exige debug ativo e ACE `mzcore.debug` ou owner;
- o frontend legado e o modo `hybrid` permanecem intencionalmente disponíveis;
- rollback, concorrência e a matriz runtime integral continuam pendentes.

O texto anterior permanece como histórico da execução estática original e não deve ser interpretado como o estado runtime mais recente.
