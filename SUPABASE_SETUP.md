# Supabase Auth "Failed to Fetch" Fix

## 1. Create `.env.local` with your Supabase credentials

1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → your **Gastro-guard back end** project
2. **Settings** → **API** → copy:
   - **Project URL** (e.g. `https://xxxx.supabase.co`)
   - **anon public** key
   - **service_role** key (secret) — required for `/api/*` routes; see [section 5](#5-rest-api-integrations-api-and-service-role-key) below
3. Create `.env.local` in the project root (you can start from `.env.example`):

```
NEXT_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

4. **Restart the dev server** (`Ctrl+C` then `npm run dev`)

---

## 2. Disable email confirmation (for local testing)

If signup still fails, Supabase may be trying to send a confirmation email and failing:

1. Supabase Dashboard → **Authentication** → **Providers** → **Email**
2. Turn **OFF** "Confirm email"
3. Try signup again

You can turn it back on later once SMTP is configured.

---

## 3. Add redirect URL (if using OAuth or magic links)

1. **Authentication** → **URL Configuration**
2. Add `http://localhost:3000` to **Site URL**
3. Add `http://localhost:3000/auth/callback` to **Redirect URLs**

---

## 4. Verify env vars are loaded

In the browser console (F12), run:

```js
console.log(process.env.NEXT_PUBLIC_SUPABASE_URL)
```

If it shows `undefined`, the env file is missing or the server wasn’t restarted.

---

## 5. REST API integrations (`/api/*`) and service role key

The routes `/api/entries`, `/api/profile`, and `/api/analytics` authenticate **external** callers with an integration API key (`Authorization: Bearer gg_...`). The server resolves that key via the Postgres function `resolve_api_key()` and uses the **service role** client to run queries (RLS bypass where the route needs it).

1. Apply the migration that defines `resolve_api_key` if you have not already (see `supabase/migrations/20260325140000_resolve_api_key_rpc.sql`). Running it in the SQL Editor may show **no rows** — that is normal for DDL (`CREATE FUNCTION`, `GRANT`, etc.).
2. In `.env.local`, set:

   ```
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
   ```

   Get the value from **Supabase Dashboard → Project Settings → API → service_role (secret)**. Copy `.env.example` to `.env.local` if you are starting fresh.

3. **Restart the dev server** (`Ctrl+C`, then `npm run dev`) so Next.js loads the new variable.

### End-to-end flow

1. In the app: **Profile → App Integrations → New** — create an integration and copy the `gg_...` key.
2. Your external app calls the API with that key.
3. The route calls `resolve_api_key()` → gets `user_id` → reads or writes only that user’s data.
4. `POST /api/entries` creates rows that go through the same sync triggers as the UI.

### Quick test with curl

Replace `YOUR_GG_KEY` with a real integration key from the app:

```bash
curl http://localhost:3000/api/entries \
  -H "Authorization: Bearer YOUR_GG_KEY"
```

You should get JSON with `entries` (or an error if the key is missing or invalid).
