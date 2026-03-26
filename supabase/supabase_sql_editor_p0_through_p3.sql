-- =============================================================================
-- GastroGuard: paste this ENTIRE file into Supabase SQL Editor and run once.
-- Prerequisite: production schema v2 (gastroguard_production_schema_v2.sql) is
-- already applied on this project. Order: P0 -> P1 -> P2 -> P3 (concatenated).
-- =============================================================================

-- =============================================================================
-- P0 Security: v_user_timeline grants + refresh_* caller must match auth.uid()
-- Idempotent. Rollback: restore prior function bodies from git; re-grant anon if needed.
-- Risk: service_role batch jobs with null auth.uid() will fail until invoked with user JWT.
--
-- Verification:
--   SELECT grantee FROM information_schema.table_privileges
--     WHERE table_schema='public' AND table_name='v_user_timeline' AND grantee='anon';
--   (expect no SELECT for anon)
-- =============================================================================

revoke all on table public.v_user_timeline from anon;
grant select on table public.v_user_timeline to authenticated;
grant select on table public.v_user_timeline to service_role;

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

  -- weekly_summaries (single-pass CTE upsert)
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
end;
$$;

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
end;
$$;

revoke all on function public.refresh_user_analytics(uuid, date, date) from public;
revoke all on function public.refresh_user_recommendations(uuid, text) from public;
grant execute on function public.refresh_user_analytics(uuid, date, date) to authenticated;
grant execute on function public.refresh_user_recommendations(uuid, text) to authenticated;
-- =============================================================================
-- P1 Type integrity: normalize JSONB array columns, then named CHECK constraints.
-- Run order: UPDATE first (data migration), then constraints.
-- Rollback: ALTER TABLE ... DROP CONSTRAINT chk_* (listed in comments below).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- log_entries
-- -----------------------------------------------------------------------------
update public.log_entries
  set symptoms = '[]'::jsonb
  where symptoms is null or jsonb_typeof(symptoms) <> 'array';

update public.log_entries
  set triggers = '[]'::jsonb
  where triggers is null or jsonb_typeof(triggers) <> 'array';

update public.log_entries
  set remedies = '[]'::jsonb
  where remedies is null or jsonb_typeof(remedies) <> 'array';

update public.log_entries
  set food_tags = '[]'::jsonb
  where food_tags is null or jsonb_typeof(food_tags) <> 'array';

-- -----------------------------------------------------------------------------
-- profiles (array-shaped JSONB)
-- -----------------------------------------------------------------------------
update public.profiles
  set allergies = '[]'::jsonb
  where allergies is null or jsonb_typeof(allergies) <> 'array';

update public.profiles
  set dietary_restrictions = '[]'::jsonb
  where dietary_restrictions is null or jsonb_typeof(dietary_restrictions) <> 'array';

update public.profiles
  set triggers = '[]'::jsonb
  where triggers is null or jsonb_typeof(triggers) <> 'array';

update public.profiles
  set effective_remedies = '[]'::jsonb
  where effective_remedies is null or jsonb_typeof(effective_remedies) <> 'array';

update public.profiles
  set integrations = '[]'::jsonb
  where integrations is null or jsonb_typeof(integrations) <> 'array';

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'conditions'
  ) then
    execute $q$
      update public.profiles
        set conditions = '[]'::jsonb
        where conditions is null or jsonb_typeof(conditions) <> 'array'
    $q$;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'medications'
  ) then
    execute $q$
      update public.profiles
        set medications = '[]'::jsonb
        where medications is null or jsonb_typeof(medications) <> 'array'
    $q$;
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- weekly_summaries
-- -----------------------------------------------------------------------------
update public.weekly_summaries
  set top_triggers = '[]'::jsonb
  where top_triggers is null or jsonb_typeof(top_triggers) <> 'array';

update public.weekly_summaries
  set top_remedies = '[]'::jsonb
  where top_remedies is null or jsonb_typeof(top_remedies) <> 'array';

update public.weekly_summaries
  set top_symptoms = '[]'::jsonb
  where top_symptoms is null or jsonb_typeof(top_symptoms) <> 'array';

-- -----------------------------------------------------------------------------
-- Named CHECK constraints (idempotent by constraint name)
-- Rollback: ALTER TABLE ... DROP CONSTRAINT <name>;
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'log_entries' and c.conname = 'chk_log_entries_symptoms_jsonb_array'
  ) then
    alter table public.log_entries add constraint chk_log_entries_symptoms_jsonb_array
      check (jsonb_typeof(symptoms) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'log_entries' and c.conname = 'chk_log_entries_triggers_jsonb_array'
  ) then
    alter table public.log_entries add constraint chk_log_entries_triggers_jsonb_array
      check (jsonb_typeof(triggers) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'log_entries' and c.conname = 'chk_log_entries_remedies_jsonb_array'
  ) then
    alter table public.log_entries add constraint chk_log_entries_remedies_jsonb_array
      check (jsonb_typeof(remedies) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'log_entries' and c.conname = 'chk_log_entries_food_tags_jsonb_array'
  ) then
    alter table public.log_entries add constraint chk_log_entries_food_tags_jsonb_array
      check (jsonb_typeof(food_tags) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_allergies_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_allergies_jsonb_array
      check (jsonb_typeof(allergies) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_dietary_restrictions_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_dietary_restrictions_jsonb_array
      check (jsonb_typeof(dietary_restrictions) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_triggers_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_triggers_jsonb_array
      check (jsonb_typeof(triggers) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_effective_remedies_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_effective_remedies_jsonb_array
      check (jsonb_typeof(effective_remedies) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_integrations_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_integrations_jsonb_array
      check (jsonb_typeof(integrations) = 'array');
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'conditions'
  ) and not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_conditions_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_conditions_jsonb_array
      check (jsonb_typeof(conditions) = 'array');
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'medications'
  ) and not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_medications_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_medications_jsonb_array
      check (jsonb_typeof(medications) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'weekly_summaries' and c.conname = 'chk_weekly_summaries_top_triggers_jsonb_array'
  ) then
    alter table public.weekly_summaries add constraint chk_weekly_summaries_top_triggers_jsonb_array
      check (jsonb_typeof(top_triggers) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'weekly_summaries' and c.conname = 'chk_weekly_summaries_top_remedies_jsonb_array'
  ) then
    alter table public.weekly_summaries add constraint chk_weekly_summaries_top_remedies_jsonb_array
      check (jsonb_typeof(top_remedies) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'weekly_summaries' and c.conname = 'chk_weekly_summaries_top_symptoms_jsonb_array'
  ) then
    alter table public.weekly_summaries add constraint chk_weekly_summaries_top_symptoms_jsonb_array
      check (jsonb_typeof(top_symptoms) = 'array');
  end if;
end;
$$;
-- =============================================================================
-- P2 Source of truth: deprecate legacy JSONB on profiles (comments only) +
-- read-only compatibility view from profile_conditions / medications.
-- Does NOT drop columns.
-- =============================================================================

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'conditions'
  ) then
    execute $c$
      comment on column public.profiles.conditions is
        'DEPRECATED — SoT is profile_conditions. Do not write to this column from application code.'
    $c$;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'medications'
  ) then
    execute $c$
      comment on column public.profiles.medications is
        'DEPRECATED — SoT is medications. Do not write to this column from application code.'
    $c$;
  end if;
end;
$$;

create or replace view public.v_profile_health_legacy
  with (security_invoker = true)
as
select
  p.id,
  p.user_id,
  p.name,
  p.age,
  p.height,
  p.weight,
  p.gender,
  p.allergies,
  p.dietary_restrictions,
  p.triggers,
  p.effective_remedies,
  p.integrations,
  p.created_at,
  p.updated_at,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'condition_name', pc.condition_name,
          'notes', pc.notes,
          'diagnosed_at', pc.diagnosed_at
        )
        order by pc.created_at
      )
      from public.profile_conditions pc
      where pc.user_id = p.user_id
    ),
    '[]'::jsonb
  ) as conditions_from_normalized,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'medication_name', m.medication_name,
          'dosage', m.dosage,
          'frequency', m.frequency,
          'notes', m.notes
        )
        order by m.created_at
      )
      from public.medications m
      where m.user_id = p.user_id
    ),
    '[]'::jsonb
  ) as medications_from_normalized
from public.profiles p;

comment on view public.v_profile_health_legacy is
  'Read-only: profile scalars plus conditions/medications aggregated from normalized tables for legacy clients.';

grant select on public.v_profile_health_legacy to authenticated;
grant select on public.v_profile_health_legacy to service_role;
-- =============================================================================
-- P3 Schema refinement: profile defaults, column contracts, meal cache trigger.
--
-- Semantics (clinical):
-- NULL means "not yet provided" for optional profile fields.
-- Zero or empty string can be valid clinical values and must not be overloaded
-- as "unknown" in application logic — only NULL should mean unknown where used.
--
-- Rollback: DROP TRIGGER tr_rebuild_meal_food_tags; DROP FUNCTION rebuild_*;
--           restore profile column defaults from prior migration snapshot.
-- =============================================================================

-- Nullable profile fields: drop accidental defaults (safe if no default exists)
alter table public.profiles alter column age drop default;
alter table public.profiles alter column age set default null;

alter table public.profiles alter column height drop default;
alter table public.profiles alter column height set default null;

alter table public.profiles alter column weight drop default;
alter table public.profiles alter column weight set default null;

alter table public.profiles alter column gender drop default;
alter table public.profiles alter column gender set default null;

comment on column public.meal_events.food_tags is
  'Cache: denormalized snapshot for read/query. SoT for tag membership is meal_tags + meal_event_meal_tags; refresh via tr_rebuild_meal_food_tags or app sync.';

comment on column public.symptom_events.symptom_name is
  'Canonical symptom identifier (slug or registry key). Must match app symptom vocabulary.';

comment on column public.symptom_events.subtype is
  'Granularity qualifier within a symptom (e.g. sharp vs dull for pain). Free text; validate at app layer.';

comment on table public.symptom_tags is
  'Classification labels (e.g. GI, neurological). Array of distinct tag names per user; use with symptom_event_symptom_tags for filtering/grouping.';

comment on table public.symptom_event_symptom_tags is
  'Links symptom_events to symptom_tags for classification and filtering.';

-- Rebuild meal_events.food_tags from normalized junction + meal_tags (read-optimized cache)
create or replace function public.rebuild_meal_event_food_tags_cache()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_meal uuid;
begin
  v_meal := coalesce(new.meal_event_id, old.meal_event_id);
  if v_meal is null then
    return null;
  end if;

  update public.meal_events me
  set food_tags = coalesce(
    (
      select jsonb_agg(jsonb_build_object('tag', mt.name) order by mt.name)
      from public.meal_event_meal_tags memt
      join public.meal_tags mt on mt.id = memt.meal_tag_id
      where memt.meal_event_id = v_meal
    ),
    '[]'::jsonb
  )
  where me.id = v_meal;

  return null;
end;
$$;

drop trigger if exists tr_rebuild_meal_food_tags on public.meal_event_meal_tags;
create trigger tr_rebuild_meal_food_tags
  after insert or update or delete on public.meal_event_meal_tags
  for each row execute function public.rebuild_meal_event_food_tags_cache();

comment on function public.rebuild_meal_event_food_tags_cache() is
  'Keeps meal_events.food_tags in sync with meal_event_meal_tags for read-optimized queries.';

-- =============================================================================
-- Post-migration checklist (verification)
-- -----------------------------------------------------------------------------
-- Risk: Frontend still reads profiles.conditions / profiles.medications JSONB.
-- Verify P1: SELECT count(*) FROM log_entries WHERE jsonb_typeof(symptoms) <> 'array';
--        expect 0.
-- Verify P0: SELECT grantee FROM information_schema.role_table_grants
--        WHERE table_name='v_user_timeline' AND grantee='anon'; expect 0 rows.
-- Rollback P0: restore refresh_* bodies from backup; GRANT anon if emergency.
-- Rollback P1: ALTER TABLE ... DROP CONSTRAINT chk_* (names in p1 migration).
-- =============================================================================
