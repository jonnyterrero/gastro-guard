"use client"

import { useState, useEffect, useCallback } from "react"
import type { User } from "@supabase/supabase-js"
import { toast } from "sonner"
import { createClient } from "@/lib/supabase/client"
import { fromDbRow, toDbPayload, toDbUpdatePayload } from "@/lib/adapter/log-entry"
import type { LogEntryUI } from "@/lib/adapter/log-entry"
import { triggerFullRefresh } from "@/lib/services/analytics.service"

// ── Form shape expected by the adapter ───────────────────────────────────────
export interface LogFormFields {
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
}

const DB_SELECT =
  "id, entry_at, entry_date, pain_score, stress_score, symptoms, triggers, remedies, notes, meal_name, food_tags, episode_at, meal_occurred_at"

export function useLogEntries(user: User | null) {
  const [entries, setEntries] = useState<LogEntryUI[]>([])
  const [loading, setLoading] = useState(false)

  // ── Load ────────────────────────────────────────────────────────────────────
  const load = useCallback(async () => {
    setLoading(true)
    if (user) {
      const supabase = createClient()
      const { data, error } = await supabase
        .from("log_entries")
        .select("*")
        .order("entry_at", { ascending: false })
      if (error) {
        toast.error("Failed to load entries")
      } else {
        setEntries((data ?? []).map(fromDbRow))
      }
    } else {
      try {
        const saved = localStorage.getItem("gastroguard-entries")
        if (saved) setEntries(JSON.parse(saved))
      } catch {
        /* ignore */
      }
    }
    setLoading(false)
  }, [user?.id]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    void load()
  }, [load])

  // ── Create ──────────────────────────────────────────────────────────────────
  const create = useCallback(
    async (form: LogFormFields): Promise<boolean> => {
      if (!user) {
        // Offline: save to localStorage
        const newEntry: LogEntryUI = {
          id: Date.now().toString(),
          date: new Date().toISOString().split("T")[0],
          time: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
          painLevel: form.painLevel,
          stressLevel: form.stressLevel,
          symptoms: form.selectedSymptoms,
          triggers: form.selectedTriggers,
          remedies: form.selectedRemedies,
          notes: form.notes,
          mealSize: form.mealSize || undefined,
          timeSinceEating: form.timeSinceEating || undefined,
          sleepQuality: form.sleepQuality || undefined,
          exerciseLevel: form.exerciseLevel || undefined,
          weatherCondition: form.weatherCondition || undefined,
          ingestionTime: form.ingestionTime || undefined,
        }
        setEntries((prev) => {
          const next = [newEntry, ...prev]
          localStorage.setItem("gastroguard-entries", JSON.stringify(next))
          return next
        })
        toast.info("Saved locally — sign in to sync across devices")
        return true
      }

      const supabase = createClient()
      const payload = toDbPayload(form, user.id)
      const { data, error } = await supabase
        .from("log_entries")
        .insert(payload)
        .select(DB_SELECT)
        .single()

      if (error) {
        toast.error("Failed to save: " + error.message)
        return false
      }

      setEntries((prev) => [fromDbRow(data), ...prev])
      toast.success("Entry saved!")
      // Fire analytics refresh in background — don't block the UI
      void triggerFullRefresh(user.id)
      return true
    },
    [user]
  )

  // ── Update ──────────────────────────────────────────────────────────────────
  const update = useCallback(
    async (
      entryId: string,
      form: LogFormFields,
      existing: LogEntryUI
    ): Promise<boolean> => {
      if (!user) return false

      const supabase = createClient()
      const entryAt = existing.entryAtIso ?? new Date().toISOString()
      const entryDate = existing.date ?? new Date().toISOString().split("T")[0]
      const updatePayload = toDbUpdatePayload(form, entryAt, entryDate)

      const { data, error } = await supabase
        .from("log_entries")
        .update(updatePayload)
        .eq("id", entryId)
        .eq("user_id", user.id)
        .select(DB_SELECT)
        .single()

      if (error) {
        toast.error("Failed to update: " + error.message)
        return false
      }

      setEntries((prev) => prev.map((e) => (e.id === entryId ? fromDbRow(data) : e)))
      toast.success("Entry updated!")
      void triggerFullRefresh(user.id)
      return true
    },
    [user]
  )

  // ── Delete ──────────────────────────────────────────────────────────────────
  const remove = useCallback(
    async (entryId: string): Promise<void> => {
      if (!user) {
        setEntries((prev) => {
          const next = prev.filter((e) => e.id !== entryId)
          localStorage.setItem("gastroguard-entries", JSON.stringify(next))
          return next
        })
        return
      }

      const supabase = createClient()
      const { error } = await supabase
        .from("log_entries")
        .delete()
        .eq("id", entryId)
        .eq("user_id", user.id)

      if (error) {
        toast.error("Delete failed: " + error.message)
        return
      }

      setEntries((prev) => prev.filter((e) => e.id !== entryId))
      toast.success("Entry deleted")
      void triggerFullRefresh(user.id)
    },
    [user]
  )

  return { entries, loading, create, update, remove, reload: load }
}
