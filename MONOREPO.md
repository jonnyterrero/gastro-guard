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

- **Run the app:** `cd frontend && npm install && npm run dev`
- **Apply DB migrations:** use Supabase CLI from `backend/supabase` (see [SUPABASE_SETUP.md](SUPABASE_SETUP.md))
- **Deploy (Vercel):** set the project **Root Directory** to `frontend` and use the same env vars as [frontend/.env.example](frontend/.env.example)

Route Handlers (`app/api/*`) live inside **frontend** because they are part of the Next.js deployment unit; **backend** is the authoritative SQL/migration tree for Postgres.
