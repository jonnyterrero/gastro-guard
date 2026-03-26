"use client"

import { useState, useEffect } from "react"
import type { User } from "@supabase/supabase-js"
import {
  fetchTimeline,
  fetchTriggerScores,
  fetchRemedyScores,
  fetchWeeklySummaries,
  fetchRecommendationCache,
  fetchDailyRollups,
  fetchLatestRollingSnapshots,
  type TimelineEvent,
  type TriggerScore,
  type RemedyScore,
  type WeeklySummary,
  type RecommendationPayload,
  type DailyFeatureRollup,
  type RollingFeatureSnapshot,
} from "@/lib/services/analytics.service"
import {
  getActiveRecommendations,
  type RecommendationItemRow,
} from "@/lib/services/recommendations"

export interface AnalyticsState {
  timeline: TimelineEvent[]
  triggerScores: TriggerScore[]
  remedyScores: RemedyScore[]
  weeklySummaries: WeeklySummary[]
  recommendations: RecommendationPayload | null
  dailyRollups: DailyFeatureRollup[]
  rollingSnapshots: RollingFeatureSnapshot[]
  recommendationItems: RecommendationItemRow[]
  loading: boolean
  error: string | null
}

export function useAnalytics(user: User | null): AnalyticsState {
  const [state, setState] = useState<AnalyticsState>({
    timeline: [],
    triggerScores: [],
    remedyScores: [],
    weeklySummaries: [],
    recommendations: null,
    dailyRollups: [],
    rollingSnapshots: [],
    recommendationItems: [],
    loading: false,
    error: null,
  })

  useEffect(() => {
    if (!user?.id) {
      setState((s) => ({ ...s, loading: false }))
      return
    }

    setState((s) => ({ ...s, loading: true, error: null }))

    ;(async () => {
      try {
        const [timeline, triggerScores, remedyScores, weeklySummaries, recommendations] =
          await Promise.all([
            fetchTimeline(user.id),
            fetchTriggerScores(user.id),
            fetchRemedyScores(user.id),
            fetchWeeklySummaries(user.id),
            fetchRecommendationCache(user.id),
          ])

        let dailyRollups: DailyFeatureRollup[] = []
        let rollingSnapshots: RollingFeatureSnapshot[] = []
        let recommendationItems: RecommendationItemRow[] = []
        try {
          ;[dailyRollups, rollingSnapshots, recommendationItems] = await Promise.all([
            fetchDailyRollups(user.id),
            fetchLatestRollingSnapshots(user.id),
            getActiveRecommendations(user.id),
          ])
        } catch {
          /* v3 tables / RPCs may not be applied yet */
        }

        setState({
          timeline,
          triggerScores,
          remedyScores,
          weeklySummaries,
          recommendations,
          dailyRollups,
          rollingSnapshots,
          recommendationItems,
          loading: false,
          error: null,
        })
      } catch (e) {
        const msg = e instanceof Error ? e.message : "Analytics load failed"
        console.error("[useAnalytics]", msg)
        setState((s) => ({ ...s, loading: false, error: msg }))
      }
    })()
  }, [user?.id])

  return state
}
