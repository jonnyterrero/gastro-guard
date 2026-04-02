-- Store integration keys client-side metadata in profiles (synced with app)
alter table public.profiles add column if not exists integrations jsonb default '[]'::jsonb;

comment on column public.profiles.integrations is 'User integration records (name, apiKey, permissions, etc.) as JSON array';
