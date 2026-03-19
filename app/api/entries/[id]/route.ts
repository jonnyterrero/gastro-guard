import { NextRequest, NextResponse } from "next/server"
import { ZodError } from "zod"
import { badRequest, getUserIdFromRequest, serverError, zodErrorDetails } from "@/lib/backend/http"
import { logEntryPatchSchema, userIdSchema } from "@/lib/backend/schemas"
import { supabaseAdmin } from "@/lib/backend/supabase-admin"
import { fromLogEntryRow, toLogEntryRow } from "@/lib/backend/mappers"

interface Context {
  params: Promise<{ id: string }>
}

export async function PATCH(request: NextRequest, context: Context) {
  try {
    const userId = userIdSchema.parse(getUserIdFromRequest(request))
    const { id } = await context.params
    const updates = logEntryPatchSchema.parse(await request.json())

    const data = await supabaseAdmin.updateSingle<Record<string, unknown>>(
      "log_entries",
      { id, user_id: userId },
      toLogEntryRow(updates),
    )

    return NextResponse.json({ entry: fromLogEntryRow(data) })
  } catch (error) {
    if (error instanceof ZodError) {
      return badRequest("Invalid request", zodErrorDetails(error))
    }

    return serverError(error instanceof Error ? error.message : undefined)
  }
}

export async function DELETE(request: NextRequest, context: Context) {
  try {
    const userId = userIdSchema.parse(getUserIdFromRequest(request))
    const { id } = await context.params

    await supabaseAdmin.delete("log_entries", { id, user_id: userId })

    return NextResponse.json({ deleted: true })
  } catch (error) {
    if (error instanceof ZodError) {
      return badRequest("Invalid request", zodErrorDetails(error))
    }

    return serverError(error instanceof Error ? error.message : undefined)
  }
}
