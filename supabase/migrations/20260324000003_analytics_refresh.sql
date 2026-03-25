-- =============================================================================
-- Recommendation cache + refresh helpers (cron or on-demand; not per-row triggers)
-- =============================================================================

create table if not exists public.recommendation_cache (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  cache_version text not null default 'v1',
  generated_at timestamptz not null default now(),
  payload jsonb not null default '{}'::jsonb,
  unique (user_id, cache_version)
);

create index if not exists idx_recommendation_cache_user_version
  on public.recommendation_cache (user_id, cache_version);

alter table public.recommendation_cache enable row level security;

create policy "recommendation_cache_select" on public.recommendation_cache
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "recommendation_cache_insert" on public.recommendation_cache
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "recommendation_cache_update" on public.recommendation_cache
  for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "recommendation_cache_delete" on public.recommendation_cache
  for delete using (auth.uid() is not null and auth.uid() = user_id);

comment on table public.recommendation_cache is 'Cached recommendation payload per user; built by refresh_user_recommendations.';

-- -----------------------------------------------------------------------------
-- refresh_user_analytics: recompute aggregates for one user and date window
-- -----------------------------------------------------------------------------
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

  -- Weekly summaries for weeks overlapping the window
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

  -- Top triggers / remedies / symptoms as json for those weeks (simple frequency)
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

  -- Remedy scores (window-level)
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

  -- Trigger scores: avg pain when trigger present vs absent (same entries window)
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

  -- Food tags: avg pain when tag appears in log_entries.food_tags
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

  -- Time patterns: hour of day
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

  -- Day of week (0 = Sunday in extract(dow))
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

comment on function public.refresh_user_analytics(uuid, date, date) is
  'Recomputes analytics_* and weekly_summaries rows for one user and [p_from, p_to] inclusive.';

-- -----------------------------------------------------------------------------
-- refresh_user_recommendations: build JSON cache from aggregates + recent logs
-- -----------------------------------------------------------------------------
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

comment on function public.refresh_user_recommendations(uuid, text) is
  'Upserts recommendation_cache from weekly_summaries and latest time-pattern window.';

grant execute on function public.refresh_user_analytics(uuid, date, date) to authenticated;
grant execute on function public.refresh_user_recommendations(uuid, text) to authenticated;
