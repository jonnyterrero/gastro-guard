/**
 * DB-compatible LogEntry shape for GastroGuard log_entries table.
 * Use this type when inserting/updating via Supabase client.
 */

export interface LogEntryDb {
  id?: string
  user_id: string
  entry_at: string // ISO 8601 timestamptz
  entry_date: string // YYYY-MM-DD
  pain_score: number
  stress_score: number
  nausea_score?: number | null
  meal_name?: string | null
  meal_notes?: string | null
  /** JSON array of strings or { tag, category?, confidence? }; DB default is [] */
  food_tags?: FoodTagItem[] | unknown
  /** When the GI episode occurred; if omitted, DB uses entry_at */
  episode_at?: string | null
  meal_occurred_at?: string | null
  symptoms: SymptomItem[]
  triggers: TriggerItem[]
  remedies: RemedyItem[]
  notes?: string | null
  created_at?: string
  updated_at?: string
}

/** String or { tag, category?, confidence? } */
export type FoodTagItem = string | { tag: string; category?: string; confidence?: number }

/** String or { name, severity?, notes?, subtype?, body_region?, onset_after_meal_minutes? } */
export type SymptomItem =
  | string
  | {
      name: string
      severity?: number
      notes?: string
      subtype?: string
      body_region?: string
      onset_after_meal_minutes?: number
    }

/** String or { name, notes?, intensity? } */
export type TriggerItem = string | { name: string; notes?: string; intensity?: number }

/** String or { name, helpfulness?, notes?, effectiveness?, effectiveness_score? } */
export type RemedyItem =
  | string
  | {
      name: string
      helpfulness?: number
      notes?: string
      effectiveness?: number
      effectiveness_score?: number
    }
