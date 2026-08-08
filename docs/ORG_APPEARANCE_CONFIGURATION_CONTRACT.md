# Contrato de configuracao de aparencia

## Campos permitidos

```text
accent
accent2
brand
headerIcon
badge
position
width
```

`headerIcon` e a chave canonica do Lote 4. O resolver continua lendo `ui.icon` legado para compatibilidade.

## Validacoes

- cores: somente `#RRGGBB`;
- position: `left`, `right` ou `center`;
- width: inteiro de 320 a 640;
- brand: ate 48 caracteres;
- badge: ate 16 caracteres;
- headerIcon: catalogo local no `mz_org` ou identificador sanitizado revalidado no core;
- HTML, JavaScript, CSS, `url(...)`, data URL e HTTP(S) sao rejeitados;
- propriedades desconhecidas sao rejeitadas.

Nao ha upload nem imagem remota.

## Heranca e reset

A resolucao continua:

1. override `config_json.ui`;
2. perfil do tipo;
3. tema global do `mz_menu`.

Restaurar propriedade remove apenas a chave escolhida. Restaurar perfil completo remove overrides do dominio UI, sem copiar defaults para o banco.

## Preview

O preview e calculado no client com o mesmo resolver compartilhado e abre um contexto temporario do `mz_menu`.

- nao chama endpoint ao abrir;
- nao persiste;
- fica vinculado a uma unica organizacao e draft;
- cancelar retorna ao contexto Staff;
- fechar restaura o tema global pelo contrato do `mz_menu`;
- salvar exige confirmacao e resposta server-side;
- depois do commit a inspecao e relida.

O Staff Menu nao adota permanentemente o tema da organizacao. Fora do contexto de preview ele sempre usa o perfil `staff`.

## Payload

```lua
{
  orgCode = 'police',
  organizationRevision = 4,
  overrides = { accent = '#1D4ED8', headerIcon = 'shield' },
  remove = { 'badge' },
  resetAll = false,
  reason = 'Padronizacao visual'
}
```

O cliente nunca envia `config_json` completo.

