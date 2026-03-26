/**
 * Analytics service — wraps all Supabase analytics table reads
 * and the refresh_user_analytics / refresh_user_recommendations RPCs.
 *
 * All functions use the browser Supabase client (client components / hooks).
 * For server-side use, swap createClient() with the server variant.
 */

import { createClient } from "@/lib/supabase/client"

// ── Types ─────────────────────────────────────────────────────────────────────

export interface TriggerScore {
  trigger_name: string
  avg_pain_when_present: number | null
  avg_pain_when_absent: number | null
  pain_delta: number | null
  sample_count: number
}

export interface RemedyScore {
  remedy_name: string
  avg_effectiveness: number | null
  usage_count: number
}

export interface WeeklySummary {
  week_start: string
  entry_count: number
  avg_pain: number | null
  avg_stress: number | null
  top_triggers: Array<{ name: string; n: number }>
  top_remedies: Array<{ name: string; n: number }>
  top_symptoms: Array<{ name: string; n: number }>
}

export interface RecommendationPayload {
  week_summary_ref: string | null
  top_triggers: Array<{ name: string; n: number }>
  top_remedies: Array<{ name: string; n: number }>
  top_symptoms: Array<{ name: string; n: number }>
  risky_hours: Array<{ hour: number; avg_pain: number; n: number }>
  recent_entry_count: number
}

export interface TimelineEvent {
  event_type: string
  occurred_at: string
  title: string
  details: Record<string, unknown>
}

// ── RPC calls (write) ─────────────────────────────────────────────────────────

/**
 * Trigger an analytics refresh for the given user + date window.
 * Fires-and-forgets — caller should not await unless needed.
 */
export async function refreshUserAnalytics(
  userId: string,
  from: string, // YYYY-MM-DD
  to: string    // YYYY-MM-DD
): Promise<void> {
  const supabase = createClient()
  const { error } = await supabase.rpc("refresh_user_analytics", {
    p_user_id: userId,
    p_from: from,
    p_to: to,
  })
  if (error) {
    // Non-fatal: analytics are best-effort; app still functions without them
    console.warn("[analytics] refresh_user_analytics failed:", error.message)
  }
}

/**
 * Rebuild the recommendation cache for a user.
 * Should be called after refreshUserAnalytics completes.
 */
export async function refreshUserRecommendations(
  userId: string,
  cacheVersion = "v1"
): Promise<void> {
  const supabase = createClient()
  const { error } = await supabase.rpc("refresh_user_recommendations", {
    p_user_id: userId,
    p_cache_version: cacheVersion,
  })
  if (error) {
    console.warn("[analytics] refresh_user_recommendations failed:", error.message)
  }
}

/**
 * Convenience: refresh analytics for the trailing 30 days then update recs.
 * Call after saving / updating / deleting a log entry.
 */
export async function triggerFullRefresh(userId: string): Promise<void> {
  const today = new Date()
  const from = new Date(today)
  from.setDate(today.getDate() - 30)
  await refreshUserAnalytics(
    userId,
    from.toISOString().split("T")[0],
    today.toISOString().split("T")[0]
  )
  await refreshUserRecommendations(userId)
}

// ── Read functions ────────────────────────────────────────────────────────────

export async function fetchTimeline(userId: string, limit = 50): Promise<TimelineEvent[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("v_user_timeline")
    .select("event_type, occurred_at, title, details")
    .eq("user_id", userId)
    .order("occurred_at", { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as TimelineEvent[]
}

export async function fetchTriggerScores(userId: string): Promise<TriggerScore[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("analytics_trigger_scores")
    .select("trigger_name, avg_pain_when_present, avg_pain_when_absent, pain_delta, sample_count")
    .eq("user_id", userId)
    .order("pain_delta", { ascending: false, nullsFirst: false })
    .limit(10)
  if (error) throw error
  return (data ?? []) as TriggerScore[]
}

export async function fetchRemedyScores(userId: string): Promise<RemedyScore[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("analytics_remedy_scores")
    .select("remedy_name, avg_effectiveness, usage_count")
    .eq("user_id", userId)
    .order("avg_effectiveness", { ascending: false, nullsFirst: false })
    .limit(10)
  if (error) throw error
  return (data ?? []) as RemedyScore[]
}

export async function fetchWeeklySummaries(
  userId: string,
  limit = 8
): Promise<WeeklySummary[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("weekly_summaries")
    .select(
      "week_start, entry_count, avg_pain, avg_stress, top_triggers, top_remedies, top_symptoms"
    )
    .eq("user_id", userId)
    .order("week_start", { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as WeeklySummary[]
}

export async function fetchRecommendationCache(
  userId: string
): Promise<RecommendationPayload | null> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("recommendation_cache")
    .select("payload, generated_at")
    .eq("user_id", userId)
    .eq("cache_version", "v1")
    .maybeSingle()
  if (error) throw error
  if (!data) return null
  return data.payload as RecommendationPayload
}
