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
