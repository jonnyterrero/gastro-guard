"use client"

import { useState } from "react"
import { Activity, Link2, RefreshCw, Trash2, Copy, Save, Plus, Eye, EyeOff } from "lucide-react"
import { toast } from "sonner"
import type { UserProfile, Integration } from "@/lib/profile"
import { TagSelector } from "@/components/shared/TagSelector"
import { CONDITIONS, GENDER_OPTIONS } from "@/lib/constants/options"

interface ProfileViewProps {
  profile: UserProfile
  integrations: Integration[]
  saving: boolean
  onProfileChange: (p: UserProfile) => void
  onSaveProfile: (p: UserProfile) => Promise<boolean>
  onPersistIntegrations: (integrations: Integration[]) => Promise<void>
}

function generateApiKey(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  let key = "gg_"
  for (let i = 0; i < 32; i++) {
    key += chars[Math.floor(Math.random() * chars.length)]
  }
  return key
}

export function ProfileView({
  profile,
  integrations,
  saving,
  onProfileChange,
  onSaveProfile,
  onPersistIntegrations,
}: ProfileViewProps) {
  const [showApiKey, setShowApiKey] = useState<string | null>(null)
  const [newIntName, setNewIntName] = useState("")
  const [showNewIntForm, setShowNewIntForm] = useState(false)

  const set = <K extends keyof UserProfile>(key: K, val: UserProfile[K]) =>
    onProfileChange({ ...profile, [key]: val })

  const handleSave = () => onSaveProfile(profile)

  // ── Integrations ────────────────────────────────────────────────────────────
  const createIntegration = async () => {
    if (!newIntName.trim()) {
      toast.warning("Enter a name for the integration")
      return
    }
    const newInt: Integration = {
      id: Date.now().toString(),
      name: newIntName.trim(),
      apiKey: generateApiKey(),
      createdAt: new Date().toISOString(),
      permissions: ["read:entries", "write:entries", "read:profile", "read:analytics"],
    }
    await onPersistIntegrations([...integrations, newInt])
    setNewIntName("")
    setShowNewIntForm(false)
    toast.success(`Integration "${newInt.name}" created`)
  }

  const regenerateKey = async (id: string) => {
    const updated = integrations.map((i) =>
      i.id === id ? { ...i, apiKey: generateApiKey() } : i
    )
    await onPersistIntegrations(updated)
    toast.success("API key regenerated")
  }

  const deleteIntegration = async (id: string) => {
    await onPersistIntegrations(integrations.filter((i) => i.id !== id))
    toast.success("Integration deleted")
  }

  const copyKey = (key: string) => {
    navigator.clipboard.writeText(key)
    toast.success("Copied to clipboard")
  }

  return (
    <div className="space-y-6">
      {/* Profile form */}
      <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
        <div className="flex items-center gap-2 mb-2">
          <Activity className="w-5 h-5 text-green-500" />
          <h2 className="text-xl font-semibold">Personal Profile</h2>
        </div>
        <p className="text-sm text-gray-500 mb-6">
          Complete your profile for personalized recommendations
        </p>

        <div className="space-y-5">
          {/* Basic info */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Field
              label="Name"
              value={profile.name}
              onChange={(v) => set("name", v)}
              placeholder="Your name"
            />
            <FieldNum
              label="Age"
              value={profile.age}
              onChange={(v) => set("age", v)}
              placeholder="Your age"
            />
            <Field
              label="Height"
              value={profile.height}
              onChange={(v) => set("height", v)}
              placeholder='e.g. 5ft 10in or 178cm'
            />
            <Field
              label="Weight"
              value={profile.weight}
              onChange={(v) => set("weight", v)}
              placeholder='e.g. 165 lbs or 75kg'
            />
            <div>
              <label className="text-sm font-medium block mb-1">Gender</label>
              <select
                value={profile.gender}
                onChange={(e) => set("gender", e.target.value)}
                className="w-full p-2.5 border border-gray-200 rounded-lg text-sm"
              >
                <option value="">Prefer not to say</option>
                {GENDER_OPTIONS.map((g) => (
                  <option key={g} value={g}>
                    {g}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Medical history */}
          <TagSelector
            label="Conditions"
            options={CONDITIONS}
            selected={profile.conditions}
            onChange={(v) => set("conditions", v)}
            colorActive="bg-red-500 text-white border-red-500"
          />

          <ChipListField
            label="Medications"
            items={profile.medications}
            onChange={(v) => set("medications", v)}
            placeholder="Add medication..."
          />

          <ChipListField
            label="Allergies"
            items={profile.allergies}
            onChange={(v) => set("allergies", v)}
            placeholder="Add allergy..."
          />

          <ChipListField
            label="Dietary Restrictions"
            items={profile.dietaryRestrictions}
            onChange={(v) => set("dietaryRestrictions", v)}
            placeholder="Add restriction..."
          />

          <ChipListField
            label="Known Triggers"
            items={profile.triggers}
            onChange={(v) => set("triggers", v)}
            placeholder="Add trigger..."
          />

          <ChipListField
            label="Effective Remedies"
            items={profile.effectiveRemedies}
            onChange={(v) => set("effectiveRemedies", v)}
            placeholder="Add remedy..."
          />

          <button
            onClick={handleSave}
            disabled={saving}
            className="w-full p-3 bg-gradient-to-r from-green-500 to-emerald-500 text-white rounded-lg font-semibold hover:shadow-lg transform hover:scale-105 transition-all flex items-center justify-center gap-2 disabled:opacity-60 disabled:transform-none"
          >
            <Save className="w-5 h-5" />
            {saving ? "Saving…" : "Save Profile"}
          </button>
        </div>
      </div>

      {/* Integrations */}
      <div className="bg-white/80 backdrop-blur-sm border border-white/20 shadow-xl rounded-xl p-6">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <Link2 className="w-5 h-5 text-blue-500" />
            <h2 className="text-xl font-semibold">App Integrations</h2>
          </div>
          <button
            onClick={() => setShowNewIntForm((v) => !v)}
            className="px-3 py-1.5 bg-blue-500 text-white rounded-lg text-sm font-medium hover:bg-blue-600 transition-colors flex items-center gap-1"
          >
            <Plus className="w-4 h-4" />
            New
          </button>
        </div>
        <p className="text-sm text-gray-500 mb-4">
          Connect GastroGuard with other apps using API keys.
        </p>

        {/* New integration form */}
        {showNewIntForm && (
          <div className="mb-4 p-4 bg-blue-50 rounded-lg border border-blue-200">
            <label className="text-sm font-medium block mb-2">
              Integration Name
            </label>
            <div className="flex gap-2">
              <input
                type="text"
                value={newIntName}
                onChange={(e) => setNewIntName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && createIntegration()}
                placeholder="e.g., My Fitness App"
                className="flex-1 p-2.5 border border-gray-200 rounded-lg text-sm"
                autoFocus
              />
              <button
                onClick={createIntegration}
                className="px-4 py-2 bg-blue-500 text-white rounded-lg text-sm font-medium hover:bg-blue-600"
              >
                Create
              </button>
            </div>
          </div>
        )}

        {integrations.length === 0 ? (
          <div className="text-center py-8 text-gray-400">
            <Link2 className="w-10 h-10 mx-auto mb-2 opacity-40" />
            <p className="text-sm">No integrations yet</p>
          </div>
        ) : (
          <div className="space-y-4">
            {integrations.map((int) => (
              <div
                key={int.id}
                className="p-4 bg-gray-50 rounded-lg border border-gray-200"
              >
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <p className="font-semibold text-sm text-gray-900">{int.name}</p>
                    <p className="text-xs text-gray-400">
                      Created {new Date(int.createdAt).toLocaleDateString()}
                    </p>
                  </div>
                  <div className="flex gap-1">
                    <button
                      onClick={() => regenerateKey(int.id)}
                      className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-lg"
                      title="Regenerate API key"
                    >
                      <RefreshCw className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => deleteIntegration(int.id)}
                      className="p-1.5 text-red-500 hover:bg-red-50 rounded-lg"
                      title="Delete integration"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>

                {/* API key */}
                <label className="text-xs font-medium text-gray-500 block mb-1">
                  API Key
                </label>
                <div className="flex gap-2">
                  <input
                    type={showApiKey === int.id ? "text" : "password"}
                    value={int.apiKey}
                    readOnly
                    className="flex-1 p-2 bg-white border border-gray-200 rounded text-xs font-mono"
                  />
                  <button
                    onClick={() =>
                      setShowApiKey(showApiKey === int.id ? null : int.id)
                    }
                    className="px-2.5 py-2 bg-gray-100 hover:bg-gray-200 rounded text-xs transition-colors"
                  >
                    {showApiKey === int.id ? (
                      <EyeOff className="w-4 h-4" />
                    ) : (
                      <Eye className="w-4 h-4" />
                    )}
                  </button>
                  <button
                    onClick={() => copyKey(int.apiKey)}
                    className="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded transition-colors"
                    title="Copy"
                  >
                    <Copy className="w-4 h-4" />
                  </button>
                </div>

                {/* Permissions */}
                <div className="flex flex-wrap gap-1 mt-2">
                  {int.permissions.map((p) => (
                    <span
                      key={p}
                      className="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded"
                    >
                      {p}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* API docs */}
        <div className="mt-6 p-4 bg-gray-50 rounded-lg border border-gray-200">
          <p className="text-xs font-semibold text-gray-700 mb-2">
            API Documentation
          </p>
          <div className="space-y-1 text-xs font-mono bg-white p-3 rounded border border-gray-200">
            <div>
              <span className="text-green-600 font-bold">GET </span>
              /api/entries
            </div>
            <div>
              <span className="text-blue-600 font-bold">POST </span>
              /api/entries
            </div>
            <div>
              <span className="text-green-600 font-bold">GET </span>
              /api/profile
            </div>
            <div>
              <span className="text-green-600 font-bold">GET </span>
              /api/analytics
            </div>
          </div>
          <p className="text-xs text-gray-500 mt-2">
            Header:{" "}
            <code className="bg-white px-1 py-0.5 rounded border">
              Authorization: Bearer YOUR_API_KEY
            </code>
          </p>
          <p className="text-xs text-amber-800 bg-amber-50 border border-amber-100 rounded p-2 mt-3">
            Server env required:{" "}
            <code className="text-[10px]">SUPABASE_SERVICE_ROLE_KEY</code> in{" "}
            <code className="text-[10px]">.env.local</code> (restart{" "}
            <code className="text-[10px]">npm run dev</code> after changes).
          </p>
          {integrations.length > 0 && (
            <div className="mt-3">
              <p className="text-xs font-semibold text-gray-700 mb-1">
                Quick test (copy, replace YOUR_GG_KEY)
              </p>
              <pre className="text-[10px] font-mono bg-white p-2 rounded border border-gray-200 overflow-x-auto whitespace-pre-wrap break-all">
                {`curl -s "${typeof window !== "undefined" ? window.location.origin : ""}/api/entries" \\\n  -H "Authorization: Bearer YOUR_GG_KEY"`}
              </pre>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function Field({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
}) {
  return (
    <div>
      <label className="text-sm font-medium block mb-1">{label}</label>
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full p-2.5 border border-gray-200 rounded-lg text-sm"
      />
    </div>
  )
}

function FieldNum({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string
  value: number
  onChange: (v: number) => void
  placeholder?: string
}) {
  return (
    <div>
      <label className="text-sm font-medium block mb-1">{label}</label>
      <input
        type="number"
        value={value || ""}
        onChange={(e) => onChange(parseInt(e.target.value) || 0)}
        placeholder={placeholder}
        className="w-full p-2.5 border border-gray-200 rounded-lg text-sm"
      />
    </div>
  )
}

function ChipListField({
  label,
  items,
  onChange,
  placeholder,
}: {
  label: string
  items: string[]
  onChange: (items: string[]) => void
  placeholder?: string
}) {
  const [input, setInput] = useState("")

  const add = () => {
    const val = input.trim()
    if (!val || items.includes(val)) return
    onChange([...items, val])
    setInput("")
  }

  const remove = (item: string) => onChange(items.filter((i) => i !== item))

  return (
    <div>
      <label className="text-sm font-medium block mb-1">{label}</label>
      <div className="flex gap-2 mb-2">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && add()}
          placeholder={placeholder}
          className="flex-1 p-2.5 border border-gray-200 rounded-lg text-sm"
        />
        <button
          type="button"
          onClick={add}
          className="px-3 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg text-sm transition-colors"
        >
          Add
        </button>
      </div>
      {items.length > 0 && (
        <div className="flex flex-wrap gap-1">
          {items.map((item) => (
            <span
              key={item}
              className="flex items-center gap-1 text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded-full"
            >
              {item}
              <button
                onClick={() => remove(item)}
                className="text-gray-400 hover:text-red-500 ml-0.5"
              >
                ×
              </button>
            </span>
          ))}
        </div>
      )}
    </div>
  )
}
