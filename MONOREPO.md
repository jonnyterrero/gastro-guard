# Gastro Guard monorepo layout

This repository is organized as a **Next.js + Supabase** monorepo (no Turborepo/Nx workspace).

```
/
├── frontend/          # Next.js 16 app (UI, middleware, Route Handlers under app/api)
│   ├── app/
│   ├── components/
│   ├── hooks/
│   ├── lib/
│   ├── public/
│   ├── middleware.ts
│   ├── package.json
│   └── .env.example
├── backend/           # Database layer (Supabase migrations + SQL helpers)
│   ├── supabase/
│   └── .env.example
├── legacy/            # Desktop/Python prototypes — not used by the web app
├── docs/              # Product & technical specs
├── README.md
└── .gitignore
```

### Local dev (Next.js)

1. `cd frontend`
2. Copy [frontend/.env.example](frontend/.env.example) → `frontend/.env.local` and fill in values from the Supabase dashboard.
3. `npm install` (first time) then `npm run dev`.

### Supabase CLI and SQL workflows

Use **`backend/supabase`** as the Supabase project directory: run the CLI from that folder so migrations and link state resolve correctly.

```bash
cd backend/supabase
# e.g. supabase link, supabase db push, supabase migration new ...
```

Alternatively, from the repo root: `supabase --workdir backend/supabase <command>`.

See [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for env vars and manual SQL apply order.
- **Deploy (Vercel):** set the project **Root Directory** to `frontend` and use the same env vars as [frontend/.env.example](frontend/.env.example).

Route Handlers (`app/api/*`) live inside **frontend** because they are part of the Next.js deployment unit; **backend** is the authoritative SQL/migration tree for Postgres.
