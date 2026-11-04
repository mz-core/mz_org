import { mockNui } from "@/lib/mock"
import type { NuiResult } from "@/lib/types"

declare global {
  interface Window { GetParentResourceName?: () => string }
}

let sequence = 0

export const isFiveM = () => typeof window.GetParentResourceName === "function"
export const isPreview = () => !isFiveM() && new URLSearchParams(window.location.search).get("preview") === "1"

export async function postNui<T>(event: string, payload: Record<string, unknown> = {}, sessionRevision?: string, contextKey?: string): Promise<NuiResult<T>> {
  if (!isFiveM()) {
    if (isPreview()) return mockNui<T>(event, payload)
    return { ok: false, error: "Preview fechado. Use ?preview=1 no navegador." }
  }

  sequence = sequence >= 999_999 ? 1 : sequence + 1
  const body = event === "session:get" || event === "close" ? payload : {
    version: 2,
    requestId: `react-${sequence}`,
    sessionRevision: sessionRevision ?? null,
    contextKey: contextKey ?? "hub",
    payload,
  }

  try {
    const response = await fetch(`https://${window.GetParentResourceName?.() ?? "mz_org"}/${event}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(body),
    })
    const result = await response.json() as NuiResult<T>
    if (!response.ok) return { ok: false, error: `NUI ${event} respondeu ${response.status}.` }
    if ("sessionRevision" in result && result.sessionRevision && sessionRevision && result.sessionRevision !== sessionRevision) return { ok: false, error: "stale_context", stale: true }
    if ("contextKey" in result && result.contextKey && contextKey && result.contextKey !== contextKey) return { ok: false, error: "stale_context", stale: true }
    return result
  } catch {
    return { ok: false, error: "Falha ao comunicar com a NUI." }
  }
}
