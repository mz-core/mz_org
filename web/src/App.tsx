import { useCallback, useEffect, useMemo, useState } from "react"
import type { ComponentProps, ComponentType, CSSProperties, FormEvent, ReactNode } from "react"
import {
  Activity, ArrowDownLeft, ArrowLeft, ArrowUp, ArrowUpRight, Banknote,
  Building2, Check, CheckCircle2, ChevronDown, ChevronRight, CircleDollarSign, ClipboardList, History,
  LayoutDashboard, LogOut, Minus, Plus, RefreshCw, Search, ShieldCheck, Target, UserMinus, UserPlus,
  UsersRound, X,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import { dateTime, hasAny, initials, maskCitizenId, money } from "@/lib/format"
import { isPreview, postNui } from "@/lib/nui"
import { getMockSession } from "@/lib/mock"
import { emptyViewData } from "@/lib/types"
import type { AccessGrade, Goal, Member, OrganizationContext, OrgLog, OrgSummary, PageKey, Recruitment, Session, ViewData } from "@/lib/types"

const copy = {
  nav: { overview: "Visão geral", members: "Membros", access: "Hierarquia", finance: "Financeiro", recruitment: "Recrutamento", goals: "Metas", logs: "Histórico", staff: "Staff" },
  loading: "Carregando dados…",
  retry: "Tentar novamente",
  noAccess: "Seu contexto não possui acesso a esta área.",
}

type OpenPayload = { initialModule?: string; mode?: string; panelMode?: string }
type ModalKind = "invite" | "promote" | "demote" | "remove" | "leader" | "bank" | "recruit-create" | "recruit-approve" | "recruit-reject" | "recruit-cancel" | "goal-create" | "org-create" | "org-edit" | "org-archive" | "org-reactivate" | "grade-create" | "grade-edit" | "grade-disable" | "grade-reactivate" | "permission-add" | "permission-remove"
type ModalState = { kind: ModalKind; item?: Member | Recruitment | OrgSummary | AccessGrade; action?: "deposit" | "withdraw" } | null

const pageMeta: Record<PageKey, { label: string; icon: ComponentType<{ className?: string }>; feature?: string }> = {
  overview: { label: copy.nav.overview, icon: LayoutDashboard, feature: "overview" },
  members: { label: copy.nav.members, icon: UsersRound, feature: "members" },
  access: { label: copy.nav.access, icon: Building2, feature: "grades" },
  finance: { label: copy.nav.finance, icon: CircleDollarSign, feature: "bank" },
  recruitment: { label: copy.nav.recruitment, icon: UserPlus, feature: "recruitment" },
  goals: { label: copy.nav.goals, icon: Target, feature: "goals" },
  logs: { label: copy.nav.logs, icon: History, feature: "logs" },
  staff: { label: copy.nav.staff, icon: ShieldCheck },
  staffLogs: { label: "Auditoria Staff", icon: History },
}

const previewOpen = isPreview()
const previewSession = previewOpen ? getMockSession() : null

export function App() {
  const [open, setOpen] = useState(previewOpen)
  const [session, setSession] = useState<Session | null>(previewSession)
  const [mode, setMode] = useState(previewOpen ? "hub" : "hub")
  const [activeOrgCode, setActiveOrgCode] = useState(previewSession?.organizations[0]?.code ?? "")
  const [staffOrg, setStaffOrg] = useState<OrgSummary | null>(null)
  const [page, setPage] = useState<PageKey>("overview")
  const [data, setData] = useState<ViewData>(emptyViewData)
  const [loading, setLoading] = useState(previewOpen)
  const [sessionLoading, setSessionLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [toast, setToast] = useState("")
  const [modal, setModal] = useState<ModalState>(null)
  const [busy, setBusy] = useState(false)
  const [reloadToken, setReloadToken] = useState(0)

  const organizations = session?.organizations ?? session?.contexts ?? []
  const activeOrg = organizations.find((org) => org.code === activeOrgCode) ?? null
  const staff = session?.staff ?? session?.staffContext ?? null
  const staffPermissions = staff?.permissions ?? staff?.capabilities ?? []
  const activeCode = staffOrg?.code ?? activeOrg?.code ?? ""
  const contextKey = staffOrg || page === "staff" || page === "staffLogs" ? "staff" : activeOrg ? `org:${activeOrg.code}` : "hub"
  const staffMode = contextKey === "staff"
  const surfaceType = staffMode ? "staff" : activeOrg?.type ?? "hub"
  const accent = staffMode ? "#0EA5E9" : activeOrg?.presentation?.theme?.accent || activeOrg?.presentation?.accent
  const accent2 = activeOrg?.presentation?.theme?.accent2 || activeOrg?.presentation?.accent2
  const surfaceStyle = { "--primary": accent || "#0EA5E9", "--ring": accent || "#0EA5E9", "--org-accent-2": accent2 || "#22D3EE" } as CSSProperties

  const flash = useCallback((message: string) => {
    setToast(message)
    window.setTimeout(() => setToast(""), 2600)
  }, [])

  const applySession = useCallback((next: Session, requestedMode = mode) => {
    const contexts = next.organizations ?? next.contexts ?? []
    const requested = typeof next.requestedEntry === "object" ? next.requestedEntry : null
    const wantedType = requested?.requestedType || (requestedMode === "illegal" ? "gang" : ["legal", "business", "government", "vip", "event"].includes(requestedMode) ? requestedMode : null)
    const requestedCode = requested?.requestedOrgCode
    const selected = contexts.find((org) => org.code === requestedCode) ?? contexts.find((org) => !wantedType || org.type === wantedType) ?? contexts[0]
    setSession(next)
    setActiveOrgCode(selected?.code ?? "")
    setStaffOrg(null)
    setPage(requestedMode === "staff" && (next.staff || next.staffContext) ? "staff" : "overview")
    setSessionLoading(false)
    setError(next.entryAllowed === false ? next.denialReason || copy.noAccess : null)
  }, [mode])

  const requestSession = useCallback(async (payload: OpenPayload) => {
    const requestedMode = payload.mode || payload.panelMode || "hub"
    setMode(requestedMode)
    setSessionLoading(true)
    setError(null)
    const requestedEntry = requestedMode === "staff" ? "staff" : requestedMode === "hub" ? "hub" : "organization"
    const requestedType = requestedEntry === "organization" ? (requestedMode === "illegal" ? "gang" : requestedMode) : null
    const result = await postNui<Session>("session:get", { requestedEntry, requestedType, command: requestedMode })
    if (result.ok && result.data) applySession(result.data, requestedMode)
    else if (!result.ok) { setSessionLoading(false); setError(result.error) }
  }, [applySession])

  const close = useCallback(() => {
    setOpen(false)
    setModal(null)
    setData(emptyViewData())
    void postNui("close")
  }, [])

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const message = event.data ?? {}
      if (message.action === "open") {
        setOpen(true)
        void requestSession(message.payload ?? {})
      } else if (message.action === "close") {
        setOpen(false)
        setModal(null)
      } else if (message.action === "session:set" && message.payload) {
        applySession(message.payload, mode)
      }
    }
    const onKey = (event: KeyboardEvent) => {
      if (event.key !== "Escape" || !open) return
      if (modal) {
        event.preventDefault()
        event.stopPropagation()
        setModal(null)
      }
      else close()
    }
    window.addEventListener("message", onMessage)
    window.addEventListener("keydown", onKey, true)
    return () => { window.removeEventListener("message", onMessage); window.removeEventListener("keydown", onKey, true) }
  }, [applySession, close, modal, mode, open, requestSession])

  useEffect(() => {
    if (!open || !session || sessionLoading) return
    let cancelled = false
    const load = async () => {
      setLoading(true)
      setError(null)
      const ask = <T,>(event: string, payload: Record<string, unknown> = {}) => postNui<T>(event, payload, session.revision, contextKey)
      try {
        if (page === "staff" && !staffOrg) {
          const result = await ask<OrgSummary[]>("orgs:list")
          if (!result.ok) throw new Error(result.error)
          if (!cancelled) setData((current) => ({ ...current, organizations: Array.isArray(result.data) ? result.data : [] }))
        } else if (activeCode) {
          if (page === "overview") {
            const [memberResult, goalResult, logResult, recruitmentResult] = await Promise.all([
              ask<Member[]>("members:list", { orgCode: activeCode }),
              ask<Goal[]>("goals:list", { orgCode: activeCode, limit: 20, offset: 0 }),
              ask<OrgLog[]>("logs:list", { orgCode: activeCode, limit: 20, offset: 0 }),
              ask<Recruitment[]>("recruitment:list", { orgCode: activeCode, limit: 20, offset: 0 }),
            ])
            if (!cancelled) setData((current) => ({ ...current, members: memberResult.ok && Array.isArray(memberResult.data) ? memberResult.data : [], goals: goalResult.ok && Array.isArray(goalResult.data) ? goalResult.data : [], logs: logResult.ok && Array.isArray(logResult.data) ? logResult.data : [], recruitment: recruitmentResult.ok && Array.isArray(recruitmentResult.data) ? recruitmentResult.data : [] }))
          }
          if (page === "members") {
            const result = await ask<Member[]>("members:list", { orgCode: activeCode })
            if (!result.ok) throw new Error(result.error)
            if (!cancelled) setData((current) => ({ ...current, members: Array.isArray(result.data) ? result.data : [] }))
          }
          if (page === "access" || (page === "staff" && staffOrg)) {
            const result = await ask<ViewData["access"]>("org-access:get", { orgCode: activeCode })
            if (!result.ok) throw new Error(result.error)
            if (!cancelled) setData((current) => ({ ...current, access: result.data }))
          }
          if (page === "finance") {
            const [account, transactions] = await Promise.all([ask<ViewData["account"]>("org-bank:get", { orgCode: activeCode }), ask<ViewData["transactions"]>("org-bank:transactions", { orgCode: activeCode, filters: { limit: 50, offset: 0 } })])
            if (!account.ok) throw new Error(account.error)
            if (!cancelled) setData((current) => ({ ...current, account: account.data, transactions: transactions.ok && Array.isArray(transactions.data) ? transactions.data : [] }))
          }
          if (page === "recruitment") {
            const result = await ask<Recruitment[]>("recruitment:list", { orgCode: activeCode, limit: 50, offset: 0 })
            if (!result.ok) throw new Error(result.error)
            if (!cancelled) setData((current) => ({ ...current, recruitment: Array.isArray(result.data) ? result.data : [] }))
          }
          if (page === "goals") {
            const result = await ask<Goal[]>("goals:list", { orgCode: activeCode, limit: 50, offset: 0 })
            if (!result.ok) throw new Error(result.error)
            if (!cancelled) setData((current) => ({ ...current, goals: Array.isArray(result.data) ? result.data : [] }))
          }
          if (page === "logs") {
            const result = await ask<OrgLog[]>("logs:list", { orgCode: activeCode, limit: 100, offset: 0 })
            if (!result.ok) throw new Error(result.error)
            if (!cancelled) setData((current) => ({ ...current, logs: Array.isArray(result.data) ? result.data : [] }))
          }
        } else if (page === "staffLogs" && staff) {
          const result = await ask<OrgLog[]>("logs:list", { limit: 100, offset: 0 })
          if (!result.ok) throw new Error(result.error)
          if (!cancelled) setData((current) => ({ ...current, logs: Array.isArray(result.data) ? result.data : [] }))
        }
      } catch (caught) {
        if (!cancelled) setError(caught instanceof Error ? caught.message : "Não foi possível carregar os dados.")
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    void load()
    return () => { cancelled = true }
  }, [activeCode, contextKey, open, page, reloadToken, session, sessionLoading, staff, staffOrg])

  const mutate = useCallback(async (event: string, payload: Record<string, unknown>, success: string) => {
    if (!session) return false
    setBusy(true)
    const result = await postNui(event, payload, session.revision, contextKey)
    setBusy(false)
    if (!result.ok) { flash(result.error); return false }
    setModal(null)
    flash(success)
    setReloadToken((value) => value + 1)
    return true
  }, [contextKey, flash, session])

  const submitModal = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!modal || (!activeCode && modal.kind !== "org-create")) return
    const form = Object.fromEntries(new FormData(event.currentTarget).entries())
    const reason = String(form.reason || "")
    const item = modal.item
    if (modal.kind === "invite") await mutate("members:invite", { orgCode: activeCode, citizenid: form.citizenid, gradeCode: form.gradeCode || undefined }, "Convite enviado.")
    if (["promote", "demote", "remove"].includes(modal.kind)) await mutate(`members:${modal.kind}`, { orgCode: activeCode, citizenid: (item as Member).citizenid }, modal.kind === "remove" ? "Membro removido." : "Cargo atualizado.")
    if (modal.kind === "leader") await mutate("members:setLeader", { orgCode: activeCode, citizenid: form.citizenid || (item as Member | undefined)?.citizenid, reason }, "Liderança atualizada.")
    if (modal.kind === "bank") await mutate(`org-bank:${modal.action}`, { orgCode: activeCode, amount: Number(form.amount), reason }, modal.action === "deposit" ? "Depósito confirmado." : "Saque confirmado.")
    if (modal.kind === "recruit-create") await mutate("recruitment:create", { orgCode: activeCode, citizenid: form.citizenid, desiredGradeCode: form.gradeCode || undefined, note: form.note || "" }, "Candidatura criada.")
    if (modal.kind.startsWith("recruit-") && modal.kind !== "recruit-create") {
      const action = modal.kind.replace("recruit-", "")
      const payload: Record<string, unknown> = { id: (item as Recruitment).id }
      if (action === "approve" && form.gradeCode) payload.gradeCode = form.gradeCode
      if (action === "reject" || action === "cancel") payload.reason = reason
      await mutate(`recruitment:${action}`, payload, "Recrutamento atualizado.")
    }
    if (modal.kind === "goal-create") await mutate("goals:create", { orgCode: activeCode, title: form.title, description: form.description || "", type: "manual", target: Number(form.target), endsAt: form.endsAt || undefined }, "Meta criada.")
    if (modal.kind === "org-create") await mutate("orgs:createFromTemplate", { type: form.type, code: form.code, name: form.name, hasSalary: form.hasSalary === "on", hasSharedAccount: form.hasSharedAccount === "on", hasStorage: form.hasStorage === "on", reason }, "Organização criada.")
    if (modal.kind === "org-edit") await mutate("orgs:updateBasic", { orgCode: activeCode, name: form.name, status: form.status, hasSalary: form.hasSalary === "on", hasSharedAccount: form.hasSharedAccount === "on", hasStorage: form.hasStorage === "on", reason }, "Organização atualizada.")
    if (modal.kind === "org-archive" || modal.kind === "org-reactivate") {
      await mutate(`orgs:${modal.kind === "org-archive" ? "archive" : "reactivate"}`, { orgCode: activeCode, reason }, modal.kind === "org-archive" ? "Organização arquivada." : "Organização reativada.")
      setStaffOrg(null)
    }
    if (modal.kind === "grade-create") await mutate("orgs:createGrade", { orgCode: activeCode, code: form.code, name: form.name, level: Number(form.level), salary: Number(form.salary), priority: Number(form.priority), inheritsLevel: form.inheritsLevel ? Number(form.inheritsLevel) : undefined, reason }, "Cargo criado.")
    if (modal.kind === "grade-edit") await mutate("orgs:updateGradeBasic", { orgCode: activeCode, gradeId: (item as AccessGrade).id, name: form.name, level: Number(form.level), salary: Number(form.salary), priority: Number(form.priority), inheritsLevel: form.inheritsLevel ? Number(form.inheritsLevel) : undefined, reason }, "Cargo atualizado.")
    if (modal.kind === "grade-disable" || modal.kind === "grade-reactivate") await mutate(`orgs:${modal.kind === "grade-disable" ? "disableGrade" : "reactivateGrade"}`, { orgCode: activeCode, gradeId: (item as AccessGrade).id, reason }, "Estado do cargo atualizado.")
    if (modal.kind === "permission-add" || modal.kind === "permission-remove") await mutate(`orgs:${modal.kind === "permission-add" ? "addGradePermission" : "removeGradePermission"}`, { orgCode: activeCode, gradeId: (item as AccessGrade).id, permission: form.permission, reason }, "Permissão atualizada.")
  }

  const availablePages = useMemo(() => {
    if (!activeOrg || staffOrg) return []
    const features = activeOrg.features ?? []
    return (Object.keys(pageMeta) as PageKey[]).filter((key) => key !== "staff" && key !== "staffLogs" && (!pageMeta[key].feature || features.includes(pageMeta[key].feature!)))
  }, [activeOrg, staffOrg])

  if (!open) return null

  return (
    <main className="mz-stage" data-testid="mz-org-root" data-open="true">
      <section className="mz-org-surface" data-org-type={surfaceType} style={surfaceStyle}>
        <Header session={session} activeOrg={activeOrg} staffOrg={staffOrg} organizations={organizations} mode={mode} onSelectOrg={(code) => { setStaffOrg(null); setActiveOrgCode(code); setPage("overview"); setData(emptyViewData()) }} onClose={close} />
        <nav className="shell-nav" aria-label="Seções da organização">
          {staffOrg ? <Button variant="ghost" size="sm" onClick={() => { setStaffOrg(null); setPage("staff") }}><ArrowLeft /> Organizações</Button> : null}
          {availablePages.map((key) => <NavButton key={key} page={key} active={page === key} onClick={() => setPage(key)} />)}
          {staff && !staffOrg ? <NavButton page="staff" active={page === "staff"} onClick={() => setPage("staff")} /> : null}
          {staff && !staffOrg && hasAny(staffPermissions, ["staff.logs.view"]) ? <NavButton page="staffLogs" active={page === "staffLogs"} onClick={() => setPage("staffLogs")} /> : null}
        </nav>

        <div className="shell-body">
          {sessionLoading ? <LoadingState /> : error ? <ErrorState message={error} onRetry={() => setReloadToken((value) => value + 1)} /> : !session ? <EmptyState title="Sessão indisponível" description="Reabra o painel para solicitar um novo contexto." /> : (
            <>
              {!activeOrg && !staffOrg && page !== "staff" && page !== "staffLogs" ? <Hub session={session} onSelect={(code) => { setActiveOrgCode(code); setPage("overview") }} onStaff={() => setPage("staff")} /> : null}
              {(activeOrg || staffOrg) && page === "overview" ? <Overview org={staffOrg ?? activeOrg!} data={data} loading={loading} onPage={setPage} /> : null}
              {(activeOrg || staffOrg) && page === "members" ? <Members orgCode={activeCode} context={activeOrg} items={data.members} loading={loading} onModal={setModal} /> : null}
              {(activeOrg || staffOrg) && page === "access" ? <Access model={data.access} loading={loading} canManage={Boolean(staffOrg && hasAny(staffPermissions, ["staff.orgs.manage"]))} onModal={setModal} /> : null}
              {(activeOrg || staffOrg) && page === "finance" ? <Finance context={activeOrg} data={data} loading={loading} onModal={setModal} /> : null}
              {(activeOrg || staffOrg) && page === "recruitment" ? <RecruitmentPage context={activeOrg} items={data.recruitment} loading={loading} onModal={setModal} /> : null}
              {(activeOrg || staffOrg) && page === "goals" ? <Goals context={activeOrg} items={data.goals} loading={loading} onModal={setModal} /> : null}
              {page === "logs" ? <Logs items={data.logs} loading={loading} /> : null}
              {page === "staffLogs" ? <Logs items={data.logs} loading={loading} /> : null}
              {page === "staff" ? <Staff organizations={data.organizations} selected={staffOrg} access={data.access} loading={loading} permissions={staffPermissions} onSelect={(org) => { setStaffOrg(org); setData((current) => ({ ...current, access: null })) }} onModal={setModal} /> : null}
            </>
          )}
        </div>

      </section>
      <ActionDialog modal={modal} busy={busy} onOpenChange={(value) => !value && setModal(null)} onSubmit={submitModal} activeOrg={staffOrg ?? activeOrg} />
      {toast ? <div className="toast" role="status"><CheckCircle2 /> {toast}</div> : null}
    </main>
  )
}

function NavButton({ page, active, onClick }: { page: PageKey; active: boolean; onClick: () => void }) {
  const meta = pageMeta[page]
  const Icon = meta.icon
  return <button className={active ? "active" : ""} onClick={onClick}><Icon className="size-4" /><span>{meta.label}</span></button>
}

function Header({ session, activeOrg, staffOrg, organizations, mode, onSelectOrg, onClose }: { session: Session | null; activeOrg: OrganizationContext | null; staffOrg: OrgSummary | null; organizations: OrganizationContext[]; mode: string; onSelectOrg: (code: string) => void; onClose: () => void }) {
  const [switcher, setSwitcher] = useState(false)
  const org = staffOrg ?? activeOrg
  const orgDetail = staffOrg
    ? `${staffOrg.memberCount ?? 0} membros`
    : activeOrg?.grade?.name ?? "Organização"
  return (
    <header className="shell-header">
      <div className="brand" aria-label="MZ Organizações"><span className="brand-mark">MZ</span><strong>mz<span>.org</span></strong><i>{activeOrg?.presentation?.label || (staffOrg ? "STAFF" : "ORG")}</i></div>
      <div className="header-divider" />
      {org ? <div className="org-switcher-wrap"><button className="org-switcher" onClick={() => setSwitcher((value) => !value)} aria-expanded={switcher}><span className="avatar emblem">{initials(org.name)}</span><span><strong>{org.name}</strong><small>{org.type} · {orgDetail}</small></span>{organizations.length > 1 && !staffOrg ? <ChevronDown /> : null}</button>{switcher && organizations.length > 1 && !staffOrg ? <div className="org-menu">{organizations.map((item) => <button key={item.code} onClick={() => { onSelectOrg(item.code); setSwitcher(false) }}><span className="avatar">{initials(item.name)}</span><span><strong>{item.name}</strong><small>{item.type}</small></span>{item.code === activeOrg?.code ? <Check /> : null}</button>)}</div> : null}</div> : <div className="org-placeholder"><Building2 /><span><strong>{mode === "staff" ? "Administração Staff" : "Central de organizações"}</strong><small>Selecione um contexto</small></span></div>}
      <div className="header-spacer" />
      <div className="current-user"><span className="semantic-dot online" /><span><small>{session?.user.isOwner ? "Owner" : activeOrg?.grade?.name ?? "Membro"}</small><strong>{session?.user.name ?? "Carregando"}</strong></span><span className="avatar">{initials(session?.user.name ?? "MZ")}</span></div>
      <Button variant="ghost" size="icon-sm" aria-label="Fechar painel" onClick={onClose}><LogOut /></Button>
    </header>
  )
}

function Hub({ session, onSelect, onStaff }: { session: Session; onSelect: (code: string) => void; onStaff: () => void }) {
  const contexts = session.organizations ?? []
  return <div className="hub"><SectionHeading eyebrow="CENTRAL MZ" title="Escolha uma organização" />{contexts.length ? <div className="hub-grid">{contexts.map((org) => <Card key={org.code} className="context-card"><CardContent><span className="avatar emblem">{initials(org.name)}</span><div><strong>{org.name}</strong><small>{org.presentation?.label || org.type} · {org.grade?.name}</small></div><Button variant="ghost" size="icon-sm" onClick={() => onSelect(org.code)} aria-label={`Abrir ${org.name}`}><ChevronRight /></Button></CardContent></Card>)}</div> : <EmptyState title="Sem vínculo ativo" description="Nenhuma organização disponível." />}{session.staff ? <Button variant="outline" onClick={onStaff}><ShieldCheck /> Abrir Staff</Button> : null}</div>
}

function SectionHeading({ eyebrow, title, description, action }: { eyebrow: string; title: string; description?: string; action?: ReactNode }) {
  return <header className="section-heading"><div><small>{eyebrow}</small><h1><span />{title}</h1>{description ? <p>{description}</p> : null}</div>{action}</header>
}

function Overview({ org, data, loading, onPage }: { org: OrganizationContext | OrgSummary; data: ViewData; loading: boolean; onPage: (page: PageKey) => void }) {
  if (loading) return <LoadingState />
  if (org.type === "vip") return <VipOverview org={org as OrganizationContext} data={data} onPage={onPage} />
  if (org.type === "event") return <EventOverview org={org} data={data} onPage={onPage} />
  const duty = data.members.filter((member) => member.isDuty).length
  const online = data.members.filter((member) => member.status === "online").length
  const roleCounts = new Map<string, number>()
  data.members.forEach((member) => roleCounts.set(member.gradeName || member.gradeCode || "Sem cargo", (roleCounts.get(member.gradeName || member.gradeCode || "Sem cargo") || 0) + 1))
  const isGang = org.type === "gang"
  return <><SectionHeading eyebrow={isGang ? "COMANDO DA FACÇÃO" : "OPERAÇÃO"} title="Visão geral" description={org.name} action={<Button variant="outline" onClick={() => onPage("members")}><UsersRound /> {isGang ? "Ver membros" : "Ver equipe"}</Button>} /><section className="operations-board"><div className="operations-column live"><span className="panel-kicker"><Activity /> {isGang ? "Efetivo" : "Agora"}</span><div className="live-number"><strong>{duty}</strong><span>{isGang ? "ativos" : "em serviço"}</span></div><div className="status-lines"><span><i className="semantic-dot online" />Online <b>{online}</b></span><span><i className="semantic-dot offline" />Offline <b>{Math.max(0, data.members.length - online)}</b></span><span><i className="semantic-dot warning" />Candidaturas <b>{data.recruitment.length}</b></span></div><button className="inline-action" onClick={() => onPage("members")}>{isGang ? "Abrir efetivo" : "Abrir equipe"} <ArrowUpRight /></button></div><div className="operations-column"><span className="panel-kicker"><UsersRound /> {isGang ? "Estrutura" : "Hierarquia"}</span><div className="role-stack">{[...roleCounts.entries()].slice(0, 5).map(([role, count]) => <div key={role}><span>{role}</span><i style={{ width: `${Math.max(10, count / Math.max(1, data.members.length) * 100)}%` }} /><b>{count}</b></div>)}</div><button className="inline-action" onClick={() => onPage("access")}>Ver cargos <ArrowUpRight /></button></div><div className="operations-column"><span className="panel-kicker"><History /> {isGang ? "Movimentação" : "Atividade recente"}</span><div className="activity-feed">{data.logs.slice(0, 5).map((item) => <div key={item.id}><time>{dateTime(item.createdAt)}</time><i className="semantic-dot info" /><span><strong>{item.message || item.action || "Atividade"}</strong><small>{item.actorName}</small></span></div>)}{!data.logs.length ? <p className="quiet">Sem atividade recente.</p> : null}</div><button className="inline-action" onClick={() => onPage("logs")}>Histórico <ArrowUpRight /></button></div></section><section className="goal-strip"><div><Target /><span><strong>Metas ativas</strong></span></div>{data.goals.slice(0, 2).map((goal) => <div className="goal-line" key={goal.id}><span>{goal.title}<b>{Math.round(goal.progressPercent ?? 0)}%</b></span><div><i style={{ width: `${Math.min(100, goal.progressPercent ?? 0)}%` }} /></div><small>{goal.endsAt ? `Prazo ${dateTime(goal.endsAt)}` : "Sem prazo"}</small></div>)}<button className="inline-action" onClick={() => onPage("goals")}>Ver todas <ArrowUpRight /></button></section></>
}

function VipOverview({ org, data, onPage }: { org: OrganizationContext; data: ViewData; onPage: (page: PageKey) => void }) {
  const online = data.members.filter((member) => member.status === "online").length
  return <><SectionHeading eyebrow="SEU VÍNCULO VIP" title={org.presentation?.panelTitle || "Meu VIP"} /><section className="vip-overview"><div className="vip-identity"><span>{org.presentation?.label || "VIP"}</span><h2>{org.name}</h2><p>{org.grade?.name || "Membro"}</p><small>Desde {dateTime(org.membership?.joinedAt)}</small></div><div className="vip-stats"><div><span>Membros</span><strong>{data.members.length}</strong></div><div><span>Online</span><strong>{online}</strong></div><Button variant="outline" onClick={() => onPage("members")}><UsersRound /> Ver membros</Button></div></section></>
}

function EventOverview({ org, data, onPage }: { org: OrganizationContext | OrgSummary; data: ViewData; onPage: (page: PageKey) => void }) {
  const goal = data.goals[0]
  const online = data.members.filter((member) => member.status === "online").length
  const progress = Math.min(100, goal?.progressPercent ?? 0)
  return <><SectionHeading eyebrow="EVENTO ATIVO" title={org.name} action={<Button variant="outline" onClick={() => onPage("members")}><UsersRound /> Participantes</Button>} /><section className="event-overview"><div className="event-goal"><span className="panel-kicker"><Target /> Objetivo principal</span><h2>{goal?.title || "Evento em andamento"}</h2><p>{goal?.description || "Acompanhe o progresso do evento."}</p><strong>{Math.round(progress)}%</strong><div className="goal-progress"><div><i style={{ width: `${progress}%` }} /></div></div>{goal ? <button className="inline-action" onClick={() => onPage("goals")}>Ver metas <ArrowUpRight /></button> : null}</div><div className="event-roster"><span className="panel-kicker"><UsersRound /> Participantes</span><strong>{data.members.length}</strong><small>{online} online</small><Button variant="outline" onClick={() => onPage("members")}>Abrir lista</Button></div><div className="event-activity"><span className="panel-kicker"><History /> Atividade</span>{data.logs.slice(0, 3).map((item) => <div key={item.id}><strong>{item.message || item.action || "Atividade"}</strong><small>{dateTime(item.createdAt)}</small></div>)}{!data.logs.length ? <p className="quiet">Sem atividade recente.</p> : null}</div></section></>
}

function Members({ context, items, loading, onModal }: { orgCode: string; context: OrganizationContext | null; items: Member[]; loading: boolean; onModal: (value: ModalState) => void }) {
  const [query, setQuery] = useState("")
  const [selectedId, setSelectedId] = useState("")
  const filtered = items.filter((member) => `${member.name} ${member.gradeName} ${member.citizenid}`.toLowerCase().includes(query.toLowerCase()))
  const selected = items.find((member) => member.citizenid === selectedId) ?? items[0]
  const caps = context?.capabilities ?? []
  const canInvite = hasAny(caps, ["members.invite", "manage.members"])
  const canPromote = hasAny(caps, ["members.promote", "manage.members"])
  const canDemote = hasAny(caps, ["members.demote", "manage.members"])
  const canRemove = hasAny(caps, ["members.remove", "members.kick", "manage.members"])
  if (loading) return <LoadingState />
  return <><SectionHeading eyebrow={`${items.length} INTEGRANTES`} title="Membros" action={canInvite ? <Button variant="outline" onClick={() => onModal({ kind: "invite" })}><UserPlus /> Convidar</Button> : undefined} /><section className="master-detail"><div className="master-pane"><div className="toolbar"><label><Search /><Input aria-label="Buscar membros" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar nome, cargo ou identificador…" /></label><span>{filtered.length} resultados</span></div><div className="table-head"><span>Membro</span><span>Status</span><span>Última atividade</span></div><div className="member-list">{filtered.map((member) => <button key={member.citizenid} className={selected?.citizenid === member.citizenid ? "selected" : ""} onClick={() => setSelectedId(member.citizenid)}><span className="avatar">{initials(member.name)}</span><span><strong>{member.name}</strong><small>{member.gradeName || member.gradeCode || "Sem cargo"}</small></span><span><i className={`semantic-dot ${member.isDuty || member.status === "online" ? "online" : "offline"}`} />{member.isDuty ? "Em serviço" : member.status === "online" ? "Online" : "Offline"}</span><time>{dateTime(member.lastSeen)}</time></button>)}{!filtered.length ? <EmptyState title="Nenhum membro encontrado" description="Ajuste sua busca para ver outros resultados." /> : null}</div></div><aside className="detail-pane">{selected ? <><div className="profile"><span className="avatar xl">{initials(selected.name)}</span><div><h2>{selected.name}</h2><p>{selected.gradeName || selected.gradeCode}</p></div></div><div className="fact-list"><div><span>CitizenID</span><strong>{maskCitizenId(selected.citizenid)}</strong></div><div><span>Entrada</span><strong>{dateTime(selected.joinedAt)}</strong></div><div><span>Última atividade</span><strong>{dateTime(selected.lastSeen)}</strong></div><div><span>Estado</span><strong>{selected.isDuty ? "Em serviço" : selected.status || "Offline"}</strong></div></div>{canPromote || canDemote || canRemove ? <div className="action-list"><small>AÇÕES</small>{canPromote ? <button onClick={() => onModal({ kind: "promote", item: selected })}><ArrowUp /> Promover membro</button> : null}{canDemote ? <button onClick={() => onModal({ kind: "demote", item: selected })}><ArrowDownLeft /> Rebaixar membro</button> : null}{canRemove ? <button className="danger" onClick={() => onModal({ kind: "remove", item: selected })}><UserMinus /> Remover da organização</button> : null}</div> : <p className="permission-note">Acesso somente leitura para este cargo.</p>}</> : <EmptyState title="Selecione um membro" description="Os detalhes aparecem aqui." />}</aside></section></>
}

function Access({ model, loading, canManage, onModal }: { model: ViewData["access"]; loading: boolean; canManage: boolean; onModal: (value: ModalState) => void }) {
  const [selectedId, setSelectedId] = useState<number | null>(null)
  if (loading) return <LoadingState />
  const grades = [...(model?.grades ?? [])].sort((a, b) => b.level - a.level)
  const selected = grades.find((grade) => grade.id === selectedId) ?? grades[0]
  return <><SectionHeading eyebrow="CARGOS E PERMISSÕES" title="Hierarquia" action={canManage ? <Button onClick={() => onModal({ kind: "grade-create" })}><Plus /> Novo cargo</Button> : undefined} /><section className="hierarchy-layout"><div className="hierarchy-chain">{grades.map((grade, index) => <button key={grade.id} className={selected?.id === grade.id ? "selected" : ""} onClick={() => setSelectedId(grade.id)}><span className="rank">{String(grade.level).padStart(2, "0")}</span><i /><span><strong>{grade.name}</strong><small>{grade.code} · {grade.capabilities?.length ?? 0} permissões</small></span><b>{money(grade.salary)}</b><ChevronRight />{index < grades.length - 1 ? <em /> : null}</button>)}{!grades.length ? <EmptyState title="Nenhum cargo disponível" description="A hierarquia está vazia." /> : null}</div><aside className="detail-pane">{selected ? <><small>CARGO SELECIONADO</small><h2>{selected.name}</h2><div className="fact-list"><div><span>Nível</span><strong>{selected.level}</strong></div><div><span>Salário</span><strong>{money(selected.salary)}</strong></div><div><span>Prioridade</span><strong>{selected.priority ?? "—"}</strong></div><div><span>Estado</span><strong>{selected.active === false ? "Inativo" : "Ativo"}</strong></div></div><div className="tag-list">{(selected.capabilities ?? []).map((capability) => <span key={capability} className={selected.directCapabilities?.includes(capability) ? "direct" : ""}>{capability}</span>)}</div>{canManage ? <div className="button-grid"><Button variant="outline" onClick={() => onModal({ kind: "grade-edit", item: selected })}>Editar</Button><Button variant="outline" onClick={() => onModal({ kind: "permission-add", item: selected })}>Adicionar permissão</Button><Button variant="outline" onClick={() => onModal({ kind: "permission-remove", item: selected })}>Remover permissão</Button><Button variant="destructive" onClick={() => onModal({ kind: selected.active === false ? "grade-reactivate" : "grade-disable", item: selected })}>{selected.active === false ? "Reativar" : "Desativar"}</Button></div> : null}</> : null}</aside></section></>
}

function Finance({ context, data, loading, onModal }: { context: OrganizationContext | null; data: ViewData; loading: boolean; onModal: (value: ModalState) => void }) {
  if (loading) return <LoadingState />
  const caps = context?.capabilities ?? []
  return <><SectionHeading eyebrow="CONTA DA ORGANIZAÇÃO" title="Financeiro" description="Saldo e movimentações." action={<div className="heading-actions">{hasAny(caps, ["account.deposit", "account.manage", "manage.account"]) ? <Button variant="outline" onClick={() => onModal({ kind: "bank", action: "deposit" })}><Plus /> Depositar</Button> : null}{hasAny(caps, ["account.withdraw", "account.manage", "manage.account"]) ? <Button onClick={() => onModal({ kind: "bank", action: "withdraw" })}><Minus /> Sacar</Button> : null}</div>} /><div className="finance-layout"><Card className="balance-card"><CardHeader><CardDescription>Saldo disponível</CardDescription><CardTitle>{money(data.account?.balance)}</CardTitle></CardHeader><CardContent><Banknote /><span>Conta compartilhada de {data.account?.orgCode || "organização"}</span></CardContent></Card><Card className="transaction-card"><CardHeader><CardTitle>Movimentações recentes</CardTitle><CardDescription>{data.transactions.length} movimentações</CardDescription></CardHeader><CardContent>{data.transactions.map((transaction) => <div className="transaction" key={transaction.id}><span className={transaction.type === "withdraw" ? "out" : "in"}>{transaction.type === "withdraw" ? <ArrowUp /> : <ArrowDownLeft />}</span><span><strong>{transaction.reason || transaction.type}</strong><small>{transaction.actorName} · {dateTime(transaction.createdAt)}</small></span><b className={transaction.type === "withdraw" ? "negative" : "positive"}>{transaction.type === "withdraw" ? "−" : "+"}{money(transaction.amount)}</b></div>)}{!data.transactions.length ? <EmptyState title="Sem movimentações" description="Ainda não há movimentações." /> : null}</CardContent></Card></div></>
}

function RecruitmentPage({ context, items, loading, onModal }: { context: OrganizationContext | null; items: Recruitment[]; loading: boolean; onModal: (value: ModalState) => void }) {
  const [selectedId, setSelectedId] = useState<string>("")
  if (loading) return <LoadingState />
  const selected = items.find((item) => String(item.id) === selectedId) ?? items[0]
  const manage = hasAny(context?.capabilities, ["recruitment.manage", "members.invite", "manage.members"])
  return <><SectionHeading eyebrow={`${items.filter((item) => item.status === "pending").length} PENDENTES`} title="Recrutamento" description="Candidaturas e convites." action={manage ? <Button variant="outline" onClick={() => onModal({ kind: "recruit-create" })}><UserPlus /> Nova candidatura</Button> : undefined} /><section className="master-detail recruitment"><div className="master-pane"><div className="candidate-list">{items.map((item) => <button key={item.id} className={selected?.id === item.id ? "selected" : ""} onClick={() => setSelectedId(String(item.id))}><span className="avatar">{initials(item.candidateName || item.targetName || "C")}</span><span><strong>{item.candidateName || item.targetName || item.candidateCitizenId || "Candidato"}</strong><small>{item.type || "candidatura"} · {dateTime(item.createdAt)}</small></span><b className={`status ${item.status}`}>{item.status || "pending"}</b></button>)}{!items.length ? <EmptyState title="Fila vazia" description="Nenhuma candidatura no momento." /> : null}</div></div><aside className="detail-pane">{selected ? <><small>CANDIDATURA SELECIONADA</small><div className="profile"><span className="avatar xl">{initials(selected.candidateName || "C")}</span><div><h2>{selected.candidateName || selected.targetName || "Candidato"}</h2><p>{maskCitizenId(selected.candidateCitizenId || selected.targetCitizenId)}</p></div></div><div className="note"><span>Observação</span><p>{selected.note || "Nenhuma observação informada."}</p></div>{manage && selected.status === "pending" ? <div className="heading-actions"><Button onClick={() => onModal({ kind: "recruit-approve", item: selected })}><Check /> Aprovar</Button><Button variant="outline" onClick={() => onModal({ kind: "recruit-reject", item: selected })}><X /> Recusar</Button><Button variant="ghost" onClick={() => onModal({ kind: "recruit-cancel", item: selected })}>Arquivar</Button></div> : null}</> : null}</aside></section></>
}

function Goals({ context, items, loading, onModal }: { context: OrganizationContext | null; items: Goal[]; loading: boolean; onModal: (value: ModalState) => void }) {
  if (loading) return <LoadingState />
  const canManage = hasAny(context?.capabilities, ["goals.manage", "manage.goals"])
  return <><SectionHeading eyebrow="ACOMPANHAMENTO OPERACIONAL" title="Metas" description="Objetivos em andamento." action={canManage ? <Button onClick={() => onModal({ kind: "goal-create" })}><Plus /> Nova meta</Button> : undefined} /><div className="goal-list">{items.map((goal) => <Card key={goal.id}><CardContent><div><span className={`status ${goal.status}`}>{goal.status || "active"}</span><h2>{goal.title}</h2><p>{goal.description || "Sem descrição."}</p></div><div className="goal-progress"><span><b>{goal.progress ?? 0}</b> / {goal.target ?? 0}<strong>{Math.round(goal.progressPercent ?? 0)}%</strong></span><div><i style={{ width: `${Math.min(100, goal.progressPercent ?? 0)}%` }} /></div><small>{goal.endsAt ? `Prazo ${dateTime(goal.endsAt)}` : "Sem prazo definido"}</small></div></CardContent></Card>)}{!items.length ? <EmptyState title="Nenhuma meta ativa" description="Crie uma meta apenas se seu cargo possuir a capacidade necessária." /> : null}</div></>
}

function Logs({ items, loading }: { items: OrgLog[]; loading: boolean }) {
  const [query, setQuery] = useState("")
  if (loading) return <LoadingState />
  const filtered = items.filter((item) => `${item.message} ${item.actorName} ${item.targetName} ${item.category}`.toLowerCase().includes(query.toLowerCase()))
  return <><SectionHeading eyebrow="TRILHA DE AUDITORIA" title="Histórico" description="Mudanças e ações recentes." /><div className="log-toolbar"><label><Search /><Input aria-label="Buscar atividade" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar atividade…" /></label><span>{filtered.length} eventos</span></div><div className="history-feed">{filtered.map((item) => <article key={item.id}><time>{dateTime(item.createdAt)}</time><i className={`semantic-dot ${item.severity === "error" ? "danger" : item.severity === "warning" ? "warning" : "info"}`} /><div><strong>{item.message || item.action || "Atividade"}</strong><small>{[item.category, item.actorName, item.targetName, item.reason].filter(Boolean).join(" · ")}</small></div></article>)}{!filtered.length ? <EmptyState title="Nenhum evento encontrado" description="Ajuste a busca ou aguarde novas atividades." /> : null}</div></>
}

function Staff({ organizations, selected, access, loading, permissions, onSelect, onModal }: { organizations: OrgSummary[]; selected: OrgSummary | null; access: ViewData["access"]; loading: boolean; permissions: string[]; onSelect: (org: OrgSummary) => void; onModal: (value: ModalState) => void }) {
  const [query, setQuery] = useState("")
  const canManage = hasAny(permissions, ["staff.orgs.manage"])
  const canCreate = hasAny(permissions, ["staff.orgs.create"])
  if (loading) return <LoadingState />
  if (selected) return <><SectionHeading eyebrow="ADMINISTRAÇÃO STAFF" title={selected.name} description={`${selected.code} · ${selected.type} · ${selected.status || (selected.active === false ? "inactive" : "active")}`} action={<div className="heading-actions">{canManage ? <Button variant="outline" onClick={() => onModal({ kind: "org-edit", item: selected })}>Editar organização</Button> : null}{canManage ? <Button variant="destructive" onClick={() => onModal({ kind: selected.active === false || selected.status === "inactive" ? "org-reactivate" : "org-archive", item: selected })}>{selected.active === false || selected.status === "inactive" ? "Reativar" : "Arquivar"}</Button> : null}</div>} /><div className="staff-detail-grid"><Card><CardHeader><CardTitle>Configuração</CardTitle><CardDescription>Recursos disponíveis.</CardDescription></CardHeader><CardContent className="fact-list"><div><span>Salários</span><strong>{selected.hasSalary ? "Ativo" : "Inativo"}</strong></div><div><span>Conta compartilhada</span><strong>{selected.hasSharedAccount ? "Ativa" : "Inativa"}</strong></div><div><span>Armazenamento</span><strong>{selected.hasStorage ? "Ativo" : "Inativo"}</strong></div><div><span>Membros</span><strong>{selected.memberCount ?? 0}</strong></div></CardContent></Card><Card><CardHeader><CardTitle>Liderança</CardTitle><CardDescription>Defina quem lidera esta organização.</CardDescription></CardHeader><CardContent>{hasAny(permissions, ["staff.orgs.set_leader"]) ? <Button variant="outline" onClick={() => onModal({ kind: "leader" })}>Definir líder</Button> : <p className="permission-note">Sem permissão para transferir liderança.</p>}</CardContent></Card></div><Access model={access} loading={false} canManage={canManage} onModal={onModal} /></>
  const filtered = organizations.filter((org) => `${org.name} ${org.code} ${org.type}`.toLowerCase().includes(query.toLowerCase()))
  return <><SectionHeading eyebrow="ADMINISTRAÇÃO STAFF" title="Organizações" description="Gerencie organizações e acessos." action={canCreate ? <Button onClick={() => onModal({ kind: "org-create" })}><Plus /> Nova organização</Button> : undefined} /><div className="staff-toolbar"><label><Search /><Input aria-label="Buscar organizações" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar por nome, código ou tipo…" /></label><span>{filtered.length} organizações</span></div><div className="org-table"><div className="table-head"><span>Organização</span><span>Tipo</span><span>Membros</span><span>Estado</span></div>{filtered.map((org) => <button key={org.code} onClick={() => onSelect(org)}><span className="avatar emblem">{initials(org.name)}</span><span><strong>{org.name}</strong><small>{org.code}</small></span><span>{org.type}</span><span>{org.memberCount ?? 0}</span><span className={`status ${org.active === false || org.status === "inactive" ? "inactive" : "active"}`}>{org.active === false || org.status === "inactive" ? "Inativa" : "Ativa"}</span><ChevronRight /></button>)}{!filtered.length ? <EmptyState title="Nenhuma organização encontrada" description="Ajuste a busca." /> : null}</div></>
}

function ActionDialog({ modal, busy, onOpenChange, onSubmit, activeOrg }: { modal: ModalState; busy: boolean; onOpenChange: (value: boolean) => void; onSubmit: (event: FormEvent<HTMLFormElement>) => void; activeOrg: OrganizationContext | OrgSummary | null }) {
  if (!modal) return null
  const member = modal.item as Member | undefined
  const recruitment = modal.item as Recruitment | undefined
  const org = modal.item as OrgSummary | undefined
  const grade = modal.item as AccessGrade | undefined
  const destructive = ["remove", "org-archive", "grade-disable"].includes(modal.kind)
  const titles: Record<ModalKind, string> = { invite: "Convidar membro", promote: "Promover membro", demote: "Rebaixar membro", remove: "Remover membro", leader: "Definir liderança", bank: modal.action === "deposit" ? "Depositar na conta" : "Sacar da conta", "recruit-create": "Nova candidatura", "recruit-approve": "Aprovar candidatura", "recruit-reject": "Recusar candidatura", "recruit-cancel": "Arquivar candidatura", "goal-create": "Criar meta", "org-create": "Criar organização", "org-edit": "Editar organização", "org-archive": "Arquivar organização", "org-reactivate": "Reativar organização", "grade-create": "Criar cargo", "grade-edit": "Editar cargo", "grade-disable": "Desativar cargo", "grade-reactivate": "Reativar cargo", "permission-add": "Adicionar permissão", "permission-remove": "Remover permissão" }
  const confirmations = new Set<ModalKind>(["promote", "demote", "remove", "org-archive", "org-reactivate", "grade-disable", "grade-reactivate"])
  return <Dialog open onOpenChange={onOpenChange}><DialogContent><DialogHeader><DialogTitle>{titles[modal.kind]}</DialogTitle><DialogDescription>{confirmations.has(modal.kind) ? `Confirme a ação em ${member?.name || org?.name || grade?.name || activeOrg?.name || "este registro"}.` : "Revise os dados antes de salvar."}</DialogDescription></DialogHeader><form className="dialog-form" autoComplete="off" onSubmit={onSubmit}>
    {modal.kind === "invite" || modal.kind === "leader" || modal.kind === "recruit-create" ? <Field name="citizenid" label="CitizenID" required defaultValue={member?.citizenid} /> : null}
    {modal.kind === "invite" || modal.kind === "recruit-create" || modal.kind === "recruit-approve" ? <Field name="gradeCode" label="Código do cargo (opcional)" /> : null}
    {modal.kind === "bank" ? <><Field name="amount" label="Valor" type="number" min="1" step="1" required /><Field name="reason" label="Motivo" required /></> : null}
    {modal.kind === "recruit-create" ? <Field name="note" label="Observação" /> : null}
    {modal.kind === "goal-create" ? <><Field name="title" label="Título" required /><Field name="description" label="Descrição" /><Field name="target" label="Meta numérica" type="number" min="1" required /><Field name="endsAt" label="Prazo" type="datetime-local" /></> : null}
    {modal.kind === "org-create" ? <><Field name="code" label="Código" required /><Field name="name" label="Nome" required /><label><span>Tipo</span><select name="type" defaultValue="business"><option value="job">Job</option><option value="gang">Gang</option><option value="business">Business</option><option value="government">Government</option><option value="vip">VIP</option><option value="event">Event</option></select></label><Flags /></> : null}
    {modal.kind === "org-edit" ? <><Field name="name" label="Nome" required defaultValue={org?.name} /><label><span>Estado</span><select name="status" defaultValue={org?.status || "private"}><option value="private">Privada</option><option value="public">Pública</option><option value="inactive">Inativa</option></select></label><Flags org={org} /></> : null}
    {modal.kind === "grade-create" || modal.kind === "grade-edit" ? <><Field name="code" label="Código" required={modal.kind === "grade-create"} defaultValue={grade?.code} disabled={modal.kind === "grade-edit"} /><Field name="name" label="Nome" required defaultValue={grade?.name} /><div className="field-row"><Field name="level" label="Nível" type="number" min="1" required defaultValue={grade?.level} /><Field name="priority" label="Prioridade" type="number" min="1" required defaultValue={grade?.priority} /></div><Field name="salary" label="Salário" type="number" min="0" required defaultValue={grade?.salary ?? 0} /><Field name="inheritsLevel" label="Herda do nível (opcional)" type="number" min="1" defaultValue={grade?.inheritsLevel ?? undefined} /></> : null}
    {modal.kind === "permission-add" || modal.kind === "permission-remove" ? <Field name="permission" label="Permissão canônica" required /> : null}
    {["leader", "recruit-reject", "recruit-cancel", "org-create", "org-edit", "org-archive", "org-reactivate", "grade-create", "grade-edit", "grade-disable", "grade-reactivate", "permission-add", "permission-remove"].includes(modal.kind) ? <Field name="reason" label="Motivo" required={destructive} /> : null}
    {recruitment ? <p className="dialog-context">Candidatura #{recruitment.id} · {recruitment.candidateName || recruitment.targetName}</p> : null}
    <DialogFooter><DialogClose asChild><Button type="button" variant="ghost">Cancelar</Button></DialogClose><Button type="submit" variant={destructive ? "destructive" : "default"} disabled={busy}>{busy ? <RefreshCw className="animate-spin" /> : null}{confirmations.has(modal.kind) ? "Confirmar" : "Salvar"}</Button></DialogFooter>
  </form></DialogContent></Dialog>
}

function Field({ label, ...props }: { label: string } & ComponentProps<typeof Input>) {
  return <label><span>{label}</span><Input autoComplete="off" {...props} /></label>
}

function Flags({ org }: { org?: OrgSummary }) {
  return <div className="check-grid"><label><input type="checkbox" name="hasSalary" defaultChecked={org?.hasSalary ?? true} /> Salários</label><label><input type="checkbox" name="hasSharedAccount" defaultChecked={org?.hasSharedAccount ?? true} /> Conta compartilhada</label><label><input type="checkbox" name="hasStorage" defaultChecked={org?.hasStorage ?? true} /> Armazenamento</label></div>
}

function LoadingState() {
  return <div className="loading-state" aria-label={copy.loading}><Skeleton className="h-6 w-40" /><Skeleton className="h-10 w-72" /><div><Skeleton /><Skeleton /><Skeleton /></div></div>
}

function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return <div className="state-screen error-state"><span><X /></span><h2>Não foi possível carregar</h2><p>{message}</p><Button variant="outline" onClick={onRetry}><RefreshCw /> {copy.retry}</Button></div>
}

function EmptyState({ title, description }: { title: string; description: string }) {
  return <div className="empty-state"><ClipboardList /><strong>{title}</strong><span>{description}</span></div>
}
