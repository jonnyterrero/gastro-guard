/**
 * Cookie-authenticated log session writes (RLS on log_entries).
 * POST create, PATCH update by body.id — in-app orchestrated flow.
 */

import { NextRequest, NextResponse } from "next/server"

import {
  toLogEntriesInsertRow,
  toLogEntriesUpdateRow,
} from "@/lib/log-session/mapToLogEntriesRow"
import {
  validateLogSessionUpdate,
  validateLogSessionWrite,
} from "@/lib/log-session/validateLogSession"
import { createClient } from "@/lib/supabase/server"
import type { LogSessionApiResponse } from "@/lib/types/log-session"

async function requireUser() {
  const supabase = await createClient()
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser()
  if (error || !user) {
    return { supabase: null, user: null as null }
  }
  return { supabase, user }
}

async function assertParentEntry(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string,
  parentId: string
): Promise<boolean> {
  const { data } = await supabase
    .from("log_entries")
    .select("id")
    .eq("id", parentId)
    .eq("user_id", userId)
    .maybeSingle()
  return !!data
}

export async function POST(request: NextRequest) {
  const { supabase, user } = await requireUser()
  if (!supabase || !user) {
    return NextResponse.json(
      { ok: false, error: "Unauthorized" } satisfies LogSessionApiResponse,
      { status: 401 }
    )
  }

  let body: unknown
  try {
    body = await request.json()
  } catch {
    return NextResponse.json(
      { ok: false, error: "Invalid JSON body" } satisfies LogSessionApiResponse,
      { status: 400 }
    )
  }

  const validated = validateLogSessionWrite(body)
  if (!validated.ok) {
    return NextResponse.json(
      {
        ok: false,
        error: "Validation failed",
        details: validated.errors,
      } satisfies LogSessionApiResponse,
      { status: 400 }
    )
  }

  const { payload } = validated
  if (payload.kind === "follow_up" && payload.follow_up_of_entry_id) {
    const ok = await assertParentEntry(
      supabase,
      user.id,
      payload.follow_up_of_entry_id
    )
    if (!ok) {
      return NextResponse.json(
        {
          ok: false,
          error: "Parent log entry not found for this user",
        } satisfies LogSessionApiResponse,
        { status: 400 }
      )
    }
  }

  const row = toLogEntriesInsertRow(user.id, payload)
  const { data, error } = await supabase
    .from("log_entries")
    .insert(row)
    .select()
    .single()

  if (error) {
    return NextResponse.json(
      {
        ok: false,
        error: error.message,
      } satisfies LogSessionApiResponse,
      { status: 500 }
    )
  }

  return NextResponse.json({
    ok: true,
    entry: data as Record<string, unknown>,
  } satisfies LogSessionApiResponse)
}

export async function PATCH(request: NextRequest) {
  const { supabase, user } = await requireUser()
  if (!supabase || !user) {
    return NextResponse.json(
      { ok: false, error: "Unauthorized" } satisfies LogSessionApiResponse,
      { status: 401 }
    )
  }

  let body: unknown
  try {
    body = await request.json()
  } catch {
    return NextResponse.json(
      { ok: false, error: "Invalid JSON body" } satisfies LogSessionApiResponse,
      { status: 400 }
    )
  }

  const validated = validateLogSessionUpdate(body)
  if (!validated.ok) {
    return NextResponse.json(
      {
        ok: false,
        error: "Validation failed",
        details: validated.errors,
      } satisfies LogSessionApiResponse,
      { status: 400 }
    )
  }

  const { payload } = validated

  if (payload.kind === "follow_up" && payload.follow_up_of_entry_id) {
    const ok = await assertParentEntry(
      supabase,
      user.id,
      payload.follow_up_of_entry_id
    )
    if (!ok) {
      return NextResponse.json(
        {
          ok: false,
          error: "Parent log entry not found for this user",
        } satisfies LogSessionApiResponse,
        { status: 400 }
      )
    }
  }

  const row = toLogEntriesUpdateRow(payload)
  const { data, error } = await supabase
    .from("log_entries")
    .update(row)
    .eq("id", payload.id)
    .select()
    .single()

  if (error) {
    const status = error.code === "PGRST116" ? 404 : 500
    return NextResponse.json(
      {
        ok: false,
        error: error.message,
      } satisfies LogSessionApiResponse,
      { status }
    )
  }

  return NextResponse.json({
    ok: true,
    entry: data as Record<string, unknown>,
  } satisfies LogSessionApiResponse)
}
