-- =============================================================================
-- GastroGuard Hybrid Backend Migration
-- =============================================================================
-- Frontend writes flat log_entries; triggers sync to normalized analytics tables.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Phase 1: Foundation
-- -----------------------------------------------------------------------------

-- Reusable trigger to set updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql security invoker;

-- Profiles table (1:1 with auth.users)
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  name text default '',
  age integer default 0,
  height text default '',
  weight text default '',
  gender text default '',
  conditions jsonb default '[]'::jsonb,
  medications jsonb default '[]'::jsonb,
  allergies jsonb default '[]'::jsonb,
  dietary_restrictions jsonb default '[]'::jsonb,
  triggers jsonb default '[]'::jsonb,
  effective_remedies jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (user_id)
  values (new.id);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Phase 2: Frontend-compatible log_entries
-- -----------------------------------------------------------------------------

create table public.log_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_at timestamptz not null default now(),
  entry_date date not null,
  pain_score integer not null default 0 check (pain_score >= 0 and pain_score <= 10),
  stress_score integer not null default 0 check (stress_score >= 0 and stress_score <= 10),
  nausea_score integer check (nausea_score is null or (nausea_score >= 0 and nausea_score <= 10)),
  meal_name text,
  meal_notes text,
  symptoms jsonb not null default '[]'::jsonb,
  triggers jsonb not null default '[]'::jsonb,
  remedies jsonb not null default '[]'::jsonb,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_log_entries_user_entry_at on public.log_entries(user_id, entry_at desc);
create index idx_log_entries_user_entry_date on public.log_entries(user_id, entry_date);

create trigger log_entries_updated_at
  before update on public.log_entries
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Phase 3: Normalized analytics tables
-- -----------------------------------------------------------------------------

create table public.log_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, log_date)
);

create trigger log_days_updated_at
  before update on public.log_days
  for each row execute function public.set_updated_at();

create table public.meal_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_day_id uuid not null references public.log_days(id) on delete cascade,
  source_entry_id uuid references public.log_entries(id) on delete set null,
  occurred_at timestamptz not null,
  meal_name text,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create trigger meal_events_updated_at
  before update on public.meal_events
  for each row execute function public.set_updated_at();

create table public.symptom_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_day_id uuid not null references public.log_days(id) on delete cascade,
  source_entry_id uuid references public.log_entries(id) on delete set null,
  occurred_at timestamptz not null,
  symptom_name text not null,
  severity integer check (severity is null or (severity >= 0 and severity <= 10)),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create trigger symptom_events_updated_at
  before update on public.symptom_events
  for each row execute function public.set_updated_at();

create table public.remedy_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_day_id uuid not null references public.log_days(id) on delete cascade,
  source_entry_id uuid references public.log_entries(id) on delete set null,
  occurred_at timestamptz not null,
  remedy_name text not null,
  helpfulness integer check (helpfulness is null or (helpfulness >= 0 and helpfulness <= 10)),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create trigger remedy_events_updated_at
  before update on public.remedy_events
  for each row execute function public.set_updated_at();

create table public.trigger_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_day_id uuid not null references public.log_days(id) on delete cascade,
  source_entry_id uuid references public.log_entries(id) on delete set null,
  source_type text not null check (source_type in ('entry','meal','symptom')),
  source_ref_id uuid,
  occurred_at timestamptz not null,
  trigger_name text not null,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create trigger trigger_events_updated_at
  before update on public.trigger_events
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Phase 4: Metadata tables
-- -----------------------------------------------------------------------------

create table public.meal_tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz default now(),
  unique(user_id, name)
);

create table public.symptom_tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz default now(),
  unique(user_id, name)
);

create table public.profile_conditions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  condition_name text not null,
  notes text,
  diagnosed_at date,
  created_at timestamptz default now()
);

create table public.medications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  medication_name text not null,
  dosage text,
  frequency text,
  notes text,
  created_at timestamptz default now()
);

-- -----------------------------------------------------------------------------
-- Phase 5 & 6: Sync logic - shared function for INSERT and UPDATE
-- -----------------------------------------------------------------------------

create or replace function public.sync_log_entry_to_normalized(p_entry public.log_entries)
returns void as $$
declare
  v_log_day_id uuid;
  v_symptom jsonb;
  v_remedy jsonb;
  v_trigger jsonb;
  v_name text;
  v_severity int;
  v_helpfulness int;
  v_notes text;
begin
  -- 1. Upsert log_days
  insert into public.log_days (user_id, log_date)
  values (p_entry.user_id, p_entry.entry_date)
  on conflict (user_id, log_date) do update set updated_at = now()
  returning id into v_log_day_id;

  if v_log_day_id is null then
    select id into v_log_day_id from public.log_days
    where user_id = p_entry.user_id and log_date = p_entry.entry_date;
  end if;

  -- 2. Meal event if meal_name or meal_notes present
  if coalesce(trim(p_entry.meal_name), '') != '' or coalesce(trim(p_entry.meal_notes), '') != '' then
    insert into public.meal_events (user_id, log_day_id, source_entry_id, occurred_at, meal_name, notes)
    values (p_entry.user_id, v_log_day_id, p_entry.id, p_entry.entry_at, p_entry.meal_name, p_entry.meal_notes);
  end if;

  -- 3. Symptom events (parse string or object)
  for v_symptom in select * from jsonb_array_elements(p_entry.symptoms)
  loop
    v_name := coalesce(nullif(trim(v_symptom->>'name'), ''), nullif(trim(v_symptom#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      v_severity := (v_symptom->>'severity')::int;
      v_notes := v_symptom->>'notes';
      insert into public.symptom_events (user_id, log_day_id, source_entry_id, occurred_at, symptom_name, severity, notes)
      values (p_entry.user_id, v_log_day_id, p_entry.id, p_entry.entry_at, v_name, v_severity, v_notes);
    end if;
  end loop;

  -- 4. Remedy events (parse string or object)
  for v_remedy in select * from jsonb_array_elements(p_entry.remedies)
  loop
    v_name := coalesce(nullif(trim(v_remedy->>'name'), ''), nullif(trim(v_remedy#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      v_helpfulness := (v_remedy->>'helpfulness')::int;
      v_notes := v_remedy->>'notes';
      insert into public.remedy_events (user_id, log_day_id, source_entry_id, occurred_at, remedy_name, helpfulness, notes)
      values (p_entry.user_id, v_log_day_id, p_entry.id, p_entry.entry_at, v_name, v_helpfulness, v_notes);
    end if;
  end loop;

  -- 5. Trigger events (parse string or object)
  for v_trigger in select * from jsonb_array_elements(p_entry.triggers)
  loop
    v_name := coalesce(nullif(trim(v_trigger->>'name'), ''), nullif(trim(v_trigger#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      v_notes := v_trigger->>'notes';
      insert into public.trigger_events (user_id, log_day_id, source_entry_id, source_type, occurred_at, trigger_name, notes)
      values (p_entry.user_id, v_log_day_id, p_entry.id, 'entry', p_entry.entry_at, v_name, v_notes);
    end if;
  end loop;
end;
$$ language plpgsql security invoker;

-- Trigger: INSERT
create or replace function public.sync_log_entry_on_insert()
returns trigger as $$
begin
  perform public.sync_log_entry_to_normalized(new);
  return new;
end;
$$ language plpgsql security invoker;

create trigger tr_sync_log_entry_insert
  after insert on public.log_entries
  for each row execute function public.sync_log_entry_on_insert();

-- Trigger: UPDATE - delete existing normalized rows, then rebuild
create or replace function public.sync_log_entry_on_update()
returns trigger as $$
begin
  delete from public.meal_events where source_entry_id = new.id;
  delete from public.symptom_events where source_entry_id = new.id;
  delete from public.remedy_events where source_entry_id = new.id;
  delete from public.trigger_events where source_entry_id = new.id;
  perform public.sync_log_entry_to_normalized(new);
  return new;
end;
$$ language plpgsql security invoker;

create trigger tr_sync_log_entry_update
  after update on public.log_entries
  for each row execute function public.sync_log_entry_on_update();

-- Trigger: DELETE
create or replace function public.sync_log_entry_on_delete()
returns trigger as $$
begin
  delete from public.meal_events where source_entry_id = old.id;
  delete from public.symptom_events where source_entry_id = old.id;
  delete from public.remedy_events where source_entry_id = old.id;
  delete from public.trigger_events where source_entry_id = old.id;
  return old;
end;
$$ language plpgsql security invoker;

create trigger tr_sync_log_entry_delete
  after delete on public.log_entries
  for each row execute function public.sync_log_entry_on_delete();

-- -----------------------------------------------------------------------------
-- Phase 7: RLS
-- -----------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.log_entries enable row level security;
alter table public.log_days enable row level security;
alter table public.meal_events enable row level security;
alter table public.symptom_events enable row level security;
alter table public.remedy_events enable row level security;
alter table public.trigger_events enable row level security;
alter table public.meal_tags enable row level security;
alter table public.symptom_tags enable row level security;
alter table public.profile_conditions enable row level security;
alter table public.medications enable row level security;

-- profiles
create policy "profiles_select" on public.profiles for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "profiles_update" on public.profiles for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "profiles_delete" on public.profiles for delete using (auth.uid() is not null and auth.uid() = user_id);

-- log_entries
create policy "log_entries_select" on public.log_entries for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "log_entries_insert" on public.log_entries for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "log_entries_update" on public.log_entries for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "log_entries_delete" on public.log_entries for delete using (auth.uid() is not null and auth.uid() = user_id);

-- log_days
create policy "log_days_select" on public.log_days for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "log_days_insert" on public.log_days for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "log_days_update" on public.log_days for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "log_days_delete" on public.log_days for delete using (auth.uid() is not null and auth.uid() = user_id);

-- meal_events
create policy "meal_events_select" on public.meal_events for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_events_insert" on public.meal_events for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_events_update" on public.meal_events for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_events_delete" on public.meal_events for delete using (auth.uid() is not null and auth.uid() = user_id);

-- symptom_events
create policy "symptom_events_select" on public.symptom_events for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_events_insert" on public.symptom_events for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_events_update" on public.symptom_events for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_events_delete" on public.symptom_events for delete using (auth.uid() is not null and auth.uid() = user_id);

-- remedy_events
create policy "remedy_events_select" on public.remedy_events for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "remedy_events_insert" on public.remedy_events for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "remedy_events_update" on public.remedy_events for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "remedy_events_delete" on public.remedy_events for delete using (auth.uid() is not null and auth.uid() = user_id);

-- trigger_events
create policy "trigger_events_select" on public.trigger_events for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "trigger_events_insert" on public.trigger_events for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "trigger_events_update" on public.trigger_events for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "trigger_events_delete" on public.trigger_events for delete using (auth.uid() is not null and auth.uid() = user_id);

-- meal_tags
create policy "meal_tags_select" on public.meal_tags for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_tags_insert" on public.meal_tags for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_tags_update" on public.meal_tags for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "meal_tags_delete" on public.meal_tags for delete using (auth.uid() is not null and auth.uid() = user_id);

-- symptom_tags
create policy "symptom_tags_select" on public.symptom_tags for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_tags_insert" on public.symptom_tags for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_tags_update" on public.symptom_tags for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "symptom_tags_delete" on public.symptom_tags for delete using (auth.uid() is not null and auth.uid() = user_id);

-- profile_conditions
create policy "profile_conditions_select" on public.profile_conditions for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "profile_conditions_insert" on public.profile_conditions for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "profile_conditions_update" on public.profile_conditions for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "profile_conditions_delete" on public.profile_conditions for delete using (auth.uid() is not null and auth.uid() = user_id);

-- medications
create policy "medications_select" on public.medications for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "medications_insert" on public.medications for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "medications_update" on public.medications for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "medications_delete" on public.medications for delete using (auth.uid() is not null and auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Phase 8: Developer ergonomics - indexes, comments, view
-- -----------------------------------------------------------------------------

create index idx_log_days_log_date on public.log_days(log_date);
create index idx_meal_events_occurred_at on public.meal_events(occurred_at);
create index idx_symptom_events_symptom_name on public.symptom_events(symptom_name);
create index idx_symptom_events_occurred_at on public.symptom_events(occurred_at);
create index idx_remedy_events_occurred_at on public.remedy_events(occurred_at);
create index idx_trigger_events_occurred_at on public.trigger_events(occurred_at);

comment on table public.profiles is 'User profile data, 1:1 with auth.users';
comment on table public.log_entries is 'Flat log entry table - frontend write surface';
comment on table public.log_days is 'Normalized: one row per user per day';
comment on table public.meal_events is 'Normalized: meal events synced from log_entries';
comment on table public.symptom_events is 'Normalized: symptom events synced from log_entries';
comment on table public.remedy_events is 'Normalized: remedy events synced from log_entries';
comment on table public.trigger_events is 'Normalized: trigger events synced from log_entries';
comment on column public.log_entries.entry_at is 'Timestamp of the log entry';
comment on column public.log_entries.entry_date is 'Date portion for partitioning/indexing';
comment on column public.log_entries.symptoms is 'JSON array of strings or {name, severity?, notes?} objects';

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
  jsonb_build_object('notes', notes),
  source_entry_id
from public.meal_events
union all
select
  user_id,
  'symptom'::text,
  occurred_at,
  symptom_name,
  jsonb_build_object('severity', severity, 'notes', notes),
  source_entry_id
from public.symptom_events
union all
select
  user_id,
  'remedy'::text,
  occurred_at,
  remedy_name,
  jsonb_build_object('helpfulness', helpfulness, 'notes', notes),
  source_entry_id
from public.remedy_events
union all
select
  user_id,
  'trigger'::text,
  occurred_at,
  trigger_name,
  jsonb_build_object('notes', notes),
  source_entry_id
from public.trigger_events;
