# Checklist runtime — ponto de serviço

Status inicial: não executado. Harness e `luac -p` não aprovam runtime FiveM.

Use staging descartável. Não execute primeiro em produção e não altere dados reais sem backup.

## Preparação

- [ ] `mz_core`, `mz_menu`, `mz_interact`, `oxmysql` e `mz_org` iniciam nessa ordem sem erro;
- [ ] a organização de teste está ativa e é de tipo suportado;
- [ ] existe um Staff com `staff.orgs.view` e `staff.orgs.duty`;
- [ ] existe um membro ativo da organização;
- [ ] console e tabela `mz_logs` podem ser observados.

## Configuração pelo Staff

1. Abra `/stafforg`, entre em uma organização e selecione `Ponto de serviço`.
2. Use F6 se precisar liberar o movimento, posicione-se e selecione `Criar ponto no local atual`.
3. Informe label, raio, distância de desenho e motivo.

- [ ] o formulário abre e o Enter confirma;
- [ ] o ponto aparece sem reiniciar o resource;
- [ ] reabrir a inspeção mostra label e coordenadas persistidas;
- [ ] reposicionar move o ponto anterior, sem duplicá-lo;
- [ ] desativar remove o ponto;
- [ ] uma organização VIP não oferece a opção;
- [ ] Staff sem `staff.orgs.duty` vê somente leitura e não consegue forçar o evento;
- [ ] revisão antiga é recusada como conflito;
- [ ] cada alteração possui `audit_id` e ação `org.duty_point.update`.

## Uso pelo membro

1. Entre com um membro ativo.
2. Aproxime-se do ponto e pressione E.

- [ ] o texto inicial mostra `Entrar em serviço`;
- [ ] ao pressionar E, `duty` muda para verdadeiro;
- [ ] o texto muda para `Sair de serviço`;
- [ ] ao pressionar novamente, `duty` volta para falso;
- [ ] `GetPlayerOrgContext` reflete o estado;
- [ ] são criados logs `org.duty.start` e `org.duty.stop`;
- [ ] o estado sobrevive a refresh/reconexão conforme persistido no banco.

## Negativos obrigatórios

- [ ] fora do raio, uma chamada manual ao evento é recusada;
- [ ] source sem membership ativo é recusado;
- [ ] membership expirado é recusado;
- [ ] organização arquivada é recusada;
- [ ] VIP é recusado mesmo com config legado injetado;
- [ ] ponto ausente ou inválido falha fechado;
- [ ] `mz_core` indisponível não gera fallback permissivo;
- [ ] falha de auditoria reverte a mudança de duty;
- [ ] spam de toggle respeita o cooldown;
- [ ] coordenadas inventadas no cliente não alteram a decisão do servidor.

## Regressão

- [ ] `/org` continua abrindo;
- [ ] `/stafforg` e as demais mutações continuam operacionais;
- [ ] `SetOrgMemberDuty` continua exportado;
- [ ] pontos de garagem e de outros resources no `mz_interact` não são removidos;
- [ ] parar/reiniciar `mz_interact` reprojeta o ponto;
- [ ] parar `mz_org` remove somente `mz_org:duty:*`;
- [ ] nenhum erro aparece ao trocar personagem ou desconectar.

## Validação estática local

```powershell
lua mz_org/tests/self_duty_contract_harness.lua mz_org
lua mz_core/tests/staff_default_roles_harness.lua
Get-ChildItem mz_org,mz_core -Recurse -Filter *.lua | ForEach-Object { luac -p $_.FullName }
```

Só marque esta checklist como aprovada depois de executar cada cenário no runtime e registrar o resultado real.

