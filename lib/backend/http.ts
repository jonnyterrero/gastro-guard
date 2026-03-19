import { NextRequest, NextResponse } from "next/server"
import { ZodError } from "zod"

export const getUserIdFromRequest = (request: NextRequest) => {
  return request.headers.get("x-user-id") ?? ""
}

export const badRequest = (message: string, details?: unknown) => {
  return NextResponse.json({ error: message, details }, { status: 400 })
}

export const serverError = (message = "Internal server error") => {
  return NextResponse.json({ error: message }, { status: 500 })
}

export const zodErrorDetails = (error: ZodError) => {
  return error.issues.map((issue) => ({
    path: issue.path.join("."),
    message: issue.message,
  }))
}
