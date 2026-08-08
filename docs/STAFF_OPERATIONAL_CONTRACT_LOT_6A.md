# Contrato operacional Staff — Lote 6A

## Escopo

O Staff Menu novo administra liderança, membros, cargos e capabilities organizacionais por eventos explícitos. O `mz_menu` continua exclusivamente visual.

## Permissões globais

| Ação | Permissão |
| --- | --- |
| Definir liderança | `staff.orgs.set_leader` |
| Adicionar membro | `staff.members.invite` |
| Remover membro | `staff.members.remove` |
| Promover | `staff.members.promote` |
| Rebaixar | `staff.members.demote` |
| Criar/editar/ativar/desativar cargos | `staff.orgs.manage` |
| Adicionar/remover capabilities de cargos | `staff.orgs.manage` |

Para inspecionar e operar uma organização existente, o Staff também precisa de `staff.orgs.view`. Uma permissão de escrita não concede leitura implicitamente.

Owner possui as ações, mas continua passando pelas validações estruturais de payload, organização, alvo e cargo.

## Validação em duas camadas

O `mz_org` exige:

- request e envelope contextual íntegros;
- módulo `organizations`;
- chave `staff:organizations:org:<code>`;
- sessão/revisão Staff corrente;
- permissão global exata;
- organização existente, ativa e na revisão apresentada;
- payload em whitelist.

O `mz_core` revalida:

- permissão global oficial;
- organização e alvo;
- membership atual;
- cargo ativo e pertencente à organização;
- limites de hierarquia;
- proteção do cargo mais alto;
- herança sem ciclos;
- capability presente no catálogo oficial.

## Membros e liderança

- Convite é feito por CitizenID e cargo ativo.
- Remoção própria é negada.
- Promoção/rebaixamento não ultrapassam a hierarquia permitida.
- Promoção e rebaixamento exigem retorno de `auditId` transacional.
- Definir liderança usa o cargo mais alto oficial e torna a organização primária.

## Cargos

- Código é imutável após criação.
- Nível e código não podem colidir.
- Cargo com membros não pode ser desativado.
- O cargo mais alto não pode ser desativado.
- Alteração que afete a liderança exige `staff.orgs.set_leader`.
- Herança própria ou cíclica é negada.

## Capabilities

Somente valores presentes em `MZOrgCapabilities` podem ser gravados. Qualquer valor `staff.*` é negado no `mz_org` e novamente no `mz_core`.

O menu diferencia capabilities efetivas das diretas. A remoção atua somente sobre uma capability direta do cargo selecionado.

## Concorrência

O DTO carrega `organizationRevision`; divergência fecha a mutação. Após sucesso, a sessão é invalidada e a inspeção é reaberta.

Operações simultâneas com o mesmo `source + sessionRevision + requestId` são recusadas enquanto a primeira estiver em execução.

## Fora do escopo

- cargos e atribuição de Staff;
- comandos operacionais gerais de Staff;
- mutações executadas por líderes no menu organizacional;
- banco, metas e recrutamento operacionais;
- hard delete.
