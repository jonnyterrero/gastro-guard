# GastroGuard Hybrid Backend

## Migration: `integrations` on profiles

Run [migrations/20260320000000_profiles_integrations_jsonb.sql](migrations/20260320000000_profiles_integrations_jsonb.sql) in the SQL Editor if you already applied the main migration before this column was added:

```sql
alter table public.profiles add column if not exists integrations jsonb default '[]'::jsonb;
```

---

## Applying the Migration

Run the migration against your Supabase project:

```bash
supabase db push
```

Or apply manually via Supabase Dashboard SQL Editor, or use the Supabase MCP `apply_migration` tool with the contents of `migrations/20260319000000_gastroguard_hybrid_backend.sql`.

---

## Section Explanations

### Phase 1 — Foundation
- **set_updated_at()**: Reusable trigger function that sets `updated_at = now()` on any table with an `updated_at` column. Uses `security invoker` so it runs with the caller's permissions.
- **profiles**: One row per user, linked 1:1 to `auth.users`. Stores name, age, height, weight, gender, and JSONB arrays for conditions, medications, allergies, dietary restrictions, triggers, and effective remedies.
- **handle_new_user()**: Trigger on `auth.users` that automatically creates a `profiles` row when a new user signs up. Uses `security definer` so it can insert into `profiles` even during the signup flow.

### Phase 2 — Frontend-Compatible log_entries
- **log_entries**: The sole write surface for the frontend. Flat structure with `entry_at`, `entry_date`, pain/stress/nausea scores (0–10), meal fields, and JSONB arrays for symptoms, triggers, and remedies. Check constraints enforce valid score ranges.
- **Indexes**: `(user_id, entry_at desc)` for recent-entries queries; `(user_id, entry_date)` for date-range queries.

### Phase 3 — Normalized Analytics Tables
- **log_days**: One row per user per calendar day; used as a parent for event tables.
- **meal_events, symptom_events, remedy_events, trigger_events**: Normalized event tables with `source_entry_id` linking back to the originating `log_entries` row. `on delete set null` preserves events if the source entry is deleted.

### Phase 4 — Metadata Tables
- **meal_tags, symptom_tags**: User-defined tags for meals and symptoms; unique per user.
- **profile_conditions**: Diagnosed conditions with optional notes and `diagnosed_at`.
- **medications**: Medications with dosage, frequency, and notes.

### Phase 5 & 6 — Sync Logic
- **sync_log_entry_to_normalized()**: Shared function that upserts `log_days`, then inserts meal/symptom/remedy/trigger events from a `log_entries` row. Parses JSON arrays that may contain strings (`"nausea"`) or objects (`{"name":"nausea","severity":7}`).
- **INSERT trigger**: Calls sync function on new rows.
- **UPDATE trigger**: Deletes existing normalized rows for the entry, then re-runs sync.
- **DELETE trigger**: Deletes normalized rows where `source_entry_id` matches.

### Phase 7 — RLS
- All user-owned tables have RLS enabled with policies: SELECT/INSERT/UPDATE/DELETE only when `auth.uid() = user_id`.

### Phase 8 — Developer Ergonomics
- Additional indexes for common filters (log_date, symptom_name, occurred_at).
- Table and column comments for documentation.
- **v_user_timeline**: Union view combining log_entries and all event types into a single timeline with `event_type`, `occurred_at`, `title`, `details`, and `source_entry_id`.

---

## TypeScript Type

See [lib/types/log-entry.ts](../lib/types/log-entry.ts) for the `LogEntryDb` type and related types (`SymptomItem`, `TriggerItem`, `RemedyItem`).

---

## Sample Insert Payload

See [sample_insert.json](./sample_insert.json) for a sample `log_entries` insert payload. Replace `user_id` with the authenticated user's UUID.

---

## Testing the Integration

### Step 1: Run the app and sign in
1. Start the dev server: `npm run dev`
2. Open http://localhost:3000
3. Click **Sign in** and create an account or sign in

### Step 2: Insert a log entry
1. Go to **Log** (bottom nav)
2. Set pain/stress levels, select symptoms, triggers, remedies
3. Click **Save Entry**
4. You should see "Entry saved successfully!" and the entry on the dashboard

### Step 3: Verify normalized tables (optional)
In Supabase Dashboard → Table Editor, check:
- `log_entries` – your new row
- `log_days` – one row per date you logged
- `meal_events`, `symptom_events`, `remedy_events`, `trigger_events` – populated by triggers

### Step 4: View the timeline
1. Go to **Analytics** (bottom nav)
2. You should see the **Event Timeline** with your log entries and normalized events

**If Analytics shows a permission error**, run this in Supabase SQL Editor:
```sql
grant select on public.v_user_timeline to anon;
grant select on public.v_user_timeline to authenticated;
```

---

## v3 feature layer (migration `20260325150000_gastroguard_v3_schema_and_rpcs.sql`)

Additive tables: `daily_feature_rollups`, `rolling_feature_snapshots`, `model_features`, `prediction_outputs`, `recommendation_items` (row-level recs), global `food_tags` + `meal_event_food_tags`. Extends `log_entries` with optional scalar fields (`sleep_quality`, `meal_size`, `source`, `sync_status`, `*_labels` mirrors).

RPCs (all require JWT matching `p_user_id`):

- `refresh_daily_feature_rollups(p_user_id, p_start_date, p_end_date)`
- `refresh_rolling_feature_snapshots(p_user_id, p_snapshot_date)`
- `refresh_recommendation_items_v3(p_user_id, p_snapshot_date)` — called from `refresh_user_recommendations` after legacy payload upsert
- `build_model_features(p_user_id, p_as_of_date, p_window_days)`

`refresh_user_analytics` now ends by calling daily + rolling rollups for the same window; `refresh_user_recommendations(uuid, text, date)` replaces the old 2-arg overload and rebuilds both `recommendation_cache` and `recommendation_items`.

**Manual SQL extras:** [supabase_sql_editor_extras_resolve_api_key_and_verify.sql](supabase_sql_editor_extras_resolve_api_key_and_verify.sql) — idempotent `resolve_api_key` + commented verification queries if you apply SQL piecemeal in the Dashboard.
