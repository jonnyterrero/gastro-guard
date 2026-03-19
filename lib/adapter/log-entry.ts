/**
 * Adapter: UI LogEntry <-> Supabase log_entries
 */

import type { LogEntryDb } from "@/lib/types/log-entry"

export interface LogEntryUI {
  id: string
  date: string
  time: string
  painLevel: number
  stressLevel: number
  symptoms: string[]
  triggers: string[]
  remedies: string[]
  notes: string
  mealSize?: string
  timeSinceEating?: number
  sleepQuality?: number
  exerciseLevel?: number
  weatherCondition?: string
  ingestionTime?: string
}

/** Convert UI form state to DB insert payload */
export function toDbPayload(
  form: {
    painLevel: number
    stressLevel: number
    selectedSymptoms: string[]
    selectedTriggers: string[]
    selectedRemedies: string[]
    notes: string
    mealSize: string
    timeSinceEating: number
    sleepQuality: number
    exerciseLevel: number
    weatherCondition: string
    ingestionTime: string
  },
  userId: string
): Omit<LogEntryDb, "id" | "created_at" | "updated_at"> {
  const now = new Date()
  const entryDate = now.toISOString().split("T")[0]
  const entryAt = now.toISOString()

  const mealNotes: string[] = []
  if (form.timeSinceEating > 0) mealNotes.push(`${form.timeSinceEating}h since eating`)
  if (form.sleepQuality > 0) mealNotes.push(`Sleep quality: ${form.sleepQuality}/10`)
  if (form.exerciseLevel > 0) mealNotes.push(`Exercise: ${form.exerciseLevel}/10`)
  if (form.weatherCondition) mealNotes.push(`Weather: ${form.weatherCondition}`)
  if (form.ingestionTime) mealNotes.push(`Ingestion: ${form.ingestionTime}`)

  return {
    user_id: userId,
    entry_at: entryAt,
    entry_date: entryDate,
    pain_score: form.painLevel,
    stress_score: form.stressLevel,
    nausea_score: null,
    meal_name: form.mealSize || null,
    meal_notes: mealNotes.length > 0 ? mealNotes.join("; ") : null,
    symptoms: form.selectedSymptoms,
    triggers: form.selectedTriggers,
    remedies: form.selectedRemedies,
    notes: form.notes || null,
  }
}

/** Convert DB row to UI LogEntry */
export function fromDbRow(row: {
  id: string
  entry_at: string
  entry_date: string
  pain_score: number
  stress_score: number
  symptoms: string[] | unknown
  triggers: string[] | unknown
  remedies: string[] | unknown
  notes: string | null
  meal_name: string | null
}): LogEntryUI {
  const entryDate = new Date(row.entry_at)
  const timeStr = entryDate.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })

  const parseArray = (val: unknown): string[] => {
    if (Array.isArray(val)) return val.map((v) => (typeof v === "string" ? v : (v as { name?: string })?.name ?? String(v)))
    return []
  }

  return {
    id: row.id,
    date: row.entry_date,
    time: timeStr,
    painLevel: row.pain_score,
    stressLevel: row.stress_score,
    symptoms: parseArray(row.symptoms),
    triggers: parseArray(row.triggers),
    remedies: parseArray(row.remedies),
    notes: row.notes ?? "",
    mealSize: row.meal_name ?? undefined,
  }
}
