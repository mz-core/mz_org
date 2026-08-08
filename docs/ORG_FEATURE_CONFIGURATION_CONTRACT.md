# Contrato de configuracao de features

## Catalogo fechado

Features aceitas:

- `overview`;
- `members`;
- `grades`;
- `bank`;
- `goals`;
- `recruitment`;
- `logs`;
- `settings`.

O catalogo, labels, descricoes, aplicabilidade e dependencias ficam em `shared/menu_features.lua`. O cliente nao pode introduzir nomes.

## Aplicabilidade

| Feature | Tipos |
| --- | --- |
| overview, members, logs, settings | todos |
| grades | job, gang, business, government, event |
| bank | job, gang, business, government |
| goals, recruitment | job, gang, business, government, event |

`bank = true` exige `hasSharedAccount = true`.

## Estados apresentados

- herdado;
- habilitado por override;
- desabilitado por override;
- indisponivel por dependencia;
- nao aplicavel ao tipo.

Cada linha informa nome, descricao, default do perfil, override, efetivo, dependencia, disponibilidade e origem.

## Persistencia

Somente overrides necessarios ficam em `config_json.features`. Restaurar uma feature remove a chave. Nao se copia o perfil inteiro.

Payload:

```lua
{
  orgCode = 'police',
  organizationRevision = 5,
  overrides = { recruitment = false },
  remove = { 'bank' },
  reason = 'Ajuste de modulos'
}
```

O `mz_org` valida catalogo, tipo e dependencia. O `mz_core` repete whitelist, aplicabilidade e dependencia oficial antes do merge.

## Mudanca de tipo

A previa calcula features habilitadas/desabilitadas e overrides incompativeis. Nenhum override incompativel e removido sem confirmacao `dropIncompatible = true`.

## Restricoes

- nenhuma capability e armazenada como feature;
- `staff.*` e rejeitado;
- organizacao arquivada nao aceita update;
- indisponibilidade de integracao nao e contornada pelo cliente;
- feature nao concede permissao de dominio.

