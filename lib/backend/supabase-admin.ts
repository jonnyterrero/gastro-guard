const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl) {
  throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL environment variable")
}

if (!serviceRoleKey) {
  throw new Error("Missing SUPABASE_SERVICE_ROLE_KEY environment variable")
}

const headers = {
  apikey: serviceRoleKey,
  Authorization: `Bearer ${serviceRoleKey}`,
  "Content-Type": "application/json",
  Prefer: "return=representation",
}

type QueryOptions = {
  select?: string
  filters?: Record<string, string | number>
  order?: { column: string; ascending?: boolean }
  limit?: number
}

const buildUrl = (table: string, options: QueryOptions = {}) => {
  const url = new URL(`${supabaseUrl}/rest/v1/${table}`)

  if (options.select) url.searchParams.set("select", options.select)
  if (options.limit) url.searchParams.set("limit", String(options.limit))
  if (options.order) url.searchParams.set("order", `${options.order.column}.${options.order.ascending === false ? "desc" : "asc"}`)

  for (const [key, value] of Object.entries(options.filters ?? {})) {
    url.searchParams.set(key, `eq.${value}`)
  }

  return url
}

const request = async <T>(method: string, table: string, options: QueryOptions = {}, body?: unknown): Promise<T> => {
  const response = await fetch(buildUrl(table, options), {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
    cache: "no-store",
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(errorText || `Supabase request failed (${response.status})`)
  }

  const payload = (await response.json().catch(() => null)) as T
  return payload
}

export const supabaseAdmin = {
  list: <T>(table: string, options: QueryOptions) => request<T[]>("GET", table, options),
  maybeSingle: async <T>(table: string, options: QueryOptions) => {
    const items = await request<T[]>("GET", table, options)
    return items.at(0) ?? null
  },
  insertSingle: async <T>(table: string, payload: unknown) => {
    const items = await request<T[]>("POST", table, {}, payload)
    return items[0]
  },
  upsertSingle: async <T>(table: string, payload: unknown, onConflict: string) => {
    const url = buildUrl(table)
    url.searchParams.set("on_conflict", onConflict)

    const response = await fetch(url, {
      method: "POST",
      headers: {
        ...headers,
        Prefer: "resolution=merge-duplicates,return=representation",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
      cache: "no-store",
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(errorText || `Supabase upsert failed (${response.status})`)
    }

    const items = (await response.json()) as T[]
    return items[0]
  },
  updateSingle: async <T>(table: string, filters: Record<string, string | number>, payload: unknown) => {
    const items = await request<T[]>("PATCH", table, { filters }, payload)
    return items[0]
  },
  delete: (table: string, filters: Record<string, string | number>) => request<unknown>("DELETE", table, { filters }),
}
