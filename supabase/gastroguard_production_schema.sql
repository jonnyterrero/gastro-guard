-- =============================================================================
-- GastroGuard — Production schema (single-file, Supabase SQL editor)
-- =============================================================================
-- Hybrid model: app writes public.log_entries; triggers sync normalized rows.
-- Run in Supabase SQL Editor on a fresh project, OR use as reference; uses
-- idempotent patterns (IF NOT EXISTS, DROP POLICY IF EXISTS) where practical.
-- =============================================================================

-- #############################################################################
-- SECTION 1 — Extensions
-- #############################################################################

create extension if not exists pgcrypto;

-- =============================================================================
-- Helper: maintain updated_at
-- =============================================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;


-- #############################################################################
-- SECTION 2 — Core tables
-- #############################################################################

-- -----------------------------------------------------------------------------
-- profiles (1:1 with auth.users)
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null default '',
  age integer not null default 0,
  height text not null default '',
  weight text not null default '',
  gender text not null default '',
  conditions jsonb not null default '[]'::jsonb,
  medications jsonb not null default '[]'::jsonb,
  allergies jsonb not null default '[]'::jsonb,
  dietary_restrictions jsonb not null default '[]'::jsonb,
  triggers jsonb not null default '[]'::jsonb,
  effective_remedies jsonb not null default '[]'::jsonb,
  integrations jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_user_id_key unique (user_id)
);

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

comment on table public.profiles is 'User profile; one row per auth user.';
comment on column public.profiles.integrations is 'Integration records (name, metadata, etc.) as JSON array.';

-- -----------------------------------------------------------------------------
-- Auth: auto-create profile on signup (after public.profiles exists)
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- log_entries (flat capture / app write surface)
-- -----------------------------------------------------------------------------
create table if not exists public.log_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  entry_at timestamptz not null default now(),
  entry_date date not null,
  pain_score integer not null default 0 check (pain_score >= 0 and pain_score <= 10),
  stress_score integer not null default 0 check (stress_score >= 0 and stress_score <= 10),
  nausea_score integer check (nausea_score is null or (nausea_score >= 0 and nausea_score <= 10)),
  meal_name text,
  meal_notes text,
  food_tags jsonb not null default '[]'::jsonb,
  episode_at timestamptz,
  meal_occurred_at timestamptz,
  symptoms jsonb not null default '[]'::jsonb,
  triggers jsonb not null default '[]'::jsonb,
  remedies jsonb not null default '[]'::jsonb,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists log_entries_updated_at on public.log_entries;
create trigger log_entries_updated_at
  before update on public.log_entries
  for each row execute function public.set_updated_at();

comment on table public.log_entries is 'Flat log row — primary insert target for the client.';
comment on column public.log_entries.food_tags is 'JSON array: strings or {tag, category?, confidence?}.';
comment on column public.log_entries.episode_at is 'When the GI episode occurred; if null, sync uses entry_at.';
comment on column public.log_entries.meal_occurred_at is 'Optional meal time; if null, meal_events use coalesce(episode_at, entry_at).';

-- Additive columns if an older partial install exists
alter table public.log_entries
  add column if not exists food_tags jsonb not null default '[]'::jsonb;
alter table public.log_entries
  add column if not exists episode_at timestamptz;
alter table public.log_entries
  add column if not exists meal_occurred_at timestamptz;
alter table public.profiles
  add column if not exists integrations jsonb not null default '[]'::jsonb;

-- -----------------------------------------------------------------------------
-- log_days
-- -----------------------------------------------------------------------------
create table if not exists public.log_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint log_days_user_date unique (user_id, log_date)
);

drop trigger if exists log_days_updated_at on public.log_days;
create trigger log_days_updated_at
  before update on public.log_days
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Normalized event tables
-- -----------------------------------------------------------------------------
create table if not exists public.meal_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_day_id uuid not null references public.log_days (id) on delete cascade,
  source_entry_id uuid references public.log_entries (id) on delete set null,
  occurred_at timestamptz not null,
  meal_name text,
  notes text,
  food_tags jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.meal_events
  add column if not exists food_tags jsonb not null default '[]'::jsonb;

drop trigger if exists meal_events_updated_at on public.meal_events;
create trigger meal_events_updated_at
  before update on public.meal_events
  for each row execute function public.set_updated_at();

create table if not exists public.symptom_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_day_id uuid not null references public.log_days (id) on delete cascade,
  source_entry_id uuid references public.log_entries (id) on delete set null,
  occurred_at timestamptz not null,
  symptom_name text not null,
  severity integer check (severity is null or (severity >= 0 and severity <= 10)),
  notes text,
  subtype text,
  body_region text,
  onset_after_meal_minutes integer check (
    onset_after_meal_minutes is null or onset_after_meal_minutes >= 0
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.symptom_events
  add column if not exists subtype text;
alter table public.symptom_events
  add column if not exists body_region text;
alter table public.symptom_events
  add column if not exists onset_after_meal_minutes integer
    check (onset_after_meal_minutes is null or onset_after_meal_minutes >= 0);

drop trigger if exists symptom_events_updated_at on public.symptom_events;
create trigger symptom_events_updated_at
  before update on public.symptom_events
  for each row execute function public.set_updated_at();

create table if not exists public.remedy_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_day_id uuid not null references public.log_days (id) on delete cascade,
  source_entry_id uuid references public.log_entries (id) on delete set null,
  occurred_at timestamptz not null,
  remedy_name text not null,
  helpfulness integer check (helpfulness is null or (helpfulness >= 0 and helpfulness <= 10)),
  effectiveness_score integer check (
    effectiveness_score is null or (effectiveness_score >= 0 and effectiveness_score <= 10)
  ),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.remedy_events
  add column if not exists effectiveness_score integer
    check (effectiveness_score is null or (effectiveness_score >= 0 and effectiveness_score <= 10));

drop trigger if exists remedy_events_updated_at on public.remedy_events;
create trigger remedy_events_updated_at
  before update on public.remedy_events
  for each row execute function public.set_updated_at();

create table if not exists public.trigger_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_day_id uuid not null references public.log_days (id) on delete cascade,
  source_entry_id uuid references public.log_entries (id) on delete set null,
  source_type text not null check (source_type in ('entry', 'meal', 'symptom')),
  source_ref_id uuid,
  occurred_at timestamptz not null,
  trigger_name text not null,
  notes text,
  intensity integer check (intensity is null or (intensity >= 0 and intensity <= 10)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.trigger_events
  add column if not exists intensity integer
    check (intensity is null or (intensity >= 0 and intensity <= 10));

drop trigger if exists trigger_events_updated_at on public.trigger_events;
create trigger trigger_events_updated_at
  before update on public.trigger_events
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- profile_conditions & medications
-- -----------------------------------------------------------------------------
create table if not exists public.profile_conditions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  condition_name text not null,
  notes text,
  diagnosed_at date,
  created_at timestamptz not null default now()
);

create table if not exists public.medications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  medication_name text not null,
  dosage text,
  frequency text,
  notes text,
  created_at timestamptz not null default now()
);


-- #############################################################################
-- SECTION 3 — Tag dimensions & relationship (junction) tables
-- #############################################################################

-- User-owned tag dictionaries
create table if not exists public.meal_tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  constraint meal_tags_user_name unique (user_id, name)
);

create table if not exists public.symptom_tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  constraint symptom_tags_user_name unique (user_id, name)
);

-- Many-to-many: meal_events ↔ meal_tags (sync fills from log_entries.food_tags)
create table if not exists public.meal_event_meal_tags (
  meal_event_id uuid not null references public.meal_events (id) on delete cascade,
  meal_tag_id uuid not null references public.meal_tags (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint meal_event_meal_tags_pkey primary key (meal_event_id, meal_tag_id)
);

-- Many-to-many: symptom_events ↔ symptom_tags (app-assigned labels; RLS enforces user_id)
create table if not exists public.symptom_event_symptom_tags (
  symptom_event_id uuid not null references public.symptom_events (id) on delete cascade,
  symptom_tag_id uuid not null references public.symptom_tags (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint symptom_event_symptom_tags_pkey primary key (symptom_event_id, symptom_tag_id)
);

comment on table public.meal_event_meal_tags is 'Links a meal_event to normalized meal_tags.';
comment on table public.symptom_event_symptom_tags is 'Links a symptom_event to normalized symptom_tags.';


-- #############################################################################
-- SECTION 4 — Analytics & recommendation cache
-- #############################################################################

create table if not exists public.analytics_trigger_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  trigger_name text not null,
  window_start date not null,
  window_end date not null,
  sample_count integer not null default 0,
  avg_pain_when_present numeric,
  avg_pain_when_absent numeric,
  correlation_hint numeric,
  updated_at timestamptz not null default now(),
  constraint analytics_trigger_scores_dedup unique (user_id, trigger_name, window_start, window_end)
);

create table if not exists public.analytics_remedy_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  remedy_name text not null,
  window_start date not null,
  window_end date not null,
  avg_effectiveness numeric,
  usage_count integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint analytics_remedy_scores_dedup unique (user_id, remedy_name, window_start, window_end)
);

create table if not exists public.analytics_food_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  food_tag text not null,
  window_start date not null,
  window_end date not null,
  co_occurrence_pain_avg numeric,
  entry_count integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint analytics_food_scores_dedup unique (user_id, food_tag, window_start, window_end)
);

create table if not exists public.analytics_time_patterns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  bucket_type text not null check (bucket_type in ('hour_of_day', 'dow')),
  bucket_value smallint not null,
  window_start date not null,
  window_end date not null,
  avg_pain numeric,
  entry_count integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint analytics_time_patterns_dedup unique (user_id, bucket_type, bucket_value, window_start, window_end)
);

create table if not exists public.weekly_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  week_start date not null,
  entry_count integer not null default 0,
  avg_pain numeric,
  avg_stress numeric,
  top_triggers jsonb not null default '[]'::jsonb,
  top_remedies jsonb not null default '[]'::jsonb,
  top_symptoms jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  constraint weekly_summaries_dedup unique (user_id, week_start)
);

create table if not exists public.recommendation_cache (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  cache_version text not null default 'v1',
  generated_at timestamptz not null default now(),
  payload jsonb not null default '{}'::jsonb,
  constraint recommendation_cache_dedup unique (user_id, cache_version)
);

comment on table public.analytics_trigger_scores is 'Precomputed trigger vs pain correlations; refresh via refresh_user_analytics.';
comment on table public.analytics_remedy_scores is 'Precomputed remedy effectiveness aggregates.';
comment on table public.analytics_food_scores is 'Precomputed food tag vs pain aggregates.';
comment on table public.analytics_time_patterns is 'Hour-of-day / day-of-week pain patterns.';
comment on table public.weekly_summaries is 'Weekly rollups for dashboard and recommendations.';
comment on table public.recommendation_cache is 'Cached recommendation payload; refresh via refresh_user_recommendations.';


-- #############################################################################
-- SECTION 5 — Indexes
-- #############################################################################

create index if not exists idx_log_entries_user_entry_at
  on public.log_entries (user_id, entry_at desc);
create index if not exists idx_log_entries_user_entry_date
  on public.log_entries (user_id, entry_date);
create index if not exists idx_log_entries_user_episode_at
  on public.log_entries (user_id, episode_at desc)
  where episode_at is not null;

create index if not exists idx_log_days_user_date
  on public.log_days (user_id, log_date);
create index if not exists idx_log_days_log_date
  on public.log_days (log_date);

create index if not exists idx_meal_events_user
  on public.meal_events (user_id);
create index if not exists idx_meal_events_log_day
  on public.meal_events (log_day_id);
create index if not exists idx_meal_events_occurred_at
  on public.meal_events (occurred_at);
create index if not exists idx_meal_events_source_entry
  on public.meal_events (source_entry_id)
  where source_entry_id is not null;

create index if not exists idx_symptom_events_user
  on public.symptom_events (user_id);
create index if not exists idx_symptom_events_log_day
  on public.symptom_events (log_day_id);
create index if not exists idx_symptom_events_symptom_name
  on public.symptom_events (symptom_name);
create index if not exists idx_symptom_events_occurred_at
  on public.symptom_events (occurred_at);
create index if not exists idx_symptom_events_onset_meal
  on public.symptom_events (user_id, onset_after_meal_minutes)
  where onset_after_meal_minutes is not null;

create index if not exists idx_remedy_events_user
  on public.remedy_events (user_id);
create index if not exists idx_remedy_events_log_day
  on public.remedy_events (log_day_id);
create index if not exists idx_remedy_events_occurred_at
  on public.remedy_events (occurred_at);

create index if not exists idx_trigger_events_user
  on public.trigger_events (user_id);
create index if not exists idx_trigger_events_log_day
  on public.trigger_events (log_day_id);
create index if not exists idx_trigger_events_occurred_at
  on public.trigger_events (occurred_at);
create index if not exists idx_trigger_events_source
  on public.trigger_events (source_type, source_ref_id)
  where source_ref_id is not null;

create index if not exists idx_meal_tags_user
  on public.meal_tags (user_id);
create index if not exists idx_symptom_tags_user
  on public.symptom_tags (user_id);

create index if not exists idx_meal_event_meal_tags_user
  on public.meal_event_meal_tags (user_id);
create index if not exists idx_symptom_event_symptom_tags_user
  on public.symptom_event_symptom_tags (user_id);

create index if not exists idx_profile_conditions_user
  on public.profile_conditions (user_id);
create index if not exists idx_medications_user
  on public.medications (user_id);

create index if not exists idx_analytics_trigger_user_window
  on public.analytics_trigger_scores (user_id, window_end desc);
create index if not exists idx_analytics_remedy_user_window
  on public.analytics_remedy_scores (user_id, window_end desc);
create index if not exists idx_weekly_summaries_user_week
  on public.weekly_summaries (user_id, week_start desc);
create index if not exists idx_recommendation_cache_user_version
  on public.recommendation_cache (user_id, cache_version);


-- #############################################################################
-- SECTION 6 — Row Level Security & policies (auth.uid() = user_id)
-- #############################################################################

alter table public.profiles enable row level security;
alter table public.log_entries enable row level security;
alter table public.log_days enable row level security;
alter table public.meal_events enable row level security;
alter table public.symptom_events enable row level security;
alter table public.remedy_events enable row level security;
alter table public.trigger_events enable row level security;
alter table public.meal_tags enable row level security;
alter table public.symptom_tags enable row level security;
alter table public.meal_event_meal_tags enable row level security;
alter table public.symptom_event_symptom_tags enable row level security;
alter table public.profile_conditions enable row level security;
alter table public.medications enable row level security;
alter table public.analytics_trigger_scores enable row level security;
alter table public.analytics_remedy_scores enable row level security;
alter table public.analytics_food_scores enable row level security;
alter table public.analytics_time_patterns enable row level security;
alter table public.weekly_summaries enable row level security;
alter table public.recommendation_cache enable row level security;

-- profiles
drop policy if exists "profiles_select" on public.profiles;
drop policy if exists "profiles_insert" on public.profiles;
drop policy if exists "profiles_update" on public.profiles;
drop policy if exists "profiles_delete" on public.profiles;
create policy "profiles_select" on public.profiles for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "profiles_update" on public.profiles for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "profiles_delete" on public.profiles for delete using (auth.uid() is not null and auth.uid() = user_id);

-- log_entries
drop policy if exists "log_entries_select" on public.log_entries;
drop policy if exists "log_entries_insert" on public.log_entries;
drop policy if exists "log_entries_update" on public.log_entries;
drop policy if exists "log_entries_delete" on public.log_entries;
create policy "log_entries_select" on public.log_entries for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "log_entries_insert" on public.log_entries for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "log_entries_update" on public.log_entries for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "log_entries_delete" on public.log_entries for delete using (auth.uid() is not null and auth.uid() = user_id);

-- log_days
drop policy if exists "log_days_select" on public.log_days;
drop policy if exists "log_days_insert" on public.log_days;
drop policy if exists "log_days_update" on public.log_days;
drop policy if exists "log_days_delete" on public.log_days;
create policy "log_days_select" on public.log_days for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "log_days_insert" on public.log_days for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "log_days_update" on public.log_days for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "log_days_delete" on public.log_days for delete using (auth.uid() is not null and auth.uid() = user_id);

-- meal_events
drop policy if exists "meal_events_select" on public.meal_events;
drop policy if exists "meal_events_insert" on public.meal_events;
drop policy if exists "meal_events_update" on public.meal_events;
drop policy if exists "meal_events_delete" on public.meal_events;
create policy "meal_events_select" on public.meal_events for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_events_insert" on public.meal_events for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_events_update" on public.meal_events for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_events_delete" on public.meal_events for delete using (auth.uid() is not null and auth.uid() = user_id);

-- symptom_events
drop policy if exists "symptom_events_select" on public.symptom_events;
drop policy if exists "symptom_events_insert" on public.symptom_events;
drop policy if exists "symptom_events_update" on public.symptom_events;
drop policy if exists "symptom_events_delete" on public.symptom_events;
create policy "symptom_events_select" on public.symptom_events for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_events_insert" on public.symptom_events for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_events_update" on public.symptom_events for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_events_delete" on public.symptom_events for delete using (auth.uid() is not null and auth.uid() = user_id);

-- remedy_events
drop policy if exists "remedy_events_select" on public.remedy_events;
drop policy if exists "remedy_events_insert" on public.remedy_events;
drop policy if exists "remedy_events_update" on public.remedy_events;
drop policy if exists "remedy_events_delete" on public.remedy_events;
create policy "remedy_events_select" on public.remedy_events for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "remedy_events_insert" on public.remedy_events for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "remedy_events_update" on public.remedy_events for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "remedy_events_delete" on public.remedy_events for delete using (auth.uid() is not null and auth.uid() = user_id);

-- trigger_events
drop policy if exists "trigger_events_select" on public.trigger_events;
drop policy if exists "trigger_events_insert" on public.trigger_events;
drop policy if exists "trigger_events_update" on public.trigger_events;
drop policy if exists "trigger_events_delete" on public.trigger_events;
create policy "trigger_events_select" on public.trigger_events for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "trigger_events_insert" on public.trigger_events for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "trigger_events_update" on public.trigger_events for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "trigger_events_delete" on public.trigger_events for delete using (auth.uid() is not null and auth.uid() = user_id);

-- meal_tags / symptom_tags
drop policy if exists "meal_tags_select" on public.meal_tags;
drop policy if exists "meal_tags_insert" on public.meal_tags;
drop policy if exists "meal_tags_update" on public.meal_tags;
drop policy if exists "meal_tags_delete" on public.meal_tags;
create policy "meal_tags_select" on public.meal_tags for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_tags_insert" on public.meal_tags for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_tags_update" on public.meal_tags for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_tags_delete" on public.meal_tags for delete using (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "symptom_tags_select" on public.symptom_tags;
drop policy if exists "symptom_tags_insert" on public.symptom_tags;
drop policy if exists "symptom_tags_update" on public.symptom_tags;
drop policy if exists "symptom_tags_delete" on public.symptom_tags;
create policy "symptom_tags_select" on public.symptom_tags for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_tags_insert" on public.symptom_tags for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_tags_update" on public.symptom_tags for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_tags_delete" on public.symptom_tags for delete using (auth.uid() is not null and auth.uid() = user_id);

-- junction tables
drop policy if exists "meal_event_meal_tags_select" on public.meal_event_meal_tags;
drop policy if exists "meal_event_meal_tags_insert" on public.meal_event_meal_tags;
drop policy if exists "meal_event_meal_tags_update" on public.meal_event_meal_tags;
drop policy if exists "meal_event_meal_tags_delete" on public.meal_event_meal_tags;
create policy "meal_event_meal_tags_select" on public.meal_event_meal_tags for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_event_meal_tags_insert" on public.meal_event_meal_tags for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_event_meal_tags_update" on public.meal_event_meal_tags for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_event_meal_tags_delete" on public.meal_event_meal_tags for delete using (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "symptom_event_symptom_tags_select" on public.symptom_event_symptom_tags;
drop policy if exists "symptom_event_symptom_tags_insert" on public.symptom_event_symptom_tags;
drop policy if exists "symptom_event_symptom_tags_update" on public.symptom_event_symptom_tags;
drop policy if exists "symptom_event_symptom_tags_delete" on public.symptom_event_symptom_tags;
create policy "symptom_event_symptom_tags_select" on public.symptom_event_symptom_tags for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_event_symptom_tags_insert" on public.symptom_event_symptom_tags for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_event_symptom_tags_update" on public.symptom_event_symptom_tags for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_event_symptom_tags_delete" on public.symptom_event_symptom_tags for delete using (auth.uid() is not null and auth.uid() = user_id);

-- profile_conditions / medications
drop policy if exists "profile_conditions_select" on public.profile_conditions;
drop policy if exists "profile_conditions_insert" on public.profile_conditions;
drop policy if exists "profile_conditions_update" on public.profile_conditions;
drop policy if exists "profile_conditions_delete" on public.profile_conditions;
create policy "profile_conditions_select" on public.profile_conditions for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "profile_conditions_insert" on public.profile_conditions for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "profile_conditions_update" on public.profile_conditions for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "profile_conditions_delete" on public.profile_conditions for delete using (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "medications_select" on public.medications;
drop policy if exists "medications_insert" on public.medications;
drop policy if exists "medications_update" on public.medications;
drop policy if exists "medications_delete" on public.medications;
create policy "medications_select" on public.medications for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "medications_insert" on public.medications for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "medications_update" on public.medications for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "medications_delete" on public.medications for delete using (auth.uid() is not null and auth.uid() = user_id);

-- analytics
drop policy if exists "analytics_trigger_scores_select" on public.analytics_trigger_scores;
drop policy if exists "analytics_trigger_scores_insert" on public.analytics_trigger_scores;
drop policy if exists "analytics_trigger_scores_update" on public.analytics_trigger_scores;
drop policy if exists "analytics_trigger_scores_delete" on public.analytics_trigger_scores;
create policy "analytics_trigger_scores_select" on public.analytics_trigger_scores for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_trigger_scores_insert" on public.analytics_trigger_scores for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_trigger_scores_update" on public.analytics_trigger_scores for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_trigger_scores_delete" on public.analytics_trigger_scores for delete using (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "analytics_remedy_scores_select" on public.analytics_remedy_scores;
drop policy if exists "analytics_remedy_scores_insert" on public.analytics_remedy_scores;
drop policy if exists "analytics_remedy_scores_update" on public.analytics_remedy_scores;
drop policy if exists "analytics_remedy_scores_delete" on public.analytics_remedy_scores;
create policy "analytics_remedy_scores_select" on public.analytics_remedy_scores for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_remedy_scores_insert" on public.analytics_remedy_scores for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_remedy_scores_update" on public.analytics_remedy_scores for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_remedy_scores_delete" on public.analytics_remedy_scores for delete using (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "analytics_food_scores_select" on public.analytics_food_scores;
drop policy if exists "analytics_food_scores_insert" on public.analytics_food_scores;
drop policy if exists "analytics_food_scores_update" on public.analytics_food_scores;
drop policy if exists "analytics_food_scores_delete" on public.analytics_food_scores;
create policy "analytics_food_scores_select" on public.analytics_food_scores for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_food_scores_insert" on public.analytics_food_scores for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_food_scores_update" on public.analytics_food_scores for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_food_scores_delete" on public.analytics_food_scores for delete using (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "analytics_time_patterns_select" on public.analytics_time_patterns;
drop policy if exists "analytics_time_patterns_insert" on public.analytics_time_patterns;
drop policy if exists "analytics_time_patterns_update" on public.analytics_time_patterns;
drop policy if exists "analytics_time_patterns_delete" on public.analytics_time_patterns;
create policy "analytics_time_patterns_select" on public.analytics_time_patterns for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_time_patterns_insert" on public.analytics_time_patterns for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_time_patterns_update" on public.analytics_time_patterns for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_time_patterns_delete" on public.analytics_time_patterns for delete using (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "weekly_summaries_select" on public.weekly_summaries;
drop policy if exists "weekly_summaries_insert" on public.weekly_summaries;
drop policy if exists "weekly_summaries_update" on public.weekly_summaries;
drop policy if exists "weekly_summaries_delete" on public.weekly_summaries;
create policy "weekly_summaries_select" on public.weekly_summaries for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "weekly_summaries_insert" on public.weekly_summaries for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "weekly_summaries_update" on public.weekly_summaries for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "weekly_summaries_delete" on public.weekly_summaries for delete using (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "recommendation_cache_select" on public.recommendation_cache;
drop policy if exists "recommendation_cache_insert" on public.recommendation_cache;
drop policy if exists "recommendation_cache_update" on public.recommendation_cache;
drop policy if exists "recommendation_cache_delete" on public.recommendation_cache;
create policy "recommendation_cache_select" on public.recommendation_cache for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "recommendation_cache_insert" on public.recommendation_cache for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "recommendation_cache_update" on public.recommendation_cache for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "recommendation_cache_delete" on public.recommendation_cache for delete using (auth.uid() is not null and auth.uid() = user_id);


-- #############################################################################
-- SECTION 7 — Sync & analytics functions
-- #############################################################################

create or replace function public.sync_log_entry_to_normalized(p_entry public.log_entries)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_log_day_id uuid;
  v_symptom jsonb;
  v_remedy jsonb;
  v_trigger jsonb;
  v_food_elem jsonb;
  v_name text;
  v_severity int;
  v_helpfulness int;
  v_effectiveness int;
  v_notes text;
  v_subtype text;
  v_body_region text;
  v_onset_min int;
  v_intensity int;
  v_effective_at timestamptz;
  v_meal_at timestamptz;
  v_symptom_at timestamptz;
  v_has_meal boolean;
  v_food_tags jsonb;
  v_meal_event_id uuid;
  v_meal_tag_id uuid;
begin
  v_effective_at := coalesce(p_entry.episode_at, p_entry.entry_at);
  v_meal_at := coalesce(p_entry.meal_occurred_at, v_effective_at);
  v_food_tags := coalesce(p_entry.food_tags, '[]'::jsonb);

  insert into public.log_days (user_id, log_date)
  values (p_entry.user_id, p_entry.entry_date)
  on conflict (user_id, log_date) do update set updated_at = now()
  returning id into v_log_day_id;

  if v_log_day_id is null then
    select id into v_log_day_id from public.log_days
    where user_id = p_entry.user_id and log_date = p_entry.entry_date;
  end if;

  v_has_meal :=
    coalesce(trim(p_entry.meal_name), '') != ''
    or coalesce(trim(p_entry.meal_notes), '') != ''
    or jsonb_array_length(v_food_tags) > 0;

  if v_has_meal then
    insert into public.meal_events (
      user_id, log_day_id, source_entry_id, occurred_at, meal_name, notes, food_tags
    )
    values (
      p_entry.user_id, v_log_day_id, p_entry.id, v_meal_at,
      p_entry.meal_name, p_entry.meal_notes, v_food_tags
    )
    returning id into v_meal_event_id;

    for v_food_elem in select * from jsonb_array_elements(v_food_tags)
    loop
      v_name := coalesce(nullif(trim(v_food_elem->>'tag'), ''), nullif(trim(v_food_elem#>>'{}'), ''));
      if v_name is not null and v_name != '' then
        insert into public.meal_tags (user_id, name)
        values (p_entry.user_id, v_name)
        on conflict (user_id, name) do nothing;

        select id into v_meal_tag_id
        from public.meal_tags
        where user_id = p_entry.user_id and name = v_name;

        if v_meal_tag_id is not null and v_meal_event_id is not null then
          insert into public.meal_event_meal_tags (meal_event_id, meal_tag_id, user_id)
          values (v_meal_event_id, v_meal_tag_id, p_entry.user_id)
          on conflict (meal_event_id, meal_tag_id) do nothing;
        end if;
      end if;
    end loop;
  end if;

  for v_symptom in select * from jsonb_array_elements(p_entry.symptoms)
  loop
    v_name := coalesce(nullif(trim(v_symptom->>'name'), ''), nullif(trim(v_symptom#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      v_severity := (v_symptom->>'severity')::int;
      v_notes := v_symptom->>'notes';
      v_subtype := v_symptom->>'subtype';
      v_body_region := v_symptom->>'body_region';
      v_onset_min := (v_symptom->>'onset_after_meal_minutes')::int;
      if v_onset_min is not null then
        v_symptom_at := v_effective_at + (v_onset_min * interval '1 minute');
      else
        v_symptom_at := v_effective_at;
      end if;
      insert into public.symptom_events (
        user_id, log_day_id, source_entry_id, occurred_at,
        symptom_name, severity, notes, subtype, body_region, onset_after_meal_minutes
      )
      values (
        p_entry.user_id, v_log_day_id, p_entry.id, v_symptom_at,
        v_name, v_severity, v_notes, v_subtype, v_body_region, v_onset_min
      );
    end if;
  end loop;

  for v_remedy in select * from jsonb_array_elements(p_entry.remedies)
  loop
    v_name := coalesce(nullif(trim(v_remedy->>'name'), ''), nullif(trim(v_remedy#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      v_effectiveness := coalesce(
        (v_remedy->>'effectiveness')::int,
        (v_remedy->>'effectiveness_score')::int,
        (v_remedy->>'helpfulness')::int
      );
      v_helpfulness := coalesce((v_remedy->>'helpfulness')::int, v_effectiveness);
      v_notes := v_remedy->>'notes';
      insert into public.remedy_events (
        user_id, log_day_id, source_entry_id, occurred_at,
        remedy_name, helpfulness, effectiveness_score, notes
      )
      values (
        p_entry.user_id, v_log_day_id, p_entry.id, v_effective_at,
        v_name, v_helpfulness, v_effectiveness, v_notes
      );
    end if;
  end loop;

  for v_trigger in select * from jsonb_array_elements(p_entry.triggers)
  loop
    v_name := coalesce(nullif(trim(v_trigger->>'name'), ''), nullif(trim(v_trigger#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      v_notes := v_trigger->>'notes';
      v_intensity := (v_trigger->>'intensity')::int;
      insert into public.trigger_events (
        user_id, log_day_id, source_entry_id, source_type, source_ref_id,
        occurred_at, trigger_name, notes, intensity
      )
      values (
        p_entry.user_id, v_log_day_id, p_entry.id, 'entry', null,
        v_effective_at, v_name, v_notes, v_intensity
      );
    end if;
  end loop;
end;
$$;

create or replace function public.sync_log_entry_on_insert()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  perform public.sync_log_entry_to_normalized(new);
  return new;
end;
$$;

create or replace function public.sync_log_entry_on_update()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  delete from public.meal_events where source_entry_id = new.id;
  delete from public.symptom_events where source_entry_id = new.id;
  delete from public.remedy_events where source_entry_id = new.id;
  delete from public.trigger_events where source_entry_id = new.id;
  perform public.sync_log_entry_to_normalized(new);
  return new;
end;
$$;

create or replace function public.sync_log_entry_on_delete()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  delete from public.meal_events where source_entry_id = old.id;
  delete from public.symptom_events where source_entry_id = old.id;
  delete from public.remedy_events where source_entry_id = old.id;
  delete from public.trigger_events where source_entry_id = old.id;
  return old;
end;
$$;

-- Analytics refresh (batch / on-demand; not per-row)
create or replace function public.refresh_user_analytics(
  p_user_id uuid,
  p_from date,
  p_to date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_from_ts timestamptz := p_from::timestamptz;
  v_to_ts_excl timestamptz := (p_to + 1)::timestamptz;
begin
  if p_user_id is null or p_from is null or p_to is null or p_from > p_to then
    raise exception 'refresh_user_analytics: invalid arguments';
  end if;

  insert into public.weekly_summaries (
    user_id, week_start, entry_count, avg_pain, avg_stress, updated_at
  )
  select
    le.user_id,
    date_trunc('week', le.entry_at at time zone 'utc')::date as week_start,
    count(*)::int,
    avg(le.pain_score),
    avg(le.stress_score),
    now()
  from public.log_entries le
  where le.user_id = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at < v_to_ts_excl
  group by le.user_id, date_trunc('week', le.entry_at at time zone 'utc')::date
  on conflict (user_id, week_start) do update set
    entry_count = excluded.entry_count,
    avg_pain = excluded.avg_pain,
    avg_stress = excluded.avg_stress,
    updated_at = now();

  update public.weekly_summaries ws
  set
    top_triggers = coalesce(sub.tg, '[]'::jsonb),
    top_remedies = coalesce(sub.rm, '[]'::jsonb),
    top_symptoms = coalesce(sub.sm, '[]'::jsonb),
    updated_at = now()
  from (
    select
      ws2.user_id,
      ws2.week_start,
      (
        select coalesce(jsonb_agg(x.obj order by (x.obj->>'n')::int desc), '[]'::jsonb)
        from (
          select jsonb_build_object('name', te.trigger_name, 'n', count(*)::int) as obj
          from public.trigger_events te
          join public.log_entries le on le.id = te.source_entry_id and le.user_id = te.user_id
          where te.user_id = p_user_id
            and date_trunc('week', le.entry_at at time zone 'utc')::date = ws2.week_start
          group by te.trigger_name
          order by count(*) desc
          limit 10
        ) x
      ) as tg,
      (
        select coalesce(jsonb_agg(y.obj order by (y.obj->>'n')::int desc), '[]'::jsonb)
        from (
          select jsonb_build_object('name', re.remedy_name, 'n', count(*)::int) as obj
          from public.remedy_events re
          join public.log_entries le on le.id = re.source_entry_id and le.user_id = re.user_id
          where re.user_id = p_user_id
            and date_trunc('week', le.entry_at at time zone 'utc')::date = ws2.week_start
          group by re.remedy_name
          order by count(*) desc
          limit 10
        ) y
      ) as rm,
      (
        select coalesce(jsonb_agg(z.obj order by (z.obj->>'n')::int desc), '[]'::jsonb)
        from (
          select jsonb_build_object('name', se.symptom_name, 'n', count(*)::int) as obj
          from public.symptom_events se
          join public.log_entries le on le.id = se.source_entry_id and le.user_id = se.user_id
          where se.user_id = p_user_id
            and date_trunc('week', le.entry_at at time zone 'utc')::date = ws2.week_start
          group by se.symptom_name
          order by count(*) desc
          limit 10
        ) z
      ) as sm
    from public.weekly_summaries ws2
    where ws2.user_id = p_user_id
      and ws2.week_start >= date_trunc('week', p_from::timestamptz at time zone 'utc')::date
      and ws2.week_start <= date_trunc('week', p_to::timestamptz at time zone 'utc')::date
  ) sub
  where ws.user_id = sub.user_id and ws.week_start = sub.week_start;

  delete from public.analytics_remedy_scores
  where user_id = p_user_id
    and window_start = p_from
    and window_end = p_to;

  insert into public.analytics_remedy_scores (
    user_id, remedy_name, window_start, window_end,
    avg_effectiveness, usage_count, updated_at
  )
  select
    p_user_id,
    re.remedy_name,
    p_from,
    p_to,
    avg(coalesce(re.effectiveness_score, re.helpfulness))::numeric,
    count(*)::int,
    now()
  from public.remedy_events re
  where re.user_id = p_user_id
    and re.occurred_at >= v_from_ts
    and re.occurred_at < v_to_ts_excl
  group by re.remedy_name;

  delete from public.analytics_trigger_scores
  where user_id = p_user_id
    and window_start = p_from
    and window_end = p_to;

  insert into public.analytics_trigger_scores (
    user_id, trigger_name, window_start, window_end,
    sample_count, avg_pain_when_present, avg_pain_when_absent, correlation_hint, updated_at
  )
  select
    p_user_id,
    s.trigger_name,
    p_from,
    p_to,
    s.n,
    s.avg_with,
    w.avg_without,
    case
      when s.avg_with is not null and w.avg_without is not null
      then (s.avg_with - w.avg_without)
      else null
    end,
    now()
  from (
    select
      te.trigger_name,
      count(distinct le.id)::int as n,
      avg(le.pain_score) as avg_with
    from public.log_entries le
    join public.trigger_events te
      on te.source_entry_id = le.id and te.user_id = le.user_id
    where le.user_id = p_user_id
      and le.entry_at >= v_from_ts
      and le.entry_at < v_to_ts_excl
    group by te.trigger_name
  ) s
  cross join lateral (
    select avg(le2.pain_score) as avg_without
    from public.log_entries le2
    where le2.user_id = p_user_id
      and le2.entry_at >= v_from_ts
      and le2.entry_at < v_to_ts_excl
      and not exists (
        select 1 from public.trigger_events te2
        where te2.source_entry_id = le2.id
          and te2.user_id = le2.user_id
          and te2.trigger_name = s.trigger_name
      )
  ) w;

  delete from public.analytics_food_scores
  where user_id = p_user_id
    and window_start = p_from
    and window_end = p_to;

  insert into public.analytics_food_scores (
    user_id, food_tag, window_start, window_end,
    co_occurrence_pain_avg, entry_count, updated_at
  )
  select
    p_user_id,
    tag_name,
    p_from,
    p_to,
    avg(le.pain_score),
    count(*)::int,
    now()
  from public.log_entries le
  cross join lateral (
    select coalesce(elem->>'tag', elem#>>'{}', trim(both '"' from elem::text)) as tag_name
    from jsonb_array_elements(coalesce(le.food_tags, '[]'::jsonb)) elem
  ) t
  where le.user_id = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at < v_to_ts_excl
    and t.tag_name is not null
    and t.tag_name <> ''
  group by tag_name;

  delete from public.analytics_time_patterns
  where user_id = p_user_id
    and window_start = p_from
    and window_end = p_to
    and bucket_type = 'hour_of_day';

  insert into public.analytics_time_patterns (
    user_id, bucket_type, bucket_value, window_start, window_end,
    avg_pain, entry_count, updated_at
  )
  select
    p_user_id,
    'hour_of_day',
    extract(hour from le.entry_at at time zone 'utc')::smallint,
    p_from,
    p_to,
    avg(le.pain_score),
    count(*)::int,
    now()
  from public.log_entries le
  where le.user_id = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at < v_to_ts_excl
  group by extract(hour from le.entry_at at time zone 'utc')::smallint;

  delete from public.analytics_time_patterns
  where user_id = p_user_id
    and window_start = p_from
    and window_end = p_to
    and bucket_type = 'dow';

  insert into public.analytics_time_patterns (
    user_id, bucket_type, bucket_value, window_start, window_end,
    avg_pain, entry_count, updated_at
  )
  select
    p_user_id,
    'dow',
    extract(dow from le.entry_at at time zone 'utc')::smallint,
    p_from,
    p_to,
    avg(le.pain_score),
    count(*)::int,
    now()
  from public.log_entries le
  where le.user_id = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at < v_to_ts_excl
  group by extract(dow from le.entry_at at time zone 'utc')::smallint;
end;
$$;

create or replace function public.refresh_user_recommendations(
  p_user_id uuid,
  p_cache_version text default 'v1'
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_payload jsonb;
  v_week date;
begin
  if p_user_id is null then
    raise exception 'refresh_user_recommendations: p_user_id required';
  end if;

  select max(ws.week_start) into v_week
  from public.weekly_summaries ws
  where ws.user_id = p_user_id;

  select jsonb_build_object(
    'week_summary_ref', case when v_week is null then null else to_char(v_week, 'YYYY-MM-DD') end,
    'top_triggers',
      coalesce(
        (select ws.top_triggers from public.weekly_summaries ws
         where ws.user_id = p_user_id and ws.week_start = v_week limit 1),
        '[]'::jsonb
      ),
    'top_remedies',
      coalesce(
        (select ws.top_remedies from public.weekly_summaries ws
         where ws.user_id = p_user_id and ws.week_start = v_week limit 1),
        '[]'::jsonb
      ),
    'top_symptoms',
      coalesce(
        (select ws.top_symptoms from public.weekly_summaries ws
         where ws.user_id = p_user_id and ws.week_start = v_week limit 1),
        '[]'::jsonb
      ),
    'risky_hours',
      coalesce(
        (select jsonb_agg(
          jsonb_build_object(
            'hour', atp.bucket_value,
            'avg_pain', atp.avg_pain,
            'n', atp.entry_count
          ) order by atp.avg_pain desc nulls last
        )
        from public.analytics_time_patterns atp
        where atp.user_id = p_user_id
          and atp.bucket_type = 'hour_of_day'
          and atp.window_end = (select max(window_end) from public.analytics_time_patterns
            where user_id = p_user_id and bucket_type = 'hour_of_day')),
        '[]'::jsonb
      ),
    'recent_entry_count',
      (select count(*)::int from public.log_entries le
       where le.user_id = p_user_id
         and le.entry_at >= now() - interval '30 days')
  ) into v_payload;

  insert into public.recommendation_cache (user_id, cache_version, generated_at, payload)
  values (p_user_id, coalesce(nullif(trim(p_cache_version), ''), 'v1'), now(), coalesce(v_payload, '{}'::jsonb))
  on conflict (user_id, cache_version) do update set
    generated_at = now(),
    payload = excluded.payload;
end;
$$;

grant execute on function public.refresh_user_analytics(uuid, date, date) to authenticated;
grant execute on function public.refresh_user_recommendations(uuid, text) to authenticated;


-- #############################################################################
-- SECTION 8 — Triggers on log_entries, timeline view, grants
-- #############################################################################

drop trigger if exists tr_sync_log_entry_insert on public.log_entries;
create trigger tr_sync_log_entry_insert
  after insert on public.log_entries
  for each row execute function public.sync_log_entry_on_insert();

drop trigger if exists tr_sync_log_entry_update on public.log_entries;
create trigger tr_sync_log_entry_update
  after update on public.log_entries
  for each row execute function public.sync_log_entry_on_update();

drop trigger if exists tr_sync_log_entry_delete on public.log_entries;
create trigger tr_sync_log_entry_delete
  after delete on public.log_entries
  for each row execute function public.sync_log_entry_on_delete();

-- Timeline view (union of flat + normalized streams)
create or replace view public.v_user_timeline as
select
  user_id,
  'log_entry'::text as event_type,
  entry_at as occurred_at,
  coalesce(meal_name, 'Log entry') as title,
  jsonb_build_object(
    'pain_score', pain_score,
    'stress_score', stress_score,
    'symptoms', symptoms,
    'triggers', triggers,
    'remedies', remedies,
    'notes', notes
  ) as details,
  id as source_entry_id
from public.log_entries
union all
select
  user_id,
  'meal'::text,
  occurred_at,
  coalesce(meal_name, 'Meal'),
  jsonb_build_object('notes', notes, 'food_tags', food_tags),
  source_entry_id
from public.meal_events
union all
select
  user_id,
  'symptom'::text,
  occurred_at,
  symptom_name,
  jsonb_build_object('severity', severity, 'notes', notes, 'subtype', subtype, 'body_region', body_region),
  source_entry_id
from public.symptom_events
union all
select
  user_id,
  'remedy'::text,
  occurred_at,
  remedy_name,
  jsonb_build_object(
    'helpfulness', helpfulness,
    'effectiveness_score', effectiveness_score,
    'notes', notes
  ),
  source_entry_id
from public.remedy_events
union all
select
  user_id,
  'trigger'::text,
  occurred_at,
  trigger_name,
  jsonb_build_object('notes', notes, 'intensity', intensity, 'source_type', source_type, 'source_ref_id', source_ref_id),
  source_entry_id
from public.trigger_events;

grant select on public.v_user_timeline to anon;
grant select on public.v_user_timeline to authenticated;

-- =============================================================================
-- End GastroGuard production schema
-- =============================================================================
