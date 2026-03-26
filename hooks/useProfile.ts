"use client"

import { useState, useEffect, useCallback } from "react"
import type { User } from "@supabase/supabase-js"
import { toast } from "sonner"
import { createClient } from "@/lib/supabase/client"
import {
  fetchProfileAndIntegrations,
  userProfileToUpsert,
  type UserProfile,
  type Integration,
} from "@/lib/profile"

const EMPTY_PROFILE: UserProfile = {
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
}

export function useProfile(user: User | null) {
  const [profile, setProfile] = useState<UserProfile>(EMPTY_PROFILE)
  const [integrations, setIntegrations] = useState<Integration[]>([])
  const [saving, setSaving] = useState(false)

  // ── Step 1: Load from localStorage immediately (no flash) ──────────────────
  useEffect(() => {
    try {
      const rawProfile = localStorage.getItem("gastroguard-profile")
      if (rawProfile) setProfile(JSON.parse(rawProfile))
      const rawInt = localStorage.getItem("gastroguard-integrations")
      if (rawInt) setIntegrations(JSON.parse(rawInt))
    } catch {
      /* ignore */
    }
  }, [])

  // ── Step 2: Sync from Supabase when user signs in ──────────────────────────
  useEffect(() => {
    if (!user?.id) return

    ;(async () => {
      try {
        const supabase = createClient()
        const { profile: remote, integrations: remoteInt } =
          await fetchProfileAndIntegrations(supabase, user.id)

        let localProfile: UserProfile | null = null
        try {
          const raw = localStorage.getItem("gastroguard-profile")
          if (raw) localProfile = JSON.parse(raw) as UserProfile
        } catch {
          /* ignore */
        }

        // Merge: prefer remote, but keep local name if remote is empty
        let merged: UserProfile
        if (remote) {
          merged =
            localProfile?.name && !remote.name
              ? { ...remote, ...localProfile }
              : remote
        } else {
          merged = localProfile ?? EMPTY_PROFILE
        }

        setProfile(merged)
        localStorage.setItem("gastroguard-profile", JSON.stringify(merged))

        // Push local-only profile to remote if remote was empty
        if (localProfile?.name && remote && !remote.name) {
          await supabase
            .from("profiles")
            .upsert(userProfileToUpsert(user.id, merged, remoteInt), {
              onConflict: "user_id",
            })
        }

        // Sync integrations
        if (remoteInt.length > 0) {
          setIntegrations(remoteInt)
          localStorage.setItem(
            "gastroguard-integrations",
            JSON.stringify(remoteInt)
          )
        }
      } catch (e) {
        console.error("[useProfile] sync failed:", e)
      }
    })()
  }, [user?.id]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Save profile ────────────────────────────────────────────────────────────
  const saveProfile = useCallback(
    async (updated: UserProfile): Promise<boolean> => {
      setSaving(true)
      setProfile(updated)
      localStorage.setItem("gastroguard-profile", JSON.stringify(updated))

      if (user?.id) {
        const supabase = createClient()
        const { error } = await supabase
          .from("profiles")
          .upsert(userProfileToUpsert(user.id, updated, integrations), {
            onConflict: "user_id",
          })
        if (error) {
          toast.error("Could not sync profile: " + error.message)
          setSaving(false)
          return false
        }
      }

      toast.success("Profile saved!")
      setSaving(false)
      return true
    },
    [user?.id, integrations]
  )

  // ── Persist integrations (state + localStorage + Supabase) ─────────────────
  const persistIntegrations = useCallback(
    async (next: Integration[]): Promise<void> => {
      setIntegrations(next)
      localStorage.setItem("gastroguard-integrations", JSON.stringify(next))
      if (user?.id) {
        const supabase = createClient()
        await supabase
          .from("profiles")
          .update({ integrations: next })
          .eq("user_id", user.id)
      }
    },
    [user?.id]
  )

  return {
    profile,
    integrations,
    saving,
    setProfile,
    saveProfile,
    persistIntegrations,
  }
}
