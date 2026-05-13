# MZ_ORG - Frontend NUI

A NUI do `mz_org` usa HTML/CSS/JS puro, no padrão tradicional do FiveM. Não há Node, Vite, React ou build na versão final do resource.

## Arquivos carregados pelo FiveM

```lua
ui_page 'web/index.html'

files {
  'web/index.html',
  'web/style.css',
  'web/script.js',
  'web/panels/**/*.js',
  'web/assets/**/*'
}
```

## Estrutura do frontend

```text
web/
├── index.html
├── style.css
├── script.js
├── assets/
│   └── icons/
└── panels/
    ├── hub/
    ├── legal/
    ├── illegal/
    ├── staff/
    ├── vip/
    ├── business/
    ├── government/
    └── event/
```

`script.js` é o núcleo da NUI: controla sessão, callbacks, renderização, estado visual e comunicação com Lua.

As pastas em `web/panels/` definem os modos de painel. Elas não executam ações sensíveis; apenas registram qual conjunto visual de módulos aparece para cada comando.

## Comandos e modos

- `/painel` e `/mzorg`: abre o hub geral.
- `/org`: abre o painel legal, filtrado para orgs legais/job como polícia, hospital e mecânica.
- `/gang`: abre o painel ilegal, filtrado para orgs do tipo gang.
- `/staff`: abre o painel staff.
- `/vip`: abre o painel VIP.
- `/business`: abre o painel de empresa.
- `/government`: abre o painel de governo/prefeitura.
- `/event`: abre o painel de eventos.

Todos os comandos usam a mesma NUI. O que muda é o `mode` enviado pelo client Lua.

## Segurança

O frontend é apenas visual. Ele nunca decide permissão real.

Qualquer ação futura precisa ser validada no server-side com o `mz_core`, usando exports como:

- `HasGlobalPermission(source, permission)`
- `CanOrg(source, orgCode, capability)`
- `GetPlayerOrgContext(source)`

A NUI não deve enviar `source` confiável. O `source` confiável é sempre o `source` do evento server-side.

## Ícones

Os ícones devem ficar em:

```text
web/assets/icons/
```

O `script.js` usa SVG local. Se um SVG não existir, a NUI mostra fallback por letra.
