import type { AccessModel, Goal, Member, NuiResult, OrgLog, OrgSummary, Recruitment, Session } from "@/lib/types"

const members: Member[] = [
  { citizenid: "MZ10482", name: "Mateus Queiroz", grade: 4, gradeCode: "gerente", gradeName: "Gerente", isLeader: true, isDuty: true, status: "online", joinedAt: "2025-04-18", lastSeen: new Date().toISOString() },
  { citizenid: "MZ20819", name: "João Santos", grade: 3, gradeCode: "supervisor", gradeName: "Supervisor", isDuty: true, status: "online", joinedAt: "2025-07-03", lastSeen: new Date(Date.now() - 4 * 60_000).toISOString() },
  { citizenid: "MZ31872", name: "Luana Ribeiro", grade: 2, gradeCode: "mecanico", gradeName: "Mecânico", isDuty: false, status: "online", joinedAt: "2026-01-11", lastSeen: new Date(Date.now() - 18 * 60_000).toISOString() },
  { citizenid: "MZ40912", name: "Carlos Silva", grade: 1, gradeCode: "aprendiz", gradeName: "Aprendiz", isDuty: false, status: "offline", joinedAt: "2026-08-14", lastSeen: new Date(Date.now() - 86_400_000).toISOString() },
  { citizenid: "MZ55031", name: "Beatriz Almeida", grade: 2, gradeCode: "mecanico", gradeName: "Mecânica", isDuty: false, status: "offline", joinedAt: "2025-11-22", lastSeen: new Date(Date.now() - 172_800_000).toISOString() },
]

const access: AccessModel = {
  orgCode: "customs",
  orgName: "MZ Customs",
  type: "business",
  baseCapabilities: ["org.view"],
  grades: [
    { id: 4, level: 4, code: "gerente", name: "Gerente", salary: 1450, priority: 4, active: true, capabilities: ["org.view", "members.view", "manage.members", "account.manage", "goals.manage", "logs.view"], directCapabilities: ["manage.members", "account.manage", "goals.manage", "logs.view"] },
    { id: 3, level: 3, code: "supervisor", name: "Supervisor", salary: 980, priority: 3, active: true, capabilities: ["org.view", "members.view", "members.invite", "goals.view"], directCapabilities: ["members.invite", "goals.view"] },
    { id: 2, level: 2, code: "mecanico", name: "Mecânico", salary: 640, priority: 2, active: true, capabilities: ["org.view", "members.view"], directCapabilities: ["members.view"] },
    { id: 1, level: 1, code: "aprendiz", name: "Aprendiz", salary: 320, priority: 1, active: true, capabilities: ["org.view"], directCapabilities: [] },
  ],
}

let recruitment: Recruitment[] = [
  { id: 71, orgCode: "customs", status: "pending", type: "application", candidateName: "Mariana Alves", candidateCitizenId: "MZ71230", desiredGradeLevel: 1, desiredGradeCode: "aprendiz", note: "Tenho experiência com preparação e quero entrar na equipe.", createdAt: new Date(Date.now() - 38 * 60_000).toISOString() },
  { id: 72, orgCode: "customs", status: "pending", type: "application", candidateName: "Rafael Costa", candidateCitizenId: "MZ80914", desiredGradeLevel: 1, desiredGradeCode: "aprendiz", note: "Disponível no período noturno.", createdAt: new Date(Date.now() - 8_400_000).toISOString() },
]

let goals: Goal[] = [
  { id: 31, orgCode: "customs", title: "Revisões concluídas", description: "Concluir a fila semanal de revisões.", type: "manual", status: "active", target: 25, progress: 17, progressPercent: 68, endsAt: new Date(Date.now() + 4 * 86_400_000).toISOString(), createdByName: "Mateus Queiroz" },
  { id: 32, orgCode: "customs", title: "Novas contratações", description: "Ampliar a equipe operacional.", type: "manual", status: "active", target: 4, progress: 2, progressPercent: 50, endsAt: new Date(Date.now() + 6 * 86_400_000).toISOString(), createdByName: "Mateus Queiroz" },
]

const logs: OrgLog[] = [
  { id: 1, createdAt: new Date(Date.now() - 6 * 60_000).toISOString(), category: "members", action: "duty", severity: "info", orgCode: "customs", actorName: "João Santos", message: "João Santos entrou em serviço" },
  { id: 2, createdAt: new Date(Date.now() - 10 * 60_000).toISOString(), category: "members", action: "promote", severity: "info", orgCode: "customs", actorName: "Mateus Queiroz", targetName: "Carlos Silva", message: "Carlos Silva foi promovido" },
  { id: 3, createdAt: new Date(Date.now() - 27 * 60_000).toISOString(), category: "recruitment", action: "create", severity: "notice", orgCode: "customs", actorName: "Mariana Alves", message: "Nova candidatura recebida" },
  { id: 4, createdAt: new Date(Date.now() - 43 * 60_000).toISOString(), category: "goals", action: "update", severity: "info", orgCode: "customs", actorName: "Mateus Queiroz", message: "Meta Revisões concluídas atualizada" },
]

const organizations: OrgSummary[] = [
  { code: "customs", name: "MZ Customs", type: "business", status: "active", active: true, memberCount: members.length, hasSalary: true, hasSharedAccount: true, hasStorage: true },
  { code: "police", name: "Polícia Metropolitana", type: "government", status: "active", active: true, memberCount: 31, hasSalary: true, hasSharedAccount: true, hasStorage: true },
]

const profiles = {
  job: { name: "Polícia Metropolitana", label: "Organização", panelTitle: "Painel da Organização", accent: "#2563EB", accent2: "#06B6D4", features: ["overview", "members", "grades", "bank", "goals", "recruitment", "logs"] },
  gang: { name: "Família Vermelha", label: "Facção", panelTitle: "Painel da Facção", accent: "#DC2626", accent2: "#7C3AED", features: ["overview", "members", "grades", "bank", "goals", "recruitment", "logs"] },
  business: { name: "MZ Customs", label: "Empresa", panelTitle: "Painel da Empresa", accent: "#D97706", accent2: "#FACC15", features: ["overview", "members", "grades", "bank", "goals", "recruitment", "logs"] },
  government: { name: "Prefeitura MZ", label: "Governo", panelTitle: "Painel do Governo", accent: "#0F766E", accent2: "#22C55E", features: ["overview", "members", "grades", "bank", "goals", "logs"] },
  vip: { name: "MZ Diamond", label: "VIP", panelTitle: "Meu VIP", accent: "#7C3AED", accent2: "#D946EF", features: ["overview", "members"] },
  event: { name: "Desafio da Cidade", label: "Evento", panelTitle: "Painel do Evento", accent: "#DB2777", accent2: "#F97316", features: ["overview", "members", "grades", "goals", "recruitment", "logs"] },
} as const

export function getMockSession(): Session {
  const requested = new URLSearchParams(window.location.search).get("type") || "business"
  const type = requested in profiles ? requested as keyof typeof profiles : "business"
  const profile = profiles[type]
  const code = type === "business" ? "customs" : `preview_${type}`
  return {
  version: 2,
  revision: "preview:1",
  entryAllowed: true,
  defaultContextId: `org:${code}`,
  requestedEntry: { id: "organization", requestedType: type, requestedOrgCode: code },
  user: { source: 1, name: "Mateus Queiroz", citizenid: "MZ10482", isOwner: true, globalPermissions: ["staff.panel.open", "staff.orgs.view", "staff.orgs.manage", "staff.orgs.create", "staff.orgs.set_leader", "staff.logs.view"] },
  organizations: [{
    id: `org:${code}`, code, name: profile.name, type, status: "active", entryAllowed: true, readOnly: false,
    grade: { id: 4, level: 4, code: "gerente", name: "Gerente" },
    membership: { citizenId: "MZ10482", grade: { id: 4, level: 4, code: "gerente", name: "Gerente" }, isPrimary: true, isDuty: true, joinedAt: "2025-04-18" },
    capabilities: ["org.view", "members.view", "members.invite", "members.promote", "members.demote", "members.remove", "manage.members", "account.view", "account.deposit", "account.withdraw", "account.manage", "goals.view", "goals.manage", "recruitment.view", "recruitment.manage", "logs.view"],
    features: [...profile.features], flags: { hasSalary: true, hasSharedAccount: true, hasStorage: true },
    presentation: { key: type, label: profile.label, panelTitle: profile.panelTitle, accent: profile.accent, accent2: profile.accent2, theme: { accent: profile.accent, accent2: profile.accent2 } },
  }],
  staff: null,
  }
}

export const mockSession = getMockSession()

const ok = <T,>(data: T): NuiResult<T> => ({ ok: true, data })

export async function mockNui<T>(event: string, payload: Record<string, unknown>): Promise<NuiResult<T>> {
  await new Promise((resolve) => window.setTimeout(resolve, 80))
  if (event === "session:get") return ok(getMockSession()) as NuiResult<T>
  if (event === "close") return ok({}) as NuiResult<T>
  if (event === "orgs:list") return ok(organizations) as NuiResult<T>
  if (event === "orgs:get") return ok(organizations.find((org) => org.code === payload.orgCode) ?? null) as NuiResult<T>
  if (event === "members:list") return ok(members) as NuiResult<T>
  if (event === "org-access:get") return ok({ ...access, orgCode: String(payload.orgCode || access.orgCode) }) as NuiResult<T>
  if (event === "org-bank:get") return ok({ orgCode: payload.orgCode, balance: 187_420, currency: "R$", canView: true }) as NuiResult<T>
  if (event === "org-bank:transactions") return ok([
    { id: 881, type: "deposit", amount: 12_500, actorName: "Mateus Queiroz", reason: "Serviços da semana", createdAt: new Date(Date.now() - 86_400_000).toISOString() },
    { id: 880, type: "withdraw", amount: 3_280, actorName: "João Santos", reason: "Compra de insumos", createdAt: new Date(Date.now() - 172_800_000).toISOString() },
  ]) as NuiResult<T>
  if (event === "recruitment:list") return ok(recruitment) as NuiResult<T>
  if (event === "goals:list") return ok(goals) as NuiResult<T>
  if (event === "logs:list") return ok(logs) as NuiResult<T>
  if (event === "recruitment:create") {
    recruitment = [{ id: Date.now(), orgCode: String(payload.orgCode), status: "pending", candidateName: String(payload.citizenid), candidateCitizenId: String(payload.citizenid), note: String(payload.note || ""), createdAt: new Date().toISOString() }, ...recruitment]
  }
  if (event === "goals:create") {
    goals = [{ id: Date.now(), orgCode: String(payload.orgCode), title: String(payload.title), description: String(payload.description || ""), target: Number(payload.target) || 1, progress: 0, progressPercent: 0, status: "active" }, ...goals]
  }
  if (event.startsWith("recruitment:") && payload.id) {
    const status = event.endsWith("approve") ? "approved" : event.endsWith("reject") ? "rejected" : "cancelled"
    recruitment = recruitment.map((item) => item.id === payload.id ? { ...item, status } : item)
  }
  return ok({}) as NuiResult<T>
}
