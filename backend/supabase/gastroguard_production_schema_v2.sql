-- =============================================================================
-- GastroGuard — Production schema v2 (audit-hardened)
-- =============================================================================
-- Changes from v1 (addresses combined Claude + ChatGPT audit):
--
-- CRITICAL
--   [fix] v_user_timeline: security_invoker = true, revoke anon grant
--
-- HIGH
--   [fix] refresh_user_analytics / refresh_user_recommendations: auth.uid() guard
--   [fix] sync trigger functions: security definer (consistent RLS context)
--   [fix] Missing source_entry_id indexes on symptom_events, remedy_events,
--         trigger_events (were causing full table scans on every sync update)
--   [fix] profiles.conditions / medications JSONB removed — profile_conditions
--         and medications tables are the single source of truth
--
-- MEDIUM
--   [fix] Integer casts in sync (severity, intensity, etc.) use safe_int()
--   [fix] Food tag extraction handles string vs object shapes correctly
--   [fix] analytics_* tables now use ON CONFLICT DO UPDATE (no DELETE gap)
--   [fix] weekly_summaries upsert is single-pass CTE (no two-round-trip)
--   [fix] jsonb_typeof = 'array' CHECK constraints on all array JSONB columns
--   [fix] analytics_trigger_scores.correlation_hint renamed to pain_delta
--         (it is avg_pain_present − avg_pain_absent, not a correlation coeff)
--
-- LOW / STYLE
--   [fix] profiles.age, height, weight, gender are now nullable (no fake defaults)
--   [fix] profile_conditions and medications gain updated_at + trigger
--   [keep] ALTER TABLE ADD COLUMN IF NOT EXISTS after log_entries / meal_events /
--          log_days — required when upgrading: CREATE TABLE IF NOT EXISTS does
--          not add columns to an existing table (fixes missing food_tags, etc.)
--   [fix] handle_new_user() pulls display name from auth metadata
--   [add] log_days gains optional day-level aggregate columns for future use
--
-- NOTE — if upgrading an existing schema, run these before this file:
--   ALTER TABLE public.profiles
--     DROP COLUMN IF EXISTS conditions,
--     DROP COLUMN IF EXISTS medications;
--   ALTER TABLE public.analytics_trigger_scores
--     RENAME COLUMN correlation_hint TO pain_delta;
-- =============================================================================
-- #############################################################################
-- SECTION 0.5 — Pre-flight: add missing columns to existing tables
-- Required because CREATE TABLE IF NOT EXISTS skips the whole statement when
-- the table already exists, so new columns in the definition are never applied.
-- These are all additive (IF NOT EXISTS) and safe to run on any version.
-- #############################################################################

-- log_entries — columns added after initial migration
alter table if exists public.log_entries
  add column if not exists food_tags         jsonb not null default '[]'::jsonb,
  add column if not exists episode_at        timestamptz,
  add column if not exists meal_occurred_at  timestamptz;

-- meal_events — food_tags added after initial migration
alter table if exists public.meal_events
  add column if not exists food_tags jsonb not null default '[]'::jsonb;

-- symptom_events — columns added after initial migration
alter table if exists public.symptom_events
  add column if not exists subtype                   text,
  add column if not exists body_region               text,
  add column if not exists onset_after_meal_minutes  integer
    check (onset_after_meal_minutes is null or onset_after_meal_minutes >= 0);

-- remedy_events — effectiveness_score added after initial migration
alter table if exists public.remedy_events
  add column if not exists effectiveness_score integer
    check (effectiveness_score is null or (effectiveness_score >= 0 and effectiveness_score <= 10));

-- trigger_events — intensity added after initial migration
alter table if exists public.trigger_events
  add column if not exists intensity integer
    check (intensity is null or (intensity >= 0 and intensity <= 10));

-- profiles — integrations added after initial migration; conditions/medications
-- removed (normalized tables are the source of truth — drop manually if upgrading)
alter table if exists public.profiles
  add column if not exists integrations jsonb not null default '[]'::jsonb;

-- profile_conditions / medications — updated_at is new in v2
alter table if exists public.profile_conditions
  add column if not exists updated_at timestamptz not null default now();
alter table if exists public.medications
  add column if not exists updated_at timestamptz not null default now();

-- log_days — day-level aggregate fields are new in v2
alter table if exists public.log_days
  add column if not exists overall_pain_score   integer
    check (overall_pain_score   is null or (overall_pain_score   >= 0 and overall_pain_score   <= 10)),
  add column if not exists overall_stress_score integer
    check (overall_stress_score is null or (overall_stress_score >= 0 and overall_stress_score <= 10)),
  add column if not exists sleep_quality        integer
    check (sleep_quality        is null or (sleep_quality        >= 0 and sleep_quality        <= 10)),
  add column if not exists day_notes            text;


-- #############################################################################
-- SECTION 0 — Extensions
-- #############################################################################

create extension if not exists pgcrypto;


-- #############################################################################
-- SECTION 1 — Helper functions
-- #############################################################################

-- Maintain updated_at on any table
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

-- Safe integer cast — returns NULL instead of throwing on garbage input
create or replace function public.safe_int(v text)
returns integer
language sql
immutable
set search_path = public
as $$
  select case when v ~ '^-?\d+$' then v::integer else null end;
$$;

comment on function public.safe_int(text) is
  'Casts text to integer; returns NULL for non-numeric input. Used in sync triggers.';


-- #############################################################################
-- SECTION 2 — Core tables
-- #############################################################################

-- -----------------------------------------------------------------------------
-- profiles (1:1 with auth.users)
-- Scalar fields only. conditions/medications live in normalized tables.
-- allergies, dietary_restrictions, triggers (known), effective_remedies,
-- integrations remain as JSONB (no normalized equivalents yet).
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references auth.users (id) on delete cascade,

  -- Identity (nullable — unknown ≠ empty / 0)
  name          text        not null default '',
  age           integer,                          -- nullable: unknown age ≠ 0
  height        text,                             -- nullable; store "5ft 10in" or "178cm"
  weight        text,                             -- nullable
  gender        text,                             -- nullable; no enum — app defines values

  -- Array-shaped profile data (still JSONB; no normalized tables yet)
  allergies             jsonb not null default '[]'::jsonb
    check (jsonb_typeof(allergies)             = 'array'),
  dietary_restrictions  jsonb not null default '[]'::jsonb
    check (jsonb_typeof(dietary_restrictions)  = 'array'),
  triggers              jsonb not null default '[]'::jsonb
    check (jsonb_typeof(triggers)              = 'array'),
  effective_remedies    jsonb not null default '[]'::jsonb
    check (jsonb_typeof(effective_remedies)    = 'array'),
  integrations          jsonb not null default '[]'::jsonb
    check (jsonb_typeof(integrations)          = 'array'),

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint profiles_user_id_key unique (user_id)
);

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

comment on table  public.profiles is 'User profile; one row per auth user.';
comment on column public.profiles.triggers is
  'User-identified personal triggers (profile-level knowledge, not log entry triggers).';
comment on column public.profiles.integrations is
  'Integration records (name, metadata, etc.) as JSON array.';

-- -----------------------------------------------------------------------------
-- Auto-create profile on signup
-- Pulls display name from auth metadata if available.
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'name'),      ''),
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      ''
    )
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- log_entries (flat capture / primary client write surface)
-- Convention:
--   entry_at   = server-recorded timestamp (UTC)
--   entry_date = user-attributed calendar date (may differ across timezones)
-- The sync trigger keys log_days on entry_date; analytics group by entry_at UTC.
-- -----------------------------------------------------------------------------
create table if not exists public.log_entries (
  id                  uuid        primary key default gen_random_uuid(),
  user_id             uuid        not null references auth.users (id) on delete cascade,

  entry_at            timestamptz not null default now(),
  entry_date          date        not null,

  pain_score          integer     not null default 0
    check (pain_score   >= 0 and pain_score   <= 10),
  stress_score        integer     not null default 0
    check (stress_score >= 0 and stress_score <= 10),
  nausea_score        integer
    check (nausea_score is null or (nausea_score >= 0 and nausea_score <= 10)),

  meal_name           text,
  meal_notes          text,
  food_tags           jsonb       not null default '[]'::jsonb
    check (jsonb_typeof(food_tags) = 'array'),

  episode_at          timestamptz,     -- when the GI episode occurred; null → uses entry_at
  meal_occurred_at    timestamptz,     -- optional meal time; null → uses coalesce(episode_at, entry_at)

  symptoms            jsonb       not null default '[]'::jsonb
    check (jsonb_typeof(symptoms)  = 'array'),
  triggers            jsonb       not null default '[]'::jsonb
    check (jsonb_typeof(triggers)  = 'array'),
  remedies            jsonb       not null default '[]'::jsonb
    check (jsonb_typeof(remedies)  = 'array'),

  notes               text,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Upgrade: existing DBs may already have log_entries without v2 columns.
-- CREATE TABLE IF NOT EXISTS does not alter an existing table — without this,
-- COMMENT / indexes / sync functions that reference food_tags raise 42703.
-- -----------------------------------------------------------------------------
alter table public.log_entries
  add column if not exists food_tags jsonb not null default '[]'::jsonb;
alter table public.log_entries
  add column if not exists episode_at timestamptz;
alter table public.log_entries
  add column if not exists meal_occurred_at timestamptz;

drop trigger if exists log_entries_updated_at on public.log_entries;
create trigger log_entries_updated_at
  before update on public.log_entries
  for each row execute function public.set_updated_at();

comment on table  public.log_entries        is 'Flat log row — primary insert target for the client.';
comment on column public.log_entries.food_tags        is 'JSON array: strings or {tag, category?, confidence?}.';
comment on column public.log_entries.episode_at       is 'When the GI episode occurred; null → sync uses entry_at.';
comment on column public.log_entries.meal_occurred_at is 'Optional meal time; null → meal_events use coalesce(episode_at, entry_at).';

-- -----------------------------------------------------------------------------
-- log_days — one row per (user, calendar date)
-- Also carries optional day-level aggregate/reflection fields.
-- -----------------------------------------------------------------------------
create table if not exists public.log_days (
  id                  uuid    primary key default gen_random_uuid(),
  user_id             uuid    not null references auth.users (id) on delete cascade,
  log_date            date    not null,

  -- Optional day-level fields (null = not captured)
  overall_pain_score  integer check (overall_pain_score  is null or (overall_pain_score  >= 0 and overall_pain_score  <= 10)),
  overall_stress_score integer check (overall_stress_score is null or (overall_stress_score >= 0 and overall_stress_score <= 10)),
  sleep_quality       integer check (sleep_quality        is null or (sleep_quality        >= 0 and sleep_quality        <= 10)),
  day_notes           text,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint log_days_user_date unique (user_id, log_date)
);

alter table public.log_days
  add column if not exists overall_pain_score integer
    check (overall_pain_score is null or (overall_pain_score >= 0 and overall_pain_score <= 10));
alter table public.log_days
  add column if not exists overall_stress_score integer
    check (overall_stress_score is null or (overall_stress_score >= 0 and overall_stress_score <= 10));
alter table public.log_days
  add column if not exists sleep_quality integer
    check (sleep_quality is null or (sleep_quality >= 0 and sleep_quality <= 10));
alter table public.log_days
  add column if not exists day_notes text;

drop trigger if exists log_days_updated_at on public.log_days;
create trigger log_days_updated_at
  before update on public.log_days
  for each row execute function public.set_updated_at();

comment on table  public.log_days is 'Day anchor; one row per (user, calendar date). Optional day-level fields for future reflection features.';


-- #############################################################################
-- SECTION 3 — Normalized event tables
-- #############################################################################

create table if not exists public.meal_events (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null references auth.users (id) on delete cascade,
  log_day_id      uuid        not null references public.log_days (id) on delete cascade,
  source_entry_id uuid        references public.log_entries (id) on delete set null,
  occurred_at     timestamptz not null,
  meal_name       text,
  notes           text,
  food_tags       jsonb       not null default '[]'::jsonb
    check (jsonb_typeof(food_tags) = 'array'),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.meal_events
  add column if not exists food_tags jsonb not null default '[]'::jsonb;

drop trigger if exists meal_events_updated_at on public.meal_events;
create trigger meal_events_updated_at
  before update on public.meal_events
  for each row execute function public.set_updated_at();

-- -

create table if not exists public.symptom_events (
  id                        uuid        primary key default gen_random_uuid(),
  user_id                   uuid        not null references auth.users (id) on delete cascade,
  log_day_id                uuid        not null references public.log_days (id) on delete cascade,
  source_entry_id           uuid        references public.log_entries (id) on delete set null,
  occurred_at               timestamptz not null,
  symptom_name              text        not null,
  severity                  integer     check (severity is null or (severity >= 0 and severity <= 10)),
  notes                     text,
  subtype                   text,
  body_region               text,
  onset_after_meal_minutes  integer     check (onset_after_meal_minutes is null or onset_after_meal_minutes >= 0),
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
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

-- -

create table if not exists public.remedy_events (
  id                  uuid        primary key default gen_random_uuid(),
  user_id             uuid        not null references auth.users (id) on delete cascade,
  log_day_id          uuid        not null references public.log_days (id) on delete cascade,
  source_entry_id     uuid        references public.log_entries (id) on delete set null,
  occurred_at         timestamptz not null,
  remedy_name         text        not null,
  helpfulness         integer     check (helpfulness        is null or (helpfulness        >= 0 and helpfulness        <= 10)),
  effectiveness_score integer     check (effectiveness_score is null or (effectiveness_score >= 0 and effectiveness_score <= 10)),
  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

alter table public.remedy_events
  add column if not exists effectiveness_score integer
    check (effectiveness_score is null or (effectiveness_score >= 0 and effectiveness_score <= 10));

comment on column public.remedy_events.helpfulness         is 'User-reported helpfulness (0–10).';
comment on column public.remedy_events.effectiveness_score is 'Computed or app-assigned effectiveness (0–10). Prefer this for analytics.';

drop trigger if exists remedy_events_updated_at on public.remedy_events;
create trigger remedy_events_updated_at
  before update on public.remedy_events
  for each row execute function public.set_updated_at();

-- -

create table if not exists public.trigger_events (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null references auth.users (id) on delete cascade,
  log_day_id      uuid        not null references public.log_days (id) on delete cascade,
  source_entry_id uuid        references public.log_entries (id) on delete set null,
  -- Polymorphic reference (no FK enforceable across types; treat as advisory)
  source_type     text        not null check (source_type in ('entry', 'meal', 'symptom')),
  source_ref_id   uuid,
  occurred_at     timestamptz not null,
  trigger_name    text        not null,
  intensity       integer     check (intensity is null or (intensity >= 0 and intensity <= 10)),
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.trigger_events
  add column if not exists intensity integer
    check (intensity is null or (intensity >= 0 and intensity <= 10));

comment on column public.trigger_events.source_ref_id is
  'Advisory polymorphic ref to meal_event / symptom_event depending on source_type. No FK — app must maintain consistency.';

drop trigger if exists trigger_events_updated_at on public.trigger_events;
create trigger trigger_events_updated_at
  before update on public.trigger_events
  for each row execute function public.set_updated_at();


-- #############################################################################
-- SECTION 4 — Profile detail tables
-- These are the single source of truth for conditions and medications.
-- The equivalent JSONB columns have been removed from profiles.
-- #############################################################################

create table if not exists public.profile_conditions (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null references auth.users (id) on delete cascade,
  condition_name  text        not null,
  notes           text,
  diagnosed_at    date,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

drop trigger if exists profile_conditions_updated_at on public.profile_conditions;
create trigger profile_conditions_updated_at
  before update on public.profile_conditions
  for each row execute function public.set_updated_at();

-- -

create table if not exists public.medications (
  id                uuid        primary key default gen_random_uuid(),
  user_id           uuid        not null references auth.users (id) on delete cascade,
  medication_name   text        not null,
  dosage            text,
  frequency         text,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

drop trigger if exists medications_updated_at on public.medications;
create trigger medications_updated_at
  before update on public.medications
  for each row execute function public.set_updated_at();


-- #############################################################################
-- SECTION 5 — Tag dimensions & junction tables
-- #############################################################################

create table if not exists public.meal_tags (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  name        text        not null,
  created_at  timestamptz not null default now(),
  constraint  meal_tags_user_name unique (user_id, name)
);

create table if not exists public.symptom_tags (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  name        text        not null,
  created_at  timestamptz not null default now(),
  constraint  symptom_tags_user_name unique (user_id, name)
);

-- meal_events ↔ meal_tags
create table if not exists public.meal_event_meal_tags (
  meal_event_id uuid not null references public.meal_events (id) on delete cascade,
  meal_tag_id   uuid not null references public.meal_tags   (id) on delete cascade,
  user_id       uuid not null references auth.users         (id) on delete cascade,
  created_at    timestamptz not null default now(),
  constraint    meal_event_meal_tags_pkey primary key (meal_event_id, meal_tag_id)
);

-- symptom_events ↔ symptom_tags
create table if not exists public.symptom_event_symptom_tags (
  symptom_event_id uuid not null references public.symptom_events (id) on delete cascade,
  symptom_tag_id   uuid not null references public.symptom_tags   (id) on delete cascade,
  user_id          uuid not null references auth.users             (id) on delete cascade,
  created_at       timestamptz not null default now(),
  constraint       symptom_event_symptom_tags_pkey primary key (symptom_event_id, symptom_tag_id)
);

comment on table public.meal_event_meal_tags        is 'Links a meal_event to normalized meal_tags.';
comment on table public.symptom_event_symptom_tags  is 'Links a symptom_event to normalized symptom_tags.';


-- #############################################################################
-- SECTION 6 — Analytics & recommendation cache
-- #############################################################################

create table if not exists public.analytics_trigger_scores (
  id                    uuid        primary key default gen_random_uuid(),
  user_id               uuid        not null references auth.users (id) on delete cascade,
  trigger_name          text        not null,
  window_start          date        not null,
  window_end            date        not null,
  sample_count          integer     not null default 0,
  avg_pain_when_present numeric,
  avg_pain_when_absent  numeric,
  -- Renamed from correlation_hint: this is avg_with − avg_without (a mean
  -- difference), NOT a bounded correlation coefficient.
  pain_delta            numeric,
  updated_at            timestamptz not null default now(),
  constraint analytics_trigger_scores_dedup unique (user_id, trigger_name, window_start, window_end)
);

create table if not exists public.analytics_remedy_scores (
  id                uuid        primary key default gen_random_uuid(),
  user_id           uuid        not null references auth.users (id) on delete cascade,
  remedy_name       text        not null,
  window_start      date        not null,
  window_end        date        not null,
  avg_effectiveness numeric,
  usage_count       integer     not null default 0,
  updated_at        timestamptz not null default now(),
  constraint analytics_remedy_scores_dedup unique (user_id, remedy_name, window_start, window_end)
);

create table if not exists public.analytics_food_scores (
  id                    uuid        primary key default gen_random_uuid(),
  user_id               uuid        not null references auth.users (id) on delete cascade,
  food_tag              text        not null,
  window_start          date        not null,
  window_end            date        not null,
  co_occurrence_pain_avg numeric,
  entry_count           integer     not null default 0,
  updated_at            timestamptz not null default now(),
  constraint analytics_food_scores_dedup unique (user_id, food_tag, window_start, window_end)
);

create table if not exists public.analytics_time_patterns (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references auth.users (id) on delete cascade,
  bucket_type   text        not null check (bucket_type in ('hour_of_day', 'dow')),
  bucket_value  smallint    not null,
  window_start  date        not null,
  window_end    date        not null,
  avg_pain      numeric,
  entry_count   integer     not null default 0,
  updated_at    timestamptz not null default now(),
  constraint analytics_time_patterns_dedup unique (user_id, bucket_type, bucket_value, window_start, window_end)
);

create table if not exists public.weekly_summaries (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references auth.users (id) on delete cascade,
  week_start    date        not null,
  entry_count   integer     not null default 0,
  avg_pain      numeric,
  avg_stress    numeric,
  top_triggers  jsonb       not null default '[]'::jsonb,
  top_remedies  jsonb       not null default '[]'::jsonb,
  top_symptoms  jsonb       not null default '[]'::jsonb,
  updated_at    timestamptz not null default now(),
  constraint weekly_summaries_dedup unique (user_id, week_start)
);

create table if not exists public.recommendation_cache (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null references auth.users (id) on delete cascade,
  cache_version   text        not null default 'v1',
  generated_at    timestamptz not null default now(),
  payload         jsonb       not null default '{}'::jsonb,
  constraint recommendation_cache_dedup unique (user_id, cache_version)
);

comment on table public.analytics_trigger_scores  is 'Precomputed trigger vs pain aggregates. pain_delta = avg_pain_with − avg_pain_without.';
comment on table public.analytics_remedy_scores   is 'Precomputed remedy effectiveness aggregates.';
comment on table public.analytics_food_scores     is 'Precomputed food tag vs pain co-occurrence aggregates.';
comment on table public.analytics_time_patterns   is 'Hour-of-day / day-of-week pain patterns.';
comment on table public.weekly_summaries          is 'Weekly rollups for dashboard and recommendations.';
comment on table public.recommendation_cache      is 'Cached recommendation payload; refresh via refresh_user_recommendations().';


-- #############################################################################
-- SECTION 7 — Indexes
-- #############################################################################

-- log_entries
create index if not exists idx_log_entries_user_entry_at
  on public.log_entries (user_id, entry_at desc);
create index if not exists idx_log_entries_user_entry_date
  on public.log_entries (user_id, entry_date);
create index if not exists idx_log_entries_user_episode_at
  on public.log_entries (user_id, episode_at desc)
  where episode_at is not null;

-- log_days
create index if not exists idx_log_days_user_date
  on public.log_days (user_id, log_date);
create index if not exists idx_log_days_log_date
  on public.log_days (log_date);

-- meal_events
create index if not exists idx_meal_events_user
  on public.meal_events (user_id);
create index if not exists idx_meal_events_log_day
  on public.meal_events (log_day_id);
create index if not exists idx_meal_events_occurred_at
  on public.meal_events (occurred_at);
create index if not exists idx_meal_events_source_entry
  on public.meal_events (source_entry_id)
  where source_entry_id is not null;

-- symptom_events
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
-- FIX: was missing — sync deletes on update were full table scans
create index if not exists idx_symptom_events_source_entry
  on public.symptom_events (source_entry_id)
  where source_entry_id is not null;

-- remedy_events
create index if not exists idx_remedy_events_user
  on public.remedy_events (user_id);
create index if not exists idx_remedy_events_log_day
  on public.remedy_events (log_day_id);
create index if not exists idx_remedy_events_occurred_at
  on public.remedy_events (occurred_at);
-- FIX: was missing
create index if not exists idx_remedy_events_source_entry
  on public.remedy_events (source_entry_id)
  where source_entry_id is not null;

-- trigger_events
create index if not exists idx_trigger_events_user
  on public.trigger_events (user_id);
create index if not exists idx_trigger_events_log_day
  on public.trigger_events (log_day_id);
create index if not exists idx_trigger_events_occurred_at
  on public.trigger_events (occurred_at);
create index if not exists idx_trigger_events_source
  on public.trigger_events (source_type, source_ref_id)
  where source_ref_id is not null;
-- FIX: was missing
create index if not exists idx_trigger_events_source_entry
  on public.trigger_events (source_entry_id)
  where source_entry_id is not null;

-- tags & junctions
create index if not exists idx_meal_tags_user
  on public.meal_tags (user_id);
create index if not exists idx_symptom_tags_user
  on public.symptom_tags (user_id);
create index if not exists idx_meal_event_meal_tags_user
  on public.meal_event_meal_tags (user_id);
create index if not exists idx_symptom_event_symptom_tags_user
  on public.symptom_event_symptom_tags (user_id);

-- profile detail tables
create index if not exists idx_profile_conditions_user
  on public.profile_conditions (user_id);
create index if not exists idx_medications_user
  on public.medications (user_id);

-- analytics
create index if not exists idx_analytics_trigger_user_window
  on public.analytics_trigger_scores (user_id, window_end desc);
create index if not exists idx_analytics_remedy_user_window
  on public.analytics_remedy_scores (user_id, window_end desc);
create index if not exists idx_weekly_summaries_user_week
  on public.weekly_summaries (user_id, week_start desc);
create index if not exists idx_recommendation_cache_user_version
  on public.recommendation_cache (user_id, cache_version);


-- #############################################################################
-- SECTION 8 — Row Level Security
-- #############################################################################

alter table public.profiles                    enable row level security;
alter table public.log_entries                 enable row level security;
alter table public.log_days                    enable row level security;
alter table public.meal_events                 enable row level security;
alter table public.symptom_events              enable row level security;
alter table public.remedy_events               enable row level security;
alter table public.trigger_events              enable row level security;
alter table public.meal_tags                   enable row level security;
alter table public.symptom_tags                enable row level security;
alter table public.meal_event_meal_tags        enable row level security;
alter table public.symptom_event_symptom_tags  enable row level security;
alter table public.profile_conditions          enable row level security;
alter table public.medications                 enable row level security;
alter table public.analytics_trigger_scores    enable row level security;
alter table public.analytics_remedy_scores     enable row level security;
alter table public.analytics_food_scores       enable row level security;
alter table public.analytics_time_patterns     enable row level security;
alter table public.weekly_summaries            enable row level security;
alter table public.recommendation_cache        enable row level security;

-- Helper macro: all tables use the same auth.uid() = user_id pattern
do $$
declare
  t text;
  tables text[] := array[
    'profiles','log_entries','log_days',
    'meal_events','symptom_events','remedy_events','trigger_events',
    'meal_tags','symptom_tags',
    'meal_event_meal_tags','symptom_event_symptom_tags',
    'profile_conditions','medications',
    'analytics_trigger_scores','analytics_remedy_scores',
    'analytics_food_scores','analytics_time_patterns',
    'weekly_summaries','recommendation_cache'
  ];
begin
  foreach t in array tables loop
    execute format('drop policy if exists "%s_select" on public.%I', t, t);
    execute format('drop policy if exists "%s_insert" on public.%I', t, t);
    execute format('drop policy if exists "%s_update" on public.%I', t, t);
    execute format('drop policy if exists "%s_delete" on public.%I', t, t);

    execute format(
      'create policy "%s_select" on public.%I for select using (auth.uid() is not null and auth.uid() = user_id)',
      t, t
    );
    execute format(
      'create policy "%s_insert" on public.%I for insert with check (auth.uid() is not null and auth.uid() = user_id)',
      t, t
    );
    execute format(
      'create policy "%s_update" on public.%I for update using (auth.uid() is not null and auth.uid() = user_id)',
      t, t
    );
    execute format(
      'create policy "%s_delete" on public.%I for delete using (auth.uid() is not null and auth.uid() = user_id)',
      t, t
    );
  end loop;
end;
$$;


-- #############################################################################
-- SECTION 9 — Sync functions
-- security definer so triggers write to RLS-protected tables consistently,
-- regardless of the calling role context (client, service role, migration).
-- #############################################################################

create or replace function public.sync_log_entry_to_normalized(p_entry public.log_entries)
returns void
language plpgsql
security definer                   -- FIX: was security invoker
set search_path = public
as $$
declare
  v_log_day_id      uuid;
  v_symptom         jsonb;
  v_remedy          jsonb;
  v_trigger         jsonb;
  v_food_elem       jsonb;
  v_name            text;
  v_severity        int;
  v_helpfulness     int;
  v_effectiveness   int;
  v_notes           text;
  v_subtype         text;
  v_body_region     text;
  v_onset_min       int;
  v_intensity       int;
  v_effective_at    timestamptz;
  v_meal_at         timestamptz;
  v_symptom_at      timestamptz;
  v_has_meal        boolean;
  v_food_tags       jsonb;
  v_meal_event_id   uuid;
  v_meal_tag_id     uuid;
begin
  v_effective_at := coalesce(p_entry.episode_at, p_entry.entry_at);
  v_meal_at      := coalesce(p_entry.meal_occurred_at, v_effective_at);
  v_food_tags    := coalesce(p_entry.food_tags, '[]'::jsonb);

  -- Upsert the day anchor
  insert into public.log_days (user_id, log_date)
  values (p_entry.user_id, p_entry.entry_date)
  on conflict (user_id, log_date) do update set updated_at = now()
  returning id into v_log_day_id;

  if v_log_day_id is null then
    select id into v_log_day_id
    from public.log_days
    where user_id = p_entry.user_id and log_date = p_entry.entry_date;
  end if;

  -- ── Meal ──────────────────────────────────────────────────────────────────
  v_has_meal :=
    coalesce(trim(p_entry.meal_name),  '') <> ''
    or coalesce(trim(p_entry.meal_notes), '') <> ''
    or jsonb_array_length(v_food_tags) > 0;

  if v_has_meal then
    insert into public.meal_events (
      user_id, log_day_id, source_entry_id, occurred_at,
      meal_name, notes, food_tags
    )
    values (
      p_entry.user_id, v_log_day_id, p_entry.id, v_meal_at,
      p_entry.meal_name, p_entry.meal_notes, v_food_tags
    )
    returning id into v_meal_event_id;

    for v_food_elem in select * from jsonb_array_elements(v_food_tags)
    loop
      -- FIX: handle both string elements and {tag:...} object elements
      if jsonb_typeof(v_food_elem) = 'string' then
        v_name := nullif(trim(v_food_elem #>> '{}'), '');
      else
        v_name := nullif(trim(v_food_elem ->> 'tag'), '');
      end if;

      if v_name is not null then
        insert into public.meal_tags (user_id, name)
        values (p_entry.user_id, v_name)
        on conflict (user_id, name) do nothing;

        select id into v_meal_tag_id
        from public.meal_tags
        where user_id = p_entry.user_id and name = v_name;

        if v_meal_tag_id is not null then
          insert into public.meal_event_meal_tags (meal_event_id, meal_tag_id, user_id)
          values (v_meal_event_id, v_meal_tag_id, p_entry.user_id)
          on conflict (meal_event_id, meal_tag_id) do nothing;
        end if;
      end if;
    end loop;
  end if;

  -- ── Symptoms ──────────────────────────────────────────────────────────────
  for v_symptom in select * from jsonb_array_elements(p_entry.symptoms)
  loop
    v_name := coalesce(
      nullif(trim(v_symptom ->> 'name'), ''),
      case when jsonb_typeof(v_symptom) = 'string' then nullif(trim(v_symptom #>> '{}'), '') end
    );
    if v_name is not null then
      -- FIX: safe_int() prevents cast errors on malformed numeric fields
      v_severity   := public.safe_int(v_symptom ->> 'severity');
      v_notes      := v_symptom ->> 'notes';
      v_subtype    := v_symptom ->> 'subtype';
      v_body_region := v_symptom ->> 'body_region';
      v_onset_min  := public.safe_int(v_symptom ->> 'onset_after_meal_minutes');

      v_symptom_at := case
        when v_onset_min is not null
        then v_effective_at + (v_onset_min * interval '1 minute')
        else v_effective_at
      end;

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

  -- ── Remedies ──────────────────────────────────────────────────────────────
  for v_remedy in select * from jsonb_array_elements(p_entry.remedies)
  loop
    v_name := coalesce(
      nullif(trim(v_remedy ->> 'name'), ''),
      case when jsonb_typeof(v_remedy) = 'string' then nullif(trim(v_remedy #>> '{}'), '') end
    );
    if v_name is not null then
      -- FIX: safe_int() on all numeric fields; coalesce multiple keys
      v_effectiveness := coalesce(
        public.safe_int(v_remedy ->> 'effectiveness'),
        public.safe_int(v_remedy ->> 'effectiveness_score'),
        public.safe_int(v_remedy ->> 'helpfulness')
      );
      v_helpfulness := coalesce(
        public.safe_int(v_remedy ->> 'helpfulness'),
        v_effectiveness
      );
      v_notes := v_remedy ->> 'notes';

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

  -- ── Triggers ──────────────────────────────────────────────────────────────
  for v_trigger in select * from jsonb_array_elements(p_entry.triggers)
  loop
    v_name := coalesce(
      nullif(trim(v_trigger ->> 'name'), ''),
      case when jsonb_typeof(v_trigger) = 'string' then nullif(trim(v_trigger #>> '{}'), '') end
    );
    if v_name is not null then
      v_intensity := public.safe_int(v_trigger ->> 'intensity'); -- FIX: safe_int
      v_notes     := v_trigger ->> 'notes';

      insert into public.trigger_events (
        user_id, log_day_id, source_entry_id,
        source_type, source_ref_id,
        occurred_at, trigger_name, notes, intensity
      )
      values (
        p_entry.user_id, v_log_day_id, p_entry.id,
        'entry', null,
        v_effective_at, v_name, v_notes, v_intensity
      );
    end if;
  end loop;
end;
$$;

-- -

create or replace function public.sync_log_entry_on_insert()
returns trigger
language plpgsql
security definer                   -- FIX: was security invoker
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
security definer                   -- FIX: was security invoker
set search_path = public
as $$
begin
  -- NOTE: delete-and-rebuild is the current sync strategy.
  -- Normalized event IDs are NOT stable across log_entry edits.
  -- Future: move to upsert-by-derived-key or soft-delete/versioning.
  delete from public.meal_events     where source_entry_id = new.id;
  delete from public.symptom_events  where source_entry_id = new.id;
  delete from public.remedy_events   where source_entry_id = new.id;
  delete from public.trigger_events  where source_entry_id = new.id;
  perform public.sync_log_entry_to_normalized(new);
  return new;
end;
$$;

create or replace function public.sync_log_entry_on_delete()
returns trigger
language plpgsql
security definer                   -- FIX: was security invoker
set search_path = public
as $$
begin
  delete from public.meal_events     where source_entry_id = old.id;
  delete from public.symptom_events  where source_entry_id = old.id;
  delete from public.remedy_events   where source_entry_id = old.id;
  delete from public.trigger_events  where source_entry_id = old.id;
  return old;
end;
$$;


-- #############################################################################
-- SECTION 10 — Analytics & recommendation functions
-- #############################################################################

create or replace function public.refresh_user_analytics(
  p_user_id uuid,
  p_from    date,
  p_to      date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_from_ts    timestamptz := p_from::timestamptz;
  v_to_ts_excl timestamptz := (p_to + 1)::timestamptz;
begin
  -- FIX: auth guard — allow service-role (auth.uid() null) or self only
  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'unauthorized: analytics refresh requires matching user';
  end if;

  if p_user_id is null or p_from is null or p_to is null or p_from > p_to then
    raise exception 'refresh_user_analytics: invalid arguments';
  end if;

  -- ── weekly_summaries (single-pass CTE upsert) ────────────────────────────
  -- FIX: was a two-round-trip insert then update; now one upsert with all fields
  insert into public.weekly_summaries (
    user_id, week_start,
    entry_count, avg_pain, avg_stress,
    top_triggers, top_remedies, top_symptoms,
    updated_at
  )
  with base as (
    select
      le.user_id,
      date_trunc('week', le.entry_at at time zone 'utc')::date as week_start,
      count(*)::int        as entry_count,
      avg(le.pain_score)   as avg_pain,
      avg(le.stress_score) as avg_stress
    from public.log_entries le
    where le.user_id = p_user_id
      and le.entry_at >= v_from_ts
      and le.entry_at <  v_to_ts_excl
    group by le.user_id,
             date_trunc('week', le.entry_at at time zone 'utc')::date
  )
  select
    b.user_id,
    b.week_start,
    b.entry_count,
    b.avg_pain,
    b.avg_stress,
    coalesce((
      select jsonb_agg(obj order by (obj->>'n')::int desc) from (
        select jsonb_build_object('name', te.trigger_name, 'n', count(*)::int) as obj
        from public.trigger_events te
        join public.log_entries le
          on le.id = te.source_entry_id and le.user_id = te.user_id
        where te.user_id = p_user_id
          and date_trunc('week', le.entry_at at time zone 'utc')::date = b.week_start
        group by te.trigger_name order by count(*) desc limit 10
      ) t
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(obj order by (obj->>'n')::int desc) from (
        select jsonb_build_object('name', re.remedy_name, 'n', count(*)::int) as obj
        from public.remedy_events re
        join public.log_entries le
          on le.id = re.source_entry_id and le.user_id = re.user_id
        where re.user_id = p_user_id
          and date_trunc('week', le.entry_at at time zone 'utc')::date = b.week_start
        group by re.remedy_name order by count(*) desc limit 10
      ) r
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(obj order by (obj->>'n')::int desc) from (
        select jsonb_build_object('name', se.symptom_name, 'n', count(*)::int) as obj
        from public.symptom_events se
        join public.log_entries le
          on le.id = se.source_entry_id and le.user_id = se.user_id
        where se.user_id = p_user_id
          and date_trunc('week', le.entry_at at time zone 'utc')::date = b.week_start
        group by se.symptom_name order by count(*) desc limit 10
      ) s
    ), '[]'::jsonb),
    now()
  from base
  on conflict (user_id, week_start) do update set
    entry_count  = excluded.entry_count,
    avg_pain     = excluded.avg_pain,
    avg_stress   = excluded.avg_stress,
    top_triggers = excluded.top_triggers,
    top_remedies = excluded.top_remedies,
    top_symptoms = excluded.top_symptoms,
    updated_at   = now();

  -- ── analytics_remedy_scores (FIX: upsert, no DELETE gap) ─────────────────
  insert into public.analytics_remedy_scores (
    user_id, remedy_name, window_start, window_end,
    avg_effectiveness, usage_count, updated_at
  )
  select
    p_user_id,
    re.remedy_name,
    p_from, p_to,
    avg(coalesce(re.effectiveness_score, re.helpfulness))::numeric,
    count(*)::int,
    now()
  from public.remedy_events re
  where re.user_id    = p_user_id
    and re.occurred_at >= v_from_ts
    and re.occurred_at <  v_to_ts_excl
  group by re.remedy_name
  on conflict (user_id, remedy_name, window_start, window_end) do update set
    avg_effectiveness = excluded.avg_effectiveness,
    usage_count       = excluded.usage_count,
    updated_at        = now();

  -- ── analytics_trigger_scores (FIX: upsert, pain_delta column) ────────────
  insert into public.analytics_trigger_scores (
    user_id, trigger_name, window_start, window_end,
    sample_count, avg_pain_when_present, avg_pain_when_absent, pain_delta, updated_at
  )
  select
    p_user_id,
    s.trigger_name,
    p_from, p_to,
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
      avg(le.pain_score)         as avg_with
    from public.log_entries le
    join public.trigger_events te
      on te.source_entry_id = le.id and te.user_id = le.user_id
    where le.user_id    = p_user_id
      and le.entry_at  >= v_from_ts
      and le.entry_at  <  v_to_ts_excl
    group by te.trigger_name
  ) s
  cross join lateral (
    select avg(le2.pain_score) as avg_without
    from public.log_entries le2
    where le2.user_id   = p_user_id
      and le2.entry_at >= v_from_ts
      and le2.entry_at <  v_to_ts_excl
      and not exists (
        select 1 from public.trigger_events te2
        where te2.source_entry_id = le2.id
          and te2.user_id         = le2.user_id
          and te2.trigger_name    = s.trigger_name
      )
  ) w
  on conflict (user_id, trigger_name, window_start, window_end) do update set
    sample_count          = excluded.sample_count,
    avg_pain_when_present = excluded.avg_pain_when_present,
    avg_pain_when_absent  = excluded.avg_pain_when_absent,
    pain_delta            = excluded.pain_delta,
    updated_at            = now();

  -- ── analytics_food_scores (FIX: upsert, fixed tag extraction) ────────────
  insert into public.analytics_food_scores (
    user_id, food_tag, window_start, window_end,
    co_occurrence_pain_avg, entry_count, updated_at
  )
  select
    p_user_id,
    t.tag_name,
    p_from, p_to,
    avg(le.pain_score),
    count(*)::int,
    now()
  from public.log_entries le
  cross join lateral (
    select
      -- FIX: handle string vs object elements correctly
      case
        when jsonb_typeof(elem) = 'string' then nullif(trim(elem #>> '{}'), '')
        else nullif(trim(elem ->> 'tag'), '')
      end as tag_name
    from jsonb_array_elements(coalesce(le.food_tags, '[]'::jsonb)) elem
  ) t
  where le.user_id   = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at <  v_to_ts_excl
    and t.tag_name is not null
    and t.tag_name <> ''
  group by t.tag_name
  on conflict (user_id, food_tag, window_start, window_end) do update set
    co_occurrence_pain_avg = excluded.co_occurrence_pain_avg,
    entry_count            = excluded.entry_count,
    updated_at             = now();

  -- ── analytics_time_patterns — hour_of_day (FIX: upsert) ─────────────────
  insert into public.analytics_time_patterns (
    user_id, bucket_type, bucket_value, window_start, window_end,
    avg_pain, entry_count, updated_at
  )
  select
    p_user_id,
    'hour_of_day',
    extract(hour from le.entry_at at time zone 'utc')::smallint,
    p_from, p_to,
    avg(le.pain_score),
    count(*)::int,
    now()
  from public.log_entries le
  where le.user_id   = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at <  v_to_ts_excl
  group by extract(hour from le.entry_at at time zone 'utc')::smallint
  on conflict (user_id, bucket_type, bucket_value, window_start, window_end) do update set
    avg_pain    = excluded.avg_pain,
    entry_count = excluded.entry_count,
    updated_at  = now();

  -- ── analytics_time_patterns — dow (FIX: upsert) ──────────────────────────
  insert into public.analytics_time_patterns (
    user_id, bucket_type, bucket_value, window_start, window_end,
    avg_pain, entry_count, updated_at
  )
  select
    p_user_id,
    'dow',
    extract(dow from le.entry_at at time zone 'utc')::smallint,
    p_from, p_to,
    avg(le.pain_score),
    count(*)::int,
    now()
  from public.log_entries le
  where le.user_id   = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at <  v_to_ts_excl
  group by extract(dow from le.entry_at at time zone 'utc')::smallint
  on conflict (user_id, bucket_type, bucket_value, window_start, window_end) do update set
    avg_pain    = excluded.avg_pain,
    entry_count = excluded.entry_count,
    updated_at  = now();
end;
$$;

-- -

create or replace function public.refresh_user_recommendations(
  p_user_id     uuid,
  p_cache_version text default 'v1'
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_payload jsonb;
  v_week    date;
begin
  -- FIX: auth guard
  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'unauthorized: recommendations refresh requires matching user';
  end if;

  if p_user_id is null then
    raise exception 'refresh_user_recommendations: p_user_id required';
  end if;

  select max(ws.week_start) into v_week
  from public.weekly_summaries ws
  where ws.user_id = p_user_id;

  select jsonb_build_object(
    'week_summary_ref',
      case when v_week is null then null else to_char(v_week, 'YYYY-MM-DD') end,
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
             'hour',     atp.bucket_value,
             'avg_pain', atp.avg_pain,
             'n',        atp.entry_count
           ) order by atp.avg_pain desc nulls last
         )
         from public.analytics_time_patterns atp
         where atp.user_id     = p_user_id
           and atp.bucket_type = 'hour_of_day'
           and atp.window_end  = (
             select max(window_end)
             from public.analytics_time_patterns
             where user_id = p_user_id and bucket_type = 'hour_of_day'
           )
        ),
        '[]'::jsonb
      ),
    'recent_entry_count',
      (select count(*)::int
       from public.log_entries le
       where le.user_id  = p_user_id
         and le.entry_at >= now() - interval '30 days')
  ) into v_payload;

  insert into public.recommendation_cache (
    user_id, cache_version, generated_at, payload
  )
  values (
    p_user_id,
    coalesce(nullif(trim(p_cache_version), ''), 'v1'),
    now(),
    coalesce(v_payload, '{}'::jsonb)
  )
  on conflict (user_id, cache_version) do update set
    generated_at = now(),
    payload      = excluded.payload;
end;
$$;

grant execute on function public.refresh_user_analytics(uuid, date, date) to authenticated;
grant execute on function public.refresh_user_recommendations(uuid, text)  to authenticated;


-- #############################################################################
-- SECTION 11 — Sync triggers on log_entries
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


-- #############################################################################
-- SECTION 12 — Timeline view
-- #############################################################################

-- FIX: security_invoker = true → view runs as the calling user, so RLS on
-- underlying tables is enforced. Without this, the view owner's privileges
-- are used, bypassing RLS and exposing all users' data.
create or replace view public.v_user_timeline
  with (security_invoker = true)
as
select
  user_id,
  'log_entry'::text                             as event_type,
  entry_at                                      as occurred_at,
  coalesce(meal_name, 'Log entry')              as title,
  jsonb_build_object(
    'pain_score',   pain_score,
    'stress_score', stress_score,
    'symptoms',     symptoms,
    'triggers',     triggers,
    'remedies',     remedies,
    'notes',        notes
  )                                             as details,
  id                                            as source_entry_id
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
  jsonb_build_object(
    'severity',    severity,
    'notes',       notes,
    'subtype',     subtype,
    'body_region', body_region
  ),
  source_entry_id
from public.symptom_events

union all

select
  user_id,
  'remedy'::text,
  occurred_at,
  remedy_name,
  jsonb_build_object(
    'helpfulness',         helpfulness,
    'effectiveness_score', effectiveness_score,
    'notes',               notes
  ),
  source_entry_id
from public.remedy_events

union all

select
  user_id,
  'trigger'::text,
  occurred_at,
  trigger_name,
  jsonb_build_object(
    'notes',        notes,
    'intensity',    intensity,
    'source_type',  source_type,
    'source_ref_id', source_ref_id
  ),
  source_entry_id
from public.trigger_events;


-- #############################################################################
-- SECTION 13 — Grants
-- #############################################################################

-- FIX: anon grant removed entirely — health data must not be readable
-- without authentication, and security_invoker handles per-user filtering.
-- FIX: was: grant select on public.v_user_timeline to anon;
grant select on public.v_user_timeline to authenticated;

-- =============================================================================
-- End GastroGuard production schema v2
-- =============================================================================
