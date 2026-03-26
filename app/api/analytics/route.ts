/**
 * /api/analytics — authenticated via API key (Bearer gg_...)
 *
 * GET /api/analytics  returns recommendation cache + weekly summaries
 *                     for the API key owner
 */

import { NextRequest, NextResponse } from "next/server"
import { createClient } from "@supabase/supabase-js"

function serviceClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )
}

async function resolveApiKey(apiKey: string): Promise<string | null> {
  try {
    const { data, error } = await serviceClient().rpc("resolve_api_key", {
      p_api_key: apiKey,
    })
    if (error || !data) return null
    return data as string
  } catch {
    return null
  }
}

export async function GET(request: NextRequest) {
  const auth = request.headers.get("authorization") ?? ""
  if (!auth.startsWith("Bearer gg_")) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }

  const userId = await resolveApiKey(auth.slice(7))
  if (!userId) {
    return NextResponse.json({ error: "Invalid API key" }, { status: 403 })
  }

  const supabase = serviceClient()

  const [cacheRes, summaryRes, triggerRes] = await Promise.all([
    supabase
      .from("recommendation_cache")
      .select("payload, generated_at")
      .eq("user_id", userId)
      .eq("cache_version", "v1")
      .maybeSingle(),
    supabase
      .from("weekly_summaries")
      .select("week_start, entry_count, avg_pain, avg_stress, top_triggers, top_symptoms, top_remedies")
      .eq("user_id", userId)
      .order("week_start", { ascending: false })
      .limit(8),
    supabase
      .from("analytics_trigger_scores")
      .select("trigger_name, pain_delta, sample_count")
      .eq("user_id", userId)
      .order("pain_delta", { ascending: false, nullsFirst: false })
      .limit(10),
  ])

  return NextResponse.json({
    recommendations: cacheRes.data?.payload ?? null,
    generated_at: cacheRes.data?.generated_at ?? null,
    weekly_summaries: summaryRes.data ?? [],
    top_triggers: triggerRes.data ?? [],
  })
}
