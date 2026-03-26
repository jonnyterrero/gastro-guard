"use client"

import { useState } from "react"
import { Calendar, Pencil, Trash2 } from "lucide-react"
import type { User } from "@supabase/supabase-js"
import type { LogEntryUI } from "@/lib/adapter/log-entry"
import { HISTORY_PAGE_SIZE } from "@/lib/constants/options"

interface HistoryViewProps {
  user: User | null
  entries: LogEntryUI[]
  onEditEntry: (entry: LogEntryUI) => void
  onDeleteEntry: (id: string) => void
}

export function HistoryView({
  user,
  entries,
  onEditEntry,
  onDeleteEntry,
}: HistoryViewProps) {
  const [page, setPage] = useState(0)
  const totalPages = Math.ceil(entries.length / HISTORY_PAGE_SIZE)
  const paged = entries.slice(
    page * HISTORY_PAGE_SIZE,
    (page + 1) * HISTORY_PAGE_SIZE
  )

  return (
    <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
      <div className="flex items-center gap-2 mb-4">
        <Calendar className="w-5 h-5 text-cyan-500" />
        <h2 className="text-xl font-semibold">History</h2>
      </div>

      {!user ? (
        <p className="text-sm text-gray-500">
          Sign in to see your full log history from any device.
        </p>
      ) : entries.length === 0 ? (
        <p className="text-sm text-gray-500">
          No entries yet. Log something from the Log tab.
        </p>
      ) : (
        <>
          <p className="text-xs text-gray-500 mb-4">
            Showing {page * HISTORY_PAGE_SIZE + 1}–
            {Math.min((page + 1) * HISTORY_PAGE_SIZE, entries.length)} of{" "}
            {entries.length} entries
          </p>

          <div className="space-y-3">
            {paged.map((entry) => (
              <div
                key={entry.id}
                className="p-4 bg-gray-50 rounded-lg border border-gray-100"
              >
                <div className="flex justify-between items-start gap-2 mb-2">
                  <div>
                    <p className="font-medium text-gray-800 text-sm">
                      {entry.date} at {entry.time}
                    </p>
                    <div className="flex gap-2 mt-1">
                      <span className="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded">
                        Pain {entry.painLevel}/10
                      </span>
                      <span className="text-xs bg-orange-100 text-orange-700 px-2 py-0.5 rounded">
                        Stress {entry.stressLevel}/10
                      </span>
                    </div>
                  </div>
                  <div className="flex gap-1 shrink-0">
                    <button
                      onClick={() => onEditEntry(entry)}
                      className="p-2 rounded-lg hover:bg-white transition-colors"
                      aria-label="Edit"
                    >
                      <Pencil className="w-4 h-4 text-cyan-600" />
                    </button>
                    <button
                      onClick={() => onDeleteEntry(entry.id)}
                      className="p-2 rounded-lg hover:bg-white transition-colors"
                      aria-label="Delete"
                    >
                      <Trash2 className="w-4 h-4 text-red-500" />
                    </button>
                  </div>
                </div>
                {entry.symptoms.length > 0 && (
                  <p className="text-xs text-gray-600">
                    Symptoms: {entry.symptoms.join(", ")}
                  </p>
                )}
                {entry.notes && (
                  <p className="text-xs text-gray-500 mt-1 line-clamp-2">
                    {entry.notes}
                  </p>
                )}
              </div>
            ))}
          </div>

          {totalPages > 1 && (
            <div className="flex justify-between items-center mt-6">
              <button
                disabled={page === 0}
                onClick={() => setPage((p) => p - 1)}
                className="px-4 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-40 hover:bg-gray-50 transition-colors"
              >
                Previous
              </button>
              <span className="text-xs text-gray-500">
                {page + 1} / {totalPages}
              </span>
              <button
                disabled={page >= totalPages - 1}
                onClick={() => setPage((p) => p + 1)}
                className="px-4 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-40 hover:bg-gray-50 transition-colors"
              >
                Next
              </button>
            </div>
          )}
        </>
      )}
    </div>
  )
}
