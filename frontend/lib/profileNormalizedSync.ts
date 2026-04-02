import type { SupabaseClient } from "@supabase/supabase-js"
import type { UserProfile } from "@/lib/profile"

/**
 * Keeps `profile_conditions` and `medications` in sync with the string lists
 * stored on `profiles` (JSONB). Canonical UX remains the profile row; normalized
 * tables mirror for analytics and SQL joins.
 */
export async function syncNormalizedProfileLists(
  supabase: SupabaseClient,
  userId: string,
  profile: UserProfile
): Promise<{ error: { message: string } | null }> {
  const conditions = profile.conditions.map((s) => s.trim()).filter(Boolean)
  const medications = profile.medications.map((s) => s.trim()).filter(Boolean)

  const { error: delPc } = await supabase
    .from("profile_conditions")
    .delete()
    .eq("user_id", userId)
  if (delPc) return { error: delPc }

  if (conditions.length > 0) {
    const { error: insPc } = await supabase.from("profile_conditions").insert(
      conditions.map((condition_name) => ({
        user_id: userId,
        condition_name,
        condition_label: condition_name,
        is_active: true,
      }))
    )
    if (insPc) return { error: insPc }
  }

  const { error: delMed } = await supabase.from("medications").delete().eq("user_id", userId)
  if (delMed) return { error: delMed }

  if (medications.length > 0) {
    const { error: insMed } = await supabase.from("medications").insert(
      medications.map((medication_name) => ({
        user_id: userId,
        medication_name,
        is_active: true,
      }))
    )
    if (insMed) return { error: insMed }
  }

  return { error: null }
}
