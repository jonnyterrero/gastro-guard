# Deploy GastroGuard to Vercel

## Environment variables

In the Vercel project: **Settings** → **Environment Variables**, add:

| Name | Value | Notes |
|------|--------|--------|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://YOUR_PROJECT_REF.supabase.co` | From Supabase → Settings → API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | anon public key | Safe for browser |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role key | **Server-only** — use only in API routes or server actions, never `NEXT_PUBLIC_` |

Apply to **Production**, **Preview**, and **Development** as needed.

## Supabase Auth URLs

After you have a production URL (e.g. `https://gastro-guard.vercel.app`):

1. Supabase → **Authentication** → **URL Configuration**
2. **Site URL**: your production URL
3. **Redirect URLs**: add `https://your-domain.vercel.app/auth/callback`

## Build

The Next.js app lives in **`frontend/`**. In Vercel: **Settings** → **General** → **Root Directory** → `frontend`.

```bash
cd frontend
npm install
npm run build
```

Fix any errors before deploying. Connect the GitHub repo in Vercel and deploy the `gastro-backend` branch (or your default branch).

## Verify

- Open the deployed URL, sign in, save a log entry, confirm it appears in Supabase Table Editor.
