"use client"

import Link from "next/link"
import { ArrowLeft, LogOut, LogIn, CloudUpload, X } from "lucide-react"
import type { User } from "@supabase/supabase-js"
import { BottomNav, type ViewId } from "@/components/layout/BottomNav"

interface AppShellProps {
  user: User | null
  currentView: ViewId
  onNavigate: (id: ViewId) => void
  onSignOut: () => void
  pendingOfflineCount?: number
  onSyncOffline?: () => void
  onDismissOffline?: () => void
  children: React.ReactNode
}

export function AppShell({
  user,
  currentView,
  onNavigate,
  onSignOut,
  pendingOfflineCount = 0,
  onSyncOffline,
  onDismissOffline,
  children,
}: AppShellProps) {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-cyan-50">
      <div className="container mx-auto px-4 py-6 pb-28">

        {/* ── Header ─────────────────────────────────────────────────────── */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            {currentView !== "dashboard" && (
              <button
                onClick={() => onNavigate("dashboard")}
                className="p-2 rounded-full bg-white/80 backdrop-blur-sm border border-white/20 shadow-lg hover:bg-white/90 transition-all"
                aria-label="Back to dashboard"
              >
                <ArrowLeft className="w-5 h-5 text-gray-600" />
              </button>
            )}
            <div>
              <h1 className="text-2xl font-bold bg-gradient-to-r from-cyan-600 to-blue-600 bg-clip-text text-transparent">
                GastroGuard
              </h1>
              <p className="text-xs text-gray-500">v3.0</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {user ? (
              <button
                onClick={onSignOut}
                className="flex items-center gap-2 px-3 py-2 rounded-lg bg-white/80 backdrop-blur-sm border border-white/20 shadow-lg hover:bg-white/90 transition-all text-sm text-gray-600"
              >
                <LogOut className="w-4 h-4" />
                Sign out
              </button>
            ) : (
              <Link
                href="/auth"
                className="flex items-center gap-2 px-3 py-2 rounded-lg bg-gradient-to-r from-cyan-600 to-blue-600 text-white shadow-lg hover:from-cyan-700 hover:to-blue-700 transition-all text-sm font-medium"
              >
                <LogIn className="w-4 h-4" />
                Sign in
              </Link>
            )}
          </div>
        </div>

        {/* ── Offline sync banner ─────────────────────────────────────────── */}
        {user && pendingOfflineCount > 0 && (
          <div className="mb-4 flex items-center justify-between gap-3 p-3 bg-amber-50 border border-amber-200 rounded-xl text-sm">
            <div className="flex items-center gap-2 text-amber-800">
              <CloudUpload className="w-4 h-4 shrink-0" />
              <span>
                <strong>{pendingOfflineCount}</strong> offline entr
                {pendingOfflineCount === 1 ? "y" : "ies"} waiting to sync
              </span>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={onSyncOffline}
                className="px-3 py-1 bg-amber-600 text-white rounded-lg text-xs font-medium hover:bg-amber-700 transition-colors"
              >
                Sync now
              </button>
              <button
                onClick={onDismissOffline}
                className="p-1 text-amber-600 hover:text-amber-800"
                aria-label="Dismiss"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}

        {/* ── Page content ───────────────────────────────────────────────── */}
        {children}
      </div>

      <BottomNav currentView={currentView} onNavigate={onNavigate} />
    </div>
  )
}
