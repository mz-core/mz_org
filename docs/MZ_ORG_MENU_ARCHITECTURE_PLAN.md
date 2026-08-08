# MZ ORG — Planejamento completo da arquitetura baseada em `mz_menu`

> Atualização de implementação — 2026-07-25: Lotes 1 a 6D concluídos estaticamente. O Lote 6D adiciona transferência organizacional de liderança opt-in, separada do contrato Staff, com capability `members.set_leader`, revision e auditoria transacional. A estabilização posterior definiu VIP como níveis de privilégio sem líder e corrigiu os seeds mínimos de leitura. Recursos rápidos continuam pendentes. Houve apenas smoke runtime parcial informado pelo operador; nenhum lote está integralmente aprovado sem execução de seu checklist.

> Sucessão de interface — 2026-07-27: a visualização de logs administrativos globais pertence ao `/admin` do `mz_admin`. O `/stafforg` preserva gestão e auditoria por organização; seus callbacks globais antigos continuam disponíveis apenas por compatibilidade.

## 1. Decisão arquitetural

A arquitetura anterior, com Staff e organizações dentro da mesma NUI grande do `mz_org`, será encerrada gradualmente.

A nova arquitetura será:

```text
mz_core
└── Autoridade de dados e regras centrais
    ├── organizações
    ├── tipos
    ├── cargos
    ├── memberships
    ├── capabilities
    ├── permissões globais Staff
    ├── contas organizacionais
    └── logs/auditoria

mz_org
└── Domínio e orquestração das organizações
    ├── validação server-side
    ├── sessões contextuais
    ├── controllers Staff
    ├── controllers organizacionais
    ├── construção dos menus
    ├── temas e perfis por tipo
    └── integrações com outros resources

mz_menu
└── Camada visual reutilizável
    ├── context menu
    ├── submenus
    ├── input dialog
    ├── confirmação
    ├── alertas
    ├── notificações
    └── tema visual por contexto
```

### Resultado pretendido

- **Staff:** administra organizações usando o `mz_menu`.
- **Membro/líder:** administra sua própria organização usando o `mz_menu`.
- **Tipos diferentes:** usam a mesma base de código, mas recebem cores, ícones, nomes e módulos próprios.
- **Servidor:** continua sendo a autoridade final de qualquer operação.
- **Frontend legado:** permanece temporariamente disponível em modo híbrido até a aprovação runtime da nova interface.

---

## 2. Diagnóstico do código atual

### `mz_menu`

O `mz_menu` atual já oferece:

- `OpenContext`;
- `RegisterContext`;
- submenus por `menu`;
- `InputDialog`;
- `AlertDialog`;
- `Confirm`;
- `Notify`;
- abertura client-side e server-side;
- NUI própria em HTML/CSS/JS puro;
- ausência intencional de regras de negócio e permissões.

Isso torna o resource adequado para a nova interface.

### Limitação principal do `mz_menu`

O tema atualmente é global:

```lua
MZMenuConfig.Theme = {
  accent = '#2563eb',
  accent2 = '#06b6d4',
  position = 'left',
  width = 380
}
```

Para atender organizações diferentes, o `mz_menu` precisa aceitar um tema no próprio contexto:

```lua
exports['mz_menu']:OpenContext({
  id = 'mz_org:org:police:root',
  title = 'Polícia Militar',
  subtitle = 'Gestão da organização',
  theme = {
    accent = '#2563eb',
    accent2 = '#06b6d4',
    position = 'left',
    width = 400
  },
  options = {}
})
```

O tema global continuará sendo o fallback.

### `mz_core`

O `mz_core` já possui a base correta:

- tabela `mz_org_types`;
- tabela `mz_orgs` com `config_json`;
- tabela de cargos;
- tabela de permissões por cargo;
- memberships;
- permissões globais;
- contas organizacionais;
- auditoria e logs;
- exports de organizações;
- separação de `staff.*` e capabilities organizacionais;
- bloqueio de organizações arquivadas;
- transações seguras para promoção/rebaixamento.

Não deve ser criado banco, saldo, membership ou sistema de permissões paralelo no `mz_org` ou no `mz_menu`.

### `mz_org`

O `mz_org` já possui controllers para:

- organizações;
- membros;
- cargos;
- permissões de cargos;
- banco;
- metas;
- recrutamento;
- logs;
- sessão V2;
- proteção contra respostas contextuais antigas.

O backend aproveitável será preservado. A NUI monolítica será substituída gradualmente por builders de menus.

---

## 3. Princípio fundamental: perfis, não cópias

Não criar:

```text
job_menu.lua
gang_menu.lua
business_menu.lua
government_menu.lua
vip_menu.lua
event_menu.lua
```

com toda a lógica repetida.

Criar:

```text
menu base reutilizável
+ perfil visual por tipo
+ matriz de features
+ capabilities do jogador
+ override visual da organização
```

### Resolução final de aparência

A aparência deve ser resolvida nesta ordem:

1. override específico da organização em `mz_orgs.config_json.ui`;
2. perfil padrão do tipo da organização;
3. tema global do `mz_menu`.

### Resolução final de módulos

Um módulo aparece somente quando:

```text
feature disponível
E
usuário possui capability de leitura
E
organização está ativa
E
integração necessária está disponível
```

Uma ação aparece habilitada somente quando:

```text
usuário possui capability da ação
E
servidor revalida a capability
E
organização não está arquivada
E
payload é válido
```

---

## 4. Perfis visuais por tipo

Criar `mz_org/shared/menu_profiles.lua`.

### Job

```lua
job = {
  label = 'Organização',
  panelTitle = 'Painel da Organização',
  icon = 'shield',
  accent = '#2563EB',
  accent2 = '#06B6D4',
  defaultFeatures = {
    overview = true,
    members = true,
    grades = true,
    bank = true,
    goals = true,
    recruitment = true,
    logs = true
  }
}
```

### Gang

```lua
gang = {
  label = 'Facção',
  panelTitle = 'Painel da Facção',
  icon = 'skull',
  accent = '#DC2626',
  accent2 = '#7C3AED',
  defaultFeatures = {
    overview = true,
    members = true,
    grades = true,
    bank = true,
    goals = true,
    recruitment = true,
    logs = true
  }
}
```

### Business

```lua
business = {
  label = 'Empresa',
  panelTitle = 'Gestão da Empresa',
  icon = 'briefcase',
  accent = '#D97706',
  accent2 = '#FACC15'
}
```

### Government

```lua
government = {
  label = 'Governo',
  panelTitle = 'Gestão Governamental',
  icon = 'landmark',
  accent = '#0F766E',
  accent2 = '#22C55E'
}
```

### VIP

VIP não possui líder. Seus grades representam níveis de privilégio para benefícios futuros do servidor; `members.set_leader` e capabilities de gestão de membership não são válidas para esse tipo. Membership e nível VIP são administrados pelo Staff.

```lua
vip = {
  label = 'VIP',
  panelTitle = 'Benefícios VIP',
  icon = 'crown',
  accent = '#7C3AED',
  accent2 = '#D946EF'
}
```

### Event

```lua
event = {
  label = 'Evento',
  panelTitle = 'Gestão do Evento',
  icon = 'calendar',
  accent = '#DB2777',
  accent2 = '#F97316'
}
```

### Staff

Staff não é uma organização comum.

```lua
staff = {
  label = 'Administração',
  panelTitle = 'Controle de Organizações',
  icon = 'settings',
  accent = '#334155',
  accent2 = '#0EA5E9'
}
```

O tipo `staff` existente no catálogo do `mz_core` não deve ser usado para conceder autorização global. Autorização Staff continua vindo somente de owner, ACE ou permissões globais legítimas.

---

## 5. Personalização por organização

O `config_json` já existe em `mz_orgs`. Ele será usado sem criar nova tabela.

Estrutura proposta:

```json
{
  "ui": {
    "profile": "job",
    "accent": "#1D4ED8",
    "accent2": "#38BDF8",
    "icon": "shield",
    "title": "Comando da Polícia Militar",
    "subtitle": "Gestão interna",
    "position": "left",
    "width": 400
  },
  "features": {
    "overview": true,
    "members": true,
    "grades": true,
    "bank": true,
    "goals": true,
    "recruitment": false,
    "logs": true
  }
}
```

### Regras

- Não armazenar permissões calculadas no JSON.
- Não armazenar saldo no JSON.
- Não armazenar members no JSON.
- Não aceitar CSS arbitrário.
- Cores devem aceitar somente hexadecimal válido.
- `position` aceita apenas `left`, `right` ou `center`.
- `width` deve ter limite mínimo e máximo.
- Ícones devem vir de catálogo local do `mz_menu`.
- Mudanças visuais devem gerar auditoria.

### Quem pode editar

Primeira versão:

- owner;
- `staff.orgs.manage`.

Versão posterior opcional:

- líder com `org.settings`, limitado a campos visuais autorizados.

---

## 6. Staff usando `mz_menu`

### Comando

```text
/staff
```

Alternativa explícita:

```text
/stafforg
```

O comando abre somente quando o servidor confirmar um contexto Staff global válido.

### Menu raiz

```text
Controle de Organizações
├── Buscar organização
├── Organizações ativas
├── Organizações arquivadas
├── Criar organização
├── Gerenciar lideranças
├── Gerenciar membros
├── Cargos e permissões
├── Aparência e módulos
├── Logs globais
├── Auditoria
└── Diagnóstico legado
```

### 6.1 Buscar organização

Fluxo:

1. Staff informa código ou nome.
2. Servidor busca resultados.
3. Menu mostra paginação.
4. Seleção abre inspeção da organização.

Não carregar todas as organizações em um único menu quando a quantidade for grande.

### 6.2 Organização selecionada

```text
Polícia Militar
├── Resumo
├── Editar dados básicos
├── Alterar aparência
├── Ativar/desativar módulos
├── Membros
├── Cargos
├── Permissões dos cargos
├── Definir liderança
├── Conta organizacional — leitura conforme permissão
├── Logs da organização
├── Arquivar
└── Reativar, quando arquivada
```

### 6.3 Criar organização

Input sugerido:

- tipo;
- código;
- nome;
- pública/privada;
- whitelist;
- salário;
- conta compartilhada;
- storage;
- perfil visual;
- cor principal opcional;
- cor secundária opcional.

Usar os templates já existentes no domínio do `mz_core`.

### 6.4 Staff granular

O menu raiz não deve ser igual para todo Staff.

Exemplos:

- `staff.orgs.view`: visualizar organizações;
- `staff.orgs.create`: criar;
- `staff.orgs.manage`: editar, arquivar e personalizar;
- `staff.orgs.set_leader`: definir liderança;
- `staff.members.invite`: adicionar membro;
- `staff.members.remove`: remover;
- `staff.members.promote`: promover;
- `staff.members.demote`: rebaixar;
- `staff.logs.view`: ver logs globais e organizacionais.

Nenhum botão deve aparecer apenas porque a pessoa conseguiu abrir `/staff`. Cada domínio deve ser montado pelas permissões globais recebidas do servidor.

---

## 7. Menu da organização

### Comandos

```text
/org
/painel
```

Comportamento:

- uma organização: abre diretamente;
- múltiplas organizações: abre seletor;
- nenhuma organização: notifica que não há contexto disponível;
- organização arquivada: não abre para membro comum.

Aliases opcionais:

```text
/gang
/business
/government
/vip
/event
```

Esses aliases somente filtram as organizações do jogador pelo tipo. Eles não abrem painéis independentes.

### Menu raiz organizacional

```text
Nome da Organização
├── Visão geral
├── Membros
├── Hierarquia e cargos
├── Conta organizacional
├── Metas
├── Recrutamento
├── Logs
├── Recursos rápidos
└── Configurações, somente se autorizado
```

### 7.1 Visão geral

Exibir por metadata e opções read-only:

- organização;
- tipo;
- cargo atual;
- status de serviço;
- quantidade de membros;
- conta disponível ou indisponível;
- metas abertas;
- candidaturas pendentes;
- módulos ativos.

### 7.2 Membros

Capabilities:

- `members.view`;
- `members.invite`;
- `members.remove`;
- `members.promote`;
- `members.demote`;
- `members.set_leader`.

Fluxos:

- lista paginada;
- busca por nome/citizenid;
- detalhes do membro;
- promoção;
- rebaixamento;
- remoção;
- mudança de liderança quando permitida.

Promoção e rebaixamento devem continuar exigindo auditoria transacional e retornar `auditId`.

### 7.3 Hierarquia e cargos

Visualização:

- nível;
- código;
- nome;
- salário;
- herança;
- ativo/inativo;
- quantidade de membros.

Ações conforme capabilities:

- criar cargo;
- editar dados básicos;
- desativar;
- reativar;
- adicionar capability;
- remover capability.

`staff.*` nunca pode ser adicionada como capability organizacional.

### 7.4 Conta organizacional

Features dependentes de:

- `has_shared_account`;
- resource financeiro disponível;
- capabilities.

Capabilities:

- `account.view`;
- `account.deposit`;
- `account.withdraw`;
- `account.manage`.

O menu não calcula nem persiste saldo. Ele apenas consome os contratos oficiais.

### 7.5 Metas

Capabilities:

- `goals.view`;
- `goals.manage`.

Fluxos:

- listar metas;
- ver progresso;
- criar meta;
- futuramente encerrar/cancelar, quando houver contrato oficial.

### 7.6 Recrutamento

Capabilities:

- `recruitment.view`;
- `recruitment.manage`;
- aliases de compatibilidade validados no servidor.

Fluxos:

- listar candidaturas/convites;
- criar;
- aprovar;
- rejeitar;
- cancelar.

### 7.7 Logs

Capability:

- `logs.view`.

Os logs devem continuar filtrados estruturalmente por `org_code` exato.

### 7.8 Recursos rápidos

O menu pode expor integrações, sem absorver as regras delas:

- abrir storage;
- abrir armory;
- abrir garagem;
- rádio;
- tablet/MDT;
- iniciar serviço;
- recursos específicos do tipo.

Cada integração deve ter:

- resource responsável;
- verificação de disponibilidade;
- capability própria;
- evento/export documentado;
- fallback quando indisponível.

---

## 8. Matriz de features

Criar `mz_org/shared/menu_features.lua`.

Exemplo conceitual:

```lua
MZOrgMenuFeatures = {
  overview = {
    viewAny = { 'org.view' }
  },
  members = {
    viewAny = { 'members.view', 'members.invite', 'members.remove', 'members.promote', 'members.demote' }
  },
  grades = {
    viewAny = { 'members.view', 'manage.permissions', 'manage.members' }
  },
  bank = {
    requiresFlag = 'hasSharedAccount',
    viewAny = { 'account.view', 'account.deposit', 'account.withdraw', 'account.manage' }
  },
  goals = {
    viewAny = { 'goals.view', 'goals.manage' }
  },
  recruitment = {
    viewAny = { 'recruitment.view', 'recruitment.manage', 'members.invite' }
  },
  logs = {
    viewAny = { 'logs.view' }
  },
  settings = {
    viewAny = { 'org.settings' }
  }
}
```

O servidor resolve a matriz. O cliente recebe apenas módulos autorizados e ainda assim toda ação é revalidada no servidor.

---

## 9. Evolução necessária do `mz_menu`

### 9.1 Tema por contexto

Adicionar suporte no payload:

```lua
{
  theme = {
    accent = '#2563EB',
    accent2 = '#06B6D4',
    position = 'left',
    width = 400
  }
}
```

Alterações:

- `normalizeMenu()` preserva `theme`;
- `RegisterContext()` armazena `theme`;
- `ShowContext()` aplica o tema do contexto;
- submenu herda o tema do pai quando não definir outro;
- fechar menu restaura o tema global;
- servidor pode enviar tema no `OpenContext`;
- validação visual impede valores inválidos.

### 9.2 Marca por contexto

Adicionar campos opcionais:

```lua
brand = 'MZ Organizations'
headerIcon = 'shield'
badge = 'JOB'
```

Esses campos são apenas visuais.

### 9.3 Atualização de contexto

Adicionar export opcional:

```lua
exports['mz_menu']:UpdateContext(id, patch)
```

Objetivo:

- atualizar lista após ação;
- evitar fechar e abrir a NUI constantemente;
- manter submenu e foco.

Pode ficar para a segunda etapa. A primeira versão pode reconstruir e reabrir o menu.

### 9.4 Paginação

Não é necessário colocar um sistema complexo de busca dentro da NUI imediatamente.

Primeira versão:

- busca por `InputDialog`;
- páginas de 20 ou 25 resultados;
- opções “Página anterior” e “Próxima página”.

---

## 10. Contrato entre menu, client e servidor

### Regra

O `mz_menu` nunca chama banco nem decide permissão.

Fluxo:

```text
jogador seleciona opção
→ mz_menu dispara evento client do mz_org
→ client mz_org solicita ação ao server mz_org
→ server revalida source, contexto, status e permissão
→ server usa export oficial do mz_core
→ server retorna DTO seguro
→ client reconstrói o menu
```

### Request manager

Criar um pequeno gerenciador no client do `mz_org`:

```text
requestId
sessionId
sessionRevision
contextKey
orgCode
```

A proteção implementada na Fase 0 deve ser reaproveitada. Respostas antigas ou de outra organização devem ser descartadas.

### Evitar dispatcher perigoso

Não criar um evento genérico como:

```text
execute qualquer action recebida do client
```

Preferir controllers explícitos por domínio:

```text
staff:listOrgs
staff:getOrg
staff:updateOrg
staff:updateAppearance
org:listMembers
org:promoteMember
org:listGoals
org:listLogs
```

---

## 11. Estrutura de arquivos proposta

### `mz_menu`

```text
mz_menu/
├── client/main.lua
├── shared/config.lua
├── web/app.js
├── web/style.css
└── docs/CONTEXT_THEME_CONTRACT.md
```

A primeira versão pode alterar os arquivos atuais sem criar uma arquitetura excessiva.

### `mz_org`

```text
mz_org/
├── client/
│   ├── main.lua
│   └── menu/
│       ├── request.lua
│       ├── router.lua
│       ├── theme.lua
│       ├── common.lua
│       ├── staff.lua
│       ├── organization.lua
│       ├── members.lua
│       ├── grades.lua
│       ├── bank.lua
│       ├── goals.lua
│       ├── recruitment.lua
│       └── logs.lua
├── server/
│   ├── menu_session.lua
│   ├── menu_staff.lua
│   ├── menu_organization.lua
│   ├── menu_appearance.lua
│   └── arquivos de domínio existentes
├── shared/
│   ├── menu_profiles.lua
│   ├── menu_features.lua
│   ├── capabilities.lua
│   └── config.lua
└── docs/
```

Não mover toda a lógica existente de uma vez. Criar adapters e reaproveitar os services/controllers atuais.

### `mz_core`

Alterações mínimas e específicas:

- export seguro para atualizar somente aparência/features permitidas;
- sanitização e merge de `config_json`;
- auditoria da alteração;
- nenhuma regra visual dentro do core além de persistência segura dos campos permitidos.

Contrato sugerido:

```lua
exports['mz_core']:UpdateOrgInterfaceConfig(source, orgCode, payload)
```

Campos aceitos devem ser whitelistados.

---

## 12. Configuração de migração

Adicionar ao `mz_org/shared/config.lua`:

```lua
Config.Interface = {
  mode = 'hybrid', -- legacy | hybrid | menu
  staffMenu = true,
  organizationMenu = true,
  legacyPanel = true,
  legacyCommands = true
}
```

### Modos

#### `legacy`

- comportamento atual;
- usado para rollback imediato.

#### `hybrid`

- Staff abre pelo `mz_menu`;
- organização abre pelo `mz_menu` quando habilitada;
- NUI antiga ainda disponível por comando de desenvolvimento;
- callbacks antigos preservados.

#### `menu`

- somente menus novos;
- frontend legado não abre;
- arquivos legados ainda podem permanecer por uma versão de segurança.

---

## 13. Plano de implementação por fases

## Fase 0 — Congelamento e proteção

Objetivo: impedir novas alterações grandes no frontend antigo.

Tarefas:

- manter correções de segurança já implementadas;
- não remover a sessão V2;
- não remover envelope contextual;
- criar feature flags de interface;
- documentar comandos atuais;
- garantir rollback para `legacy`.

Critério de aceite:

- nenhuma regressão no modo atual;
- mudança de modo sem alteração de banco.

## Fase 1 — `mz_menu` com tema por contexto

Tarefas:

- aceitar `theme` no menu;
- herdar tema em submenus;
- aceitar brand/icon/badge opcionais;
- preservar API antiga;
- criar teste visual para cada perfil.

Critério de aceite:

- resources atuais que usam `mz_menu` continuam funcionando;
- seis menus de teste abrem com aparências diferentes;
- tema não vaza para o próximo contexto.

## Fase 2 — Fundação dos menus do `mz_org`

Tarefas:

- adicionar dependency `mz_menu`;
- criar request manager contextual;
- criar resolver de perfil;
- criar resolver de features;
- criar seletor de organizações;
- implementar `/org` e `/painel` no modo híbrido.

Critério de aceite:

- jogador com uma org abre diretamente;
- jogador com múltiplas escolhe;
- jogador sem org não abre;
- organização arquivada não abre;
- cor muda conforme o tipo.

## Fase 3 — Staff read-only

Tarefas:

- `/staff` com autorização global;
- listar/buscar organizações;
- visualizar detalhes;
- visualizar cargos;
- visualizar membros;
- visualizar logs conforme permissão;
- visualizar configuração visual.

Critério de aceite:

- jogador comum não abre;
- líder sem Staff não abre;
- Staff parcial vê somente domínios autorizados;
- nenhuma mutação disponível.

## Fase 4 — Staff operacional

Tarefas:

- criar organização;
- editar dados básicos;
- alterar aparência;
- alterar features;
- criar/editar/desativar cargos;
- gerenciar capabilities de cargos;
- definir liderança;
- convidar/remover/promover/rebaixar;
- arquivar/reativar;
- auditoria obrigatória.

Critério de aceite:

- cada ação revalidada no servidor;
- ações retornam resultado consistente;
- promoção/rebaixamento retornam `auditId`;
- alteração visual gera log;
- `staff.*` não pode entrar em cargo organizacional.

## Fase 5 — Organização read-only

Tarefas:

- visão geral;
- lista de membros;
- lista de cargos;
- saldo e transações quando autorizado;
- metas;
- recrutamento;
- logs;
- módulos filtrados por feature/capability.

Critério de aceite:

- cada tipo abre com identidade própria;
- usuário vê somente dados da própria organização;
- resposta da organização A não aparece na B;
- campos sensíveis não são enviados sem autorização.

## Fase 6 — Organização operacional

Tarefas:

- convite;
- remoção;
- promoção;
- rebaixamento;
- conta: depósito/saque;
- criação de metas;
- recrutamento;
- gestão de cargos conforme capability;
- recursos rápidos e integrações.

Estado do corte atual:

- Lotes 6A, 6B, 6C e 6D implementaram Staff operacional, operações organizacionais, gestão de cargos e transferência segura de liderança;
- transferência pelo `/org` exige gate opt-in e `members.set_leader`;
- transferência Staff permanece em contrato administrativo separado;
- liderança existe somente para `job`, `gang`, `business`, `government` e `event`; VIP usa níveis sem líder e sem autogestão de membership;
- recursos rápidos e integrações externas permanecem pendentes de inventário de contratos reais.

Critério de aceite:

- todas as mutações passam pelo servidor;
- hierarquia impede manipular cargo igual ou superior;
- líder não recebe permissão Staff;
- organização arquivada é fail-closed.

## Fase 7 — Personalização por organização

Tarefas:

- editor Staff de cor principal/secundária;
- ícone;
- título/subtítulo;
- ativação de módulos;
- reset para padrão do tipo;
- preview antes de salvar;
- persistência em `config_json`.

Critério de aceite:

- valor inválido é rejeitado;
- reset restaura perfil padrão;
- mudança não altera permissions ou dados de domínio;
- auditoria registrada.

## Fase 8 — Regressão e desligamento do legado

Tarefas:

- testar todos os comandos;
- testar Staff granular;
- testar todos os tipos;
- testar organizações múltiplas;
- testar performance;
- testar recursos consumidores;
- mudar `mode = 'menu'`;
- manter rollback simples.

Critério de aceite:

- nenhuma operação necessária depende da NUI antiga;
- não há shell Staff no frontend legado acessível;
- logs e auditoria permanecem íntegros;
- uso diário aprovado.

## Fase 9 — Remoção controlada do frontend legado

Somente depois de uma versão estável em produção.

Tarefas:

- backup do resource;
- inventário dos callbacks ainda usados;
- remover HTML/CSS/JS antigos;
- remover callbacks NUI sem consumidores;
- remover comandos legados redundantes;
- atualizar documentação.

Não remover automaticamente os controllers server-side que continuam sendo usados pelos menus.

---

## 14. Testes obrigatórios

### `mz_menu`

1. tema global continua funcionando;
2. tema por contexto funciona;
3. submenu herda tema;
4. submenu pode sobrescrever tema;
5. fechar restaura tema global;
6. cor inválida é ignorada/rejeitada;
7. largura fora do limite é normalizada;
8. API antiga continua funcionando.

### Staff

9. jogador comum não abre `/staff`;
10. líder não abre `/staff`;
11. Staff view-only não recebe ações de escrita;
12. `staff.logs.view` não concede gestão de organização;
13. `staff.orgs.set_leader` não concede outras ações;
14. owner recebe acesso completo;
15. organização arquivada aparece somente onde permitido;
16. alterações geram auditoria.

### Organização

17. uma organização abre diretamente;
18. múltiplas organizações exibem seletor;
19. filtro por tipo funciona;
20. organização arquivada é bloqueada;
21. membros exigem capability;
22. promoção respeita hierarquia;
23. rebaixamento respeita hierarquia;
24. banco exige feature e capability;
25. logs usam `org_code` exato;
26. resposta antiga é descartada;
27. troca rápida A→B não mistura dados;
28. tema corresponde ao tipo;
29. override específico é aplicado;
30. reset volta ao perfil padrão.

### Compatibilidade

31. `mz_houses` e outros consumidores do `mz_menu` continuam funcionando;
32. exports antigos do `mz_menu` permanecem;
33. exports do `mz_core` não são removidos sem adaptação;
34. callbacks do painel legado funcionam no modo `legacy`;
35. mudança `hybrid → legacy` funciona sem migration.

---

## 15. Segurança

Regras inegociáveis:

- `mz_menu` é visual, nunca autoridade.
- Botão escondido não é controle de acesso.
- Toda ação server-side revalida source e permission.
- `staff.*` é exclusivamente global.
- `CanOrg` rejeita `staff.*`.
- Organização arquivada não aceita mutação.
- Staff parcial não recebe wildcard.
- Logs organizacionais usam filtro estrutural exato.
- Respostas carregam contexto e revisão.
- Promoção/rebaixamento e auditoria permanecem atômicos.
- Configuração visual usa whitelist.
- Eventos não aceitam nome arbitrário de export/comando enviado pelo client.
- Rate limits devem permanecer em ações sensíveis.

---

## 16. O que será reaproveitado

- tabelas atuais do `mz_core`;
- `config_json` de organizações;
- sistema de tipos;
- cargos e herança;
- permissions/capabilities;
- memberships;
- contas organizacionais;
- metas;
- recrutamento;
- logs seguros;
- auditoria;
- sessão contextual;
- proteção de respostas antigas;
- exports visuais do `mz_menu`;
- backend atual do `mz_org`.

O trabalho de segurança da Fase 0 não será descartado.

---

## 17. O que não será feito

- React/Vite/TypeScript;
- um frontend completo diferente para cada organização;
- duplicação de regras de negócio no client;
- permissões dentro do `mz_menu`;
- banco próprio do `mz_org` para dados já pertencentes ao core;
- saldo paralelo;
- `staff.*` dentro de cargos organizacionais;
- remoção imediata do frontend antigo;
- migration destrutiva sem rollback.

---

## 18. Critério final de conclusão

A nova arquitetura estará concluída quando:

- Staff administrar tudo que precisa pelo `mz_menu`;
- cada organização abrir um menu com identidade visual correta;
- tipos compartilharem componentes sem duplicação de domínio;
- overrides por organização funcionarem;
- features e capabilities controlarem módulos e ações;
- organizações múltiplas funcionarem;
- organização arquivada estiver bloqueada;
- logs permanecerem isolados;
- auditoria permanecer obrigatória;
- nenhum jogador comum visualizar ferramentas Staff;
- modo `menu` funcionar sem dependência da NUI antiga;
- rollback para `legacy` tiver sido testado antes da remoção final.

---

## 19. Ordem recomendada para começar

Começar somente por estas duas entregas:

1. **Fase 1 — tema por contexto no `mz_menu`**;
2. **Fase 2 — fundação e menu organizacional read-only mínimo**.

Não implementar todas as ações de uma vez. O primeiro corte funcional deve permitir:

```text
/org
→ selecionar organização
→ aplicar cor conforme o tipo
→ mostrar visão geral
→ mostrar módulos permitidos
→ abrir membros em modo leitura
```

Depois disso, implementar Staff read-only e seguir a ordem do plano.
