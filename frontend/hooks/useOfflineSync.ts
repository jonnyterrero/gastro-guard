"use client"

import { useState, useEffect, useCallback } from "react"
import type { User } from "@supabase/supabase-js"
import { toast } from "sonner"
import { createClient } from "@/lib/supabase/client"
import type { LogEntryUI } from "@/lib/adapter/log-entry"

/**
 * Detects local-only log entries and provides a sync function
 * that migrates them to Supabase after login.
 *
 * Usage:
 *   const { pendingCount, syncLocalEntries, dismissSync } = useOfflineSync(user)
 *
 * Show a banner when pendingCount > 0, offering to sync or dismiss.
 */
export function useOfflineSync(user: User | null) {
  const [pendingCount, setPendingCount] = useState(0)

  // Detect pending local entries when user signs in
  useEffect(() => {
    if (!user) return
    try {
      const raw = localStorage.getItem("gastroguard-entries")
      if (!raw) return
      const local: LogEntryUI[] = JSON.parse(raw)
      if (local.length > 0) setPendingCount(local.length)
    } catch {
      /* ignore */
    }
  }, [user?.id]) // eslint-disable-line react-hooks/exhaustive-deps

  /**
   * Upload all locally stored entries to Supabase.
   * Entries that succeed are removed from localStorage.
   * Simple conflict strategy: local always wins (insert only).
   */
  const syncLocalEntries = useCallback(async (): Promise<number> => {
    if (!user) return 0

    let raw: string | null = null
    try {
      raw = localStorage.getItem("gastroguard-entries")
    } catch {
      return 0
    }
    if (!raw) return 0

    let local: LogEntryUI[]
    try {
      local = JSON.parse(raw)
    } catch {
      return 0
    }
    if (local.length === 0) return 0

    const supabase = createClient()
    let synced = 0

    for (const entry of local) {
      const hours = entry.timeSinceEating
      const payload = {
        user_id: user.id,
        entry_at: entry.entryAtIso ?? `${entry.date}T12:00:00Z`,
        entry_date: entry.date,
        pain_score: entry.painLevel,
        stress_score: entry.stressLevel,
        symptoms: entry.symptoms,
        triggers: entry.triggers,
        remedies: entry.remedies,
        notes: entry.notes || null,
        meal_name: entry.mealSize || null,
        meal_size: entry.mealSize || null,
        time_since_eating_minutes:
          hours != null && hours > 0 ? Math.round(hours * 60) : null,
        sleep_quality: entry.sleepQuality != null && entry.sleepQuality > 0 ? entry.sleepQuality : null,
        exercise_level:
          entry.exerciseLevel != null && entry.exerciseLevel > 0 ? entry.exerciseLevel : null,
        weather_condition: entry.weatherCondition || null,
        source: "offline_sync",
        sync_status: "synced",
        meal_notes: [
          entry.timeSinceEating ? `${entry.timeSinceEating}h since eating` : null,
          entry.sleepQuality ? `Sleep: ${entry.sleepQuality}/10` : null,
          entry.weatherCondition ? `Weather: ${entry.weatherCondition}` : null,
        ]
          .filter(Boolean)
          .join("; ") || null,
      }
      const { error } = await supabase.from("log_entries").insert(payload)
      if (!error) synced++
    }

    if (synced > 0) {
      localStorage.removeItem("gastroguard-entries")
      setPendingCount(0)
      toast.success(`Synced ${synced} offline entr${synced === 1 ? "y" : "ies"} to cloud`)
    }

    if (synced < local.length) {
      toast.warning(`${local.length - synced} entries could not be synced`)
    }

    return synced
  }, [user])

  /** Discard local entries without uploading (user chose to start fresh). */
  const dismissSync = useCallback(() => {
    localStorage.removeItem("gastroguard-entries")
    setPendingCount(0)
  }, [])

  return { pendingCount, syncLocalEntries, dismissSync }
}
