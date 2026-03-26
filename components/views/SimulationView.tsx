"use client"

import { useState } from "react"
import { Zap, Brain, BarChart } from "lucide-react"
import type { LogEntryUI } from "@/lib/adapter/log-entry"
import type { UserProfile } from "@/lib/profile"

interface SimulationResult {
  riskLevel: string
  riskScore: number
  predictions: string[]
  recommendations: string[]
}

interface SimulationViewProps {
  entries: LogEntryUI[]
  profile: UserProfile
}

export function SimulationView({ entries, profile }: SimulationViewProps) {
  const [food, setFood] = useState("")
  const [mealSize, setMealSize] = useState("medium")
  const [timeOfDay, setTimeOfDay] = useState("lunch")
  const [results, setResults] = useState<SimulationResult | null>(null)

  const run = () => {
    if (!food.trim()) return

    const relevant = entries.filter((e) => {
      const lower = food.toLowerCase()
      return (
        e.notes.toLowerCase().includes(lower) ||
        e.triggers.some((t) => lower.includes(t.toLowerCase()))
      )
    })

    let riskScore = 0
    const predictions: string[] = []
    const recommendations: string[] = []

    if (relevant.length > 0) {
      const avgPain =
        relevant.reduce((s, e) => s + e.painLevel, 0) / relevant.length
      const avgStress =
        relevant.reduce((s, e) => s + e.stressLevel, 0) / relevant.length

      riskScore = Math.round((avgPain + avgStress) / 2)
      predictions.push(`Based on ${relevant.length} similar entries`)
      predictions.push(`Average pain: ${avgPain.toFixed(1)}/10`)
      predictions.push(`Average stress: ${avgStress.toFixed(1)}/10`)

      const symptomCounts: Record<string, number> = {}
      relevant.forEach((e) =>
        e.symptoms.forEach((s) => {
          symptomCounts[s] = (symptomCounts[s] ?? 0) + 1
        })
      )
      const top = Object.entries(symptomCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([s]) => s)
      if (top.length > 0) predictions.push(`Likely symptoms: ${top.join(", ")}`)
    } else {
      riskScore = 5
      predictions.push("No historical data for this food")
      predictions.push("Risk based on general patterns and your profile")

      const matching = profile.triggers.filter((t) =>
        food.toLowerCase().includes(t.toLowerCase())
      )
      if (matching.length > 0) {
        riskScore += 3
        predictions.push(`⚠️ Known triggers: ${matching.join(", ")}`)
      }
    }

    if (mealSize === "large") { riskScore += 1; predictions.push("Large meal may increase symptoms") }
    if (mealSize === "small") { riskScore -= 1; predictions.push("Small meal may reduce symptoms") }
    if (timeOfDay === "late-night") { riskScore += 2; predictions.push("Late night eating increases GERD risk") }
    if (timeOfDay === "breakfast") { riskScore -= 1; predictions.push("Morning meals typically better tolerated") }

    riskScore = Math.max(0, Math.min(10, riskScore))

    if (riskScore >= 7) {
      recommendations.push("⚠️ High risk — consider avoiding this food")
      recommendations.push("Have antacids ready if you proceed")
      recommendations.push("Eat a much smaller portion")
      recommendations.push("Avoid lying down for 3 hours after eating")
    } else if (riskScore >= 4) {
      recommendations.push("⚠️ Moderate risk — proceed with caution")
      recommendations.push("Eat slowly and chew thoroughly")
      recommendations.push("Have remedies available")
      recommendations.push("Monitor symptoms closely")
    } else {
      recommendations.push("✓ Low risk — should be well tolerated")
      recommendations.push("Still eat mindfully and in moderation")
      recommendations.push("Stay hydrated")
    }

    if (profile.conditions.includes("GERD"))
      recommendations.push("GERD: Avoid lying down for 2–3 hours after")
    if (profile.conditions.includes("IBS"))
      recommendations.push("IBS: Consider FODMAP content")

    setResults({
      riskLevel: riskScore >= 7 ? "High Risk" : riskScore >= 4 ? "Moderate Risk" : "Low Risk",
      riskScore,
      predictions,
      recommendations,
    })
  }

  const relevantForChart = entries.filter((e) => {
    const lower = food.toLowerCase()
    return (
      e.notes.toLowerCase().includes(lower) ||
      e.triggers.some((t) => lower.includes(t.toLowerCase()))
    )
  })

  return (
    <div className="space-y-6">
      {/* Input card */}
      <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
        <div className="flex items-center gap-2 mb-2">
          <Zap className="w-5 h-5 text-yellow-500" />
          <h2 className="text-xl font-semibold">Symptom Simulator</h2>
        </div>
        <p className="text-sm text-gray-500 mb-6">
          Predict how your body might react based on your historical data
        </p>

        <div className="space-y-5">
          <div>
            <label className="text-sm font-medium block mb-1">
              What are you considering eating?
            </label>
            <input
              type="text"
              value={food}
              onChange={(e) => setFood(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && run()}
              placeholder="e.g., Pizza, Spicy curry, Coffee…"
              className="w-full p-3 border border-gray-200 rounded-lg text-sm"
            />
          </div>

          <div>
            <label className="text-sm font-medium block mb-2">Meal Size</label>
            <div className="grid grid-cols-3 gap-2">
              {["small", "medium", "large"].map((s) => (
                <button
                  key={s}
                  onClick={() => setMealSize(s)}
                  className={`p-3 rounded-lg border capitalize text-sm transition-all ${
                    mealSize === s
                      ? "bg-blue-500 text-white border-blue-500"
                      : "bg-white text-gray-700 border-gray-200 hover:border-blue-300"
                  }`}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="text-sm font-medium block mb-2">Time of Day</label>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              {[
                { value: "breakfast", label: "Breakfast" },
                { value: "lunch", label: "Lunch" },
                { value: "dinner", label: "Dinner" },
                { value: "late-night", label: "Late Night" },
              ].map((t) => (
                <button
                  key={t.value}
                  onClick={() => setTimeOfDay(t.value)}
                  className={`p-3 rounded-lg border text-sm transition-all ${
                    timeOfDay === t.value
                      ? "bg-blue-500 text-white border-blue-500"
                      : "bg-white text-gray-700 border-gray-200 hover:border-blue-300"
                  }`}
                >
                  {t.label}
                </button>
              ))}
            </div>
          </div>

          <button
            onClick={run}
            disabled={!food.trim()}
            className="w-full p-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-white rounded-lg font-semibold hover:shadow-lg transform hover:scale-105 transition-all flex items-center justify-center gap-2 disabled:opacity-50 disabled:transform-none"
          >
            <Zap className="w-5 h-5" />
            Run Simulation
          </button>
        </div>
      </div>

      {/* Results */}
      {results && (
        <>
          <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
            <div className="flex items-center gap-2 mb-4">
              <Brain className="w-5 h-5 text-purple-500" />
              <h2 className="text-xl font-semibold">Simulation Results</h2>
            </div>

            <div className="mb-6">
              <span
                className={`inline-flex items-center gap-2 px-4 py-2 rounded-full font-semibold text-lg ${
                  results.riskScore >= 7
                    ? "bg-red-100 text-red-700"
                    : results.riskScore >= 4
                      ? "bg-yellow-100 text-yellow-700"
                      : "bg-green-100 text-green-700"
                }`}
              >
                {results.riskScore}/10 — {results.riskLevel}
              </span>
            </div>

            <div className="space-y-4">
              <div>
                <h3 className="font-semibold mb-2 text-sm">Predictions</h3>
                <div className="space-y-2">
                  {results.predictions.map((p, i) => (
                    <div
                      key={i}
                      className="p-3 bg-blue-50 rounded-lg border-l-4 border-blue-400 text-sm"
                    >
                      {p}
                    </div>
                  ))}
                </div>
              </div>
              <div>
                <h3 className="font-semibold mb-2 text-sm">Recommendations</h3>
                <div className="space-y-2">
                  {results.recommendations.map((r, i) => (
                    <div
                      key={i}
                      className="p-3 bg-purple-50 rounded-lg border-l-4 border-purple-400 text-sm"
                    >
                      {r}
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <p className="text-xs text-gray-500 mt-4 p-3 bg-gray-50 rounded-lg">
              <strong>Note:</strong> This simulation is based on your historical data and
              general patterns. It&apos;s not medical advice. Always consult your healthcare
              provider.
            </p>
          </div>

          {/* Pain timeline chart */}
          <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
            <div className="flex items-center gap-2 mb-4">
              <BarChart className="w-5 h-5 text-blue-500" />
              <h2 className="text-xl font-semibold">Pain Timeline Prediction</h2>
            </div>
            <p className="text-sm text-gray-500 mb-4">
              Predicted pain levels over time after ingestion
            </p>

            <div className="relative h-56">
              {/* Y-axis */}
              <div className="absolute left-0 top-0 bottom-0 w-8 flex flex-col justify-between text-xs text-gray-400">
                {[10, 8, 6, 4, 2, 0].map((v) => (
                  <span key={v}>{v}</span>
                ))}
              </div>
              {/* Chart area */}
              <div className="ml-10 h-full border-l-2 border-b-2 border-gray-200 relative overflow-hidden">
                {/* Grid */}
                {[0, 1, 2, 3, 4, 5].map((i) => (
                  <div
                    key={i}
                    className="absolute left-0 right-0 border-t border-gray-100"
                    style={{ bottom: `${i * 20}%` }}
                  />
                ))}
                {/* Historical dots */}
                {relevantForChart.slice(0, 10).map((e, i) => {
                  const x = ((e.timeSinceEating ?? (i * 0.5)) / 8) * 100
                  const y = (e.painLevel / 10) * 100
                  return (
                    <div
                      key={e.id}
                      className="absolute w-3 h-3 bg-blue-500 rounded-full border-2 border-white shadow"
                      style={{
                        left: `${Math.min(x, 95)}%`,
                        bottom: `${y}%`,
                        transform: "translate(-50%, 50%)",
                      }}
                      title={`Pain: ${e.painLevel}`}
                    />
                  )
                })}
                {/* Predicted curve */}
                <svg className="absolute inset-0 w-full h-full pointer-events-none">
                  <path
                    d={(() => {
                      const r = results.riskScore
                      const pts = []
                      for (let i = 0; i <= 8; i += 0.5) {
                        const x = (i / 8) * 100
                        let y
                        if (i < 0.5) y = (r * 0.3 * (i / 0.5)) / 10
                        else if (i < 2) y = (r * (0.3 + 0.7 * ((i - 0.5) / 1.5))) / 10
                        else if (i < 4) y = (r * (1 - 0.2 * ((i - 2) / 2))) / 10
                        else y = (r * (0.8 - 0.6 * ((i - 4) / 4))) / 10
                        pts.push(`${x},${(1 - y) * 100}`)
                      }
                      return `M ${pts.join(" L ")}`
                    })()}
                    fill="none"
                    stroke="#f59e0b"
                    strokeWidth="2.5"
                    strokeLinecap="round"
                  />
                </svg>
              </div>
              {/* X-axis */}
              <div className="ml-10 mt-1 flex justify-between text-xs text-gray-400">
                <span>0h</span>
                <span>2h</span>
                <span>4h</span>
                <span>6h</span>
                <span>8h</span>
              </div>
            </div>

            {/* Legend */}
            <div className="flex flex-wrap gap-4 justify-center text-xs mt-4">
              <div className="flex items-center gap-1">
                <div className="w-3 h-3 bg-blue-500 rounded-full" />
                <span>Historical</span>
              </div>
              <div className="flex items-center gap-1">
                <div className="w-6 h-0.5 bg-yellow-500" />
                <span>Predicted curve</span>
              </div>
            </div>

            {/* Stats */}
            <div className="mt-4 grid grid-cols-2 sm:grid-cols-4 gap-3">
              {[
                {
                  value: relevantForChart.length,
                  label: "Similar entries",
                  color: "text-blue-600",
                  bg: "bg-blue-50",
                },
                {
                  value: `${results.riskScore}/10`,
                  label: "Peak pain",
                  color: "text-yellow-600",
                  bg: "bg-yellow-50",
                },
                {
                  value: "2–4h",
                  label: "Peak time",
                  color: "text-green-600",
                  bg: "bg-green-50",
                },
                {
                  value: "6–8h",
                  label: "Recovery",
                  color: "text-purple-600",
                  bg: "bg-purple-50",
                },
              ].map(({ value, label, color, bg }) => (
                <div key={label} className={`text-center p-3 ${bg} rounded-lg`}>
                  <div className={`text-xl font-bold ${color}`}>{value}</div>
                  <div className="text-xs text-gray-500">{label}</div>
                </div>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  )
}
