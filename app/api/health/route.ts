import { NextResponse } from "next/server"

export async function GET() {
  return NextResponse.json({ ok: true, service: "gastro-guard-api", timestamp: new Date().toISOString() })
}
