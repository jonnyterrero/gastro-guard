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
  symptoms: SymptomItem[]
  triggers: TriggerItem[]
  remedies: RemedyItem[]
  notes?: string | null
  created_at?: string
  updated_at?: string
}

/** String or { name, severity?, notes? } */
export type SymptomItem = string | { name: string; severity?: number; notes?: string }

/** String or { name, notes? } */
export type TriggerItem = string | { name: string; notes?: string }

/** String or { name, helpfulness?, notes? } */
export type RemedyItem = string | { name: string; helpfulness?: number; notes?: string }
