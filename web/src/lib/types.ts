export type PageKey = "overview" | "members" | "access" | "finance" | "recruitment" | "goals" | "logs" | "staff" | "staffLogs"

export type NuiResult<T> = { ok: true; data: T; sessionRevision?: string; contextKey?: string } | { ok: false; error: string; stale?: boolean }

export type Grade = {
  id?: number | null
  level: number
  code: string
  name: string
}

export type OrganizationContext = {
  id: string
  kind?: "organization"
  code: string
  name: string
  type: string
  status?: string
  grade?: Grade
  membership?: { citizenId?: string | null; grade?: Grade; isPrimary?: boolean; isDuty?: boolean; joinedAt?: string | null }
  capabilities: string[]
  features: string[]
  entryAllowed?: boolean
  readOnly?: boolean
  flags?: { hasSalary?: boolean; hasSharedAccount?: boolean; hasStorage?: boolean }
  presentation?: { key?: string; label?: string; panelTitle?: string; title?: string; icon?: string; accent?: string; accent2?: string; theme?: { accent?: string; accent2?: string } }
}

export type StaffContext = {
  id: "staff"
  kind: "staff"
  permissions: string[]
  capabilities?: string[]
  features: string[]
  readOnly?: boolean
}

export type Session = {
  version: number
  revision: string
  entryAllowed: boolean
  denialReason?: string | null
  defaultContextId?: string | null
  requestedEntry?: { id?: string; requestedType?: string | null; requestedOrgCode?: string | null } | string | null
  user: { source?: number; name: string; citizenid?: string | null; citizenId?: string | null; isOwner?: boolean; globalPermissions?: string[] }
  organizations: OrganizationContext[]
  contexts?: OrganizationContext[]
  staff?: StaffContext | null
  staffContext?: StaffContext | null
}

export type OrgSummary = {
  code: string
  name: string
  type: string
  status?: string
  active?: boolean
  locked?: boolean
  protected?: boolean
  memberCount?: number
  hasSalary?: boolean
  hasSharedAccount?: boolean
  hasStorage?: boolean
  is_public?: boolean
  playerRole?: string
  gradeName?: string
}

export type Member = {
  citizenid: string
  name: string
  orgCode?: string
  grade?: number
  gradeCode?: string
  gradeName?: string
  isLeader?: boolean
  isDuty?: boolean
  joinedAt?: string | null
  lastSeen?: string | null
  status?: string
}

export type AccessGrade = {
  id: number
  level: number
  code: string
  name: string
  salary?: number
  priority?: number
  active?: boolean
  inheritsLevel?: number | null
  capabilities?: string[]
  directCapabilities?: string[]
}

export type AccessModel = {
  orgCode: string
  orgName?: string
  type?: string
  baseCapabilities?: string[]
  grades?: AccessGrade[]
}

export type BankAccount = { orgCode: string; balance: number; currency?: string; canView?: boolean }
export type BankTransaction = { id: number | string; type?: string; amount?: number; balanceBefore?: number; balanceAfter?: number; actorName?: string; reason?: string; createdAt?: string }

export type Recruitment = {
  id: number | string
  orgCode?: string
  type?: string
  status?: string
  candidateName?: string
  candidateCitizenId?: string
  targetName?: string
  targetCitizenId?: string
  desiredGradeLevel?: number | null
  desiredGradeCode?: string | null
  note?: string
  decisionNote?: string
  createdAt?: string
}

export type Goal = {
  id: number | string
  orgCode?: string
  title: string
  description?: string
  type?: string
  status?: string
  target?: number
  progress?: number
  progressPercent?: number
  startsAt?: string | null
  endsAt?: string | null
  createdByName?: string
  priority?: string
}

export type OrgLog = {
  id: number | string
  createdAt?: string
  category?: string
  action?: string
  severity?: string
  orgCode?: string | null
  actorName?: string
  targetName?: string
  message?: string
  reason?: string
}

export type ViewData = {
  members: Member[]
  access: AccessModel | null
  account: BankAccount | null
  transactions: BankTransaction[]
  recruitment: Recruitment[]
  goals: Goal[]
  logs: OrgLog[]
  organizations: OrgSummary[]
}

export const emptyViewData = (): ViewData => ({
  members: [], access: null, account: null, transactions: [], recruitment: [], goals: [], logs: [], organizations: [],
})
