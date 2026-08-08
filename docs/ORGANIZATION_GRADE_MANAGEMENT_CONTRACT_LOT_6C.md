# Contrato de gestão organizacional de cargos — Lote 6C

> Nota histórica: este contrato continua proibindo `members.set_leader` no editor de cargos. A transferência legítima usa o contrato dedicado do Lote 6D.

## Escopo

O módulo **Cargos** do `/org` permite que um membro com `manage.permissions` administre somente cargos estritamente inferiores ao seu. Este contrato não concede autorização Staff e não altera os exports administrativos existentes.

## Autorizações obrigatórias

Cada ação exige, em duas camadas:

1. `mz_org`: envelope contextual, sessão e revisão correntes, organização ativa, vínculo atual, feature `grades` e capability `manage.permissions`;
2. `mz_core`: player carregado, membership ativo consultado no banco, cargo do ator ativo, `manage.permissions` resolvida novamente a partir do cargo e hierarquia válida.

Owner, ACE e permissões globais Staff não são fallback do caminho organizacional.

## Exports organizacionais

```lua
exports['mz_core']:CreateOrganizationGrade(source, orgCode, payload)
exports['mz_core']:UpdateOrganizationGradeBasic(source, orgCode, gradeId, payload)
exports['mz_core']:DisableOrganizationGrade(source, orgCode, gradeId, reason)
exports['mz_core']:ReactivateOrganizationGrade(source, orgCode, gradeId, reason)
exports['mz_core']:AddOrganizationGradePermission(source, orgCode, gradeId, capability, reason)
exports['mz_core']:RemoveOrganizationGradePermission(source, orgCode, gradeId, capability, reason)
```

Os exports antigos `CreateOrgGrade`, `UpdateOrgGradeBasic`, `DisableOrgGrade`, `ReactivateOrgGrade`, `AddOrgGradePermission` e `RemoveOrgGradePermission` continuam administrativos e preservam a exigência Staff.

## Regras de hierarquia

- O ator não altera o próprio cargo.
- Cargo de nível igual ou superior ao ator é protegido.
- Cargo criado ou editado deve permanecer abaixo do ator.
- Cargo só pode herdar de outro cargo de nível inferior.
- Alterar nível não pode inverter a relação com cargos dependentes.
- Ciclos de herança continuam recusados.
- O cargo mais alto permanece protegido por consequência da hierarquia estrita.
- Desativação exige cargo vazio; não existe hard delete.

## Regras de capabilities

- Apenas capabilities da allowlist oficial podem ser persistidas.
- `staff.*` é sempre recusada.
- O ator só pode adicionar ou remover uma capability que seu próprio cargo possui efetivamente.
- `members.set_leader` permanece protegida; este lote não implementa transferência de liderança pelo `/org`.
- A remoção atua somente sobre capability direta do cargo selecionado.

## Auditoria e atualização

As ações reutilizam os logs oficiais:

- `org.grade.create`;
- `org.grade.update`;
- `org.grade.disable`;
- `org.grade.reactivate`;
- `org.grade.permission.add`;
- `org.grade.permission.remove`;
- variantes `.blocked` para recusas.

Após sucesso, o cache organizacional dos membros online é recarregado, as sessões do `mz_org` são invalidadas e o menu volta a ser construído com dados atuais.

## Fora do escopo

- transferência de liderança pelo `/org`;
- criação ou gestão de cargos Staff;
- capabilities `staff.*`;
- alteração de cargos iguais ou superiores;
- hard delete;
- recursos rápidos e integrações externas.
