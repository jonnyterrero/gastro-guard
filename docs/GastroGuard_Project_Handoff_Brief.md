# GastroGuard Project Handoff Brief

**Source of truth:** This brief extends and operationalizes [`GastroGuard_System_Specification.md`](GastroGuard_System_Specification.md) (reverse-engineered from the repo). Statements marked **confirmed in code** were verified in TypeScript/SQL; **inferred** items are called out explicitly.

---

## 1. Product Summary

**What it is:** GastroGuard is a browser-based **PWA** (Next.js 14) for people tracking **digestive / gastritis-style** symptoms. It brands as “Enhanced v3.0” and emphasizes pain/stress tracking, logging, lightweight “smart” guidance, a **symptom simulator**, and a unified **event timeline** when signed in.

**Problem it solves:** Gives users a single place to record flare-ups, context (meals, triggers, remedies), and see trends—optionally **synced via Supabase** so data is not trapped on one device.

**User-visible behavior (confirmed in code):**

- **Without account:** Full dashboard and most screens work; logs and profile persist in **localStorage**. Sign-in is optional (`middleware` does not force auth).
- **With account:** Same UI; logs and profile read/write **Postgres via Supabase** under RLS. Header shows **Sign out**; timeline (**Stats** tab) loads `v_user_timeline`.
- **Not medical software:** Copy in the simulator disclaims medical advice; recommendations are **heuristic**, not clinician-authored.

---

## 2. Current Feature Inventory

Legend: **Complete** = usable end-to-end in app. **Partial** = works but limited, stub, or UI/data mismatch. **Placeholder** = UI or schema exists; no real backend enforcement.

### Authentication

| Feature | What it does | Where | Status |
|--------|----------------|------|--------|
| Email/password sign-up | Creates user; may require email confirm depending on Supabase project settings | [`app/auth/page.tsx`](../app/auth/page.tsx) | **Complete** (depends on Supabase config) |
| Email/password sign-in | Session via Supabase | [`app/auth/page.tsx`](../app/auth/page.tsx) | **Complete** |
| OAuth callback | Exchanges `code` for session | [`app/auth/callback/route.ts`](../app/auth/callback/route.ts) | **Complete** |
| Session refresh | Cookies refreshed on navigation | [`middleware.ts`](../middleware.ts), [`lib/supabase/middleware.ts`](../lib/supabase/middleware.ts) | **Complete** |
| Route guarding | None—no redirect to `/auth` for protected routes | — | **By design / gap:** app is usable logged out |

### Profile / account

| Feature | What it does | Where | Status |
|--------|----------------|------|--------|
| Profile bootstrap | New auth user gets `profiles` row (`handle_new_user`) | SQL in [`supabase/gastroguard_production_schema_v2.sql`](../supabase/gastroguard_production_schema_v2.sql) | **Complete** (DB) |
| Load profile + integrations | Fetches `profiles`; merges with localStorage | [`app/page.tsx`](../app/page.tsx), [`lib/profile.ts`](../lib/profile.ts) | **Complete** |
| Save profile | Upserts `profiles` when logged in; always updates localStorage | [`app/page.tsx`](../app/page.tsx) | **Partial** — **only Name and Age have form fields**; `UserProfile` also carries conditions, medications, allergies, etc., but there are **no inputs** for those in JSX (only `setUserProfile` for name/age **confirmed**). Data can still arrive from localStorage merge or future edits. |
| Sign out | `supabase.auth.signOut()` | [`app/page.tsx`](../app/page.tsx) | **Complete** |

### Symptom and health logging

| Feature | What it does | Where | Status |
|--------|----------------|------|--------|
| Enhanced log | Pain/stress sliders, multi-select symptoms, triggers, remedies, notes, meal context fields | [`app/page.tsx`](../app/page.tsx) | **Complete** |
| Save entry (logged in) | Insert/update `log_entries` via adapter | [`lib/adapter/log-entry.ts`](../lib/adapter/log-entry.ts) | **Complete** |
| Save entry (logged out) | Append to state + `localStorage` `gastroguard-entries` | [`app/page.tsx`](../app/page.tsx) | **Complete** |
| Edit / delete entry | Update/delete by `id` + `user_id` when logged in | [`app/page.tsx`](../app/page.tsx) | **Complete** |
| History list | Paginated list of entries | [`app/page.tsx`](../app/page.tsx) `currentView === "history"` | **Complete** |
| Dashboard “today” stats | Derived from in-memory `entries` | [`app/page.tsx`](../app/page.tsx) | **Complete** |

### Triggers / remedies / meals

| Feature | What it does | Where | Status |
|--------|----------------|------|--------|
| Fixed symptom/trigger/remedy picklists | Hardcoded string arrays | [`app/page.tsx`](../app/page.tsx) | **Complete** (not DB-driven) |
| Meal name + derived `meal_notes` | Optional fields folded into `meal_notes` text (sleep, exercise, weather, etc.) | [`lib/adapter/log-entry.ts`](../lib/adapter/log-entry.ts) | **Complete** |
| Food tags / rich JSONB | Types support `food_tags`, `episode_at`, `meal_occurred_at`; adapter exposes `fromDbRow` foodTags | [`lib/types/log-entry.ts`](../lib/types/log-entry.ts), adapter | **Partial** — DB + types support extended shape; **[`app/page.tsx`](../app/page.tsx) has no references to `food_tags`, `episode_at`, or `meal_occurred_at`** (verified), so the enhanced log UI does not capture those fields. |
| DB normalization | Triggers expand `log_entries` → `meal_events`, `symptom_events`, etc. | SQL triggers | **Complete** (server-side) |

### Analytics / timeline

| Feature | What it does | Where | Status |
|--------|----------------|------|--------|
| Event timeline (Stats) | Loads last 50 rows from `v_user_timeline` | `AnalyticsView` in [`app/page.tsx`](../app/page.tsx) | **Complete** when authenticated |
| Batch analytics RPCs | `refresh_user_analytics`, `refresh_user_recommendations` populate cache tables | SQL | **Prepared only** — **no** `.rpc()` calls in app TS/TSX (verified) |
| Charts package | `recharts` in dependencies | [`package.json`](../package.json) | **Unused** in main feature path (simulator uses custom SVG) |

### Integrations

| Feature | What it does | Where | Status |
|--------|----------------|------|--------|
| Integration records | Client-generated `gg_…` keys, permissions labels; stored in `profiles.integrations` JSONB | [`app/page.tsx`](../app/page.tsx), [`lib/profile.ts`](../lib/profile.ts) | **Complete** (persistence) |
| **REST API** advertised in UI | Docs block lists `GET /api/entries`, etc. | [`app/page.tsx`](../app/page.tsx) | **Placeholder** — **no** [`app/api/`](../app/) routes in repo (verified) |

### Offline / PWA behavior

| Feature | What it does | Where | Status |
|--------|----------------|------|--------|
| localStorage keys | `gastroguard-entries`, `gastroguard-profile`, `gastroguard-integrations` | [`app/page.tsx`](../app/page.tsx) | **Complete** |
| Manifest | Icons, theme, shortcuts | [`public/manifest.json`](../public/manifest.json) | **Complete** |
| Service worker | Registered on load | [`app/layout.tsx`](../app/layout.tsx), [`public/sw.js`](../public/sw.js) | **Complete** (registration) |
| Shortcut URLs | `/?action=log`, `/?action=analytics` | [`public/manifest.json`](../public/manifest.json) | **Partial** — **no** `useSearchParams` / handler in [`app/page.tsx`](../app/page.tsx) (verified) so shortcuts may not open the right tab |

### Inferred / hidden features

| Feature | Notes | Status |
|--------|--------|--------|
| **Smart Recommendations** | `getPersonalizedRecommendations()` — rules from `currentPainLevel`, `currentStressLevel`, `userProfile` (conditions, allergies) | **Complete** as **client-only**; not DB |
| **Symptom Simulator** | `runSimulation()` + chart — uses local `entries` + heuristics; not ML/DB | **Complete** as demo logic |
| **Conditions in recs** | GERD/IBS checks use `userProfile.conditions` | **Partial** — logic exists, **no UI** to edit conditions (see profile) |
| **Python desktop app** | Separate artifact | **Out of scope** for web handoff |

---

## 3. Current System Architecture

**Frontend**

- **Framework:** Next.js 14 App Router, React 18.
- **Primary UI:** Single **client component** [`app/page.tsx`](../app/page.tsx) (~1700+ lines) owns all views via `currentView` string state.
- **Auth UI:** [`app/auth/page.tsx`](../app/auth/page.tsx).
- **Styling:** Tailwind + Radix + Lucide icons; gradient “glass” aesthetic.

**Backend (application)**

- **No Next.js Route Handler API** for domain data (integrations doc is fake).
- **Middleware:** Session refresh only.
- **Server Supabase client:** Used in auth callback and available for server components—not used for a separate BFF layer.

**Database (Supabase Postgres)**

- **Auth:** Supabase Auth (`auth.users`).
- **App data:** `public.*` tables per system spec; **RLS** on all listed tables with `auth.uid() = user_id`.
- **Triggers:** `log_entries` → `sync_log_entry_*` → normalized tables (`security definer`).
- **Views:** `v_user_timeline` with `security_invoker = true`; `authenticated` SELECT only (v2 + P0 migrations).
- **RPCs:** `refresh_user_analytics`, `refresh_user_recommendations` (defined in SQL; optional auth rules in P0 migrations).

**Storage**

- **Remote:** Postgres via Supabase.
- **Local:** `localStorage` for offline/anonymous parity.

**Auth**

- Browser: `createBrowserClient` + env (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`).
- Server: cookie adapter in [`lib/supabase/server.ts`](../lib/supabase/server.ts).

**Adapters / mappers**

- [`lib/adapter/log-entry.ts`](../lib/adapter/log-entry.ts): form ↔ `log_entries`.
- [`lib/profile.ts`](../lib/profile.ts): `profiles` ↔ `UserProfile` / integrations.

---

## 4. Current Data Model

### `UserProfile` ([`lib/profile.ts`](../lib/profile.ts))

- Fields: `name`, `age`, `height`, `weight`, `gender`, `conditions[]`, `medications[]`, `allergies[]`, `dietaryRestrictions[]`, `triggers[]`, `effectiveRemedies[]`.
- **Mismatch:** v2 schema stores **conditions/medications** in **`profile_conditions`** / **`medications`** tables, not JSONB columns on `profiles`. Client still uses **`profiles` row only** and arrays in memory; **no client code** reads/writes normalized condition/medication tables (confirmed in system spec).

### `LogEntry` (local interface in [`app/page.tsx`](../app/page.tsx))

- UI-facing shape: `id`, `date`, `time`, `painLevel`, `stressLevel`, `symptoms[]`, `triggers[]`, `remedies[]`, `notes`, optional meal/sleep/exercise fields.
- **Mismatch vs DB:** [`LogEntryDb`](../lib/types/log-entry.ts) supports structured JSONB elements and `food_tags`; local `LogEntry` is **simpler** (mostly string arrays for symptoms/triggers/remedies).

### `profiles` table

- Scalar + JSONB arrays (`allergies`, `dietary_restrictions`, `triggers`, `effective_remedies`, `integrations`), **no** `conditions`/`medications` columns in v2.

### `log_entries` table

- Canonical write surface: scores, JSONB arrays, `food_tags`, `episode_at`, `meal_occurred_at`, etc.

### Normalized event tables

- `meal_events`, `symptom_events`, `remedy_events`, `trigger_events` (+ tags/junctions); **read** via `v_user_timeline`; **not** written by client directly.

### Analytics tables

- `*_scores`, `weekly_summaries`, `recommendation_cache` — **populated by RPCs**, not by current app.

### Timeline view `v_user_timeline`

- Union of log + normalized rows; **Stats** tab consumes this.

---

## 5. App Flow Overview

### Unauthenticated / offline

1. `mounted` gate shows loading splash (“Loading GastroGuard…”).
2. `getSession()` → no user → entries load from `localStorage` (or empty).
3. Profile load merges `localStorage` profile only.
4. Save log/profile writes **localStorage** only.
5. Timeline (**Stats**) shows “Sign in to view…”.

### Authenticated

1. `onAuthStateChange` sets `user`.
2. Entries load: `log_entries` `select *` ordered by `entry_at`.
3. Profile: `fetchProfileAndIntegrations` + merge with localStorage for name gap-fill.
4. Save log: insert/update `log_entries` (triggers run server-side).
5. Timeline: `v_user_timeline` select for `AnalyticsView`.
6. Sign out: clears session; next load behaves as offline unless local data remains.

### Profile load / save

- **Load:** Supabase + `localStorage` merge rules in [`app/page.tsx`](../app/page.tsx) (e.g. push local name to server if empty).
- **Save:** `upsert` `profiles` with `userProfileToUpsert` + integrations array.

### Log create / update / delete

- **Create:** `toDbPayload` → insert → `fromDbRow` → prepend to list.
- **Update:** `toDbUpdatePayload` preserving `entry_at` / `entry_date`.
- **Delete:** `delete` with `eq` on `id` and `user_id`.

### Timeline loading

- **Component:** `AnalyticsView` fetches `v_user_timeline` when `user` present.

### Integrations storage

- **Update:** `profiles.integrations` JSONB via `update` or `upsert`.

---

## 6. Implementation Status Matrix

| Area | Implemented Now | Partial / Complete / Planned | Notes |
|------|-------------------|------------------------------|--------|
| Auth (email/password + callback) | Yes | **Complete** | No forced login |
| Profile CRUD | Name/age UI + upsert | **Partial** | Many `UserProfile` fields not editable in UI |
| Log CRUD + Supabase | Yes | **Complete** | Single-table write |
| Normalized sync | DB triggers | **Complete** | Client never bypasses |
| Timeline view | Yes | **Complete** | Needs auth |
| Smart recommendations | Client heuristics | **Complete** (client-only) | Not `recommendation_cache` |
| Symptom simulator | Client heuristics | **Complete** (demo) | Not server-side model |
| Analytics RPCs + cache tables | SQL only | **Planned / wired** | No app calls |
| REST API for integrations | Advertised in UI | **Planned** | No `app/api` routes |
| PWA shortcuts | Manifest | **Partial** | Query params not handled |
| Normalized conditions/medications | DB tables | **Planned** | No client integration |
| `@vercel/analytics` | Dependency | **Unused** | Optional enable |

---

## 7. Current Technical Debt and Weak Points

1. **Monolithic [`app/page.tsx`](../app/page.tsx):** All views, state, and business logic in one file—hard to test, review, and code-split.
2. **Coupling:** UI state (`currentPainLevel`) drives “recommendations” that are unrelated to stored log entries.
3. **Missing abstractions:** No domain hooks (`useLogEntries`, `useProfile`), no API layer, no feature folders.
4. **Schema mismatch:** `UserProfile.conditions` / `medications` vs `profile_conditions` / `medications` tables — **dual models** without migration path in the client.
5. **Unfinished backend wiring:** `refresh_user_*`, analytics tables, `recommendation_cache` unused by app.
6. **False integration surface:** `/api/*` documentation in UI **misleading** for production.
7. **Production risks:** Offline data never auto-merges to cloud on first login (user must re-save); no migration from localStorage → Supabase.
8. **PWA shortcuts:** Broken or no-op deep links without query handling.
9. **Placeholder env:** `@vercel/analytics` unused—dead dependency or TODO.

---

## 8. What Is Built vs What Is Planned

| Category | Items |
|----------|--------|
| **Confirmed implemented** | Email auth, session middleware, log CRUD to `log_entries`, profile upsert to `profiles`, integrations JSON, `v_user_timeline` read, DB triggers, RLS, PWA shell + SW registration, localStorage offline mode, client recommendations + simulator |
| **Partially implemented** | Profile (full type vs 2 fields), food_tags / episode times in UI vs DB, manifest shortcuts |
| **Prepared in schema, not wired to UI** | `refresh_user_analytics`, `refresh_user_recommendations`, analytics + weekly + recommendation cache tables, `profile_conditions` / `medications` tables |
| **Conceptual / marketing only** | REST API for third parties, permission strings on integrations |

---

## 9. Recommended Next Development Priorities

1. **Split [`app/page.tsx`](../app/page.tsx)** into routes or feature components (`dashboard`, `log`, `history`, `stats`, `profile`, `simulator`) with shared hooks—highest leverage for maintainability.
2. **Either implement or remove** fake `/api/*` documentation; if real, add authenticated Edge/Route handlers or Supabase RLS-safe patterns.
3. **Wire analytics:** Call `refresh_user_analytics` after log save (debounced) or via cron; **Stats** tab could show `weekly_summaries` or cached scores—not only raw timeline.
4. **Profile completeness:** Add UI for conditions, allergies, medications **or** sync `profile_conditions` / `medications` tables and drop duplicate arrays from mental model.
5. **Handle PWA shortcuts:** Read `searchParams` on `/` and set `currentView` / open log.
6. **First-login migration:** Optional flow to import `localStorage` entries into Supabase.
7. **Production readiness:** Error boundaries, toast instead of `alert`, loading states on mutations, remove `Math.random()` in simulator chart path if any remains.
8. **Remove or enable** `@vercel/analytics` explicitly.

---

## 10. Final Claude Context Summary

GastroGuard is a **Next.js 14 + Supabase** PWA with a **single monolithic client page** driving every feature. **Users can run fully offline** via `localStorage`; **signed-in users** sync **`log_entries`** and **`profiles`** under strict **RLS**. **Postgres triggers** normalize logs into event tables; the **Stats** view reads **`v_user_timeline`**. **Analytics RPCs and cache tables exist in SQL but are not called from TypeScript.** Smart recommendations and the symptom simulator are **client-side heuristics**, not DB-backed. **Integrations** persist `gg_` keys in JSONB with **no server API**. **Profile** types include conditions/medications, but the **UI only edits name and age**—a **major product/DB gap**. **Next priorities:** decompose the main file, wire or remove fake APIs, connect analytics RPCs and/or normalized profile tables, and fix PWA shortcut handling. **System spec** remains the detailed architecture reference; this brief is the **actionable backlog** for continued development.
