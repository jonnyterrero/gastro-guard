import { z } from "zod"
import { logEntrySchema, profileSchema } from "@/lib/backend/schemas"

type ProfileInput = z.infer<typeof profileSchema>
type LogEntryInput = z.infer<typeof logEntrySchema>

type AnyRecord = Record<string, unknown>

export const toProfileRow = (profile: ProfileInput): AnyRecord => ({
  name: profile.name,
  age: profile.age,
  height: profile.height,
  weight: profile.weight,
  gender: profile.gender,
  conditions: profile.conditions,
  medications: profile.medications,
  allergies: profile.allergies,
  dietary_restrictions: profile.dietaryRestrictions,
  triggers: profile.triggers,
  effective_remedies: profile.effectiveRemedies,
})

export const fromProfileRow = (row: AnyRecord | null) => {
  if (!row) return null

  return {
    id: row.id,
    name: row.name,
    age: row.age,
    height: row.height,
    weight: row.weight,
    gender: row.gender,
    conditions: row.conditions,
    medications: row.medications,
    allergies: row.allergies,
    dietaryRestrictions: row.dietary_restrictions,
    triggers: row.triggers,
    effectiveRemedies: row.effective_remedies,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

export const toLogEntryRow = (entry: Partial<LogEntryInput>): AnyRecord => ({
  date: entry.date,
  time: entry.time,
  pain_level: entry.painLevel,
  stress_level: entry.stressLevel,
  symptoms: entry.symptoms,
  triggers: entry.triggers,
  remedies: entry.remedies,
  remedy_effectiveness: entry.remedyEffectiveness,
  notes: entry.notes,
  meal_size: entry.mealSize,
  time_since_eating: entry.timeSinceEating,
  sleep_quality: entry.sleepQuality,
  exercise_level: entry.exerciseLevel,
  weather_condition: entry.weatherCondition,
  ingestion_time: entry.ingestionTime,
  reflux_severity: entry.refluxSeverity,
  nausea_severity: entry.nauseaSeverity,
  bloating_severity: entry.bloatingSeverity,
  fullness_severity: entry.fullnessSeverity,
  burning_location: entry.burningLocation,
  symptom_start_delay_min: entry.symptomStartDelayMin,
  symptom_duration_min: entry.symptomDurationMin,
  suspected_foods: entry.suspectedFoods,
  tolerated_foods: entry.toleratedFoods,
  medication_taken: entry.medicationTaken,
  medication_effectiveness: entry.medicationEffectiveness,
  medication_side_effects: entry.medicationSideEffects,
  bowel_changes: entry.bowelChanges,
  vomiting: entry.vomiting,
  burping: entry.burping,
  regurgitation: entry.regurgitation,
  hydration_tolerance: entry.hydrationTolerance,
  relief_time_min: entry.reliefTimeMin,
})

export const fromLogEntryRow = (row: AnyRecord) => ({
  id: row.id,
  userId: row.user_id,
  date: row.date,
  time: row.time,
  painLevel: row.pain_level,
  stressLevel: row.stress_level,
  symptoms: row.symptoms,
  triggers: row.triggers,
  remedies: row.remedies,
  remedyEffectiveness: row.remedy_effectiveness,
  notes: row.notes,
  mealSize: row.meal_size,
  timeSinceEating: row.time_since_eating,
  sleepQuality: row.sleep_quality,
  exerciseLevel: row.exercise_level,
  weatherCondition: row.weather_condition,
  ingestionTime: row.ingestion_time,
  refluxSeverity: row.reflux_severity,
  nauseaSeverity: row.nausea_severity,
  bloatingSeverity: row.bloating_severity,
  fullnessSeverity: row.fullness_severity,
  burningLocation: row.burning_location,
  symptomStartDelayMin: row.symptom_start_delay_min,
  symptomDurationMin: row.symptom_duration_min,
  suspectedFoods: row.suspected_foods,
  toleratedFoods: row.tolerated_foods,
  medicationTaken: row.medication_taken,
  medicationEffectiveness: row.medication_effectiveness,
  medicationSideEffects: row.medication_side_effects,
  bowelChanges: row.bowel_changes,
  vomiting: row.vomiting,
  burping: row.burping,
  regurgitation: row.regurgitation,
  hydrationTolerance: row.hydration_tolerance,
  reliefTimeMin: row.relief_time_min,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
})
