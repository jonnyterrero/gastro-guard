/**
 * Extended LogEntry for GastroGuard symptom tracking.
 * All new fields are optional for backward compatibility.
 */
export interface LogEntry {
  id: string
  date: string
  time: string
  painLevel: number
  stressLevel: number
  symptoms: string[]
  triggers: string[]
  remedies: string[]
  remedyEffectiveness?: number
  notes: string
  mealSize?: string
  timeSinceEating?: number
  sleepQuality?: number
  exerciseLevel?: number
  weatherCondition?: string
  ingestionTime?: string
  // Digestive pattern insights fields
  refluxSeverity?: number
  nauseaSeverity?: number
  bloatingSeverity?: number
  fullnessSeverity?: number
  burningLocation?: "chest" | "throat" | "stomach" | "upper_abdomen"
  symptomStartDelayMin?: number
  symptomDurationMin?: number
  suspectedFoods?: string[]
  toleratedFoods?: string[]
  medicationTaken?: string[]
  medicationEffectiveness?: Record<string, number>
  medicationSideEffects?: Record<string, string[]>
  bowelChanges?: string[]
  vomiting?: boolean
  burping?: boolean
  regurgitation?: boolean
  hydrationTolerance?: "good" | "moderate" | "poor"
  reliefTimeMin?: number
}
