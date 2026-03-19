-- Gastro Guard backend schema
-- Run this in Supabase SQL editor.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id text primary key,
  name text not null default '',
  age integer not null default 0,
  height text not null default '',
  weight text not null default '',
  gender text not null default '',
  conditions text[] not null default '{}',
  medications text[] not null default '{}',
  allergies text[] not null default '{}',
  dietary_restrictions text[] not null default '{}',
  triggers text[] not null default '{}',
  effective_remedies text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.log_entries (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.profiles(id) on delete cascade,
  date timestamptz not null,
  time text not null,
  pain_level integer not null check (pain_level between 0 and 10),
  stress_level integer not null check (stress_level between 0 and 10),
  symptoms text[] not null default '{}',
  triggers text[] not null default '{}',
  remedies text[] not null default '{}',
  remedy_effectiveness integer,
  notes text not null default '',
  meal_size text,
  time_since_eating integer,
  sleep_quality integer,
  exercise_level integer,
  weather_condition text,
  ingestion_time text,
  reflux_severity integer,
  nausea_severity integer,
  bloating_severity integer,
  fullness_severity integer,
  burning_location text,
  symptom_start_delay_min integer,
  symptom_duration_min integer,
  suspected_foods text[] default '{}',
  tolerated_foods text[] default '{}',
  medication_taken text[] default '{}',
  medication_effectiveness jsonb,
  medication_side_effects jsonb,
  bowel_changes text[] default '{}',
  vomiting boolean,
  burping boolean,
  regurgitation boolean,
  hydration_tolerance text,
  relief_time_min integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_log_entries_user_date on public.log_entries(user_id, date desc);

alter table public.profiles enable row level security;
alter table public.log_entries enable row level security;

-- Replace auth.uid() with your own user-key mapping if not using Supabase Auth.
create policy "profiles_select_own" on public.profiles
for select using (id = auth.uid()::text);

create policy "profiles_upsert_own" on public.profiles
for all using (id = auth.uid()::text) with check (id = auth.uid()::text);

create policy "entries_select_own" on public.log_entries
for select using (user_id = auth.uid()::text);

create policy "entries_mutate_own" on public.log_entries
for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);
