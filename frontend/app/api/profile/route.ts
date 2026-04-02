/**
 * /api/profile — authenticated via API key (Bearer gg_...)
 *
 * GET /api/profile  returns the profile for the API key owner
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

  const { data, error } = await serviceClient()
    .from("profiles")
    .select("name, age, height, weight, gender, allergies, dietary_restrictions, triggers, effective_remedies")
    .eq("user_id", userId)
    .maybeSingle()

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  return NextResponse.json({ profile: data ?? null })
}
