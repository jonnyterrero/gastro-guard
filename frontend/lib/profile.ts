import type { SupabaseClient } from "@supabase/supabase-js"

export interface UserProfile {
  name: string
  age: number
  height: string
  weight: string
  gender: string
  conditions: string[]
  medications: string[]
  allergies: string[]
  dietaryRestrictions: string[]
  triggers: string[]
  effectiveRemedies: string[]
}

export interface Integration {
  id: string
  name: string
  apiKey: string
  createdAt: string
  lastUsed?: string
  permissions: string[]
}

type ProfileRow = {
  user_id: string
  name: string | null
  age: number | null
  height: string | null
  weight: string | null
  gender: string | null
  conditions: unknown
  medications: unknown
  allergies: unknown
  dietary_restrictions: unknown
  triggers: unknown
  effective_remedies: unknown
  integrations?: unknown
}

function parseStringArray(v: unknown): string[] {
  if (Array.isArray(v)) return v.filter((x): x is string => typeof x === "string")
  return []
}

export function rowToUserProfile(row: ProfileRow): UserProfile {
  return {
    name: row.name ?? "",
    age: row.age ?? 0,
    height: row.height ?? "",
    weight: row.weight ?? "",
    gender: row.gender ?? "",
    conditions: parseStringArray(row.conditions),
    medications: parseStringArray(row.medications),
    allergies: parseStringArray(row.allergies),
    dietaryRestrictions: parseStringArray(row.dietary_restrictions),
    triggers: parseStringArray(row.triggers),
    effectiveRemedies: parseStringArray(row.effective_remedies),
  }
}

export function userProfileToUpsert(
  userId: string,
  profile: UserProfile,
  integrations: Integration[]
): Record<string, unknown> {
  return {
    user_id: userId,
    name: profile.name,
    age: profile.age,
    height: profile.height,
    weight: profile.weight,
    gender: profile.gender,
    conditions: profile.conditions,
    medications: profile.medications,
    allergies: profile.allergies,
    dietary_restrictions: profile.dietaryRestrictions,
    triggers: profile.triggers,
    effective_remedies: profile.effectiveRemedies,
    integrations: integrations,
  }
}

export async function fetchProfileAndIntegrations(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase.from("profiles").select("*").eq("user_id", userId).maybeSingle()
  if (error) throw error
  if (!data) return { profile: null as UserProfile | null, integrations: [] as Integration[] }
  const row = data as ProfileRow
  const integrations = Array.isArray(row.integrations)
    ? (row.integrations as Integration[])
    : []

  const base = rowToUserProfile(row)

  const [{ data: condRows, error: condErr }, { data: medRows, error: medErr }] =
    await Promise.all([
      supabase
        .from("profile_conditions")
        .select("condition_name")
        .eq("user_id", userId)
        .eq("is_active", true),
      supabase
        .from("medications")
        .select("medication_name")
        .eq("user_id", userId)
        .eq("is_active", true),
    ])

  let conditions = base.conditions
  if (conditions.length === 0 && !condErr && condRows?.length) {
    conditions = condRows.map((r) => r.condition_name).filter((x): x is string => typeof x === "string")
  }

  let medications = base.medications
  if (medications.length === 0 && !medErr && medRows?.length) {
    medications = medRows.map((r) => r.medication_name).filter((x): x is string => typeof x === "string")
  }

  return {
    profile: { ...base, conditions, medications },
    integrations,
  }
}
