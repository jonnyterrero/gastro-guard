"use client"

import { useState, useCallback } from "react"
import { toast } from "sonner"

// ── Hooks ─────────────────────────────────────────────────────────────────────
import { useAuth } from "@/hooks/useAuth"
import { useLogEntries, type LogFormFields } from "@/hooks/useLogEntries"
import { useProfile } from "@/hooks/useProfile"
import { useAnalytics } from "@/hooks/useAnalytics"
import { useOfflineSync } from "@/hooks/useOfflineSync"

// ── Layout ────────────────────────────────────────────────────────────────────
import { AppShell } from "@/components/layout/AppShell"
import type { ViewId } from "@/components/layout/BottomNav"

// ── Views ─────────────────────────────────────────────────────────────────────
import { DashboardView } from "@/components/views/DashboardView"
import { LogView } from "@/components/views/LogView"
import { HistoryView } from "@/components/views/HistoryView"
import { SimulationView } from "@/components/views/SimulationView"
import { AnalyticsView } from "@/components/views/AnalyticsView"
import { ProfileView } from "@/components/views/ProfileView"

// ── Types ─────────────────────────────────────────────────────────────────────
import type { LogEntryUI } from "@/lib/adapter/log-entry"

export default function GastroGuardApp() {
  // ── Auth ───────────────────────────────────────────────────────────────────
  const { user, loading: authLoading, signOut } = useAuth()

  // ── Data hooks ─────────────────────────────────────────────────────────────
  const {
    entries,
    create,
    update,
    remove,
  } = useLogEntries(user)

  const {
    profile,
    integrations,
    saving: profileSaving,
    setProfile,
    saveProfile,
    persistIntegrations,
  } = useProfile(user)

  const analytics = useAnalytics(user)

  const {
    pendingCount,
    syncLocalEntries,
    dismissSync,
  } = useOfflineSync(user)

  // ── Navigation state ───────────────────────────────────────────────────────
  const [currentView, setCurrentView] = useState<ViewId>("dashboard")

  // ── Log form state ─────────────────────────────────────────────────────────
  const [editingEntry, setEditingEntry] = useState<LogEntryUI | null>(null)

  // ── Dashboard quick-access pain / stress sliders ───────────────────────────
  const [currentPainLevel, setCurrentPainLevel] = useState(0)
  const [currentStressLevel, setCurrentStressLevel] = useState(0)

  // ── Navigation handler ─────────────────────────────────────────────────────
  const handleNavigate = useCallback((id: ViewId) => {
    // Leaving the log view without explicitly editing clears the edit state
    if (id !== "enhanced-log") setEditingEntry(null)
    setCurrentView(id)
  }, [])

  // ── Edit entry ─────────────────────────────────────────────────────────────
  const handleEditEntry = useCallback((entry: LogEntryUI) => {
    setEditingEntry(entry)
    setCurrentView("enhanced-log")
  }, [])

  // ── Delete entry (toast-based confirmation) ────────────────────────────────
  const handleDeleteEntry = useCallback(
    (id: string) => {
      toast("Delete this entry?", {
        action: {
          label: "Delete",
          onClick: () => void remove(id),
        },
        cancel: {
          label: "Cancel",
          onClick: () => {},
        },
        duration: 6000,
      })
    },
    [remove]
  )

  // ── Log save (handles both create and update) ──────────────────────────────
  const handleLogSave = useCallback(
    async (fields: LogFormFields): Promise<boolean> => {
      if (editingEntry) {
        const ok = await update(editingEntry.id, fields, editingEntry)
        if (ok) {
          setEditingEntry(null)
          setCurrentView("dashboard")
        }
        return ok
      }
      const ok = await create(fields)
      if (ok) setCurrentView("dashboard")
      return ok
    },
    [editingEntry, create, update]
  )

  // ── Cancel edit ────────────────────────────────────────────────────────────
  const handleCancelEdit = useCallback(() => {
    setEditingEntry(null)
    setCurrentView("dashboard")
  }, [])

  // ── Auth loading splash ────────────────────────────────────────────────────
  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 via-white to-cyan-50">
        <div className="text-center space-y-3">
          <div className="w-12 h-12 rounded-full bg-gradient-to-r from-cyan-500 to-blue-500 animate-pulse mx-auto" />
          <p className="text-sm text-gray-500">Loading GastroGuard…</p>
        </div>
      </div>
    )
  }

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <AppShell
      user={user}
      currentView={currentView}
      onNavigate={handleNavigate}
      onSignOut={signOut}
      pendingOfflineCount={pendingCount}
      onSyncOffline={() => void syncLocalEntries()}
      onDismissOffline={dismissSync}
    >
      {currentView === "dashboard" && (
        <DashboardView
          user={user}
          entries={entries}
          profile={profile}
          currentPainLevel={currentPainLevel}
          currentStressLevel={currentStressLevel}
          onPainChange={setCurrentPainLevel}
          onStressChange={setCurrentStressLevel}
          onNavigate={handleNavigate}
          onEditEntry={handleEditEntry}
          onDeleteEntry={handleDeleteEntry}
        />
      )}

      {currentView === "enhanced-log" && (
        <LogView
          editingEntry={editingEntry}
          onSave={handleLogSave}
          onCancelEdit={handleCancelEdit}
        />
      )}

      {currentView === "history" && (
        <HistoryView
          user={user}
          entries={entries}
          onEditEntry={handleEditEntry}
          onDeleteEntry={handleDeleteEntry}
        />
      )}

      {currentView === "simulation" && (
        <SimulationView entries={entries} profile={profile} />
      )}

      {currentView === "analytics" && (
        <AnalyticsView user={user} analytics={analytics} />
      )}

      {currentView === "profile" && (
        <ProfileView
          profile={profile}
          integrations={integrations}
          saving={profileSaving}
          onProfileChange={setProfile}
          onSaveProfile={saveProfile}
          onPersistIntegrations={persistIntegrations}
        />
      )}
    </AppShell>
  )
}
