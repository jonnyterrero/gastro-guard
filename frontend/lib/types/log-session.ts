/**
 * Canonical write contract for a single GastroGuard log session (orchestrated UX).
 * Maps 1:1 to `log_entries` via lib/log-session/mapToLogEntriesRow.ts.
 */

import type {
  FoodTagItem,
  RemedyItem,
  SymptomItem,
  TriggerItem,
} from "@/lib/types/log-entry"

export type LogSessionKind = "session" | "retroactive" | "follow_up"

/**
 * App → server payload for create (POST /api/log-session).
 * Legacy JSONB arrays (symptoms, triggers, remedies, food_tags) are the sync SoT;
 * optional *_labels mirror for v3; when omitted, server copies from legacy arrays.
 */
export interface LogSessionWritePayload {
  kind?: LogSessionKind
  /** Required when kind === 'follow_up'; parent log_entries.id */
  follow_up_of_entry_id?: string | null

  pain: number
  stress: number
  nausea?: number | null

  meal_name?: string | null
  meal_notes?: string | null
  meal_size?: string | null
  meal_occurred_at?: string | null
  time_since_eating_minutes?: number | null

  symptoms: SymptomItem[]
  triggers: TriggerItem[]
  remedies: RemedyItem[]
  food_tags: FoodTagItem[]

  symptom_labels?: SymptomItem[] | null
  trigger_labels?: TriggerItem[] | null
  remedy_labels?: RemedyItem[] | null
  food_tag_labels?: FoodTagItem[] | null

  sleep_quality?: number | null
  sleep_hours?: number | null
  exercise_level?: number | null
  weather_condition?: string | null

  notes?: string | null

  /** Default 'app'; follow-ups stored as source 'follow_up' */
  source?: string
  source_id?: string | null

  /** ISO timestamps; optional for kind session (server defaults to now / today) */
  entry_at?: string | null
  entry_date?: string | null
  episode_at?: string | null
}

/** Update (PATCH): same fields plus target row id */
export interface LogSessionUpdatePayload extends LogSessionWritePayload {
  id: string
}

export type LogSessionApiSuccess = {
  ok: true
  entry: Record<string, unknown>
}

export type LogSessionApiError = {
  ok: false
  error: string
  details?: string[]
}

export type LogSessionApiResponse = LogSessionApiSuccess | LogSessionApiError
