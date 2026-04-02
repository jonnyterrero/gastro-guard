/**
 * /api/entries — authenticated via API key (Bearer gg_...)
 *
 * GET  /api/entries          returns last 100 entries for the key owner
 * POST /api/entries          creates a new log entry
 *
 * Authentication: checks Authorization header against integrations JSONB
 * on the profiles table using the resolve_api_key DB function.
 *
 * Requires env var: SUPABASE_SERVICE_ROLE_KEY (server-side only)
 */

import { NextRequest, NextResponse } from "next/server"
import { createClient } from "@supabase/supabase-js"
import { fromDbRow } from "@/lib/adapter/log-entry"

function serviceClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY!
  if (!key) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY is not set")
  }
  return createClient(url, key)
}

async function resolveApiKey(apiKey: string): Promise<string | null> {
  try {
    const supabase = serviceClient()
    const { data, error } = await supabase.rpc("resolve_api_key", {
      p_api_key: apiKey,
    })
    if (error || !data) return null
    return data as string
  } catch {
    return null
  }
}

function extractApiKey(request: NextRequest): string | null {
  const auth = request.headers.get("authorization") ?? ""
  if (!auth.startsWith("Bearer gg_")) return null
  return auth.slice(7)
}

// ── GET /api/entries ──────────────────────────────────────────────────────────
export async function GET(request: NextRequest) {
  const apiKey = extractApiKey(request)
  if (!apiKey) {
    return NextResponse.json(
      { error: "Missing or invalid Authorization header" },
      { status: 401 }
    )
  }

  const userId = await resolveApiKey(apiKey)
  if (!userId) {
    return NextResponse.json({ error: "Invalid API key" }, { status: 403 })
  }

  const supabase = serviceClient()
  const { searchParams } = new URL(request.url)
  const limit = Math.min(Number(searchParams.get("limit") ?? "100"), 500)

  const { data, error } = await supabase
    .from("log_entries")
    .select("*")
    .eq("user_id", userId)
    .order("entry_at", { ascending: false })
    .limit(limit)

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  return NextResponse.json({
    entries: (data ?? []).map(fromDbRow),
    count: data?.length ?? 0,
  })
}

// ── POST /api/entries ─────────────────────────────────────────────────────────
export async function POST(request: NextRequest) {
  const apiKey = extractApiKey(request)
  if (!apiKey) {
    return NextResponse.json(
      { error: "Missing or invalid Authorization header" },
      { status: 401 }
    )
  }

  const userId = await resolveApiKey(apiKey)
  if (!userId) {
    return NextResponse.json({ error: "Invalid API key" }, { status: 403 })
  }

  let body: Record<string, unknown>
  try {
    body = await request.json()
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 })
  }

  // Validate required fields
  const painScore = Number(body.pain_score ?? body.painLevel ?? 0)
  const stressScore = Number(body.stress_score ?? body.stressLevel ?? 0)
  if (painScore < 0 || painScore > 10 || stressScore < 0 || stressScore > 10) {
    return NextResponse.json(
      { error: "pain_score and stress_score must be 0–10" },
      { status: 400 }
    )
  }

  const now = new Date()
  const payload = {
    user_id: userId,
    entry_at: (body.entry_at as string) ?? now.toISOString(),
    entry_date: (body.entry_date as string) ?? now.toISOString().split("T")[0],
    pain_score: painScore,
    stress_score: stressScore,
    nausea_score: body.nausea_score != null ? Number(body.nausea_score) : null,
    meal_name: (body.meal_name as string) ?? null,
    meal_notes: (body.meal_notes as string) ?? null,
    symptoms: Array.isArray(body.symptoms) ? body.symptoms : [],
    triggers: Array.isArray(body.triggers) ? body.triggers : [],
    remedies: Array.isArray(body.remedies) ? body.remedies : [],
    food_tags: Array.isArray(body.food_tags) ? body.food_tags : [],
    notes: (body.notes as string) ?? null,
  }

  const supabase = serviceClient()
  const { data, error } = await supabase
    .from("log_entries")
    .insert(payload)
    .select("id, entry_at, entry_date, pain_score, stress_score, symptoms, triggers, remedies, notes, meal_name, food_tags")
    .single()

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  return NextResponse.json({ entry: fromDbRow(data) }, { status: 201 })
}
