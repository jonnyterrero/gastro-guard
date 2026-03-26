/**
 * v3 structured recommendations (recommendation_items table).
 * Legacy JSON payload remains in recommendation_cache via refresh_user_recommendations.
 */

import { createClient } from "@/lib/supabase/client"

export interface RecommendationItemRow {
  id: string
  user_id: string
  generated_at: string
  recommendation_type: string
  priority: number
  status: string
  title: string
  summary: string
  rationale: unknown
  evidence: unknown
  confidence: number | null
  expires_at: string | null
  model_version: string
  source: string
}

/** Active rows for the insights panel (server rules + refresh_user_recommendations). */
export async function getActiveRecommendations(
  userId: string,
  limit = 20
): Promise<RecommendationItemRow[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("recommendation_items")
    .select("*")
    .eq("user_id", userId)
    .eq("status", "active")
    .order("priority", { ascending: true })
    .order("generated_at", { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as RecommendationItemRow[]
}

/**
 * Rebuilds legacy cache + v3 recommendation_items.
 * Prefer calling via triggerFullRefresh after analytics, or pass snapshotDate aligned with refresh window end.
 */
export async function refreshRecommendations(
  userId: string,
  snapshotDate?: string
): Promise<void> {
  const supabase = createClient()
  const { error } = await supabase.rpc("refresh_user_recommendations", {
    p_user_id: userId,
    p_cache_version: "v1",
    p_snapshot_date: snapshotDate ?? new Date().toISOString().split("T")[0],
  })
  if (error) {
    console.warn("[recommendations] refresh_user_recommendations failed:", error.message)
  }
}
