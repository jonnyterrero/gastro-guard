/**
 * Maps LogSessionWritePayload → log_entries insert/update shapes (flat columns;
 * no packing sleep/weather into meal_notes).
 */

import type { LogSessionKind, LogSessionWritePayload } from "@/lib/types/log-session"

export type LogEntriesInsertRow = Record<string, unknown>

function nowIso(): string {
  return new Date().toISOString()
}

function todayYmd(): string {
  return nowIso().slice(0, 10)
}

/**
 * Resolves entry_at / entry_date from kind + payload.
 * - session / follow_up: default to now/today when omitted.
 * - retroactive: never replaces user-supplied times with "now" when at least one is present.
 */
export function resolveEntryTimes(
  kind: LogSessionKind,
  payload: LogSessionWritePayload
): { entry_at: string; entry_date: string } {
  const { entry_at: ea, entry_date: ed } = payload

  if (kind === "retroactive") {
    if (ea && ed) return { entry_at: ea, entry_date: ed.slice(0, 10) }
    if (ea && !ed) return { entry_at: ea, entry_date: ea.slice(0, 10) }
    if (!ea && ed) {
      const d = ed.slice(0, 10)
      return { entry_at: `${d}T12:00:00.000Z`, entry_date: d }
    }
  }

  if (ea && ed) return { entry_at: ea, entry_date: ed.slice(0, 10) }
  if (ea && !ed) return { entry_at: ea, entry_date: ea.slice(0, 10) }
  if (!ea && ed) {
    const d = ed.slice(0, 10)
    return { entry_at: `${d}T12:00:00.000Z`, entry_date: d }
  }

  const n = nowIso()
  return { entry_at: n, entry_date: todayYmd() }
}

function mirrorLabels(payload: LogSessionWritePayload) {
  const symptom_labels = payload.symptom_labels ?? payload.symptoms
  const trigger_labels = payload.trigger_labels ?? payload.triggers
  const remedy_labels = payload.remedy_labels ?? payload.remedies
  const food_tag_labels = payload.food_tag_labels ?? payload.food_tags
  return { symptom_labels, trigger_labels, remedy_labels, food_tag_labels }
}

function sourceFields(payload: LogSessionWritePayload): {
  source: string
  source_id: string | null
} {
  if (payload.kind === "follow_up" && payload.follow_up_of_entry_id) {
    return {
      source: "follow_up",
      source_id: payload.follow_up_of_entry_id,
    }
  }
  return {
    source: payload.source ?? "app",
    source_id: payload.source_id ?? null,
  }
}

export function toLogEntriesInsertRow(
  userId: string,
  payload: LogSessionWritePayload
): LogEntriesInsertRow {
  const kind = payload.kind ?? "session"
  const { entry_at, entry_date } = resolveEntryTimes(kind, payload)
  const labels = mirrorLabels(payload)
  const { source, source_id } = sourceFields(payload)

  return {
    user_id: userId,
    entry_at,
    entry_date,
    pain_score: payload.pain,
    stress_score: payload.stress,
    nausea_score: payload.nausea ?? null,
    meal_name: payload.meal_name ?? null,
    meal_notes: payload.meal_notes ?? null,
    meal_size: payload.meal_size ?? null,
    meal_occurred_at: payload.meal_occurred_at ?? null,
    time_since_eating_minutes: payload.time_since_eating_minutes ?? null,
    food_tags: payload.food_tags,
    symptoms: payload.symptoms,
    triggers: payload.triggers,
    remedies: payload.remedies,
    symptom_labels: labels.symptom_labels,
    trigger_labels: labels.trigger_labels,
    remedy_labels: labels.remedy_labels,
    food_tag_labels: labels.food_tag_labels,
    notes: payload.notes ?? null,
    sleep_quality: payload.sleep_quality ?? null,
    sleep_hours: payload.sleep_hours ?? null,
    exercise_level: payload.exercise_level ?? null,
    weather_condition: payload.weather_condition ?? null,
    source,
    source_id,
    sync_status: "synced",
    episode_at: payload.episode_at ?? null,
  }
}

/** PATCH: same column set as insert except user_id / id */
export function toLogEntriesUpdateRow(
  payload: LogSessionWritePayload
): LogEntriesInsertRow {
  const kind = payload.kind ?? "session"
  const { entry_at, entry_date } = resolveEntryTimes(kind, payload)
  const labels = mirrorLabels(payload)
  const { source, source_id } = sourceFields(payload)

  return {
    entry_at,
    entry_date,
    pain_score: payload.pain,
    stress_score: payload.stress,
    nausea_score: payload.nausea ?? null,
    meal_name: payload.meal_name ?? null,
    meal_notes: payload.meal_notes ?? null,
    meal_size: payload.meal_size ?? null,
    meal_occurred_at: payload.meal_occurred_at ?? null,
    time_since_eating_minutes: payload.time_since_eating_minutes ?? null,
    food_tags: payload.food_tags,
    symptoms: payload.symptoms,
    triggers: payload.triggers,
    remedies: payload.remedies,
    symptom_labels: labels.symptom_labels,
    trigger_labels: labels.trigger_labels,
    remedy_labels: labels.remedy_labels,
    food_tag_labels: labels.food_tag_labels,
    notes: payload.notes ?? null,
    sleep_quality: payload.sleep_quality ?? null,
    sleep_hours: payload.sleep_hours ?? null,
    exercise_level: payload.exercise_level ?? null,
    weather_condition: payload.weather_condition ?? null,
    source,
    source_id,
    sync_status: "synced",
    episode_at: payload.episode_at ?? null,
  }
}
