"use client"

import { BarChart2, TrendingDown, TrendingUp, Clock, Calendar, RefreshCw } from "lucide-react"
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
} from "recharts"
import type { User } from "@supabase/supabase-js"
import type { AnalyticsState } from "@/hooks/useAnalytics"

interface AnalyticsViewProps {
  user: User | null
  analytics: AnalyticsState
}

function Card({
  title,
  icon: Icon,
  children,
}: {
  title: string
  icon: React.ElementType
  children: React.ReactNode
}) {
  return (
    <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
      <div className="flex items-center gap-2 mb-4">
        <Icon className="w-5 h-5 text-cyan-500" />
        <h2 className="text-lg font-semibold">{title}</h2>
      </div>
      {children}
    </div>
  )
}

export function AnalyticsView({ user, analytics }: AnalyticsViewProps) {
  const { timeline, triggerScores, remedyScores, weeklySummaries, recommendations, loading, error } =
    analytics

  if (!user) {
    return (
      <Card title="Analytics" icon={BarChart2}>
        <p className="text-sm text-gray-500">Sign in to view your analytics.</p>
      </Card>
    )
  }

  if (loading) {
    return (
      <Card title="Analytics" icon={BarChart2}>
        <div className="flex items-center gap-2 text-gray-500 text-sm">
          <RefreshCw className="w-4 h-4 animate-spin" />
          Loading analytics…
        </div>
      </Card>
    )
  }

  if (error) {
    return (
      <Card title="Analytics" icon={BarChart2}>
        <p className="text-sm text-red-500">
          Could not load analytics: {error}
        </p>
      </Card>
    )
  }

  // Weekly chart data (reverse so oldest first)
  const weeklyChartData = [...weeklySummaries].reverse().map((w) => ({
    week: w.week_start.slice(5), // MM-DD
    pain: Number(w.avg_pain?.toFixed(1) ?? 0),
    stress: Number(w.avg_stress?.toFixed(1) ?? 0),
    entries: w.entry_count,
  }))

  return (
    <div className="space-y-6">
      {/* Top-line recommendation summary */}
      {recommendations && (
        <Card title="This Week's Insights" icon={TrendingUp}>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-4">
            <Insight
              label="Worst Trigger"
              value={recommendations.top_triggers[0]?.name ?? "—"}
              color="text-red-600"
              bg="bg-red-50"
            />
            <Insight
              label="Best Remedy"
              value={recommendations.top_remedies[0]?.name ?? "—"}
              color="text-green-600"
              bg="bg-green-50"
            />
            <Insight
              label="Entries (30d)"
              value={String(recommendations.recent_entry_count)}
              color="text-blue-600"
              bg="bg-blue-50"
            />
          </div>
          {recommendations.risky_hours.length > 0 && (
            <p className="text-xs text-gray-500">
              Highest pain hour: <strong>{recommendations.risky_hours[0].hour}:00</strong> (avg{" "}
              {recommendations.risky_hours[0].avg_pain?.toFixed(1)}/10)
            </p>
          )}
        </Card>
      )}

      {/* Weekly pain / stress trend */}
      {weeklyChartData.length > 0 && (
        <Card title="Weekly Pain & Stress Trend" icon={TrendingDown}>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={weeklyChartData} margin={{ top: 4, right: 4, bottom: 4, left: -20 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="week" tick={{ fontSize: 10 }} />
              <YAxis domain={[0, 10]} tick={{ fontSize: 10 }} />
              <Tooltip
                formatter={(value, name) => [value, name === "pain" ? "Avg Pain" : "Avg Stress"]}
                labelFormatter={(l) => `Week of ${l}`}
              />
              <Bar dataKey="pain" fill="#ef4444" radius={[3, 3, 0, 0]} name="pain" />
              <Bar dataKey="stress" fill="#f97316" radius={[3, 3, 0, 0]} name="stress" />
            </BarChart>
          </ResponsiveContainer>
          <div className="flex gap-4 justify-center text-xs mt-2">
            <span className="flex items-center gap-1">
              <span className="w-3 h-3 bg-red-400 rounded-sm inline-block" />
              Avg Pain
            </span>
            <span className="flex items-center gap-1">
              <span className="w-3 h-3 bg-orange-400 rounded-sm inline-block" />
              Avg Stress
            </span>
          </div>
        </Card>
      )}

      {/* Trigger scores */}
      {triggerScores.length > 0 && (
        <Card title="Top Pain Triggers" icon={TrendingUp}>
          <p className="text-xs text-gray-500 mb-3">
            pain_delta = avg pain when present minus avg pain when absent (higher = worse trigger)
          </p>
          <div className="space-y-2">
            {triggerScores.map((t) => (
              <div key={t.trigger_name} className="flex items-center gap-3">
                <div className="w-32 text-xs font-medium text-gray-700 truncate">
                  {t.trigger_name}
                </div>
                <div className="flex-1 bg-gray-100 rounded-full h-2 relative">
                  <div
                    className="absolute left-0 top-0 h-full bg-red-400 rounded-full"
                    style={{
                      width: `${Math.min(100, ((t.pain_delta ?? 0) / 10) * 100)}%`,
                    }}
                  />
                </div>
                <span className="text-xs font-mono text-gray-600 w-10 text-right">
                  {t.pain_delta != null ? `+${t.pain_delta.toFixed(1)}` : "—"}
                </span>
                <span className="text-xs text-gray-400">({t.sample_count})</span>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Remedy scores */}
      {remedyScores.length > 0 && (
        <Card title="Most Effective Remedies" icon={TrendingDown}>
          <div className="space-y-2">
            {remedyScores.map((r) => (
              <div key={r.remedy_name} className="flex items-center gap-3">
                <div className="w-32 text-xs font-medium text-gray-700 truncate">
                  {r.remedy_name}
                </div>
                <div className="flex-1 bg-gray-100 rounded-full h-2 relative">
                  <div
                    className="absolute left-0 top-0 h-full bg-green-400 rounded-full"
                    style={{
                      width: `${Math.min(100, ((r.avg_effectiveness ?? 0) / 10) * 100)}%`,
                    }}
                  />
                </div>
                <span className="text-xs font-mono text-gray-600 w-10 text-right">
                  {r.avg_effectiveness != null ? r.avg_effectiveness.toFixed(1) : "—"}
                </span>
                <span className="text-xs text-gray-400">({r.usage_count})</span>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Event timeline */}
      <Card title="Event Timeline" icon={Clock}>
        <p className="text-xs text-gray-500 mb-3">
          Unified stream from log entries and normalized events
        </p>
        {timeline.length === 0 ? (
          <p className="text-sm text-gray-500">
            No events yet. Log some entries to see your timeline.
          </p>
        ) : (
          <div className="space-y-2 max-h-80 overflow-y-auto pr-1">
            {timeline.map((e, i) => (
              <div
                key={i}
                className="p-3 bg-gray-50 rounded-lg border-l-4 border-cyan-400"
              >
                <div className="flex justify-between items-start gap-2">
                  <span className="text-sm font-medium text-gray-800">{e.title}</span>
                  <span className="text-xs text-gray-400 shrink-0">
                    {new Date(e.occurred_at).toLocaleString()}
                  </span>
                </div>
                <span className="text-xs text-cyan-600 capitalize">{e.event_type}</span>
              </div>
            ))}
          </div>
        )}
      </Card>

      {/* No data state */}
      {!loading &&
        triggerScores.length === 0 &&
        remedyScores.length === 0 &&
        weeklySummaries.length === 0 && (
          <Card title="No Analytics Yet" icon={Calendar}>
            <p className="text-sm text-gray-500">
              Log at least a few entries to generate your analytics. Analytics
              refresh automatically after each log entry.
            </p>
          </Card>
        )}
    </div>
  )
}

function Insight({
  label,
  value,
  color,
  bg,
}: {
  label: string
  value: string
  color: string
  bg: string
}) {
  return (
    <div className={`${bg} rounded-lg p-3 text-center`}>
      <div className={`font-semibold text-sm ${color}`}>{value}</div>
      <div className="text-xs text-gray-500 mt-0.5">{label}</div>
    </div>
  )
}
