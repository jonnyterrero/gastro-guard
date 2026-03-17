import type { LogEntry } from "./types"

export type InsightConfidence = "low" | "medium" | "high"
export type InsightType =
  | "motility"
  | "acid"
  | "bile"
  | "food_tolerance"
  | "medication"
  | "stress"
  | "timing"

export interface InsightResult {
  title: string
  description: string
  confidence: InsightConfidence
  type: InsightType
}

// --- Helper analytics functions ---

export function getTopToleratedFoods(logs: LogEntry[], minCount = 2): { food: string; count: number }[] {
  const counts: Record<string, number> = {}
  for (const log of logs) {
    for (const food of log.toleratedFoods || []) {
      const key = food.trim().toLowerCase()
      if (key) counts[key] = (counts[key] || 0) + 1
    }
  }
  return Object.entries(counts)
    .filter(([, c]) => c >= minCount)
    .map(([food, count]) => ({ food, count }))
    .sort((a, b) => b.count - a.count)
}

export function getTopSuspectedTriggers(logs: LogEntry[], minCount = 2): { trigger: string; count: number }[] {
  const counts: Record<string, number> = {}
  for (const log of logs) {
    for (const t of log.suspectedFoods || log.triggers || []) {
      const key = String(t).trim().toLowerCase()
      if (key) counts[key] = (counts[key] || 0) + 1
    }
  }
  return Object.entries(counts)
    .filter(([, c]) => c >= minCount)
    .map(([trigger, count]) => ({ trigger, count }))
    .sort((a, b) => b.count - a.count)
}

export function getHelpfulMedications(logs: LogEntry[]): { name: string; avgEffectiveness: number; count: number }[] {
  const byMed: Record<string, { sum: number; count: number }> = {}
  for (const log of logs) {
    const eff = log.medicationEffectiveness || {}
    for (const [name, score] of Object.entries(eff)) {
      if (score >= 6) {
        const key = name.trim().toLowerCase()
        if (!byMed[key]) byMed[key] = { sum: 0, count: 0 }
        byMed[key].sum += score
        byMed[key].count += 1
      }
    }
  }
  return Object.entries(byMed)
    .filter(([, v]) => v.count >= 2)
    .map(([name, v]) => ({ name, avgEffectiveness: v.sum / v.count, count: v.count }))
    .sort((a, b) => b.avgEffectiveness - a.avgEffectiveness)
}

export function getUnhelpfulMedications(logs: LogEntry[]): { name: string; avgEffectiveness: number; count: number }[] {
  const byMed: Record<string, { sum: number; count: number }> = {}
  for (const log of logs) {
    const eff = log.medicationEffectiveness || {}
    for (const [name, score] of Object.entries(eff)) {
      const key = name.trim().toLowerCase()
      if (!byMed[key]) byMed[key] = { sum: 0, count: 0 }
      byMed[key].sum += score
      byMed[key].count += 1
    }
  }
  return Object.entries(byMed)
    .filter(([, v]) => v.count >= 2)
    .map(([name, v]) => ({ name, avgEffectiveness: v.sum / v.count, count: v.count }))
    .filter((m) => m.avgEffectiveness < 5)
    .sort((a, b) => a.avgEffectiveness - b.avgEffectiveness)
}

export function getAverageSymptomDelay(logs: LogEntry[]): number | null {
  const delays = logs
    .map((l) => l.symptomStartDelayMin)
    .filter((d): d is number => typeof d === "number" && d >= 0)
  if (delays.length === 0) return null
  return Math.round(delays.reduce((a, b) => a + b, 0) / delays.length)
}

export function getMostCommonSymptoms(logs: LogEntry[]): { symptom: string; count: number }[] {
  const counts: Record<string, number> = {}
  for (const log of logs) {
    for (const s of log.symptoms || []) {
      const key = s.trim().toLowerCase()
      if (key) counts[key] = (counts[key] || 0) + 1
    }
  }
  return Object.entries(counts)
    .map(([symptom, count]) => ({ symptom, count }))
    .sort((a, b) => b.count - a.count)
}

// --- Rule-based insight generation ---

export function generateInsights(logs: LogEntry[]): InsightResult[] {
  const insights: InsightResult[] = []

  if (logs.length < 2) return insights

  // Antacid ineffectiveness pattern
  const antacidEntries = logs.filter((l) => {
    const meds = l.medicationTaken || []
    const eff = l.medicationEffectiveness || {}
    return meds.some((m) => /tums|antacid|calcium carbonate|gaviscon/i.test(m)) && Object.keys(eff).length > 0
  })
  if (antacidEntries.length >= 2) {
    const lowEffCount = antacidEntries.filter((l) => {
      const eff = l.medicationEffectiveness || {}
      const antacidKey = Object.keys(eff).find((k) => /tums|antacid|calcium carbonate|gaviscon/i.test(k))
      return antacidKey && eff[antacidKey] <= 3
    }).length
    if (lowEffCount >= 2) {
      insights.push({
        title: "Acid-neutralizing remedies may not be helping",
        description:
          "Your logs suggest acid-neutralizing remedies (e.g., Tums, antacids) appear ineffective in several entries. This pattern may suggest symptoms are not primarily driven by excess acid. Worth discussing with a clinician.",
        confidence: lowEffCount >= 3 ? "high" : "medium",
        type: "acid",
      })
    }
  }

  // Delayed digestion pattern
  const delayedEntries = logs.filter(
    (l) =>
      (l.symptomStartDelayMin ?? 0) >= 60 &&
      ((l.nauseaSeverity ?? 0) >= 5 || (l.fullnessSeverity ?? 0) >= 5)
  )
  if (delayedEntries.length >= 2) {
    insights.push({
      title: "Pattern resembles delayed digestion",
      description: `Symptoms often begin 1+ hours after eating with notable nausea or fullness in ${delayedEntries.length} entries. This may suggest a motility-related pattern. Worth discussing with a clinician.`,
      confidence: delayedEntries.length >= 4 ? "high" : "medium",
      type: "motility",
    })
  }

  // Stress-linked flare pattern
  const highStressEntries = logs.filter((l) => (l.stressLevel ?? 0) >= 6)
  const highStressWithSymptoms = highStressEntries.filter(
    (l) =>
      (l.painLevel ?? 0) >= 5 ||
      (l.nauseaSeverity ?? 0) >= 5 ||
      (l.refluxSeverity ?? 0) >= 5
  )
  if (highStressWithSymptoms.length >= 2 && highStressEntries.length >= 2) {
    insights.push({
      title: "Stress may be amplifying GI symptoms",
      description: `High stress entries frequently align with higher pain, nausea, or reflux. This pattern appears in ${highStressWithSymptoms.length} of your logs. Stress reduction techniques may be worth exploring.`,
      confidence: highStressWithSymptoms.length >= 4 ? "high" : "medium",
      type: "stress",
    })
  }

  // Food tolerance pattern
  const tolerated = getTopToleratedFoods(logs)
  if (tolerated.length >= 1) {
    const top = tolerated.slice(0, 3).map((t) => t.food)
    insights.push({
      title: "Foods that appear better tolerated",
      description: `${top.join(", ")} ${top.length === 1 ? "appears" : "appear"} better tolerated in your logs. These are observational patterns, not medical advice.`,
      confidence: tolerated[0].count >= 3 ? "medium" : "low",
      type: "food_tolerance",
    })
  }

  // Food trigger pattern
  const triggers = getTopSuspectedTriggers(logs)
  const highSeverityLogs = logs.filter((l) => (l.painLevel ?? 0) >= 5 || (l.refluxSeverity ?? 0) >= 5)
  const triggerInHighSeverity: Record<string, number> = {}
  for (const log of highSeverityLogs) {
    for (const t of log.suspectedFoods || log.triggers || []) {
      const key = String(t).trim().toLowerCase()
      if (key) triggerInHighSeverity[key] = (triggerInHighSeverity[key] || 0) + 1
    }
  }
  const likelyTriggers = Object.entries(triggerInHighSeverity)
    .filter(([, c]) => c >= 2)
    .sort((a, b) => b[1] - a[1])
  if (likelyTriggers.length >= 1) {
    const names = likelyTriggers.slice(0, 3).map(([n]) => n)
    insights.push({
      title: "Possible symptom triggers",
      description: `${names.join(", ")} ${names.length === 1 ? "appears" : "appear"} in entries with higher symptom severity. These may be worth avoiding or tracking more closely.`,
      confidence: likelyTriggers[0][1] >= 3 ? "medium" : "low",
      type: "food_tolerance",
    })
  }

  // Medication response pattern - unhelpful
  const unhelpful = getUnhelpfulMedications(logs)
  if (unhelpful.length >= 1) {
    const names = unhelpful.slice(0, 2).map((m) => m.name)
    insights.push({
      title: "Some medications appear ineffective",
      description: `${names.join(" and ")} ${names.length === 1 ? "has" : "have"} low effectiveness scores in several entries. This pattern may suggest they are not addressing your symptoms well. Worth discussing with a clinician.`,
      confidence: "medium",
      type: "medication",
    })
  }

  // Medication response pattern - helpful
  const helpful = getHelpfulMedications(logs)
  if (helpful.length >= 1 && (unhelpful.length === 0 || helpful[0].avgEffectiveness > (unhelpful[0]?.avgEffectiveness ?? 0))) {
    const names = helpful.slice(0, 2).map((m) => m.name)
    insights.push({
      title: "Medications that appear more helpful",
      description: `${names.join(" and ")} ${names.length === 1 ? "appears" : "appear"} more effective in your logs. These are observational patterns, not medical advice.`,
      confidence: "medium",
      type: "medication",
    })
  }

  // Timing pattern
  const avgDelay = getAverageSymptomDelay(logs)
  if (avgDelay != null && avgDelay >= 60 && avgDelay <= 180) {
    const min = Math.floor(avgDelay / 60)
    const max = Math.ceil(avgDelay / 60) + 1
    insights.push({
      title: "Symptoms often begin in a consistent window after eating",
      description: `Your logs suggest symptoms often start around ${min}-${max} hours after meals. This timing pattern may be worth discussing with a clinician.`,
      confidence: "medium",
      type: "timing",
    })
  }

  return insights
}
