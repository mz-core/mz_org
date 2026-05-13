# MZ_ORG - Checklist

## Base

- [x] Resource separado `mz_org` dependente do `mz_core`.
- [x] NUI HTML/CSS/JS puro.
- [x] Sem Node/Vite/React na versão final.
- [x] `_v0_reference` removida da entrega atual.
- [x] `fxmanifest.lua` apontando para `web/index.html`.

## Comandos e modos

- [x] `/mzorg` abre hub geral.
- [x] `/painel` abre hub geral.
- [x] `/org` abre painel legal.
- [x] `/gang` abre painel ilegal.
- [x] `/staff` abre painel staff.
- [x] `/vip` abre painel VIP.
- [x] `/business` abre painel empresa.
- [x] `/government` abre painel governo.
- [x] `/event` abre painel eventos.

## Integração com `mz_core`

- [x] Sessão real com `GetPlayerOrgContext`.
- [x] Permissão global com `HasGlobalPermission`.
- [x] Validação por org com `CanOrg`.
- [x] Membros read-only com `ListOrgMembers`.
- [x] Logs read-only com `ListLogs`.
- [x] Banco read-only com `GetOrgAccount`.

## Frontend read-only

- [x] Painel hub.
- [x] Painel legal.
- [x] Painel ilegal/gang.
- [x] Painel staff.
- [x] Placeholders VIP/business/government/event.
- [x] Orgs read-only.
- [x] Membros read-only.
- [x] Logs read-only.
- [x] Banco read-only.

## Pendente

- [ ] Cofre/baú read-only.
- [ ] Garagem read-only.
- [ ] Recrutamento real.
- [ ] Metas reais.
- [ ] Ações de membros.
- [ ] Ações financeiras.
- [ ] Edição de grades/capabilities.
- [ ] Auditoria completa das ações futuras.
- [ ] Rate limit para ações futuras.
