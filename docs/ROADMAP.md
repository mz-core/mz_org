# MZ_ORG — Roadmap

## Estado atual

Arquitetura `mz_core + mz_org + mz_menu` implementada estaticamente até o **Lote 6D**.

| Entrega | Estado estático | Runtime |
| --- | --- | --- |
| Lote 1 — tema por contexto no `mz_menu` | concluído | pendente |
| Lote 2 — fundação do menu organizacional | concluído | pendente |
| Lote 3 — Staff read-only | concluído | pendente |
| Lote 4 — Staff: organização, lifecycle, features e aparência | concluído | pendente |
| Lote 5 — organização read-only | concluído | pendente |
| Lote 6A — Staff operacional | concluído | pendente |
| Lote 6B — membros, banco, metas e recrutamento no `/org` | concluído | pendente |
| Lote 6C — gestão hierárquica de cargos no `/org` | concluído | pendente |
| Lote 6D — transferência segura de liderança no `/org` | concluído | smoke parcial informado; checklist integral pendente |

Testes estáticos não equivalem a aprovação runtime. `docs/PHASE_0_RUNTIME_RESULTS.md` continua normativo para o estado runtime geral.

Em 2026-07-25, o operador informou sucesso ao abrir `/org` como líder da organização `mafia` e no happy path acompanhado da transferência de liderança. Isso não aprova os cenários negativos, concorrência, rollback, compatibilidade ou os demais lotes.

Na mesma data, o operador aprovou o escopo runtime de VIP: atribuição pelo Staff, abertura do `/vip`, ausência de liderança/autogestão e diagnóstico negativo das capabilities de gestão. O log integral do comando não foi anexado; o aceite geral dos Lotes 1–6D permanece pendente.

## Entregas atuais

- sessão V2 e envelope contextual;
- descarte de respostas antigas/cross-org;
- Staff granular por permissões globais;
- temas e profiles compartilhados;
- organizações múltiplas e aliases por tipo;
- Staff read-only e operacional;
- membros, cargos, banco, metas, recrutamento e logs;
- personalização visual/features em `config_json`;
- transferência organizacional de liderança opt-in, atômica e auditada;
- liderança restrita a `job`, `gang`, `business`, `government` e `event`;
- VIP modelado como níveis de privilégio administrados pelo Staff, sem líder ou autogestão, inclusive diante de capabilities legadas;
- seeds padrão de `ambulance`, `mechanic` e `vip` com leitura mínima do menu;
- frontend legado preservado pelo modo híbrido.

## Próxima ordem recomendada

### 1. Aceite runtime acompanhado

- executar checklists dos Lotes 1–6D em staging descartável;
- manter produção e VPS fora dos ensaios iniciais;
- corrigir somente bugs comprovados;
- não marcar itens não executados como PASS.

### 2. Recursos rápidos

Inventariar primeiro os resources reais responsáveis por:

- storage/armory;
- rádio;
- tablet/MDT;
- duty.

Uma integração só pode ser adicionada com resource proprietário, disponibilidade, capability e evento/export real documentado. Ausência de contrato é bloqueio, não autorização para inventar um.

Estado da garagem em 2026-07-25: contrato persistente implementado no `mz_garagem`, assistente público/organizacional integrado ao `/admin` e smoke runtime informado como aprovado pelo operador. Os demais recursos rápidos continuam pendentes.

### 3. Staff hierárquico

Fundação implementada em domínio próprio:

- owner, ACE e overrides globais;
- nenhuma autoridade por membership do tipo `staff`;
- comandos Staff protegidos por permissões explícitas;
- contrato e auditoria próprios.

Estado em 2026-07-27: fundação local implementada estaticamente no `mz_core`, com catálogo granular baseado nos comandos reais, cargos padrão `suporte`, `moderador`, `administrador` e `gerente_staff`, níveis, atribuições, resolução em `HasGlobalPermission` e interface no `/admin`. Staff Supremo permanece exclusivamente no ACE de owner. O guard `actor > target` com auditoria fail-closed foi aplicado a bring/heal/revive; seu runtime integral permanece pendente.

### 4. Regressão e corte do legado

- regressão de comandos, tipos, múltiplas organizações e consumidores;
- [concluído em 2026-07-25] aplicar perfil seguro com debug, mock e comandos de teste desabilitados;
- mudar `hybrid` para `menu` somente após aceite runtime;
- manter rollback simples.

### 5. Remoção controlada do legado

Somente após período estável e aprovação operacional. Não remover controllers ainda consumidos.

## Backlog fora do Lote 6D

- busca de membros por nome/CitizenID;
- progresso, conclusão e cancelamento de metas;
- cooldown e aceite player-facing de recrutamento;
- reparo Staff explícito para zero/múltiplos líderes;
- hardening transacional das mutações históricas que auditam depois da escrita;
- quick integrations restantes;
- validação runtime da hierarquia Staff;
- ampliar a proteção `actor > target` somente quando novas ações administrativas reais forem implementadas;
- release package.

Hard delete de organização, cargo ou dados reais não faz parte do roadmap atual.

## Avanço posterior — fundação do `/admin`

O inventário de `mz_admin`, `mz_garagem`, `mz_interact`, `mz_vehicles` e duty foi concluído localmente em 2026-07-25 e está documentado em `QUICK_INTEGRATIONS_INVENTORY_2026_07_25.md`.

- o `mz_admin` recebeu autorização fail-closed pelo servidor e shell `/admin` com `mz_menu`;
- os comandos anteriores e o export de estado do noclip foram preservados;
- o atalho de organizações delega a abertura ao Staff Menu existente, que revalida sua própria sessão;
- criação persistente de garagem pública/organizacional foi implementada no resource proprietário `mz_garagem`, sem substituir definições estáticas;
- o operador informou aprovação dos testes runtime acompanhados da garagem; o checklist integral do `/admin` continua pendente;
- integração de self-duty foi implementada localmente em 2026-07-29 com contrato player-facing dedicado, validação de proximidade no servidor, auditoria transacional e projeção via `mz_interact`;
- criação, reposicionamento e desativação do ponto estão disponíveis na inspeção Staff para `job`, `gang`, `business`, `government` e `event`; VIP permanece fora;
- aceite runtime do ponto de serviço segue pendente conforme `RUNTIME_CHECKLIST_SELF_DUTY.md`.

Estado: fundação do `/admin`, diretório de players, garagem persistente, hierarquia Staff e self-duty implementados estaticamente. Hierarquia Staff, self-duty e checklist integral do `/admin` permanecem pendentes de runtime.
