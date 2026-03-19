# Supabase Auth "Failed to Fetch" Fix

## 1. Create `.env.local` with your Supabase credentials

1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → your **Gastro-guard back end** project
2. **Settings** → **API** → copy:
   - **Project URL** (e.g. `https://hudpufcpgwuieuntinwk.supabase.co`)
   - **anon public** key
3. Create `.env.local` in the project root:

```
NEXT_PUBLIC_SUPABASE_URL=https://hudpufcpgwuieuntinwk.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
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
