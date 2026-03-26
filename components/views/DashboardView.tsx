"use client"

import { useMemo } from "react"
import {
  Heart,
  Activity,
  Calendar,
  Clock,
  PenTool,
  Brain,
  Zap,
  Pencil,
  Trash2,
} from "lucide-react"
import type { User } from "@supabase/supabase-js"
import type { LogEntryUI } from "@/lib/adapter/log-entry"
import type { UserProfile } from "@/lib/profile"
import type { ViewId } from "@/components/layout/BottomNav"
import { PainSlider } from "@/components/shared/PainSlider"

interface DashboardViewProps {
  user: User | null
  entries: LogEntryUI[]
  profile: UserProfile
  currentPainLevel: number
  currentStressLevel: number
  onPainChange: (v: number) => void
  onStressChange: (v: number) => void
  onNavigate: (id: ViewId) => void
  onEditEntry: (entry: LogEntryUI) => void
  onDeleteEntry: (id: string) => void
}

export function DashboardView({
  user,
  entries,
  profile,
  currentPainLevel,
  currentStressLevel,
  onPainChange,
  onStressChange,
  onNavigate,
  onEditEntry,
  onDeleteEntry,
}: DashboardViewProps) {
  const todayEntries = useMemo(() => {
    const today = new Date().toDateString()
    return entries.filter((e) => new Date(e.date).toDateString() === today)
  }, [entries])

  const recentEntries = useMemo(() => entries.slice(0, 5), [entries])

  const avgPain =
    todayEntries.length > 0
      ? Math.round(
          todayEntries.reduce((s, e) => s + e.painLevel, 0) / todayEntries.length
        )
      : 0

  const avgStress =
    todayEntries.length > 0
      ? Math.round(
          todayEntries.reduce((s, e) => s + e.stressLevel, 0) / todayEntries.length
        )
      : 0

  const totalRemedies = todayEntries.reduce((s, e) => s + e.remedies.length, 0)

  return (
    <div className="space-y-6">
      {/* Welcome card */}
      <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
        <div className="flex items-center gap-2 mb-1">
          <Heart className="w-5 h-5 text-red-500" />
          <h2 className="text-xl font-semibold">
            Welcome back{profile.name ? `, ${profile.name}` : ""}!
          </h2>
        </div>
        <p className="text-sm text-gray-600">
          Track your symptoms and get personalized recommendations
        </p>
      </div>

      {/* Current status */}
      <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
        <div className="flex items-center gap-2 mb-4">
          <Activity className="w-5 h-5 text-blue-500" />
          <h2 className="text-xl font-semibold">Current Status</h2>
        </div>
        <div className="space-y-5">
          <PainSlider
            label="Current Pain Level"
            value={currentPainLevel}
            onChange={onPainChange}
            showDescription
            color="red"
          />
          <PainSlider
            label="Current Stress Level"
            value={currentStressLevel}
            onChange={onStressChange}
            color="orange"
          />
        </div>
      </div>

      {/* Quick actions */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <button
          onClick={() => onNavigate("enhanced-log")}
          className="p-6 rounded-xl bg-gradient-to-r from-cyan-500 to-blue-500 text-white shadow-lg hover:shadow-xl transform hover:scale-105 transition-all flex items-center justify-center gap-3"
        >
          <PenTool className="w-6 h-6" />
          <span className="font-semibold">Enhanced Log</span>
        </button>
        <button
          onClick={() => onNavigate("smart-recommendations" as ViewId)}
          className="p-6 rounded-xl bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-lg hover:shadow-xl transform hover:scale-105 transition-all flex items-center justify-center gap-3"
        >
          <Brain className="w-6 h-6" />
          <span className="font-semibold">Recommendations</span>
        </button>
        <button
          onClick={() => onNavigate("simulation")}
          className="p-6 rounded-xl bg-gradient-to-r from-yellow-500 to-orange-500 text-white shadow-lg hover:shadow-xl transform hover:scale-105 transition-all flex items-center justify-center gap-3"
        >
          <Zap className="w-6 h-6" />
          <span className="font-semibold">Symptom Simulator</span>
        </button>
        <button
          onClick={() => onNavigate("analytics")}
          className="p-6 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-500 text-white shadow-lg hover:shadow-xl transform hover:scale-105 transition-all flex items-center justify-center gap-3"
        >
          <Activity className="w-6 h-6" />
          <span className="font-semibold">Analytics</span>
        </button>
      </div>

      {/* Today's summary */}
      <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
        <div className="flex items-center gap-2 mb-4">
          <Calendar className="w-5 h-5 text-green-500" />
          <h2 className="text-xl font-semibold">Today&apos;s Summary</h2>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {[
            { value: todayEntries.length, label: "Entries", color: "text-blue-600" },
            { value: avgPain, label: "Avg Pain", color: "text-red-500" },
            { value: avgStress, label: "Avg Stress", color: "text-orange-500" },
            { value: totalRemedies, label: "Remedies", color: "text-green-500" },
          ].map(({ value, label, color }) => (
            <div key={label} className="text-center">
              <div className={`text-2xl font-bold ${color}`}>{value}</div>
              <div className="text-xs text-gray-500">{label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Recent entries */}
      {recentEntries.length > 0 && (
        <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Clock className="w-5 h-5 text-purple-500" />
            <h2 className="text-xl font-semibold">Recent Entries</h2>
          </div>
          <div className="space-y-3">
            {recentEntries.map((entry) => (
              <div key={entry.id} className="p-3 bg-gray-50 rounded-lg">
                <div className="flex justify-between items-start mb-1 gap-2">
                  <span className="text-sm font-medium text-gray-800">
                    {entry.date} at {entry.time}
                  </span>
                  <div className="flex items-center gap-1 shrink-0">
                    <span className="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded">
                      Pain: {entry.painLevel}
                    </span>
                    <span className="text-xs bg-orange-100 text-orange-700 px-2 py-0.5 rounded">
                      Stress: {entry.stressLevel}
                    </span>
                    {user && (
                      <>
                        <button
                          onClick={() => onEditEntry(entry)}
                          className="p-1 rounded hover:bg-white"
                          aria-label="Edit"
                        >
                          <Pencil className="w-3.5 h-3.5 text-cyan-600" />
                        </button>
                        <button
                          onClick={() => onDeleteEntry(entry.id)}
                          className="p-1 rounded hover:bg-white"
                          aria-label="Delete"
                        >
                          <Trash2 className="w-3.5 h-3.5 text-red-500" />
                        </button>
                      </>
                    )}
                  </div>
                </div>
                {entry.symptoms.length > 0 && (
                  <p className="text-xs text-gray-500">
                    {entry.symptoms.join(", ")}
                  </p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
