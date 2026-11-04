# Inventário de integrações rápidas — 2026-07-25

## Resultado

O próximo lote seguro é a fundação protegida do `mz_admin` e o shell `/admin`. A criação de garagens permanece bloqueada por ausência de autoridade persistente e contrato de escrita no resource proprietário.

## Contratos encontrados

### `mz_admin`

Antes deste lote, comandos locais e eventos sobre players não revalidavam permissão. `bringPlayer` aceitava coordenadas do cliente. O resource agora usa permissões globais `staff.*` via `mz_core`, preserva os comandos e disponibiliza um shell em `mz_menu`.

### `mz_garagem`

- definições públicas, organizacionais e de serviço vivem em `shared/garages.lua`;
- frota de serviço vive em `shared/service_fleet.lua`;
- `OpenHouseGarage` cria apenas uma sessão efêmera de garagem de casa;
- não existe export/evento/repositório para criar, editar ou remover persistentemente garagem pública/organizacional;
- acesso organizacional suporta membership, duty, grade, primary e capabilities configuradas;
- catálogo de veículos é consultado no `mz_vehicles`;
- estado/propriedade de veículos pertence ao `mz_vehicles` desde `POST_VEHICLES_GARAGE_EXTRACTION`.

Conclusão: não persistir garagem em `mz_orgs.config_json` e não criar tabela ad hoc neste lote.

### `mz_interact`

Exports client reais:

- `AddPoint`;
- `RemovePoint`;
- `ClearPoints`;
- `GetPoint`;
- `SetPointActive`;
- `RefreshBlips`.

É uma camada visual/client de pontos. Não pode ser autoridade. Qualquer ação sensível disparada por um ponto precisa ser revalidada no servidor proprietário.

### Duty

O inventário inicial encontrou somente `SetOrgMemberDuty`, um contrato administrativo. Em 2026-07-29 foi adicionado `SetSelfOrgDutyAtPoint`, dedicado ao próprio jogador, com membership ativo, tipo, configuração e proximidade revalidados pelo servidor. A escrita de `mz_player_orgs.duty` e o log são transacionais. `mz_interact` continua somente como projeção visual.

### Veículos

`mz_vehicles` fornece catálogo, registro persistente, ownership, propriedades/condição, lifecycle, impound e associação runtime. `mz_garagem` orquestra retirada, armazenamento e políticas de garagem por contratos do owner.

## Ordem recomendada

1. validar runtime do hardening e shell do `mz_admin`;
2. projetar hierarquia Staff e atribuições globais em domínio próprio;
3. definir autoridade, schema não destrutivo e lifecycle para definições persistentes de garagem;
4. implementar serviço/export servidor de garagem com validação e auditoria;
5. consumir esse contrato no `/admin`;
6. registrar/remover pontos no `mz_interact` somente como projeção client;
7. [concluído estaticamente em 2026-07-29] criar contrato de self-duty separado, sem reutilizar mutação administrativa diretamente;
8. executar `RUNTIME_CHECKLIST_SELF_DUTY.md` antes de considerar a integração aprovada.

## Restrições

- não usar membership do tipo `staff` como autoridade;
- não confiar em evento ou coordenada client;
- não inventar fallback quando resource proprietário estiver indisponível;
- não criar garagem dinâmica somente em memória;
- não alterar produção, VPS ou dados reais;
- não marcar runtime como aprovado sem execução.
