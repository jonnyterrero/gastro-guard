import { NextRequest, NextResponse } from "next/server"
import { ZodError } from "zod"
import { badRequest, getUserIdFromRequest, serverError, zodErrorDetails } from "@/lib/backend/http"
import { profileSchema, userIdSchema } from "@/lib/backend/schemas"
import { supabaseAdmin } from "@/lib/backend/supabase-admin"
import { fromProfileRow, toProfileRow } from "@/lib/backend/mappers"

export async function GET(request: NextRequest) {
  try {
    const userId = userIdSchema.parse(getUserIdFromRequest(request))
    const data = await supabaseAdmin.maybeSingle<Record<string, unknown>>("profiles", {
      select: "*",
      filters: { id: userId },
      limit: 1,
    })

    return NextResponse.json({ profile: fromProfileRow(data) })
  } catch (error) {
    if (error instanceof ZodError) {
      return badRequest("Invalid request", zodErrorDetails(error))
    }

    return serverError(error instanceof Error ? error.message : undefined)
  }
}

export async function PUT(request: NextRequest) {
  try {
    const userId = userIdSchema.parse(getUserIdFromRequest(request))
    const parsedProfile = profileSchema.parse(await request.json())

    const data = await supabaseAdmin.upsertSingle<Record<string, unknown>>(
      "profiles",
      { id: userId, ...toProfileRow(parsedProfile) },
      "id",
    )

    return NextResponse.json({ profile: fromProfileRow(data) })
  } catch (error) {
    if (error instanceof ZodError) {
      return badRequest("Invalid request", zodErrorDetails(error))
    }

    return serverError(error instanceof Error ? error.message : undefined)
  }
}
