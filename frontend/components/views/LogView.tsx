"use client"

import { useState, useEffect } from "react"
import { PenTool, Save } from "lucide-react"
import { PainSlider } from "@/components/shared/PainSlider"
import { TagSelector } from "@/components/shared/TagSelector"
import { SYMPTOMS, TRIGGERS, REMEDIES, WEATHER_OPTIONS } from "@/lib/constants/options"
import type { LogEntryUI } from "@/lib/adapter/log-entry"
import type { LogFormFields } from "@/hooks/useLogEntries"

interface LogViewProps {
  editingEntry?: LogEntryUI | null
  onSave: (fields: LogFormFields) => Promise<boolean>
  onCancelEdit?: () => void
}

function emptyForm(): LogFormFields {
  return {
    painLevel: 0,
    stressLevel: 0,
    selectedSymptoms: [],
    selectedTriggers: [],
    selectedRemedies: [],
    notes: "",
    mealSize: "",
    timeSinceEating: 0,
    sleepQuality: 5,
    exerciseLevel: 0,
    weatherCondition: "",
    ingestionTime: "",
  }
}

export function LogView({ editingEntry, onSave, onCancelEdit }: LogViewProps) {
  const [form, setForm] = useState<LogFormFields>(emptyForm())
  const [saving, setSaving] = useState(false)

  // Populate form when entering edit mode
  useEffect(() => {
    if (editingEntry) {
      setForm({
        painLevel: editingEntry.painLevel,
        stressLevel: editingEntry.stressLevel,
        selectedSymptoms: [...editingEntry.symptoms],
        selectedTriggers: [...editingEntry.triggers],
        selectedRemedies: [...editingEntry.remedies],
        notes: editingEntry.notes,
        mealSize: editingEntry.mealSize ?? "",
        timeSinceEating: editingEntry.timeSinceEating ?? 0,
        sleepQuality: editingEntry.sleepQuality ?? 5,
        exerciseLevel: editingEntry.exerciseLevel ?? 0,
        weatherCondition: editingEntry.weatherCondition ?? "",
        ingestionTime: editingEntry.ingestionTime ?? "",
      })
    } else {
      setForm(emptyForm())
    }
  }, [editingEntry?.id]) // eslint-disable-line react-hooks/exhaustive-deps

  const set = <K extends keyof LogFormFields>(key: K, value: LogFormFields[K]) =>
    setForm((f) => ({ ...f, [key]: value }))

  const handleSave = async () => {
    setSaving(true)
    const ok = await onSave(form)
    if (ok) setForm(emptyForm())
    setSaving(false)
  }

  const isEditing = !!editingEntry

  return (
    <div className="space-y-6">
      <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
        <div className="flex items-center justify-between gap-2 mb-2">
          <div className="flex items-center gap-2">
            <PenTool className="w-5 h-5 text-blue-500" />
            <h2 className="text-xl font-semibold">
              {isEditing ? "Edit Log Entry" : "Enhanced Symptom Log"}
            </h2>
          </div>
          {isEditing && (
            <button
              type="button"
              onClick={() => {
                setForm(emptyForm())
                onCancelEdit?.()
              }}
              className="text-sm text-gray-500 hover:text-red-500 transition-colors"
            >
              Cancel edit
            </button>
          )}
        </div>
        <p className="text-sm text-gray-500 mb-6">
          Comprehensive tracking with detailed pain scale and contextual factors
        </p>

        <div className="space-y-6">
          {/* Pain & stress */}
          <PainSlider
            label="Pain Level"
            value={form.painLevel}
            onChange={(v) => set("painLevel", v)}
            showDescription
            color="red"
          />
          <PainSlider
            label="Stress Level"
            value={form.stressLevel}
            onChange={(v) => set("stressLevel", v)}
            color="orange"
          />

          {/* Symptoms */}
          <TagSelector
            label="Symptoms"
            options={SYMPTOMS}
            selected={form.selectedSymptoms}
            onChange={(v) => set("selectedSymptoms", v)}
            colorActive="bg-blue-500 text-white border-blue-500"
          />

          {/* Triggers */}
          <TagSelector
            label="Triggers"
            options={TRIGGERS}
            selected={form.selectedTriggers}
            onChange={(v) => set("selectedTriggers", v)}
            colorActive="bg-red-500 text-white border-red-500"
          />

          {/* Remedies */}
          <TagSelector
            label="Remedies Used"
            options={REMEDIES}
            selected={form.selectedRemedies}
            onChange={(v) => set("selectedRemedies", v)}
            colorActive="bg-green-500 text-white border-green-500"
          />

          {/* Context */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="text-sm font-medium block mb-1">Meal Size</label>
              <select
                value={form.mealSize}
                onChange={(e) => set("mealSize", e.target.value)}
                className="w-full p-2.5 border border-gray-200 rounded-lg text-sm"
              >
                <option value="">Not applicable</option>
                <option value="small">Small</option>
                <option value="medium">Medium</option>
                <option value="large">Large</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium block mb-1">
                Time since eating (h)
              </label>
              <input
                type="number"
                min={0}
                max={24}
                value={form.timeSinceEating || ""}
                onChange={(e) => set("timeSinceEating", Number(e.target.value))}
                placeholder="0"
                className="w-full p-2.5 border border-gray-200 rounded-lg text-sm"
              />
            </div>
            <div>
              <label className="text-sm font-medium block mb-1">
                Sleep quality (0–10)
              </label>
              <input
                type="number"
                min={0}
                max={10}
                value={form.sleepQuality || ""}
                onChange={(e) => set("sleepQuality", Number(e.target.value))}
                placeholder="5"
                className="w-full p-2.5 border border-gray-200 rounded-lg text-sm"
              />
            </div>
            <div>
              <label className="text-sm font-medium block mb-1">Weather</label>
              <select
                value={form.weatherCondition}
                onChange={(e) => set("weatherCondition", e.target.value)}
                className="w-full p-2.5 border border-gray-200 rounded-lg text-sm"
              >
                <option value="">Select...</option>
                {WEATHER_OPTIONS.map((w) => (
                  <option key={w} value={w}>
                    {w}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Notes */}
          <div>
            <label className="text-sm font-medium block mb-1">
              Additional Notes
            </label>
            <textarea
              value={form.notes}
              onChange={(e) => set("notes", e.target.value)}
              placeholder="Any additional details about your symptoms, what you ate, activities, etc."
              className="w-full p-3 border border-gray-200 rounded-lg resize-none h-24 text-sm"
            />
          </div>

          <button
            onClick={handleSave}
            disabled={saving}
            className="w-full p-3 bg-gradient-to-r from-blue-500 to-cyan-500 text-white rounded-lg font-semibold hover:shadow-lg transform hover:scale-105 transition-all flex items-center justify-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed disabled:transform-none"
          >
            <Save className="w-5 h-5" />
            {saving ? "Saving…" : isEditing ? "Update Entry" : "Save Entry"}
          </button>
        </div>
      </div>
    </div>
  )
}
