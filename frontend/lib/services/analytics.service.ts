/**
 * Analytics service — wraps all Supabase analytics table reads
 * and the refresh_user_analytics / refresh_user_insight_engine / refresh_user_recommendations RPCs.
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

/** v3 daily_feature_rollups row */
export interface DailyFeatureRollup {
  feature_date: string
  log_count: number
  avg_pain: number | null
  max_pain: number | null
  avg_stress: number | null
  max_stress: number | null
  symptom_count: number
  flare_flag: boolean
  flare_score: number | null
  spicy_exposure_count: number
}

/** v3 rolling_feature_snapshots row */
export interface RollingFeatureSnapshot {
  snapshot_date: string
  window_days: number
  avg_pain: number | null
  avg_stress: number | null
  flare_days: number | null
  spicy_correlation_score: number | null
  stress_vs_pain_score: number | null
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
 * Insight engine: predictions, insight model_features, recommendation_items (source=insight_engine),
 * and insight_engine_runs audit. Same date window as analytics refresh.
 * Returns JSON includes `ok`; false means the run row was logged with status=error (HTTP may still be 200).
 */
export async function refreshUserInsightEngine(
  userId: string,
  from: string,
  to: string
): Promise<void> {
  const supabase = createClient()
  const { data, error } = await supabase.rpc("refresh_user_insight_engine", {
    p_user_id: userId,
    p_start: from,
    p_end: to,
  })
  if (error) {
    console.warn("[analytics] refresh_user_insight_engine failed:", error.message)
    return
  }
  const payload = data as { ok?: boolean; error?: string; failed_step?: string } | null
  if (payload && payload.ok === false) {
    console.warn(
      "[analytics] refresh_user_insight_engine reported failure:",
      payload.error ?? "unknown",
      payload.failed_step ? `(step: ${payload.failed_step})` : ""
    )
  }
}

/**
 * Rebuild the recommendation cache for a user.
 * Should be called after refreshUserAnalytics and refreshUserInsightEngine complete.
 */
export async function refreshUserRecommendations(
  userId: string,
  cacheVersion = "v1",
  snapshotDate?: string
): Promise<void> {
  const supabase = createClient()
  const { error } = await supabase.rpc("refresh_user_recommendations", {
    p_user_id: userId,
    p_cache_version: cacheVersion,
    p_snapshot_date: snapshotDate ?? new Date().toISOString().split("T")[0],
  })
  if (error) {
    console.warn("[analytics] refresh_user_recommendations failed:", error.message)
  }
}

/**
 * Convenience: refresh analytics + insight engine + recommendations for the trailing 30 days.
 * Call after saving / updating / deleting a log entry.
 */
export async function triggerFullRefresh(userId: string): Promise<void> {
  const today = new Date()
  const to = today.toISOString().split("T")[0]
  const from = new Date(today)
  from.setDate(today.getDate() - 30)
  const fromStr = from.toISOString().split("T")[0]
  await refreshUserAnalytics(userId, fromStr, to)
  await refreshUserInsightEngine(userId, fromStr, to)
  await refreshUserRecommendations(userId, "v1", to)
}

/** Snapshot ML-ready features (writes model_features). */
export async function buildModelFeaturesSnapshot(
  userId: string,
  asOfDate: string,
  windowDays: 7 | 14 | 30 | 60
): Promise<string | null> {
  const supabase = createClient()
  const { data, error } = await supabase.rpc("build_model_features", {
    p_user_id: userId,
    p_as_of_date: asOfDate,
    p_window_days: windowDays,
  })
  if (error) {
    console.warn("[analytics] build_model_features failed:", error.message)
    return null
  }
  return data as string | null
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

export async function fetchDailyRollups(
  userId: string,
  limit = 30
): Promise<DailyFeatureRollup[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("daily_feature_rollups")
    .select(
      "feature_date, log_count, avg_pain, max_pain, avg_stress, max_stress, symptom_count, flare_flag, flare_score, spicy_exposure_count"
    )
    .eq("user_id", userId)
    .order("feature_date", { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as DailyFeatureRollup[]
}

/** Latest snapshot_date rows (all window_days) for the most recent snapshot. */
export async function fetchLatestRollingSnapshots(
  userId: string
): Promise<RollingFeatureSnapshot[]> {
  const supabase = createClient()
  const { data: latest, error: e1 } = await supabase
    .from("rolling_feature_snapshots")
    .select("snapshot_date")
    .eq("user_id", userId)
    .order("snapshot_date", { ascending: false })
    .limit(1)
    .maybeSingle()
  if (e1) throw e1
  if (!latest?.snapshot_date) return []

  const { data, error } = await supabase
    .from("rolling_feature_snapshots")
    .select(
      "snapshot_date, window_days, avg_pain, avg_stress, flare_days, spicy_correlation_score, stress_vs_pain_score"
    )
    .eq("user_id", userId)
    .eq("snapshot_date", latest.snapshot_date)
    .order("window_days", { ascending: true })
  if (error) throw error
  return (data ?? []) as RollingFeatureSnapshot[]
}
