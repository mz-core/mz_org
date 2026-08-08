# Contrato de ponto de serviço

Status: implementado localmente e validado estaticamente. Aceite runtime pendente.

## Objetivo

Permitir que um Staff autorizado defina, reposicione ou desative o local no qual um membro entra e sai de serviço. O mesmo componente atende `job`, `gang`, `business`, `government` e `event`. O tipo `vip` não possui duty.

## Autoridades

- `mz_core` continua autoridade do vínculo e de `mz_player_orgs.duty`;
- `mz_org` define as regras da interface, sanitiza o formulário e orquestra o fluxo;
- `mz_menu` apenas apresenta o formulário e os contextos;
- `mz_interact` apenas desenha o ponto e encaminha a intenção do jogador.

Nenhuma coordenada enviada pelo cliente participa da autorização do toggle. O servidor lê a posição real com `GetPlayerPed` e `GetEntityCoords`.

## Persistência

O ponto usa o domínio existente `mz_orgs.config_json`:

```json
{
  "dutyPoint": {
    "enabled": true,
    "coords": { "x": 441.25, "y": -981.8, "z": 30.69 },
    "radius": 2.0,
    "drawDistance": 20.0,
    "label": "Recepção da polícia"
  }
}
```

Desativar o ponto remove `dutyPoint` do config. Não foi criada tabela, coluna, migration, saldo, membership ou permissão organizacional paralela.

## Validação da configuração

- tipo permitido: `job|gang|business|government|event`;
- `enabled`: booleano;
- coordenadas finitas: X/Y entre -10000 e 10000; Z entre -1000 e 3000;
- raio: 1 a 5 metros;
- distância de desenho: 5 a 50 metros e nunca menor que o raio;
- label: texto seguro de 2 a 64 caracteres;
- motivo: texto seguro de 3 a 255 caracteres;
- campos desconhecidos e qualquer campo `staff.*` no payload são recusados;
- revisão da organização, envelope contextual e permissão global são revalidados.

## Contratos adicionados

### Staff

- permissão global: `staff.orgs.duty`;
- evento contextual: `mz_org:server:staffUpdateOrganizationDutyPoint`;
- export core: `UpdateStaffOrganizationDutyPoint(source, payload)`;
- auditoria: `org.duty_point.update`;
- configuração e log são confirmados na mesma transação da revisão da organização.

O cargo padrão `gerente_staff` recebe a permissão. O owner continua autorizado pelo ACE `group.mz_owner`. Cargos Staff já existentes não são sobrescritos pelo seed.

### Jogador

- solicitação visual: `mz_org:server:requestDutyPoints`;
- intenção de toggle: `mz_org:server:setSelfDutyAtPoint(orgCode, desiredDuty)`;
- export core: `SetSelfOrgDutyAtPoint(source, orgCode, duty)`;
- auditoria: `org.duty.start` ou `org.duty.stop`.

O servidor exige organização ativa, tipo compatível, membership ativo e não expirado, ponto válido e proximidade real. A escrita de duty e o log usam uma transação com precondição e asserção fail-closed.

## Compatibilidade

- `SetOrgMemberDuty` foi preservado;
- nenhum callback legado foi removido;
- o estado continua refletido em `GetPlayerOrgContext`;
- consumidores que já verificam `org.duty`, como garagens configuradas dessa forma, recebem o novo estado após o refresh do player;
- VIP permanece um modelo de privilégios, sem liderança e sem ponto de serviço.

## Comportamento no mundo

O cliente registra somente os pontos das organizações ativas do próprio jogador. O texto alterna entre “Entrar em serviço” e “Sair de serviço”. Ao parar `mz_org`, apenas os pontos registrados por ele são removidos.

