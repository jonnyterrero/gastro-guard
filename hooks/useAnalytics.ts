"use client"

import { useState, useEffect } from "react"
import type { User } from "@supabase/supabase-js"
import {
  fetchTimeline,
  fetchTriggerScores,
  fetchRemedyScores,
  fetchWeeklySummaries,
  fetchRecommendationCache,
  type TimelineEvent,
  type TriggerScore,
  type RemedyScore,
  type WeeklySummary,
  type RecommendationPayload,
} from "@/lib/services/analytics.service"

export interface AnalyticsState {
  timeline: TimelineEvent[]
  triggerScores: TriggerScore[]
  remedyScores: RemedyScore[]
  weeklySummaries: WeeklySummary[]
  recommendations: RecommendationPayload | null
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

        setState({
          timeline,
          triggerScores,
          remedyScores,
          weeklySummaries,
          recommendations,
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
