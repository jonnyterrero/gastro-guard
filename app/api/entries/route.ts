import { NextRequest, NextResponse } from "next/server"
import { ZodError } from "zod"
import { badRequest, getUserIdFromRequest, serverError, zodErrorDetails } from "@/lib/backend/http"
import { logEntrySchema, userIdSchema } from "@/lib/backend/schemas"
import { supabaseAdmin } from "@/lib/backend/supabase-admin"
import { fromLogEntryRow, toLogEntryRow } from "@/lib/backend/mappers"

export async function GET(request: NextRequest) {
  try {
    const userId = userIdSchema.parse(getUserIdFromRequest(request))
    const { searchParams } = new URL(request.url)
    const limit = Number(searchParams.get("limit") ?? 200)

    const data = await supabaseAdmin.list<Record<string, unknown>>("log_entries", {
      select: "*",
      filters: { user_id: userId },
      order: { column: "date", ascending: false },
      limit: Math.min(limit, 500),
    })

    return NextResponse.json({ entries: data.map((row) => fromLogEntryRow(row)) })
  } catch (error) {
    if (error instanceof ZodError) {
      return badRequest("Invalid request", zodErrorDetails(error))
    }

    return serverError(error instanceof Error ? error.message : undefined)
  }
}

export async function POST(request: NextRequest) {
  try {
    const userId = userIdSchema.parse(getUserIdFromRequest(request))
    const parsedEntry = logEntrySchema.parse(await request.json())

    const data = await supabaseAdmin.insertSingle<Record<string, unknown>>("log_entries", {
      user_id: userId,
      ...toLogEntryRow(parsedEntry),
    })

    return NextResponse.json({ entry: fromLogEntryRow(data) }, { status: 201 })
  } catch (error) {
    if (error instanceof ZodError) {
      return badRequest("Invalid request", zodErrorDetails(error))
    }

    return serverError(error instanceof Error ? error.message : undefined)
  }
}
