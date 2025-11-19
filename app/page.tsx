"use client"

import { useState, useEffect, useMemo } from "react"
import {
  Activity,
  ArrowLeft,
  Save,
  Brain,
  Clock,
  Calendar,
  Heart,
  Home,
  PenTool,
  BarChart,
  Link2,
  Copy,
  RefreshCw,
  Trash2,
  Zap,
} from "lucide-react"

interface LogEntry {
  id: string
  date: string
  time: string
  painLevel: number
  stressLevel: number
  symptoms: string[]
  triggers: string[]
  remedies: string[]
  notes: string
  mealSize?: string
  timeSinceEating?: number
  sleepQuality?: number
  exerciseLevel?: number
  weatherCondition?: string
  ingestionTime?: string
}

interface UserProfile {
  name: string
  age: number
  height: string
  weight: string
  gender: string
  conditions: string[]
  medications: string[]
  allergies: string[]
  dietaryRestrictions: string[]
  triggers: string[]
  effectiveRemedies: string[]
}

interface Integration {
  id: string
  name: string
  apiKey: string
  createdAt: string
  lastUsed?: string
  permissions: string[]
}

export default function GastroGuardApp() {
  const [mounted, setMounted] = useState(false)
  const [currentView, setCurrentView] = useState("dashboard")
  const [entries, setEntries] = useState<LogEntry[]>([])
  const [userProfile, setUserProfile] = useState<UserProfile>({
    name: "",
    age: 0,
    height: "",
    weight: "",
    gender: "",
    conditions: [],
    medications: [],
    allergies: [],
    dietaryRestrictions: [],
    triggers: [],
    effectiveRemedies: [],
  })

  const [integrations, setIntegrations] = useState<Integration[]>([])
  const [showApiKey, setShowApiKey] = useState<string | null>(null)

  const [simulationFood, setSimulationFood] = useState("")
  const [simulationMealSize, setSimulationMealSize] = useState("medium")
  const [simulationTimeOfDay, setSimulationTimeOfDay] = useState("lunch")
  const [simulationResults, setSimulationResults] = useState<{
    riskLevel: string
    riskScore: number
    predictions: string[]
    recommendations: string[]
  } | null>(null)

  const todayEntries = useMemo(() => {
    const today = new Date().toDateString()
    return entries.filter((entry) => new Date(entry.date).toDateString() === today)
  }, [entries])

  const recentEntries = useMemo(() => {
    return entries.slice(-5).reverse()
  }, [entries])

  // Current symptom tracking state
  const [currentPainLevel, setCurrentPainLevel] = useState(0)
  const [currentStressLevel, setCurrentStressLevel] = useState(0)

  // Enhanced logging state
  const [painLevel, setPainLevel] = useState(0)
  const [stressLevel, setStressLevel] = useState(0)
  const [selectedSymptoms, setSelectedSymptoms] = useState<string[]>([])
  const [selectedTriggers, setSelectedTriggers] = useState<string[]>([])
  const [selectedRemedies, setSelectedRemedies] = useState<string[]>([])
  const [notes, setNotes] = useState("")
  const [mealSize, setMealSize] = useState("")
  const [timeSinceEating, setTimeSinceEating] = useState(0)
  const [sleepQuality, setSleepQuality] = useState(5)
  const [exerciseLevel, setExerciseLevel] = useState(0)
  const [weatherCondition, setWeatherCondition] = useState("")
  const [ingestionTime, setIngestionTime] = useState("")

  const symptoms = [
    "Stomach Pain",
    "Nausea",
    "Bloating",
    "Heartburn",
    "Acid Reflux",
    "Indigestion",
    "Cramping",
    "Gas",
    "Diarrhea",
    "Constipation",
    "Loss of Appetite",
    "Vomiting",
    "Belching",
    "Fullness",
  ]

  const triggers = [
    "Spicy Food",
    "Fatty Food",
    "Acidic Food",
    "Dairy",
    "Gluten",
    "Alcohol",
    "Caffeine",
    "Stress",
    "Lack of Sleep",
    "Medication",
    "Large Meal",
    "Eating Late",
    "Smoking",
    "NSAIDs",
  ]

  const remedies = [
    "Antacid",
    "PPI",
    "H2 Blocker",
    "Probiotics",
    "Ginger Tea",
    "Chamomile Tea",
    "Rest",
    "Light Walk",
    "Heat Pad",
    "Deep Breathing",
    "Small Meals",
    "Bland Diet",
    "Hydration",
    "Meditation",
  ]

  const conditions = ["Gastritis", "GERD", "IBS", "Dyspepsia", "Food Sensitivities", "IBD"]
  const weatherOptions = ["Sunny", "Cloudy", "Rainy", "Stormy", "Hot", "Cold", "Humid", "Dry"]
  const genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say", "AMAB", "AFAB"]

  useEffect(() => {
    setMounted(true)
    // Load data from localStorage
    try {
      const savedEntries = localStorage.getItem("gastroguard-entries")
      const savedProfile = localStorage.getItem("gastroguard-profile")
      const savedIntegrations = localStorage.getItem("gastroguard-integrations")

      if (savedEntries) {
        setEntries(JSON.parse(savedEntries))
      }
      if (savedProfile) {
        setUserProfile(JSON.parse(savedProfile))
      }
      if (savedIntegrations) {
        setIntegrations(JSON.parse(savedIntegrations))
      }
    } catch (error) {
      console.error("Error loading saved data:", error)
    }
  }, [])

  const saveEntry = () => {
    const newEntry: LogEntry = {
      id: Date.now().toString(),
      date: new Date().toISOString().split("T")[0],
      time: new Date().toLocaleTimeString(),
      painLevel,
      stressLevel,
      symptoms: selectedSymptoms,
      triggers: selectedTriggers,
      remedies: selectedRemedies,
      notes,
      mealSize,
      timeSinceEating,
      sleepQuality,
      exerciseLevel,
      weatherCondition,
      ingestionTime,
    }

    const updatedEntries = [...entries, newEntry]
    setEntries(updatedEntries)
    localStorage.setItem("gastroguard-entries", JSON.stringify(updatedEntries))

    // Reset form
    setPainLevel(0)
    setStressLevel(0)
    setSelectedSymptoms([])
    setSelectedTriggers([])
    setSelectedRemedies([])
    setNotes("")
    setMealSize("")
    setTimeSinceEating(0)
    setSleepQuality(5)
    setExerciseLevel(0)
    setWeatherCondition("")
    setIngestionTime("")

    alert("Entry saved successfully!")
    setCurrentView("dashboard")
  }

  const saveProfile = () => {
    localStorage.setItem("gastroguard-profile", JSON.stringify(userProfile))
    alert("Profile updated successfully!")
  }

  const generateApiKey = () => {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    let key = "gg_"
    for (let i = 0; i < 32; i++) {
      key += chars.charAt(Math.floor(Math.random() * chars.length))
    }
    return key
  }

  const createIntegration = () => {
    const name = prompt("Enter a name for this integration (e.g., 'My Fitness App', 'Meal Tracker'):")
    if (!name) return

    const newIntegration: Integration = {
      id: Date.now().toString(),
      name,
      apiKey: generateApiKey(),
      createdAt: new Date().toISOString(),
      permissions: ["read:entries", "write:entries", "read:profile", "read:analytics"],
    }

    const updatedIntegrations = [...integrations, newIntegration]
    setIntegrations(updatedIntegrations)
    localStorage.setItem("gastroguard-integrations", JSON.stringify(updatedIntegrations))
    alert(`Integration "${name}" created successfully!`)
  }

  const regenerateApiKey = (integrationId: string) => {
    if (!confirm("Are you sure you want to regenerate this API key? The old key will stop working.")) return

    const updatedIntegrations = integrations.map((integration) =>
      integration.id === integrationId ? { ...integration, apiKey: generateApiKey() } : integration,
    )
    setIntegrations(updatedIntegrations)
    localStorage.setItem("gastroguard-integrations", JSON.stringify(updatedIntegrations))
    alert("API key regenerated successfully!")
  }

  const deleteIntegration = (integrationId: string) => {
    if (!confirm("Are you sure you want to delete this integration? This action cannot be undone.")) return

    const updatedIntegrations = integrations.filter((integration) => integration.id !== integrationId)
    setIntegrations(updatedIntegrations)
    localStorage.setItem("gastroguard-integrations", JSON.stringify(updatedIntegrations))
    alert("Integration deleted successfully!")
  }

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
    alert("Copied to clipboard!")
  }

  const getPersonalizedRecommendations = () => {
    if (!userProfile.name) {
      return ["Please complete your profile first to get personalized recommendations."]
    }

    const recommendations = []

    // Pain level based recommendations
    if (currentPainLevel >= 7) {
      recommendations.push("Consider taking your prescribed PPI or antacid")
      recommendations.push("Try gentle breathing exercises to manage severe pain")
      recommendations.push("Avoid solid foods until pain subsides")
    } else if (currentPainLevel >= 4) {
      recommendations.push("Consider a light, bland meal if you haven't eaten")
      recommendations.push("Try chamomile or ginger tea for relief")
    }

    // Stress level recommendations
    if (currentStressLevel >= 6) {
      recommendations.push("Practice stress reduction techniques like meditation")
      recommendations.push("Consider a short walk or gentle exercise")
    }

    // Condition-specific recommendations
    if (userProfile.conditions.includes("GERD")) {
      recommendations.push("Avoid lying down for 2-3 hours after eating")
      recommendations.push("Keep your head elevated while sleeping")
    }

    if (userProfile.conditions.includes("IBS")) {
      recommendations.push("Consider following a low-FODMAP diet")
      recommendations.push("Track fiber intake and adjust accordingly")
    }

    // Medication safety check
    if (userProfile.allergies.length > 0) {
      recommendations.push(`⚠️ Remember your allergies: ${userProfile.allergies.join(", ")}`)
    }

    return recommendations.length > 0
      ? recommendations
      : ["Stay hydrated throughout the day", "Eat smaller, more frequent meals", "Keep a consistent sleep schedule"]
  }

  const getPainDescription = (level: number) => {
    const descriptions = [
      "No pain",
      "Very mild discomfort",
      "Mild pain, barely noticeable",
      "Moderate pain, noticeable but manageable",
      "Moderate pain, interferes with some activities",
      "Moderately severe pain, interferes with most activities",
      "Severe pain, difficult to ignore",
      "Very severe pain, dominates your senses",
      "Intense pain, unable to do most activities",
      "Excruciating pain, unable to function",
      "Unbearable pain, seek immediate medical attention",
    ]
    return descriptions[level] || "Unknown"
  }

  const runSimulation = () => {
    if (!simulationFood.trim()) {
      alert("Please enter a food or meal to simulate")
      return
    }

    // Analyze historical data to predict outcomes
    const relevantEntries = entries.filter((entry) => {
      const entryFoods = entry.notes.toLowerCase()
      const searchFood = simulationFood.toLowerCase()
      return entryFoods.includes(searchFood) || entry.triggers.some((t) => searchFood.includes(t.toLowerCase()))
    })

    let riskScore = 0
    const predictions: string[] = []
    const recommendations: string[] = []

    // Calculate risk based on historical data
    if (relevantEntries.length > 0) {
      const avgPain = relevantEntries.reduce((sum, e) => sum + e.painLevel, 0) / relevantEntries.length
      const avgStress = relevantEntries.reduce((sum, e) => sum + e.stressLevel, 0) / relevantEntries.length

      riskScore = Math.round((avgPain + avgStress) / 2)

      predictions.push(`Based on ${relevantEntries.length} similar entries in your history`)
      predictions.push(`Average pain level: ${avgPain.toFixed(1)}/10`)
      predictions.push(`Average stress level: ${avgStress.toFixed(1)}/10`)

      // Common symptoms from similar entries
      const symptomCounts: { [key: string]: number } = {}
      relevantEntries.forEach((entry) => {
        entry.symptoms.forEach((symptom) => {
          symptomCounts[symptom] = (symptomCounts[symptom] || 0) + 1
        })
      })

      const commonSymptoms = Object.entries(symptomCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([symptom]) => symptom)

      if (commonSymptoms.length > 0) {
        predictions.push(`Likely symptoms: ${commonSymptoms.join(", ")}`)
      }
    } else {
      // No historical data - use general risk assessment
      riskScore = 5
      predictions.push("No historical data found for this food")
      predictions.push("Risk assessment based on general patterns and your profile")

      // Check against known triggers
      const matchingTriggers = userProfile.triggers.filter((trigger) =>
        simulationFood.toLowerCase().includes(trigger.toLowerCase()),
      )

      if (matchingTriggers.length > 0) {
        riskScore += 3
        predictions.push(`⚠️ Contains known triggers: ${matchingTriggers.join(", ")}`)
      }
    }

    // Meal size impact
    if (simulationMealSize === "large") {
      riskScore += 1
      predictions.push("Large meal size may increase symptoms")
    } else if (simulationMealSize === "small") {
      riskScore -= 1
      predictions.push("Small meal size may reduce symptoms")
    }

    // Time of day impact
    if (simulationTimeOfDay === "late-night") {
      riskScore += 2
      predictions.push("Late night eating increases GERD risk")
    } else if (simulationTimeOfDay === "breakfast") {
      riskScore -= 1
      predictions.push("Morning meals typically better tolerated")
    }

    // Cap risk score
    riskScore = Math.max(0, Math.min(10, riskScore))

    // Generate recommendations based on risk
    if (riskScore >= 7) {
      recommendations.push("⚠️ High risk - Consider avoiding this food")
      recommendations.push("Have antacids ready if you proceed")
      recommendations.push("Eat a smaller portion than planned")
      recommendations.push("Avoid lying down for 3 hours after eating")
    } else if (riskScore >= 4) {
      recommendations.push("⚠️ Moderate risk - Proceed with caution")
      recommendations.push("Eat slowly and chew thoroughly")
      recommendations.push("Have remedies available")
      recommendations.push("Monitor symptoms closely")
    } else {
      recommendations.push("✓ Low risk - Should be well tolerated")
      recommendations.push("Still eat mindfully and in moderation")
      recommendations.push("Stay hydrated")
    }

    // Condition-specific recommendations
    if (userProfile.conditions.includes("GERD")) {
      recommendations.push("GERD: Avoid lying down for 2-3 hours after")
    }
    if (userProfile.conditions.includes("IBS")) {
      recommendations.push("IBS: Consider FODMAP content")
    }

    const riskLevel = riskScore >= 7 ? "High Risk" : riskScore >= 4 ? "Moderate Risk" : "Low Risk"

    setSimulationResults({
      riskLevel,
      riskScore,
      predictions,
      recommendations,
    })
  }

  if (!mounted) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-cyan-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading GastroGuard...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-cyan-50">
      <div className="container mx-auto px-4 py-6 pb-24">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            {currentView !== "dashboard" && (
              <button
                onClick={() => setCurrentView("dashboard")}
                className="p-2 rounded-full bg-white/80 backdrop-blur-sm border border-white/20 shadow-lg hover:bg-white/90 transition-all duration-200"
              >
                <ArrowLeft className="w-5 h-5 text-gray-600" />
              </button>
            )}
            <div>
              <h1 className="text-2xl font-bold bg-gradient-to-r from-cyan-600 to-blue-600 bg-clip-text text-transparent">
                GastroGuard
              </h1>
              <p className="text-sm text-gray-600">Enhanced v3.0</p>
            </div>
          </div>
        </div>

        {/* Dashboard View */}
        {currentView === "dashboard" && (
          <div className="space-y-6">
            {/* Welcome Card */}
            <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
              <div className="flex items-center gap-2 mb-2">
                <Heart className="w-5 h-5 text-red-500" />
                <h2 className="text-xl font-semibold">
                  Welcome back{userProfile.name ? `, ${userProfile.name}` : ""}!
                </h2>
              </div>
              <p className="text-gray-600">Track your symptoms and get personalized recommendations</p>
            </div>

            {/* Current Status */}
            <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
              <div className="flex items-center gap-2 mb-4">
                <Activity className="w-5 h-5 text-blue-500" />
                <h2 className="text-xl font-semibold">Current Status</h2>
              </div>
              <div className="space-y-4">
                <div>
                  <label className="text-sm font-medium block mb-2">Current Pain Level: {currentPainLevel}/10</label>
                  <p className="text-xs text-gray-600 mb-2">{getPainDescription(currentPainLevel)}</p>
                  <input
                    type="range"
                    min="0"
                    max="10"
                    value={currentPainLevel}
                    onChange={(e) => setCurrentPainLevel(Number(e.target.value))}
                    className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium block mb-2">
                    Current Stress Level: {currentStressLevel}/10
                  </label>
                  <input
                    type="range"
                    min="0"
                    max="10"
                    value={currentStressLevel}
                    onChange={(e) => setCurrentStressLevel(Number(e.target.value))}
                    className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                  />
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <button
                onClick={() => setCurrentView("enhanced-log")}
                className="p-6 rounded-xl bg-gradient-to-r from-cyan-500 to-blue-500 text-white shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200 flex items-center justify-center gap-3"
              >
                <PenTool className="w-6 h-6" />
                <span className="font-semibold">Enhanced Log</span>
              </button>

              <button
                onClick={() => setCurrentView("smart-recommendations")}
                className="p-6 rounded-xl bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200 flex items-center justify-center gap-3"
              >
                <Brain className="w-6 h-6" />
                <span className="font-semibold">Smart Recommendations</span>
              </button>

              {/* Added Simulation Button */}
              <button
                onClick={() => setCurrentView("simulation")}
                className="p-6 rounded-xl bg-gradient-to-r from-yellow-500 to-orange-500 text-white shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200 flex items-center justify-center gap-3"
              >
                <Zap className="w-6 h-6" />
                <span className="font-semibold">Symptom Simulator</span>
              </button>
            </div>

            {/* Today's Summary */}
            <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
              <div className="flex items-center gap-2 mb-4">
                <Calendar className="w-5 h-5 text-green-500" />
                <h2 className="text-xl font-semibold">Today's Summary</h2>
              </div>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="text-center">
                  <div className="text-2xl font-bold text-blue-600">{todayEntries.length}</div>
                  <div className="text-sm text-gray-600">Entries</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-red-500">
                    {todayEntries.length > 0
                      ? Math.round(todayEntries.reduce((sum, entry) => sum + entry.painLevel, 0) / todayEntries.length)
                      : 0}
                  </div>
                  <div className="text-sm text-gray-600">Avg Pain</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-orange-500">
                    {todayEntries.length > 0
                      ? Math.round(
                          todayEntries.reduce((sum, entry) => sum + entry.stressLevel, 0) / todayEntries.length,
                        )
                      : 0}
                  </div>
                  <div className="text-sm text-gray-600">Avg Stress</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-green-500">
                    {todayEntries.reduce((sum, entry) => sum + entry.remedies.length, 0)}
                  </div>
                  <div className="text-sm text-gray-600">Remedies Used</div>
                </div>
              </div>
            </div>

            {/* Recent Entries */}
            {recentEntries.length > 0 && (
              <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
                <div className="flex items-center gap-2 mb-4">
                  <Clock className="w-5 h-5 text-purple-500" />
                  <h2 className="text-xl font-semibold">Recent Entries</h2>
                </div>
                <div className="space-y-3">
                  {recentEntries.map((entry) => (
                    <div key={entry.id} className="p-3 bg-gray-50 rounded-lg">
                      <div className="flex justify-between items-start mb-2">
                        <span className="text-sm font-medium">
                          {entry.date} at {entry.time}
                        </span>
                        <div className="flex gap-2">
                          <span className="text-xs bg-red-100 text-red-700 px-2 py-1 rounded">
                            Pain: {entry.painLevel}/10
                          </span>
                          <span className="text-xs bg-orange-100 text-orange-700 px-2 py-1 rounded">
                            Stress: {entry.stressLevel}/10
                          </span>
                        </div>
                      </div>
                      {entry.symptoms.length > 0 && (
                        <p className="text-sm text-gray-600">Symptoms: {entry.symptoms.join(", ")}</p>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* Enhanced Log View */}
        {currentView === "enhanced-log" && (
          <div className="space-y-6">
            <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
              <div className="flex items-center gap-2 mb-2">
                <PenTool className="w-5 h-5 text-blue-500" />
                <h2 className="text-xl font-semibold">Enhanced Symptom Log</h2>
              </div>
              <p className="text-gray-600 mb-6">
                Comprehensive tracking with detailed pain scale and contextual factors
              </p>

              <div className="space-y-6">
                {/* Pain Level with Enhanced Scale */}
                <div>
                  <label className="text-sm font-medium block mb-2">Pain Level: {painLevel}/10</label>
                  <p className="text-xs text-gray-600 mb-2">{getPainDescription(painLevel)}</p>
                  <input
                    type="range"
                    min="0"
                    max="10"
                    value={painLevel}
                    onChange={(e) => setPainLevel(Number(e.target.value))}
                    className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                  />
                </div>

                {/* Stress Level */}
                <div>
                  <label className="text-sm font-medium block mb-2">Stress Level: {stressLevel}/10</label>
                  <input
                    type="range"
                    min="0"
                    max="10"
                    value={stressLevel}
                    onChange={(e) => setStressLevel(Number(e.target.value))}
                    className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                  />
                </div>

                {/* Symptoms */}
                <div>
                  <label className="text-sm font-medium mb-2 block">Symptoms</label>
                  <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
                    {symptoms.map((symptom) => (
                      <button
                        key={symptom}
                        onClick={() => {
                          if (selectedSymptoms.includes(symptom)) {
                            setSelectedSymptoms(selectedSymptoms.filter((s) => s !== symptom))
                          } else {
                            setSelectedSymptoms([...selectedSymptoms, symptom])
                          }
                        }}
                        className={`p-2 text-xs rounded-lg border transition-all ${
                          selectedSymptoms.includes(symptom)
                            ? "bg-blue-500 text-white border-blue-500"
                            : "bg-white text-gray-700 border-gray-200 hover:border-blue-300"
                        }`}
                      >
                        {symptom}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Notes */}
                <div>
                  <label className="text-sm font-medium block mb-2">Additional Notes</label>
                  <textarea
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    placeholder="Any additional details about your symptoms, what you ate, activities, etc."
                    className="w-full p-3 border border-gray-200 rounded-lg resize-none h-24"
                  />
                </div>

                <button
                  onClick={saveEntry}
                  className="w-full p-3 bg-gradient-to-r from-blue-500 to-cyan-500 text-white rounded-lg font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200 flex items-center justify-center gap-2"
                >
                  <Save className="w-5 h-5" />
                  Save Entry
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Smart Recommendations View */}
        {currentView === "smart-recommendations" && (
          <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
            <div className="flex items-center gap-2 mb-4">
              <Brain className="w-5 h-5 text-purple-500" />
              <h2 className="text-xl font-semibold">Smart Recommendations</h2>
            </div>
            <div className="space-y-4">
              {getPersonalizedRecommendations().map((recommendation, index) => (
                <div key={index} className="p-3 bg-blue-50 rounded-lg border-l-4 border-blue-500">
                  <p className="text-sm">{recommendation}</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Profile View */}
        {currentView === "profile" && (
          <div className="space-y-6">
            <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
              <div className="flex items-center gap-2 mb-2">
                <Activity className="w-5 h-5 text-green-500" />
                <h2 className="text-xl font-semibold">Personal Profile</h2>
              </div>
              <p className="text-gray-600 mb-6">
                Complete your profile for personalized recommendations and better tracking
              </p>

              <div className="space-y-6">
                {/* Basic Information */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="text-sm font-medium block mb-2">Name</label>
                    <input
                      type="text"
                      value={userProfile.name}
                      onChange={(e) => setUserProfile({ ...userProfile, name: e.target.value })}
                      placeholder="Enter your name"
                      className="w-full p-3 border border-gray-200 rounded-lg"
                    />
                  </div>
                  <div>
                    <label className="text-sm font-medium block mb-2">Age</label>
                    <input
                      type="number"
                      value={userProfile.age || ""}
                      onChange={(e) =>
                        setUserProfile({
                          ...userProfile,
                          age: Number.parseInt(e.target.value) || 0,
                        })
                      }
                      placeholder="Enter your age"
                      className="w-full p-3 border border-gray-200 rounded-lg"
                    />
                  </div>
                </div>

                <button
                  onClick={saveProfile}
                  className="w-full p-3 bg-gradient-to-r from-green-500 to-emerald-500 text-white rounded-lg font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200 flex items-center justify-center gap-2"
                >
                  <Save className="w-5 h-5" />
                  Save Profile
                </button>
              </div>
            </div>

            <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Link2 className="w-5 h-5 text-blue-500" />
                  <h2 className="text-xl font-semibold">App Integrations</h2>
                </div>
                <button
                  onClick={createIntegration}
                  className="px-4 py-2 bg-blue-500 text-white rounded-lg text-sm font-medium hover:bg-blue-600 transition-colors"
                >
                  + New Integration
                </button>
              </div>
              <p className="text-gray-600 mb-6">
                Connect GastroGuard with your other apps using API keys. Share your health data securely across
                platforms.
              </p>

              {integrations.length === 0 ? (
                <div className="text-center py-8 text-gray-500">
                  <Link2 className="w-12 h-12 mx-auto mb-3 opacity-50" />
                  <p>No integrations yet. Create one to get started!</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {integrations.map((integration) => (
                    <div key={integration.id} className="p-4 bg-gray-50 rounded-lg border border-gray-200">
                      <div className="flex items-start justify-between mb-3">
                        <div>
                          <h3 className="font-semibold text-gray-900">{integration.name}</h3>
                          <p className="text-xs text-gray-500">
                            Created {new Date(integration.createdAt).toLocaleDateString()}
                          </p>
                        </div>
                        <div className="flex gap-2">
                          <button
                            onClick={() => regenerateApiKey(integration.id)}
                            className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                            title="Regenerate API Key"
                          >
                            <RefreshCw className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => deleteIntegration(integration.id)}
                            className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                            title="Delete Integration"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>

                      <div className="mb-3">
                        <label className="text-xs font-medium text-gray-600 block mb-1">API Key</label>
                        <div className="flex gap-2">
                          <input
                            type={showApiKey === integration.id ? "text" : "password"}
                            value={integration.apiKey}
                            readOnly
                            className="flex-1 p-2 bg-white border border-gray-200 rounded text-sm font-mono"
                          />
                          <button
                            onClick={() => setShowApiKey(showApiKey === integration.id ? null : integration.id)}
                            className="px-3 py-2 bg-gray-200 hover:bg-gray-300 rounded text-sm transition-colors"
                          >
                            {showApiKey === integration.id ? "Hide" : "Show"}
                          </button>
                          <button
                            onClick={() => copyToClipboard(integration.apiKey)}
                            className="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded transition-colors"
                            title="Copy to clipboard"
                          >
                            <Copy className="w-4 h-4" />
                          </button>
                        </div>
                      </div>

                      <div>
                        <label className="text-xs font-medium text-gray-600 block mb-1">Permissions</label>
                        <div className="flex flex-wrap gap-1">
                          {integration.permissions.map((permission) => (
                            <span key={permission} className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                              {permission}
                            </span>
                          ))}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <div className="mt-6 p-4 bg-gray-50 rounded-lg border border-gray-200">
                <h3 className="font-semibold text-sm mb-2 text-blue-900">API Documentation</h3>
                <p className="text-xs text-blue-800 mb-3">Use these endpoints to integrate with GastroGuard:</p>
                <div className="space-y-2 text-xs font-mono bg-white p-3 rounded border border-blue-200">
                  <div>
                    <span className="text-green-600 font-semibold">GET</span> /api/entries - Fetch all entries
                  </div>
                  <div>
                    <span className="text-blue-600 font-semibold">POST</span> /api/entries - Create new entry
                  </div>
                  <div>
                    <span className="text-green-600 font-semibold">GET</span> /api/profile - Get user profile
                  </div>
                  <div>
                    <span className="text-green-600 font-semibold">GET</span> /api/analytics - Get analytics data
                  </div>
                </div>
                <p className="text-xs text-blue-700 mt-3">
                  Include your API key in the Authorization header:{" "}
                  <code className="bg-white px-1 py-0.5 rounded">Bearer YOUR_API_KEY</code>
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Simulation View */}
        {currentView === "simulation" && (
          <div className="space-y-6">
            <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
              <div className="flex items-center gap-2 mb-2">
                <Zap className="w-5 h-5 text-yellow-500" />
                <h2 className="text-xl font-semibold">Symptom Simulator</h2>
              </div>
              <p className="text-gray-600 mb-6">
                Predict how your body might react to foods based on your historical data and patterns
              </p>

              <div className="space-y-6">
                {/* Food Input */}
                <div>
                  <label className="text-sm font-medium block mb-2">What are you considering eating?</label>
                  <input
                    type="text"
                    value={simulationFood}
                    onChange={(e) => setSimulationFood(e.target.value)}
                    placeholder="e.g., Pizza, Spicy curry, Coffee, etc."
                    className="w-full p-3 border border-gray-200 rounded-lg"
                  />
                </div>

                {/* Meal Size */}
                <div>
                  <label className="text-sm font-medium block mb-2">Meal Size</label>
                  <div className="grid grid-cols-3 gap-2">
                    {["small", "medium", "large"].map((size) => (
                      <button
                        key={size}
                        onClick={() => setSimulationMealSize(size)}
                        className={`p-3 rounded-lg border transition-all capitalize ${
                          simulationMealSize === size
                            ? "bg-blue-500 text-white border-blue-500"
                            : "bg-white text-gray-700 border-gray-200 hover:border-blue-300"
                        }`}
                      >
                        {size}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Time of Day */}
                <div>
                  <label className="text-sm font-medium block mb-2">Time of Day</label>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                    {[
                      { value: "breakfast", label: "Breakfast" },
                      { value: "lunch", label: "Lunch" },
                      { value: "dinner", label: "Dinner" },
                      { value: "late-night", label: "Late Night" },
                    ].map((time) => (
                      <button
                        key={time.value}
                        onClick={() => setSimulationTimeOfDay(time.value)}
                        className={`p-3 rounded-lg border transition-all ${
                          simulationTimeOfDay === time.value
                            ? "bg-blue-500 text-white border-blue-500"
                            : "bg-white text-gray-700 border-gray-200 hover:border-blue-300"
                        }`}
                      >
                        {time.label}
                      </button>
                    ))}
                  </div>
                </div>

                <button
                  onClick={runSimulation}
                  className="w-full p-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-white rounded-lg font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200 flex items-center justify-center gap-2"
                >
                  <Zap className="w-5 h-5" />
                  Run Simulation
                </button>
              </div>
            </div>

            {/* Simulation Results */}
            {simulationResults && (
              <div className="space-y-6">
                <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
                  <div className="flex items-center gap-2 mb-4">
                    <Brain className="w-5 h-5 text-purple-500" />
                    <h2 className="text-xl font-semibold">Simulation Results</h2>
                  </div>

                  {/* Risk Level Badge */}
                  <div className="mb-6">
                    <div
                      className={`inline-flex items-center gap-2 px-4 py-2 rounded-full font-semibold ${
                        simulationResults.riskScore >= 7
                          ? "bg-red-100 text-red-700"
                          : simulationResults.riskScore >= 4
                            ? "bg-yellow-100 text-yellow-700"
                            : "bg-green-100 text-green-700"
                      }`}
                    >
                      <span className="text-2xl">{simulationResults.riskScore}/10</span>
                      <span>{simulationResults.riskLevel}</span>
                    </div>
                  </div>

                  {/* Predictions */}
                  <div className="mb-6">
                    <h3 className="font-semibold mb-3">Predictions</h3>
                    <div className="space-y-2">
                      {simulationResults.predictions.map((prediction, index) => (
                        <div key={index} className="p-3 bg-blue-50 rounded-lg border-l-4 border-blue-500">
                          <p className="text-sm">{prediction}</p>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Recommendations */}
                  <div>
                    <h3 className="font-semibold mb-3">Recommendations</h3>
                    <div className="space-y-2">
                      {simulationResults.recommendations.map((recommendation, index) => (
                        <div key={index} className="p-3 bg-purple-50 rounded-lg border-l-4 border-purple-500">
                          <p className="text-sm">{recommendation}</p>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="mt-6 p-4 bg-gray-50 rounded-lg border border-gray-200">
                    <p className="text-xs text-gray-600">
                      <strong>Note:</strong> This simulation is based on your historical data and general patterns. It's
                      not medical advice. Always consult with your healthcare provider for personalized guidance.
                    </p>
                  </div>
                </div>

                <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
                  <div className="flex items-center gap-2 mb-4">
                    <BarChart className="w-5 h-5 text-blue-500" />
                    <h2 className="text-xl font-semibold">Pain Timeline Prediction</h2>
                  </div>
                  <p className="text-sm text-gray-600 mb-6">
                    Predicted pain levels over time based on your historical data for similar foods
                  </p>

                  {/* Graph */}
                  <div className="relative h-64 mb-4">
                    {/* Y-axis labels */}
                    <div className="absolute left-0 top-0 bottom-0 w-8 flex flex-col justify-between text-xs text-gray-500">
                      <span>10</span>
                      <span>8</span>
                      <span>6</span>
                      <span>4</span>
                      <span>2</span>
                      <span>0</span>
                    </div>

                    {/* Graph area */}
                    <div className="ml-10 h-full border-l-2 border-b-2 border-gray-300 relative">
                      {/* Grid lines */}
                      {[0, 1, 2, 3, 4, 5].map((i) => (
                        <div
                          key={i}
                          className="absolute left-0 right-0 border-t border-gray-200"
                          style={{ bottom: `${i * 20}%` }}
                        />
                      ))}

                      {/* Historical data points */}
                      {(() => {
                        const relevantEntries = entries.filter((entry) => {
                          const entryFoods = entry.notes.toLowerCase()
                          const searchFood = simulationFood.toLowerCase()
                          return (
                            entryFoods.includes(searchFood) ||
                            entry.triggers.some((t) => searchFood.includes(t.toLowerCase()))
                          )
                        })

                        return relevantEntries.slice(0, 10).map((entry, index) => {
                          const timeOffset = entry.timeSinceEating || Math.random() * 6
                          const xPos = (timeOffset / 8) * 100
                          const yPos = (entry.painLevel / 10) * 100

                          return (
                            <div
                              key={entry.id}
                              className="absolute w-3 h-3 bg-blue-500 rounded-full border-2 border-white shadow-lg"
                              style={{
                                left: `${xPos}%`,
                                bottom: `${yPos}%`,
                                transform: "translate(-50%, 50%)",
                              }}
                              title={`Pain: ${entry.painLevel}/10 at ${timeOffset.toFixed(1)}h`}
                            />
                          )
                        })
                      })()}

                      {/* Predicted pain curve */}
                      <svg className="absolute inset-0 w-full h-full pointer-events-none">
                        <path
                          d={(() => {
                            const riskScore = simulationResults.riskScore
                            const points = []

                            // Generate curve points based on typical gastritis pain pattern
                            for (let i = 0; i <= 8; i += 0.5) {
                              const x = (i / 8) * 100
                              let y

                              if (i < 0.5) {
                                // Initial onset
                                y = (riskScore * 0.3 * (i / 0.5)) / 10
                              } else if (i < 2) {
                                // Peak pain
                                y = (riskScore * (0.3 + 0.7 * ((i - 0.5) / 1.5))) / 10
                              } else if (i < 4) {
                                // Sustained pain
                                y = (riskScore * (1 - 0.2 * ((i - 2) / 2))) / 10
                              } else {
                                // Gradual relief
                                y = (riskScore * (0.8 - 0.6 * ((i - 4) / 4))) / 10
                              }

                              points.push(`${x},${(1 - y) * 100}`)
                            }

                            return `M ${points.join(" L ")}`
                          })()}
                          fill="none"
                          stroke="#f59e0b"
                          strokeWidth="3"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </svg>

                      {/* Ingestion marker */}
                      <div className="absolute bottom-0 w-0.5 bg-green-500" style={{ left: "0%", height: "100%" }}>
                        <div className="absolute -top-6 left-1/2 transform -translate-x-1/2 text-xs font-semibold text-green-600 whitespace-nowrap">
                          Ingestion
                        </div>
                      </div>
                    </div>

                    {/* X-axis labels */}
                    <div className="ml-10 mt-2 flex justify-between text-xs text-gray-500">
                      <span>0h</span>
                      <span>2h</span>
                      <span>4h</span>
                      <span>6h</span>
                      <span>8h</span>
                    </div>
                  </div>

                  {/* Legend */}
                  <div className="flex flex-wrap gap-4 justify-center text-sm">
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 bg-blue-500 rounded-full border-2 border-white" />
                      <span className="text-gray-600">Historical Data</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-0.5 bg-yellow-500" />
                      <span className="text-gray-600">Predicted Pain Curve</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-0.5 h-4 bg-green-500" />
                      <span className="text-gray-600">Time of Ingestion</span>
                    </div>
                  </div>

                  {/* Data Summary */}
                  <div className="mt-6 grid grid-cols-2 md:grid-cols-4 gap-4">
                    <div className="text-center p-3 bg-blue-50 rounded-lg">
                      <div className="text-2xl font-bold text-blue-600">
                        {
                          entries.filter((entry) => {
                            const entryFoods = entry.notes.toLowerCase()
                            const searchFood = simulationFood.toLowerCase()
                            return (
                              entryFoods.includes(searchFood) ||
                              entry.triggers.some((t) => searchFood.includes(t.toLowerCase()))
                            )
                          }).length
                        }
                      </div>
                      <div className="text-xs text-gray-600">Similar Entries</div>
                    </div>
                    <div className="text-center p-3 bg-yellow-50 rounded-lg">
                      <div className="text-2xl font-bold text-yellow-600">{simulationResults.riskScore}/10</div>
                      <div className="text-xs text-gray-600">Peak Pain</div>
                    </div>
                    <div className="text-center p-3 bg-green-50 rounded-lg">
                      <div className="text-2xl font-bold text-green-600">2-4h</div>
                      <div className="text-xs text-gray-600">Peak Time</div>
                    </div>
                    <div className="text-center p-3 bg-purple-50 rounded-lg">
                      <div className="text-2xl font-bold text-purple-600">6-8h</div>
                      <div className="text-xs text-gray-600">Recovery Time</div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Other placeholder views */}
        {currentView === "analytics" && (
          <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">Analytics</h2>
            <p>Analytics view coming soon...</p>
          </div>
        )}

        {currentView === "history" && (
          <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">History</h2>
            <p>History view coming soon...</p>
          </div>
        )}
      </div>

      <div className="fixed bottom-0 left-0 right-0 bg-white/90 backdrop-blur-sm border-t border-gray-200 px-4 py-2">
        <div className="flex justify-around items-center max-w-md mx-auto">
          {[
            { id: "dashboard", icon: Home, label: "Dashboard" },
            { id: "enhanced-log", icon: PenTool, label: "Log" },
            { id: "simulation", icon: Zap, label: "Simulate" },
            { id: "analytics", icon: BarChart, label: "Analytics" },
            { id: "profile", icon: Activity, label: "Profile" },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setCurrentView(tab.id)}
              className={`flex flex-col items-center gap-1 p-2 rounded-lg transition-all duration-200 ${
                currentView === tab.id
                  ? "text-cyan-600 bg-cyan-50"
                  : "text-gray-600 hover:text-cyan-600 hover:bg-gray-50"
              }`}
            >
              <tab.icon className="w-5 h-5" />
              <span className="text-xs font-medium">{tab.label}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
