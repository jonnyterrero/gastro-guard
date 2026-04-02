---
name: GastroGuard Full Backend Buildout
overview: Production backend buildout for GastroGuard on Supabase. Phases 1-4 (schema, triggers, RLS) are largely complete; Phase 5 (frontend integration, profile sync, History, edit/delete, deployment) remains.
todos: []
isProject: false
---

# GastroGuard Full Backend Buildout

## Current State vs Spec


| Phase | Spec                                | Current State                                                               |
| ----- | ----------------------------------- | --------------------------------------------------------------------------- |
| 1     | profiles (id, email, display_name)  | Done: profiles has user_id FK, richer schema (name, age, conditions, etc.)  |
| 2     | log_entries with entry_date derived | Done: log_entries exists; entry_date is stored, not generated               |
| 3     | 5 normalized tables                 | Done: log_days, meal_events, symptom_events, remedy_events, trigger_events  |
| 4     | 4 metadata tables                   | Done: meal_tags, symptom_tags, profile_conditions, medications              |
| 5     | Frontend integration                | Partial: log save/load works; profile, History, edit/delete, deploy pending |


Sync triggers and RLS are in place. Minor schema differences (profiles structure, remedy helpfulness 0-5 vs 0-10) can be addressed if needed.

---

## Phase 1 — Project and Auth Foundation

**Status:** Done (with richer profiles schema)

**Spec:**

- `set_updated_at()` trigger
- `profiles`: id (PK = auth.users.id), email, display_name, created_at, updated_at
- `handle_new_user()` inserts (id, email) on auth.users insert
- RLS: SELECT/UPDATE where `(select auth.uid()) = id`

**Current:** [backend/supabase/migrations/20260319000000_gastroguard_hybrid_backend.sql](../../backend/supabase/migrations/20260319000000_gastroguard_hybrid_backend.sql) has profiles with user_id FK and extended columns. Consider adding `email` and `display_name` if aligning to spec.

---

## Phase 2 — Frontend-Compatible Write Model

**Status:** Done

**Spec:** log_entries with entry_date generated or trigger-derived; pain/stress/nausea 0-10; meal_name, meal_notes; symptoms/triggers/remedies jsonb; indexes on (user_id, entry_at desc), (user_id, entry_date).

**Current:** Matches. entry_date is stored (frontend supplies it). Could add generated column in a follow-up migration if desired.

---

## Phase 3 — Normalized Analytics Tables

**Status:** Done

**Spec:** log_days, meal_events, symptom_events, remedy_events, trigger_events with FKs, source_entry_id, RLS, indexes.

**Current:** All five tables exist. Note: spec has remedy `helpfulness` 0-5; current migration uses 0-10.

---

## Phase 4 — User Metadata and Lookup Tables

**Status:** Done

**Spec:** meal_tags, symptom_tags, profile_conditions, medications with user_id, RLS, unique constraints.

**Current:** All four tables exist.

---

## Phase 5 — Frontend Integration and Deployment

**Status:** To build

### 5a. Profile sync to Supabase

- Load profile from `profiles` on login (by user_id).
- On save, upsert to `profiles` (display name, conditions, medications, etc.).
- Keep localStorage as fallback when offline.
- **Files:** [app/page.tsx](app/page.tsx) (profile state, saveProfile, useEffect for profile load).

### 5b. History view

- Replace placeholder with Supabase query: `log_entries` where user_id = auth.uid(), order by entry_at desc.
- Add pagination (limit 20, offset or cursor).
- **Files:** [app/page.tsx](app/page.tsx) (currentView === "history" section).

### 5c. Edit and delete entries

- **Edit:** Pre-fill log form with entry data; on submit, `update log_entries set ... where id = :id and user_id = :uid`.
- **Delete:** Confirm dialog, then `delete from log_entries where id = :id and user_id = :uid`.
- Add edit/delete controls to entry cards (Recent Entries, History).
- **Files:** [app/page.tsx](app/page.tsx), [lib/adapter/log-entry.ts](lib/adapter/log-entry.ts) (add update payload helper if needed).

### 5d. API key storage

- Check if app stores API keys in localStorage (e.g. integrations).
- If yes: add `user_settings` table or jsonb column on profiles; migrate keys; avoid exposing server-side keys to client.
- If no: skip.
- **Current:** [app/page.tsx](app/page.tsx) has integrations with apiKey in localStorage; these are user-generated keys for external apps, not secrets like OpenAI. Evaluate whether to move to Supabase.

### 5e. Deploy to Vercel

- Set env vars in Vercel: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (server-only).
- Add Supabase redirect URLs for production domain.
- Run build and verify auth and data flow on production.

---

## Constraints and Standards

- RLS on every user-owned table.
- Use `(select auth.uid())` in policies where spec requires it (current code uses `auth.uid()`).
- CHECK constraints on score fields (0-10 or 0-5 per spec).
- Migrations: pure PostgreSQL, Supabase SQL editor compatible.
- Do not break existing frontend; `log_entries` remains the write surface.
- Add table/column comments in migrations.
- Migration naming: `001`*, `002`*, etc. (current uses timestamps; can add numbered aliases).

---

## Execution Order for Tomorrow

1. **5a** — Profile sync (highest impact)
2. **5b** — History view (wire to Supabase)
3. **5c** — Edit and delete entries
4. **5d** — API key storage (if applicable)
5. **5e** — Vercel deployment

Optional schema tweaks: add email/display_name to profiles; change remedy helpfulness to 0-5; add generated entry_date.