export function money(value: unknown) {
  return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(Number(value) || 0)
}

export function dateTime(value: unknown) {
  if (!value) return "—"
  const date = new Date(String(value))
  return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" })
}

export function initials(name: string) {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join("").toUpperCase() || "MZ"
}

export function maskCitizenId(value?: string | null) {
  if (!value) return "—"
  return value.length <= 5 ? value : `${value.slice(0, 3)}•••${value.slice(-2)}`
}

export function hasAny(values: string[] | undefined, candidates: string[]) {
  if (!values) return false
  return candidates.some((candidate) => values.includes(candidate))
}
