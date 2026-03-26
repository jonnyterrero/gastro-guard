"use client"

import {
  Home,
  PenTool,
  Clock,
  Zap,
  BarChart,
  Activity,
} from "lucide-react"

export type ViewId =
  | "dashboard"
  | "enhanced-log"
  | "history"
  | "simulation"
  | "analytics"
  | "profile"

const TABS: { id: ViewId; icon: React.ElementType; label: string }[] = [
  { id: "dashboard", icon: Home, label: "Home" },
  { id: "enhanced-log", icon: PenTool, label: "Log" },
  { id: "history", icon: Clock, label: "History" },
  { id: "simulation", icon: Zap, label: "Sim" },
  { id: "analytics", icon: BarChart, label: "Stats" },
  { id: "profile", icon: Activity, label: "Profile" },
]

interface BottomNavProps {
  currentView: ViewId
  onNavigate: (id: ViewId) => void
}

export function BottomNav({ currentView, onNavigate }: BottomNavProps) {
  return (
    <div className="fixed bottom-0 left-0 right-0 bg-white/90 backdrop-blur-sm border-t border-gray-200 px-4 py-2 z-50">
      <div className="flex justify-around items-center max-w-md mx-auto">
        {TABS.map((tab) => {
          const Icon = tab.icon
          const active = currentView === tab.id
          return (
            <button
              key={tab.id}
              onClick={() => onNavigate(tab.id)}
              className={`flex flex-col items-center gap-1 p-2 rounded-lg transition-all duration-200 ${
                active
                  ? "text-cyan-600 bg-cyan-50"
                  : "text-gray-600 hover:text-cyan-600 hover:bg-gray-50"
              }`}
              aria-current={active ? "page" : undefined}
            >
              <Icon className="w-5 h-5" />
              <span className="text-xs font-medium">{tab.label}</span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
