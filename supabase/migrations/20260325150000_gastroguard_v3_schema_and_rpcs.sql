-- =============================================================================
-- GastroGuard v3 — additive schema + feature rollups + RPCs
-- Idempotent where possible. Depends on prior hybrid + analytics migrations.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) profiles — optional v3 scalar fields (additive)
-- -----------------------------------------------------------------------------
alter table if exists public.profiles
  add column if not exists preferred_units jsonb not null default '{}'::jsonb;
alter table if exists public.profiles
  add column if not exists gastritis_diagnosis boolean default false;
alter table if exists public.profiles
  add column if not exists ibs_diagnosis boolean default false;
alter table if exists public.profiles
  add column if not exists gerd_diagnosis boolean default false;
alter table if exists public.profiles
  add column if not exists height_cm numeric;
alter table if exists public.profiles
  add column if not exists weight_kg numeric;

-- -----------------------------------------------------------------------------
-- 2) log_entries — v3 capture fields (additive; keep pain_score / symptoms as SoT)
-- -----------------------------------------------------------------------------
alter table if exists public.log_entries
  add column if not exists meal_size text;
alter table if exists public.log_entries
  add column if not exists time_since_eating_minutes integer
    check (time_since_eating_minutes is null or time_since_eating_minutes >= 0);
alter table if exists public.log_entries
  add column if not exists sleep_quality integer
    check (sleep_quality is null or (sleep_quality >= 0 and sleep_quality <= 10));
alter table if exists public.log_entries
  add column if not exists sleep_hours numeric;
alter table if exists public.log_entries
  add column if not exists exercise_level integer
    check (exercise_level is null or (exercise_level >= 0 and exercise_level <= 10));
alter table if exists public.log_entries
  add column if not exists weather_condition text;
alter table if exists public.log_entries
  add column if not exists source text not null default 'app';
alter table if exists public.log_entries
  add column if not exists source_id text;
alter table if exists public.log_entries
  add column if not exists sync_status text default 'synced';

alter table if exists public.log_entries
  add column if not exists symptom_labels jsonb not null default '[]'::jsonb;
alter table if exists public.log_entries
  add column if not exists trigger_labels jsonb not null default '[]'::jsonb;
alter table if exists public.log_entries
  add column if not exists remedy_labels jsonb not null default '[]'::jsonb;
alter table if exists public.log_entries
  add column if not exists food_tag_labels jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'chk_log_entries_symptom_labels_array'
  ) then
    alter table public.log_entries
      add constraint chk_log_entries_symptom_labels_array
      check (jsonb_typeof(symptom_labels) = 'array');
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'chk_log_entries_trigger_labels_array'
  ) then
    alter table public.log_entries
      add constraint chk_log_entries_trigger_labels_array
      check (jsonb_typeof(trigger_labels) = 'array');
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'chk_log_entries_remedy_labels_array'
  ) then
    alter table public.log_entries
      add constraint chk_log_entries_remedy_labels_array
      check (jsonb_typeof(remedy_labels) = 'array');
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'chk_log_entries_food_tag_labels_array'
  ) then
    alter table public.log_entries
      add constraint chk_log_entries_food_tag_labels_array
      check (jsonb_typeof(food_tag_labels) = 'array');
  end if;
end $$;

-- Mirror legacy JSONB columns into *_labels (additive; keeps symptoms/triggers as SoT for older clients)
update public.log_entries
set
  symptom_labels  = coalesce(symptoms, '[]'::jsonb),
  trigger_labels  = coalesce(triggers, '[]'::jsonb),
  remedy_labels   = coalesce(remedies, '[]'::jsonb),
  food_tag_labels = coalesce(food_tags, '[]'::jsonb);

-- -----------------------------------------------------------------------------
-- 3) profile_conditions & medications — v3 columns
-- -----------------------------------------------------------------------------
alter table if exists public.profile_conditions
  add column if not exists condition_code text;
alter table if exists public.profile_conditions
  add column if not exists condition_label text;
alter table if exists public.profile_conditions
  add column if not exists is_active boolean not null default true;
alter table if exists public.profile_conditions
  add column if not exists severity integer
    check (severity is null or (severity between 1 and 10));

update public.profile_conditions
set condition_label = condition_name
where condition_label is null and condition_name is not null;

update public.profile_conditions
set condition_code = lower(regexp_replace(trim(condition_name), '\s+', '_', 'g'))
where condition_code is null and condition_name is not null;

alter table if exists public.medications
  add column if not exists medication_class text;
alter table if exists public.medications
  add column if not exists dosage_text text;
alter table if exists public.medications
  add column if not exists frequency_text text;
alter table if exists public.medications
  add column if not exists started_at date;
alter table if exists public.medications
  add column if not exists ended_at date;
alter table if exists public.medications
  add column if not exists is_active boolean not null default true;

update public.medications
set dosage_text = dosage
where dosage_text is null and dosage is not null;

update public.medications
set frequency_text = frequency
where frequency_text is null and frequency is not null;

-- -----------------------------------------------------------------------------
-- 4) Global food_tags + meal_event_food_tags (coexists with meal_tags)
-- -----------------------------------------------------------------------------
create table if not exists public.food_tags (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  label text not null,
  category text,
  created_at timestamptz not null default now()
);

insert into public.food_tags (slug, label, category) values
  ('spicy', 'Spicy', 'cooking'),
  ('acidic', 'Acidic', 'cooking'),
  ('fried', 'Fried', 'cooking'),
  ('dairy', 'Dairy', 'ingredient'),
  ('carbonated', 'Carbonated', 'drink'),
  ('caffeine', 'Caffeine', 'drink'),
  ('alcohol', 'Alcohol', 'drink'),
  ('high-fat', 'High fat', 'cooking')
on conflict (slug) do nothing;

create table if not exists public.meal_event_food_tags (
  id uuid primary key default gen_random_uuid(),
  meal_event_id uuid not null references public.meal_events (id) on delete cascade,
  food_tag_id uuid not null references public.food_tags (id) on delete cascade,
  unique (meal_event_id, food_tag_id)
);

create index if not exists idx_meal_event_food_tags_meal
  on public.meal_event_food_tags (meal_event_id);

-- -----------------------------------------------------------------------------
-- 5) Feature & intelligence tables
-- -----------------------------------------------------------------------------
create table if not exists public.daily_feature_rollups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  feature_date date not null,

  log_count integer not null default 0,
  avg_pain numeric,
  max_pain integer,
  avg_stress numeric,
  max_stress integer,

  symptom_count integer not null default 0,
  trigger_count integer not null default 0,
  remedy_count integer not null default 0,
  meal_count integer not null default 0,

  nausea_count integer not null default 0,
  bloating_count integer not null default 0,
  reflux_count integer not null default 0,
  cramp_count integer not null default 0,

  spicy_exposure_count integer not null default 0,
  acidic_exposure_count integer not null default 0,
  dairy_exposure_count integer not null default 0,
  caffeine_exposure_count integer not null default 0,
  fried_exposure_count integer not null default 0,

  sleep_quality_avg numeric,
  sleep_hours_avg numeric,
  exercise_level_avg numeric,

  flare_flag boolean not null default false,
  flare_score numeric,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (user_id, feature_date)
);

create table if not exists public.rolling_feature_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  snapshot_date date not null,
  window_days integer not null check (window_days in (7, 14, 30, 60)),

  avg_pain numeric,
  avg_stress numeric,
  flare_days integer,
  symptom_days integer,
  meal_trigger_days integer,

  spicy_correlation_score numeric,
  dairy_correlation_score numeric,
  caffeine_correlation_score numeric,
  fried_correlation_score numeric,

  sleep_vs_pain_score numeric,
  stress_vs_pain_score numeric,
  remedy_effectiveness_score numeric,

  created_at timestamptz not null default now(),
  unique (user_id, snapshot_date, window_days)
);

create table if not exists public.model_features (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  feature_timestamp timestamptz not null default now(),
  feature_set_version text not null,

  features jsonb not null,
  target jsonb,
  source_window_days integer,

  created_at timestamptz not null default now()
);

create index if not exists idx_model_features_user_created
  on public.model_features (user_id, created_at desc);

create table if not exists public.prediction_outputs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  predicted_at timestamptz not null default now(),
  prediction_type text not null,
  prediction_window_hours integer,
  score numeric not null,
  label text,
  explanation jsonb default '{}'::jsonb,
  model_version text not null,
  expires_at timestamptz
);

create index if not exists idx_prediction_outputs_user
  on public.prediction_outputs (user_id, predicted_at desc);

-- Row-per-recommendation (v3); legacy recommendation_cache.payload unchanged
create table if not exists public.recommendation_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  generated_at timestamptz not null default now(),

  recommendation_type text not null,
  priority integer not null default 1,
  status text not null default 'active',

  title text not null,
  summary text not null,
  rationale jsonb not null default '[]'::jsonb,
  evidence jsonb not null default '{}'::jsonb,
  confidence numeric,
  expires_at timestamptz,

  model_version text not null default 'rules-v1',
  source text not null default 'analytics_engine'
);

create index if not exists idx_recommendation_items_user_gen
  on public.recommendation_items (user_id, generated_at desc);

-- -----------------------------------------------------------------------------
-- 6) RLS
-- -----------------------------------------------------------------------------
alter table public.food_tags enable row level security;
-- food_tags: global read for authenticated
drop policy if exists "food_tags_select_authenticated" on public.food_tags;
create policy "food_tags_select_authenticated" on public.food_tags
  for select to authenticated using (true);

alter table public.meal_event_food_tags enable row level security;
drop policy if exists "meal_event_food_tags_all" on public.meal_event_food_tags;
create policy "meal_event_food_tags_select" on public.meal_event_food_tags
  for select using (
    exists (
      select 1 from public.meal_events m
      where m.id = meal_event_id and m.user_id = auth.uid()
    )
  );
create policy "meal_event_food_tags_insert" on public.meal_event_food_tags
  for insert with check (
    exists (
      select 1 from public.meal_events m
      where m.id = meal_event_id and m.user_id = auth.uid()
    )
  );
create policy "meal_event_food_tags_delete" on public.meal_event_food_tags
  for delete using (
    exists (
      select 1 from public.meal_events m
      where m.id = meal_event_id and m.user_id = auth.uid()
    )
  );

alter table public.daily_feature_rollups enable row level security;
drop policy if exists "daily_feature_rollups_select" on public.daily_feature_rollups;
drop policy if exists "daily_feature_rollups_insert" on public.daily_feature_rollups;
drop policy if exists "daily_feature_rollups_update" on public.daily_feature_rollups;
drop policy if exists "daily_feature_rollups_delete" on public.daily_feature_rollups;
create policy "daily_feature_rollups_select" on public.daily_feature_rollups
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "daily_feature_rollups_insert" on public.daily_feature_rollups
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "daily_feature_rollups_update" on public.daily_feature_rollups
  for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "daily_feature_rollups_delete" on public.daily_feature_rollups
  for delete using (auth.uid() is not null and auth.uid() = user_id);

alter table public.rolling_feature_snapshots enable row level security;
drop policy if exists "rolling_feature_snapshots_select" on public.rolling_feature_snapshots;
drop policy if exists "rolling_feature_snapshots_insert" on public.rolling_feature_snapshots;
drop policy if exists "rolling_feature_snapshots_update" on public.rolling_feature_snapshots;
drop policy if exists "rolling_feature_snapshots_delete" on public.rolling_feature_snapshots;
create policy "rolling_feature_snapshots_select" on public.rolling_feature_snapshots
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "rolling_feature_snapshots_insert" on public.rolling_feature_snapshots
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "rolling_feature_snapshots_update" on public.rolling_feature_snapshots
  for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "rolling_feature_snapshots_delete" on public.rolling_feature_snapshots
  for delete using (auth.uid() is not null and auth.uid() = user_id);

alter table public.model_features enable row level security;
drop policy if exists "model_features_select" on public.model_features;
drop policy if exists "model_features_insert" on public.model_features;
drop policy if exists "model_features_delete" on public.model_features;
create policy "model_features_select" on public.model_features
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "model_features_insert" on public.model_features
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "model_features_delete" on public.model_features
  for delete using (auth.uid() is not null and auth.uid() = user_id);

alter table public.prediction_outputs enable row level security;
drop policy if exists "prediction_outputs_select" on public.prediction_outputs;
drop policy if exists "prediction_outputs_insert" on public.prediction_outputs;
drop policy if exists "prediction_outputs_delete" on public.prediction_outputs;
create policy "prediction_outputs_select" on public.prediction_outputs
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "prediction_outputs_insert" on public.prediction_outputs
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "prediction_outputs_delete" on public.prediction_outputs
  for delete using (auth.uid() is not null and auth.uid() = user_id);

alter table public.recommendation_items enable row level security;
drop policy if exists "recommendation_items_select" on public.recommendation_items;
drop policy if exists "recommendation_items_insert" on public.recommendation_items;
drop policy if exists "recommendation_items_update" on public.recommendation_items;
drop policy if exists "recommendation_items_delete" on public.recommendation_items;
create policy "recommendation_items_select" on public.recommendation_items
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "recommendation_items_insert" on public.recommendation_items
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "recommendation_items_update" on public.recommendation_items
  for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "recommendation_items_delete" on public.recommendation_items
  for delete using (auth.uid() is not null and auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 7) Helper: extract normalized food tag string from jsonb array element
-- -----------------------------------------------------------------------------
create or replace function public._food_tag_elem_text(elem jsonb)
returns text
language sql
immutable
as $$
  select case
    when jsonb_typeof(elem) = 'string' then lower(trim(elem #>> '{}'))
    else lower(trim(coalesce(elem ->> 'tag', elem ->> 'name', '')))
  end;
$$;

-- -----------------------------------------------------------------------------
-- 8) refresh_daily_feature_rollups
-- -----------------------------------------------------------------------------
create or replace function public.refresh_daily_feature_rollups(
  p_user_id uuid,
  p_start_date date,
  p_end_date date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  d date;
begin
  if p_user_id is null or p_start_date is null or p_end_date is null or p_start_date > p_end_date then
    raise exception 'refresh_daily_feature_rollups: invalid arguments';
  end if;

  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized: caller cannot act on this user';
  end if;

  for d in
    select generate_series(p_start_date, p_end_date, '1 day'::interval)::date
  loop
    insert into public.daily_feature_rollups (
      user_id, feature_date,
      log_count, avg_pain, max_pain, avg_stress, max_stress,
      symptom_count, trigger_count, remedy_count, meal_count,
      nausea_count, bloating_count, reflux_count, cramp_count,
      spicy_exposure_count, acidic_exposure_count, dairy_exposure_count,
      caffeine_exposure_count, fried_exposure_count,
      sleep_quality_avg, sleep_hours_avg, exercise_level_avg,
      flare_flag, flare_score,
      updated_at
    )
    select
      p_user_id,
      d,
      coalesce(le.cnt, 0),
      le.avg_pain,
      le.max_pain,
      le.avg_stress,
      le.max_stress,
      coalesce(sc.symptom_count, 0),
      coalesce(tc.trigger_count, 0),
      coalesce(rc.remedy_count, 0),
      coalesce(mc.meal_count, 0),
      coalesce(sc.nausea_count, 0),
      coalesce(sc.bloating_count, 0),
      coalesce(sc.reflux_count, 0),
      coalesce(sc.cramp_count, 0),
      coalesce(fe.spicy_n, 0),
      coalesce(fe.acidic_n, 0),
      coalesce(fe.dairy_n, 0),
      coalesce(fe.caffeine_n, 0),
      coalesce(fe.fried_n, 0),
      le.sleep_quality_avg,
      le.sleep_hours_avg,
      le.exercise_level_avg,
      case
        when coalesce(le.max_pain, 0) >= 7 then true
        when coalesce(le.avg_pain, 0) >= 6 and coalesce(sc.symptom_count, 0) >= 3 then true
        else false
      end,
      case
        when coalesce(le.max_pain, 0) >= 7 then (coalesce(le.max_pain, 0)::numeric / 10.0)
        else coalesce(le.avg_pain, 0)::numeric / 10.0 + coalesce(sc.symptom_count, 0)::numeric * 0.05
      end,
      now()
    from (
      select
        count(*)::int as cnt,
        avg(pain_score)::numeric as avg_pain,
        max(pain_score)::int as max_pain,
        avg(stress_score)::numeric as avg_stress,
        max(stress_score)::int as max_stress,
        avg(sleep_quality)::numeric as sleep_quality_avg,
        avg(sleep_hours)::numeric as sleep_hours_avg,
        avg(exercise_level)::numeric as exercise_level_avg
      from public.log_entries
      where user_id = p_user_id and entry_date = d
    ) le
    left join lateral (
      select
        count(*)::int as symptom_count,
        count(*) filter (where lower(symptom_name) like '%nausea%')::int as nausea_count,
        count(*) filter (where lower(symptom_name) like '%bloat%')::int as bloating_count,
        count(*) filter (where lower(symptom_name) like '%reflux%' or lower(symptom_name) like '%heartburn%')::int as reflux_count,
        count(*) filter (where lower(symptom_name) like '%cramp%')::int as cramp_count
      from public.symptom_events se
      join public.log_entries le2 on le2.id = se.source_entry_id and le2.user_id = se.user_id
      where se.user_id = p_user_id and le2.entry_date = d
    ) sc on true
    left join lateral (
      select count(*)::int as trigger_count
      from public.trigger_events te
      join public.log_entries le2 on le2.id = te.source_entry_id and le2.user_id = te.user_id
      where te.user_id = p_user_id and le2.entry_date = d
    ) tc on true
    left join lateral (
      select count(*)::int as remedy_count
      from public.remedy_events re
      join public.log_entries le2 on le2.id = re.source_entry_id and le2.user_id = re.user_id
      where re.user_id = p_user_id and le2.entry_date = d
    ) rc on true
    left join lateral (
      select count(*)::int as meal_count
      from public.meal_events me
      join public.log_entries le2 on le2.id = me.source_entry_id and le2.user_id = me.user_id
      where me.user_id = p_user_id and le2.entry_date = d
    ) mc on true
    left join lateral (
      select
        count(*) filter (where public._food_tag_elem_text(elem) like '%spicy%')::int as spicy_n,
        count(*) filter (where public._food_tag_elem_text(elem) like '%acid%')::int as acidic_n,
        count(*) filter (where public._food_tag_elem_text(elem) like '%dairy%' or public._food_tag_elem_text(elem) like '%milk%')::int as dairy_n,
        count(*) filter (where public._food_tag_elem_text(elem) like '%caffe%')::int as caffeine_n,
        count(*) filter (where public._food_tag_elem_text(elem) like '%fried%' or public._food_tag_elem_text(elem) like '%fry%')::int as fried_n
      from public.log_entries le3,
      lateral jsonb_array_elements(coalesce(le3.food_tags, '[]'::jsonb)) as elem
      where le3.user_id = p_user_id and le3.entry_date = d
    ) fe on true
    on conflict (user_id, feature_date) do update set
      log_count = excluded.log_count,
      avg_pain = excluded.avg_pain,
      max_pain = excluded.max_pain,
      avg_stress = excluded.avg_stress,
      max_stress = excluded.max_stress,
      symptom_count = excluded.symptom_count,
      trigger_count = excluded.trigger_count,
      remedy_count = excluded.remedy_count,
      meal_count = excluded.meal_count,
      nausea_count = excluded.nausea_count,
      bloating_count = excluded.bloating_count,
      reflux_count = excluded.reflux_count,
      cramp_count = excluded.cramp_count,
      spicy_exposure_count = excluded.spicy_exposure_count,
      acidic_exposure_count = excluded.acidic_exposure_count,
      dairy_exposure_count = excluded.dairy_exposure_count,
      caffeine_exposure_count = excluded.caffeine_exposure_count,
      fried_exposure_count = excluded.fried_exposure_count,
      sleep_quality_avg = excluded.sleep_quality_avg,
      sleep_hours_avg = excluded.sleep_hours_avg,
      exercise_level_avg = excluded.exercise_level_avg,
      flare_flag = excluded.flare_flag,
      flare_score = excluded.flare_score,
      updated_at = now();
  end loop;
end;
$$;

comment on function public.refresh_daily_feature_rollups(uuid, date, date) is
  'Recomputes daily_feature_rollups for [p_start_date, p_end_date] from log_entries and events.';

-- -----------------------------------------------------------------------------
-- 9) refresh_rolling_feature_snapshots
-- -----------------------------------------------------------------------------
create or replace function public.refresh_rolling_feature_snapshots(
  p_user_id uuid,
  p_snapshot_date date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  w int;
  v_start date;
  v_flare_days int;
  v_symptom_days int;
  v_meal_trigger_days int;
  v_avg_pain numeric;
  v_avg_stress numeric;
  v_spicy_corr numeric;
  v_dairy_corr numeric;
  v_caffeine_corr numeric;
  v_fried_corr numeric;
  v_sleep_pain numeric;
  v_stress_pain numeric;
  v_remedy_eff numeric;
begin
  if p_user_id is null or p_snapshot_date is null then
    raise exception 'refresh_rolling_feature_snapshots: invalid arguments';
  end if;

  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized: caller cannot act on this user';
  end if;

  foreach w in array array[7, 14, 30, 60]
  loop
    v_start := p_snapshot_date - (w - 1);

    select
      count(*) filter (where flare_flag)::int,
      count(*) filter (where symptom_count > 0)::int,
      count(*) filter (where meal_count > 0 and flare_flag)::int,
      avg(avg_pain),
      avg(avg_stress)
    into v_flare_days, v_symptom_days, v_meal_trigger_days, v_avg_pain, v_avg_stress
    from public.daily_feature_rollups
    where user_id = p_user_id
      and feature_date between v_start and p_snapshot_date;

    select
      case when avg_spicy_flare is not null and avg_spicy_ok is not null
        then least(1.0, greatest(-1.0, (avg_spicy_flare - avg_spicy_ok) / 10.0))
        else null end,
      case when avg_dai_flare is not null and avg_dai_ok is not null
        then least(1.0, greatest(-1.0, (avg_dai_flare - avg_dai_ok) / 10.0))
        else null end,
      case when avg_caf_flare is not null and avg_caf_ok is not null
        then least(1.0, greatest(-1.0, (avg_caf_flare - avg_caf_ok) / 10.0))
        else null end,
      case when avg_fri_flare is not null and avg_fri_ok is not null
        then least(1.0, greatest(-1.0, (avg_fri_flare - avg_fri_ok) / 10.0))
        else null end
    into v_spicy_corr, v_dairy_corr, v_caffeine_corr, v_fried_corr
    from (
      select
        avg(avg_pain) filter (where spicy_exposure_count > 0 and flare_flag) as avg_spicy_flare,
        avg(avg_pain) filter (where spicy_exposure_count = 0 and not flare_flag) as avg_spicy_ok,
        avg(avg_pain) filter (where dairy_exposure_count > 0 and flare_flag) as avg_dai_flare,
        avg(avg_pain) filter (where dairy_exposure_count = 0 and not flare_flag) as avg_dai_ok,
        avg(avg_pain) filter (where caffeine_exposure_count > 0 and flare_flag) as avg_caf_flare,
        avg(avg_pain) filter (where caffeine_exposure_count = 0 and not flare_flag) as avg_caf_ok,
        avg(avg_pain) filter (where fried_exposure_count > 0 and flare_flag) as avg_fri_flare,
        avg(avg_pain) filter (where fried_exposure_count = 0 and not flare_flag) as avg_fri_ok
      from public.daily_feature_rollups
      where user_id = p_user_id
        and feature_date between v_start and p_snapshot_date
    ) x;

    select
      case when corr_sleep_pain is not null then -corr_sleep_pain / 10.0 else null end,
      case when corr_stress_pain is not null then corr_stress_pain / 10.0 else null end
    into v_sleep_pain, v_stress_pain
    from (
      select
        corr(sleep_quality_avg, avg_pain) as corr_sleep_pain,
        corr(avg_stress, avg_pain) as corr_stress_pain
      from public.daily_feature_rollups
      where user_id = p_user_id
        and feature_date between v_start and p_snapshot_date
    ) c;

    select avg(coalesce(re.effectiveness_score, re.helpfulness, 0))::numeric
    into v_remedy_eff
    from public.remedy_events re
    where re.user_id = p_user_id
      and re.occurred_at >= (v_start::timestamptz)
      and re.occurred_at < (p_snapshot_date + 1)::timestamptz;

    if v_remedy_eff is null then
      v_remedy_eff := 0.5;
    end if;

    insert into public.rolling_feature_snapshots (
      user_id, snapshot_date, window_days,
      avg_pain, avg_stress, flare_days, symptom_days, meal_trigger_days,
      spicy_correlation_score, dairy_correlation_score, caffeine_correlation_score, fried_correlation_score,
      sleep_vs_pain_score, stress_vs_pain_score, remedy_effectiveness_score
    )
    values (
      p_user_id, p_snapshot_date, w,
      v_avg_pain, v_avg_stress, v_flare_days, v_symptom_days, v_meal_trigger_days,
      v_spicy_corr, v_dairy_corr, v_caffeine_corr, v_fried_corr,
      v_sleep_pain, v_stress_pain, v_remedy_eff
    )
    on conflict (user_id, snapshot_date, window_days) do update set
      avg_pain = excluded.avg_pain,
      avg_stress = excluded.avg_stress,
      flare_days = excluded.flare_days,
      symptom_days = excluded.symptom_days,
      meal_trigger_days = excluded.meal_trigger_days,
      spicy_correlation_score = excluded.spicy_correlation_score,
      dairy_correlation_score = excluded.dairy_correlation_score,
      caffeine_correlation_score = excluded.caffeine_correlation_score,
      fried_correlation_score = excluded.fried_correlation_score,
      sleep_vs_pain_score = excluded.sleep_vs_pain_score,
      stress_vs_pain_score = excluded.stress_vs_pain_score,
      remedy_effectiveness_score = excluded.remedy_effectiveness_score;
  end loop;
end;
$$;

comment on function public.refresh_rolling_feature_snapshots(uuid, date) is
  'Computes rolling_feature_snapshots for snapshot_date across windows 7/14/30/60.';

-- -----------------------------------------------------------------------------
-- 10) refresh_recommendation_items_v3 — rule-based rows
-- -----------------------------------------------------------------------------
create or replace function public.refresh_recommendation_items_v3(
  p_user_id uuid,
  p_snapshot_date date default current_date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_spicy_flare_days int;
  v_avg_pain_7d numeric;
  v_avg_stress_7d numeric;
  v_flare_7d int;
  v_missing_meal_pct numeric;
  v_spicy_corr_30 numeric;
  v_from_30 date := p_snapshot_date - 30;
begin
  if p_user_id is null then
    raise exception 'refresh_recommendation_items_v3: p_user_id required';
  end if;

  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  delete from public.recommendation_items where user_id = p_user_id;

  select count(*)::int into v_spicy_flare_days
  from public.daily_feature_rollups
  where user_id = p_user_id
    and feature_date >= v_from_30
    and feature_date <= p_snapshot_date
    and flare_flag
    and spicy_exposure_count > 0;

  select avg_pain, avg_stress, flare_days
  into v_avg_pain_7d, v_avg_stress_7d, v_flare_7d
  from public.rolling_feature_snapshots
  where user_id = p_user_id
    and snapshot_date = p_snapshot_date
    and window_days = 7;

  select spicy_correlation_score into v_spicy_corr_30
  from public.rolling_feature_snapshots
  where user_id = p_user_id
    and snapshot_date = p_snapshot_date
    and window_days = 30;

  select
    case when count(*) = 0 then 0
      else (count(*) filter (where meal_name is null or trim(meal_name) = '')::numeric / count(*)::numeric)
    end
  into v_missing_meal_pct
  from public.log_entries
  where user_id = p_user_id
    and entry_at >= v_from_30::timestamptz
    and entry_at < (p_snapshot_date + 1)::timestamptz;

  if v_spicy_flare_days >= 3 then
    insert into public.recommendation_items (
      user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence
    ) values (
      p_user_id, 'trigger_warning', 1,
      'Spicy foods may be aggravating symptoms',
      'Spicy-tagged meals appeared on several recent high-pain or flare days.',
      '["spicy exposure on flare days in the last 30 days"]'::jsonb,
      jsonb_build_object('spicy_flare_days', v_spicy_flare_days),
      0.72
    );
  end if;

  if v_avg_stress_7d is not null and v_avg_stress_7d > 6 and v_flare_7d is not null and v_flare_7d >= 2 then
    insert into public.recommendation_items (
      user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence
    ) values (
      p_user_id, 'flare_risk', 2,
      'Stress and symptom pattern',
      'Recent week shows elevated stress and multiple flare days.',
      '["avg stress 7d > 6", "multiple flare days in 7d window"]'::jsonb,
      jsonb_build_object('avg_stress_7d', v_avg_stress_7d, 'flare_days_7d', v_flare_7d),
      0.65
    );
  end if;

  if v_missing_meal_pct >= 0.5 then
    insert into public.recommendation_items (
      user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence
    ) values (
      p_user_id, 'behavioral_nudge', 3,
      'Add meal context',
      'Many recent logs are missing meal details; richer meal context improves insights.',
      '["high fraction of logs without meal_name"]'::jsonb,
      jsonb_build_object('missing_meal_fraction', round(v_missing_meal_pct::numeric, 2)),
      0.55
    );
  end if;

  if v_spicy_corr_30 is not null and v_spicy_corr_30 > 0.3 then
    insert into public.recommendation_items (
      user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence
    ) values (
      p_user_id, 'trend_summary', 4,
      'Spicy exposure vs pain (30d)',
      'Rolling window suggests higher pain on days with spicy exposure relative to other days.',
      '["30d rolling spicy correlation"]'::jsonb,
      jsonb_build_object('spicy_correlation_30d', v_spicy_corr_30),
      0.6
    );
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 11) build_model_features
-- -----------------------------------------------------------------------------
create or replace function public.build_model_features(
  p_user_id uuid,
  p_as_of_date date,
  p_window_days integer
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
  v_features jsonb;
  v_start date;
  v_roll_json jsonb;
begin
  if p_user_id is null or p_as_of_date is null or p_window_days is null then
    raise exception 'build_model_features: invalid arguments';
  end if;

  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  v_start := p_as_of_date - (p_window_days - 1);

  select row_to_json(r)::jsonb into v_roll_json
  from public.rolling_feature_snapshots r
  where r.user_id = p_user_id
    and r.snapshot_date = p_as_of_date
    and r.window_days = p_window_days;

  v_features := jsonb_build_object(
    'window_days', p_window_days,
    'as_of', p_as_of_date,
    'rolling_snapshot', coalesce(v_roll_json, '{}'::jsonb),
    'gerd_active', (select gerd_diagnosis from public.profiles where user_id = p_user_id),
    'flare_days_window',
      (select count(*) from public.daily_feature_rollups d
       where d.user_id = p_user_id and d.feature_date between v_start and p_as_of_date and d.flare_flag)
  );

  insert into public.model_features (user_id, feature_set_version, features, source_window_days)
  values (p_user_id, 'v3-rules-1', v_features, p_window_days)
  returning id into v_id;

  return v_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- 12) Patch refresh_user_analytics: call v3 rollups at end
-- -----------------------------------------------------------------------------
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
  if p_user_id is null or p_from is null or p_to is null or p_from > p_to then
    raise exception 'refresh_user_analytics: invalid arguments';
  end if;

  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized: caller (%) cannot act on user (%)', auth.uid(), p_user_id;
  end if;

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

  perform public.refresh_daily_feature_rollups(p_user_id, p_from, p_to);
  perform public.refresh_rolling_feature_snapshots(p_user_id, p_to);
end;
$$;

-- -----------------------------------------------------------------------------
-- 13) Patch refresh_user_recommendations: legacy payload + v3 items
-- -----------------------------------------------------------------------------
drop function if exists public.refresh_user_recommendations(uuid, text);

create or replace function public.refresh_user_recommendations(
  p_user_id     uuid,
  p_cache_version text default 'v1',
  p_snapshot_date date default (current_date)
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
  if p_user_id is null then
    raise exception 'refresh_user_recommendations: p_user_id required';
  end if;

  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized: caller (%) cannot act on user (%)', auth.uid(), p_user_id;
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

  perform public.refresh_recommendation_items_v3(p_user_id, p_snapshot_date);
end;
$$;

revoke all on function public.refresh_daily_feature_rollups(uuid, date, date) from public;
revoke all on function public.refresh_rolling_feature_snapshots(uuid, date) from public;
revoke all on function public.refresh_recommendation_items_v3(uuid, date) from public;
revoke all on function public.build_model_features(uuid, date, integer) from public;

grant execute on function public.refresh_daily_feature_rollups(uuid, date, date) to authenticated;
grant execute on function public.refresh_rolling_feature_snapshots(uuid, date) to authenticated;
grant execute on function public.refresh_recommendation_items_v3(uuid, date) to authenticated;
grant execute on function public.build_model_features(uuid, date, integer) to authenticated;

grant execute on function public.refresh_user_recommendations(uuid, text, date) to authenticated;

comment on function public.refresh_user_recommendations(uuid, text, date) is
  'Upserts legacy recommendation_cache payload and rebuilds recommendation_items (v3 rules).';
