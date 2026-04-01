/**
 * Validates JSON bodies for POST/PATCH /api/log-session.
 */

import type {
  FoodTagItem,
  RemedyItem,
  SymptomItem,
  TriggerItem,
} from "@/lib/types/log-entry"
import type { LogSessionKind, LogSessionWritePayload } from "@/lib/types/log-session"

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function isUuid(value: string): boolean {
  return UUID_RE.test(value)
}

function clampScore0to10(n: number): number {
  return Math.max(0, Math.min(10, Math.round(n)))
}

function asArray<T>(v: unknown, field: string, errors: string[]): T[] {
  if (v === undefined || v === null) return []
  if (!Array.isArray(v)) {
    errors.push(`${field} must be an array`)
    return []
  }
  return v as T[]
}

function optionalNumber(
  v: unknown,
  field: string,
  errors: string[],
  opts?: { min?: number; max?: number; integer?: boolean }
): number | null | undefined {
  if (v === undefined || v === null) return v === null ? null : undefined
  const n = typeof v === "number" ? v : Number(v)
  if (!Number.isFinite(n)) {
    errors.push(`${field} must be a number`)
    return undefined
  }
  let x = n
  if (opts?.integer) x = Math.round(x)
  if (opts?.min !== undefined && x < opts.min) {
    errors.push(`${field} must be >= ${opts.min}`)
  }
  if (opts?.max !== undefined && x > opts.max) {
    errors.push(`${field} must be <= ${opts.max}`)
  }
  return x
}

function requiredScore(
  v: unknown,
  field: string,
  errors: string[]
): number | undefined {
  if (v === undefined || v === null) {
    errors.push(`${field} is required`)
    return undefined
  }
  const n = typeof v === "number" ? v : Number(v)
  if (!Number.isFinite(n)) {
    errors.push(`${field} must be a number`)
    return undefined
  }
  const x = clampScore0to10(n)
  if (n < 0 || n > 10) {
    errors.push(`${field} must be between 0 and 10`)
  }
  return x
}

function parseKind(v: unknown, errors: string[]): LogSessionKind {
  if (v === undefined || v === null) return "session"
  if (v === "session" || v === "retroactive" || v === "follow_up") return v
  errors.push('kind must be "session", "retroactive", or "follow_up"')
  return "session"
}

/**
 * Validates a create payload. Returns normalized payload or errors.
 */
export function validateLogSessionWrite(
  body: unknown
):
  | { ok: true; payload: LogSessionWritePayload }
  | { ok: false; errors: string[] } {
  const errors: string[] = []
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, errors: ["Request body must be a JSON object"] }
  }

  const raw = body as Record<string, unknown>
  const kind = parseKind(raw.kind, errors)

  const followRaw = raw.follow_up_of_entry_id
  const follow_up_of_entry_id =
    followRaw === undefined || followRaw === null
      ? null
      : typeof followRaw === "string"
        ? followRaw
        : (errors.push("follow_up_of_entry_id must be a string"), null)

  if (kind === "follow_up") {
    if (!follow_up_of_entry_id) {
      errors.push("follow_up_of_entry_id is required when kind is follow_up")
    } else if (!isUuid(follow_up_of_entry_id)) {
      errors.push("follow_up_of_entry_id must be a valid UUID")
    }
  } else if (follow_up_of_entry_id && !isUuid(follow_up_of_entry_id)) {
    errors.push("follow_up_of_entry_id must be a valid UUID when provided")
  }

  const pain = requiredScore(raw.pain, "pain", errors)
  const stress = requiredScore(raw.stress, "stress", errors)

  let nausea: number | null | undefined
  if (raw.nausea !== undefined && raw.nausea !== null) {
    const n = optionalNumber(raw.nausea, "nausea", errors, {
      min: 0,
      max: 10,
    })
    if (n !== undefined && n !== null) nausea = clampScore0to10(n)
  }

  const symptoms = asArray<SymptomItem>(raw.symptoms, "symptoms", errors)
  const triggers = asArray<TriggerItem>(raw.triggers, "triggers", errors)
  const remedies = asArray<RemedyItem>(raw.remedies, "remedies", errors)
  const food_tags = asArray<FoodTagItem>(raw.food_tags, "food_tags", errors)

  const symptom_labels = raw.symptom_labels
  const trigger_labels = raw.trigger_labels
  const remedy_labels = raw.remedy_labels
  const food_tag_labels = raw.food_tag_labels

  if (symptom_labels !== undefined && symptom_labels !== null) {
    if (!Array.isArray(symptom_labels))
      errors.push("symptom_labels must be an array")
  }
  if (trigger_labels !== undefined && trigger_labels !== null) {
    if (!Array.isArray(trigger_labels))
      errors.push("trigger_labels must be an array")
  }
  if (remedy_labels !== undefined && remedy_labels !== null) {
    if (!Array.isArray(remedy_labels))
      errors.push("remedy_labels must be an array")
  }
  if (food_tag_labels !== undefined && food_tag_labels !== null) {
    if (!Array.isArray(food_tag_labels))
      errors.push("food_tag_labels must be an array")
  }

  const meal_name =
    raw.meal_name === undefined || raw.meal_name === null
      ? null
      : String(raw.meal_name)
  const meal_notes =
    raw.meal_notes === undefined || raw.meal_notes === null
      ? null
      : String(raw.meal_notes)
  const meal_size =
    raw.meal_size === undefined || raw.meal_size === null
      ? null
      : String(raw.meal_size)
  const meal_occurred_at =
    raw.meal_occurred_at === undefined || raw.meal_occurred_at === null
      ? null
      : String(raw.meal_occurred_at)
  const time_since_eating_minutes =
    raw.time_since_eating_minutes === undefined ||
    raw.time_since_eating_minutes === null
      ? null
      : optionalNumber(
          raw.time_since_eating_minutes,
          "time_since_eating_minutes",
          errors,
          { min: 0, integer: true }
        ) ?? null

  const sleep_quality =
    raw.sleep_quality === undefined || raw.sleep_quality === null
      ? null
      : optionalNumber(raw.sleep_quality, "sleep_quality", errors, {
          min: 0,
          max: 10,
          integer: true,
        }) ?? null
  const sleep_hours =
    raw.sleep_hours === undefined || raw.sleep_hours === null
      ? null
      : optionalNumber(raw.sleep_hours, "sleep_hours", errors, { min: 0 }) ??
        null
  const exercise_level =
    raw.exercise_level === undefined || raw.exercise_level === null
      ? null
      : optionalNumber(raw.exercise_level, "exercise_level", errors, {
          min: 0,
          max: 10,
          integer: true,
        }) ?? null
  const weather_condition =
    raw.weather_condition === undefined || raw.weather_condition === null
      ? null
      : String(raw.weather_condition)

  const notes =
    raw.notes === undefined || raw.notes === null ? null : String(raw.notes)

  const source =
    raw.source === undefined || raw.source === null
      ? undefined
      : String(raw.source)
  const source_id =
    raw.source_id === undefined || raw.source_id === null
      ? null
      : String(raw.source_id)

  const entry_at =
    raw.entry_at === undefined || raw.entry_at === null
      ? null
      : String(raw.entry_at)
  const entry_date =
    raw.entry_date === undefined || raw.entry_date === null
      ? null
      : String(raw.entry_date)
  const episode_at =
    raw.episode_at === undefined || raw.episode_at === null
      ? null
      : String(raw.episode_at)

  if (kind === "retroactive") {
    if (!entry_at && !entry_date) {
      errors.push(
        "retroactive sessions require entry_at and/or entry_date (past time)"
      )
    }
  }

  if (errors.length > 0) return { ok: false, errors }

  const payload: LogSessionWritePayload = {
    kind,
    follow_up_of_entry_id: follow_up_of_entry_id ?? undefined,
    pain: pain!,
    stress: stress!,
    nausea: nausea ?? undefined,
    symptoms,
    triggers,
    remedies,
    food_tags,
    symptom_labels:
      symptom_labels === undefined
        ? undefined
        : (symptom_labels as SymptomItem[] | null),
    trigger_labels:
      trigger_labels === undefined
        ? undefined
        : (trigger_labels as TriggerItem[] | null),
    remedy_labels:
      remedy_labels === undefined
        ? undefined
        : (remedy_labels as RemedyItem[] | null),
    food_tag_labels:
      food_tag_labels === undefined
        ? undefined
        : (food_tag_labels as FoodTagItem[] | null),
    meal_name,
    meal_notes,
    meal_size,
    meal_occurred_at,
    time_since_eating_minutes,
    sleep_quality,
    sleep_hours,
    exercise_level,
    weather_condition,
    notes,
    source,
    source_id,
    entry_at,
    entry_date,
    episode_at,
  }

  return { ok: true, payload }
}

export function validateLogSessionUpdate(
  body: unknown
):
  | { ok: true; payload: import("@/lib/types/log-session").LogSessionUpdatePayload }
  | { ok: false; errors: string[] } {
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, errors: ["Request body must be a JSON object"] }
  }
  const raw = body as Record<string, unknown>
  const id = raw.id
  if (id === undefined || id === null || typeof id !== "string") {
    return { ok: false, errors: ["id is required for update"] }
  }
  if (!isUuid(id)) {
    return { ok: false, errors: ["id must be a valid UUID"] }
  }

  const base = validateLogSessionWrite(body)
  if (!base.ok) return base

  return {
    ok: true,
    payload: { ...base.payload, id },
  }
}
