import { z } from "zod"

export const userIdSchema = z.string().min(1, "Missing user id")

export const profileSchema = z.object({
  name: z.string().trim().default(""),
  age: z.number().int().min(0).max(130).default(0),
  height: z.string().trim().default(""),
  weight: z.string().trim().default(""),
  gender: z.string().trim().default(""),
  conditions: z.array(z.string()).default([]),
  medications: z.array(z.string()).default([]),
  allergies: z.array(z.string()).default([]),
  dietaryRestrictions: z.array(z.string()).default([]),
  triggers: z.array(z.string()).default([]),
  effectiveRemedies: z.array(z.string()).default([]),
})

export const logEntrySchema = z.object({
  date: z.string().datetime().or(z.string().min(1)),
  time: z.string().min(1),
  painLevel: z.number().int().min(0).max(10),
  stressLevel: z.number().int().min(0).max(10),
  symptoms: z.array(z.string()).default([]),
  triggers: z.array(z.string()).default([]),
  remedies: z.array(z.string()).default([]),
  remedyEffectiveness: z.number().int().min(0).max(10).optional(),
  notes: z.string().default(""),
  mealSize: z.string().optional(),
  timeSinceEating: z.number().int().min(0).optional(),
  sleepQuality: z.number().int().min(0).max(10).optional(),
  exerciseLevel: z.number().int().min(0).max(10).optional(),
  weatherCondition: z.string().optional(),
  ingestionTime: z.string().optional(),
  refluxSeverity: z.number().int().min(0).max(10).optional(),
  nauseaSeverity: z.number().int().min(0).max(10).optional(),
  bloatingSeverity: z.number().int().min(0).max(10).optional(),
  fullnessSeverity: z.number().int().min(0).max(10).optional(),
  burningLocation: z.enum(["chest", "throat", "stomach", "upper_abdomen"]).optional(),
  symptomStartDelayMin: z.number().int().min(0).optional(),
  symptomDurationMin: z.number().int().min(0).optional(),
  suspectedFoods: z.array(z.string()).optional(),
  toleratedFoods: z.array(z.string()).optional(),
  medicationTaken: z.array(z.string()).optional(),
  medicationEffectiveness: z.record(z.string(), z.number().int().min(0).max(10)).optional(),
  medicationSideEffects: z.record(z.string(), z.array(z.string())).optional(),
  bowelChanges: z.array(z.string()).optional(),
  vomiting: z.boolean().optional(),
  burping: z.boolean().optional(),
  regurgitation: z.boolean().optional(),
  hydrationTolerance: z.enum(["good", "moderate", "poor"]).optional(),
  reliefTimeMin: z.number().int().min(0).optional(),
})

export const logEntryPatchSchema = logEntrySchema.partial()
