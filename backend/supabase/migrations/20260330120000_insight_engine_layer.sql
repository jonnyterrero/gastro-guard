-- =============================================================================
-- GastroGuard insight engine — granular analytics, features, predictions,
-- recommendations, and orchestration. Additive; preserves existing tables.
-- All public entrypoints: SECURITY INVOKER + auth.uid() = p_user_id (Supabase-safe).
-- =============================================================================

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'analytics_trigger_scores'
      and column_name = 'correlation_hint'
  ) then
    alter table public.analytics_trigger_scores
      rename column correlation_hint to pain_delta;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 1) Granular analytics refresh (aligned with refresh_user_analytics slices)
-- -----------------------------------------------------------------------------

create or replace function public.refresh_trigger_scores(
  p_user_id uuid,
  p_start date,
  p_end date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_from_ts timestamptz := p_start::timestamptz;
  v_to_ts_excl timestamptz := (p_end + 1)::timestamptz;
begin
  if p_user_id is null or p_start is null or p_end is null or p_start > p_end then
    raise exception 'refresh_trigger_scores: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  insert into public.analytics_trigger_scores (
    user_id, trigger_name, window_start, window_end,
    sample_count, avg_pain_when_present, avg_pain_when_absent, pain_delta, updated_at
  )
  select
    p_user_id,
    s.trigger_name,
    p_start,
    p_end,
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
  ) w
  on conflict (user_id, trigger_name, window_start, window_end) do update set
    sample_count = excluded.sample_count,
    avg_pain_when_present = excluded.avg_pain_when_present,
    avg_pain_when_absent = excluded.avg_pain_when_absent,
    pain_delta = excluded.pain_delta,
    updated_at = now();
end;
$$;

create or replace function public.refresh_remedy_scores(
  p_user_id uuid,
  p_start date,
  p_end date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_from_ts timestamptz := p_start::timestamptz;
  v_to_ts_excl timestamptz := (p_end + 1)::timestamptz;
begin
  if p_user_id is null or p_start is null or p_end is null or p_start > p_end then
    raise exception 'refresh_remedy_scores: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  insert into public.analytics_remedy_scores (
    user_id, remedy_name, window_start, window_end,
    avg_effectiveness, usage_count, updated_at
  )
  select
    p_user_id,
    re.remedy_name,
    p_start,
    p_end,
    avg(coalesce(re.effectiveness_score, re.helpfulness))::numeric,
    count(*)::int,
    now()
  from public.remedy_events re
  where re.user_id = p_user_id
    and re.occurred_at >= v_from_ts
    and re.occurred_at < v_to_ts_excl
  group by re.remedy_name
  on conflict (user_id, remedy_name, window_start, window_end) do update set
    avg_effectiveness = excluded.avg_effectiveness,
    usage_count = excluded.usage_count,
    updated_at = now();
end;
$$;

create or replace function public.refresh_food_scores(
  p_user_id uuid,
  p_start date,
  p_end date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_from_ts timestamptz := p_start::timestamptz;
  v_to_ts_excl timestamptz := (p_end + 1)::timestamptz;
begin
  if p_user_id is null or p_start is null or p_end is null or p_start > p_end then
    raise exception 'refresh_food_scores: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  insert into public.analytics_food_scores (
    user_id, food_tag, window_start, window_end,
    co_occurrence_pain_avg, entry_count, updated_at
  )
  select
    p_user_id,
    t.tag_name,
    p_start,
    p_end,
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
  where le.user_id = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at < v_to_ts_excl
    and t.tag_name is not null
    and t.tag_name <> ''
  group by t.tag_name
  on conflict (user_id, food_tag, window_start, window_end) do update set
    co_occurrence_pain_avg = excluded.co_occurrence_pain_avg,
    entry_count = excluded.entry_count,
    updated_at = now();
end;
$$;

create or replace function public.refresh_time_patterns(
  p_user_id uuid,
  p_start date,
  p_end date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_from_ts timestamptz := p_start::timestamptz;
  v_to_ts_excl timestamptz := (p_end + 1)::timestamptz;
begin
  if p_user_id is null or p_start is null or p_end is null or p_start > p_end then
    raise exception 'refresh_time_patterns: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  insert into public.analytics_time_patterns (
    user_id, bucket_type, bucket_value, window_start, window_end,
    avg_pain, entry_count, updated_at
  )
  select
    p_user_id,
    'hour_of_day',
    extract(hour from le.entry_at at time zone 'utc')::smallint,
    p_start,
    p_end,
    avg(le.pain_score),
    count(*)::int,
    now()
  from public.log_entries le
  where le.user_id = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at < v_to_ts_excl
  group by extract(hour from le.entry_at at time zone 'utc')::smallint
  on conflict (user_id, bucket_type, bucket_value, window_start, window_end) do update set
    avg_pain = excluded.avg_pain,
    entry_count = excluded.entry_count,
    updated_at = now();

  insert into public.analytics_time_patterns (
    user_id, bucket_type, bucket_value, window_start, window_end,
    avg_pain, entry_count, updated_at
  )
  select
    p_user_id,
    'dow',
    extract(dow from le.entry_at at time zone 'utc')::smallint,
    p_start,
    p_end,
    avg(le.pain_score),
    count(*)::int,
    now()
  from public.log_entries le
  where le.user_id = p_user_id
    and le.entry_at >= v_from_ts
    and le.entry_at < v_to_ts_excl
  group by extract(dow from le.entry_at at time zone 'utc')::smallint
  on conflict (user_id, bucket_type, bucket_value, window_start, window_end) do update set
    avg_pain = excluded.avg_pain,
    entry_count = excluded.entry_count,
    updated_at = now();
end;
$$;

-- -----------------------------------------------------------------------------
-- 2) Single-day / single-window feature refresh
-- -----------------------------------------------------------------------------

create or replace function public.refresh_daily_feature_rollup(
  p_user_id uuid,
  p_feature_date date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_user_id is null or p_feature_date is null then
    raise exception 'refresh_daily_feature_rollup: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;
  perform public.refresh_daily_feature_rollups(p_user_id, p_feature_date, p_feature_date);
end;
$$;

create or replace function public.refresh_rolling_feature_snapshot(
  p_user_id uuid,
  p_snapshot_date date,
  p_window_days integer
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  w int := p_window_days;
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
  if p_user_id is null or p_snapshot_date is null or p_window_days is null then
    raise exception 'refresh_rolling_feature_snapshot: invalid arguments';
  end if;
  if w not in (7, 14, 30, 60) then
    raise exception 'refresh_rolling_feature_snapshot: p_window_days must be 7, 14, 30, or 60';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

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
    and re.occurred_at >= v_start::timestamptz
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
end;
$$;

-- -----------------------------------------------------------------------------
-- 3) ML-ready model_features row with simple targets
-- -----------------------------------------------------------------------------

create or replace function public.refresh_insight_model_features(
  p_user_id uuid,
  p_as_of_date date,
  p_window_start date,
  p_window_end date,
  p_window_days integer default 14
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
  v_start date;
  v_roll jsonb;
  v_daily jsonb;
  v_next_flare boolean;
  v_next_pain numeric;
  v_target jsonb;
  v_features jsonb;
  v_top_td numeric;
  v_top_food numeric;
begin
  if p_user_id is null or p_as_of_date is null or p_window_start is null or p_window_end is null then
    raise exception 'refresh_insight_model_features: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  v_start := p_as_of_date - (coalesce(p_window_days, 14) - 1);

  select row_to_json(r)::jsonb into v_roll
  from public.rolling_feature_snapshots r
  where r.user_id = p_user_id
    and r.snapshot_date = p_as_of_date
    and r.window_days = 7
  limit 1;

  select row_to_json(d)::jsonb into v_daily
  from public.daily_feature_rollups d
  where d.user_id = p_user_id
    and d.feature_date = p_as_of_date
  limit 1;

  select d.flare_flag, d.avg_pain
  into v_next_flare, v_next_pain
  from public.daily_feature_rollups d
  where d.user_id = p_user_id
    and d.feature_date = p_as_of_date + 1;

  select max(ats.pain_delta) into v_top_td
  from public.analytics_trigger_scores ats
  where ats.user_id = p_user_id
    and ats.window_start = p_window_start
    and ats.window_end = p_window_end;

  select max(afs.co_occurrence_pain_avg) into v_top_food
  from public.analytics_food_scores afs
  where afs.user_id = p_user_id
    and afs.window_start = p_window_start
    and afs.window_end = p_window_end;

  v_target := jsonb_build_object(
    'label_date', p_as_of_date + 1,
    'flare_next_day', coalesce(v_next_flare, false),
    'avg_pain_next_day', v_next_pain,
    'pain_risk_next_day', case
      when v_next_pain is null then null
      else least(1.0, greatest(0.0, v_next_pain / 10.0))
    end
  );

  v_features := jsonb_build_object(
    'as_of', p_as_of_date,
    'window_days', coalesce(p_window_days, 14),
    'rolling_7d', coalesce(v_roll, '{}'::jsonb),
    'daily_as_of', coalesce(v_daily, '{}'::jsonb),
    'flare_days_in_window',
      (select count(*) from public.daily_feature_rollups d2
       where d2.user_id = p_user_id
         and d2.feature_date between v_start and p_as_of_date
         and d2.flare_flag),
    'top_trigger_pain_delta', v_top_td,
    'top_food_pain_avg', v_top_food
  );

  insert into public.model_features (
    user_id, feature_set_version, features, target, source_window_days
  )
  values (
    p_user_id,
    'insight-engine-v1',
    v_features,
    v_target,
    coalesce(p_window_days, 14)
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4) Rule-based predictions
-- -----------------------------------------------------------------------------

create or replace function public.refresh_insight_predictions(
  p_user_id uuid,
  p_as_of_date date,
  p_window_start date,
  p_window_end date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_flare_score numeric;
  v_reflux_score numeric;
  v_food_score numeric;
  v_flare_days int;
  v_stress_vs_pain numeric;
  v_avg_pain_7 numeric;
  v_trigger_count int;
  v_avg_pain_d numeric;
  v_reflux_count int;
  v_symptom_count int;
  v_top_food_tag text;
  v_top_food_pain numeric;
  v_max_hour numeric;
begin
  if p_user_id is null or p_as_of_date is null or p_window_start is null or p_window_end is null then
    raise exception 'refresh_insight_predictions: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  delete from public.prediction_outputs
  where user_id = p_user_id
    and model_version = 'rules-insight-v1';

  select r.flare_days, r.stress_vs_pain_score, r.avg_pain
  into v_flare_days, v_stress_vs_pain, v_avg_pain_7
  from public.rolling_feature_snapshots r
  where r.user_id = p_user_id and r.snapshot_date = p_as_of_date and r.window_days = 7;

  v_trigger_count := coalesce((
    select d.trigger_count from public.daily_feature_rollups d
    where d.user_id = p_user_id and d.feature_date = p_as_of_date limit 1
  ), 0);
  v_avg_pain_d := coalesce((
    select d.avg_pain from public.daily_feature_rollups d
    where d.user_id = p_user_id and d.feature_date = p_as_of_date limit 1
  ), 0);
  v_reflux_count := coalesce((
    select d.reflux_count from public.daily_feature_rollups d
    where d.user_id = p_user_id and d.feature_date = p_as_of_date limit 1
  ), 0);
  v_symptom_count := coalesce((
    select d.symptom_count from public.daily_feature_rollups d
    where d.user_id = p_user_id and d.feature_date = p_as_of_date limit 1
  ), 0);

  select afs.food_tag, afs.co_occurrence_pain_avg
  into v_top_food_tag, v_top_food_pain
  from public.analytics_food_scores afs
  where afs.user_id = p_user_id
    and afs.window_start = p_window_start
    and afs.window_end = p_window_end
  order by afs.co_occurrence_pain_avg desc nulls last
  limit 1;

  select max(avg_pain) into v_max_hour
  from public.analytics_time_patterns
  where user_id = p_user_id
    and bucket_type = 'hour_of_day'
    and window_start = p_window_start
    and window_end = p_window_end;

  v_flare_score := least(1.0, greatest(0.0,
    coalesce(v_flare_days::numeric / nullif(7, 0), 0) * 0.5
    + coalesce(v_stress_vs_pain, 0) * 0.25
    + case when v_trigger_count >= 2 then 0.15 else 0 end
    + case when v_avg_pain_d >= 6 then 0.1 else 0 end
  ));

  v_reflux_score := least(1.0, greatest(0.0,
    coalesce(v_reflux_count::numeric / nullif(greatest(v_symptom_count, 1), 0), 0) * 0.4
    + case when extract(hour from now() at time zone 'utc') between 20 and 23 then 0.15 else 0 end
    + coalesce(v_max_hour / 10.0, 0) * 0.35
    + coalesce(v_avg_pain_7 / 10.0, 0) * 0.1
  ));

  v_food_score := least(1.0, greatest(0.0,
    coalesce(v_top_food_pain / 10.0, 0)
  ));

  insert into public.prediction_outputs (
    user_id, prediction_type, prediction_window_hours, score, label, explanation, model_version, expires_at
  ) values (
    p_user_id,
    'flare_risk',
    24,
    round(v_flare_score::numeric, 4),
    case when v_flare_score >= 0.55 then 'elevated' when v_flare_score >= 0.35 then 'moderate' else 'low' end,
    jsonb_build_object(
      'flare_days_7d', v_flare_days,
      'stress_vs_pain', v_stress_vs_pain,
      'trigger_count_today', v_trigger_count
    ),
    'rules-insight-v1',
    (now() + interval '7 days')
  );

  insert into public.prediction_outputs (
    user_id, prediction_type, prediction_window_hours, score, label, explanation, model_version, expires_at
  ) values (
    p_user_id,
    'reflux_symptom_risk',
    24,
    round(v_reflux_score::numeric, 4),
    case when v_reflux_score >= 0.5 then 'elevated' when v_reflux_score >= 0.3 then 'moderate' else 'low' end,
    jsonb_build_object(
      'reflux_events', v_reflux_count,
      'symptom_count', v_symptom_count,
      'peak_hour_avg_pain', v_max_hour
    ),
    'rules-insight-v1',
    (now() + interval '7 days')
  );

  insert into public.prediction_outputs (
    user_id, prediction_type, prediction_window_hours, score, label, explanation, model_version, expires_at
  ) values (
    p_user_id,
    'food_tag_risk',
    168,
    round(v_food_score::numeric, 4),
    coalesce(v_top_food_tag, 'unknown'),
    jsonb_build_object(
      'top_tag', v_top_food_tag,
      'avg_pain_when_tag_logged', v_top_food_pain,
      'window', jsonb_build_object('start', p_window_start, 'end', p_window_end)
    ),
    'rules-insight-v1',
    (now() + interval '7 days')
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- 5) Rule-based recommendation_items (source = insight_engine)
-- -----------------------------------------------------------------------------

create or replace function public.refresh_insight_recommendation_items(
  p_user_id uuid,
  p_snapshot_date date,
  p_window_start date,
  p_window_end date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_stress_30 numeric;
  v_worst_hour smallint;
  v_worst_dow smallint;
begin
  if p_user_id is null or p_snapshot_date is null or p_window_start is null or p_window_end is null then
    raise exception 'refresh_insight_recommendation_items: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  delete from public.recommendation_items
  where user_id = p_user_id
    and source = 'insight_engine';

  select stress_vs_pain_score into v_stress_30
  from public.rolling_feature_snapshots
  where user_id = p_user_id
    and snapshot_date = p_snapshot_date
    and window_days = 30;

  select bucket_value into v_worst_hour
  from public.analytics_time_patterns
  where user_id = p_user_id
    and bucket_type = 'hour_of_day'
    and window_start = p_window_start
    and window_end = p_window_end
  order by avg_pain desc nulls last
  limit 1;

  select bucket_value into v_worst_dow
  from public.analytics_time_patterns
  where user_id = p_user_id
    and bucket_type = 'dow'
    and window_start = p_window_start
    and window_end = p_window_end
  order by avg_pain desc nulls last
  limit 1;

  insert into public.recommendation_items (
    user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence,
    model_version, source
  )
  select
    p_user_id,
    'trigger_avoidance',
    1,
    'Consider reducing exposure: ' || ats.trigger_name,
    'This trigger is associated with higher pain versus entries without it in your selected window.',
    jsonb_build_array(
      jsonb_build_object('reason', 'pain_delta_positive', 'delta', ats.pain_delta)
    ),
    jsonb_build_object(
      'trigger_name', ats.trigger_name,
      'avg_pain_when_present', ats.avg_pain_when_present,
      'sample_count', ats.sample_count
    ),
    least(1.0, greatest(0.3, coalesce(ats.pain_delta, 0) / 10.0 + 0.35)),
    'insight-v1',
    'insight_engine'
  from public.analytics_trigger_scores ats
  where ats.user_id = p_user_id
    and ats.window_start = p_window_start
    and ats.window_end = p_window_end
    and ats.pain_delta is not null
    and ats.pain_delta > 0.5
  order by ats.pain_delta desc
  limit 5;

  insert into public.recommendation_items (
    user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence,
    model_version, source
  )
  select
    p_user_id,
    'remedy_effectiveness',
    2,
    'Remedy working well: ' || ars.remedy_name,
    'Higher average helpfulness when this remedy is logged.',
    jsonb_build_array(jsonb_build_object('metric', 'avg_effectiveness', 'value', ars.avg_effectiveness)),
    jsonb_build_object('remedy_name', ars.remedy_name, 'usage_count', ars.usage_count),
    least(1.0, greatest(0.4, coalesce(ars.avg_effectiveness, 0) / 10.0)),
    'insight-v1',
    'insight_engine'
  from public.analytics_remedy_scores ars
  where ars.user_id = p_user_id
    and ars.window_start = p_window_start
    and ars.window_end = p_window_end
    and ars.avg_effectiveness is not null
    and ars.avg_effectiveness >= 5
  order by ars.avg_effectiveness desc
  limit 4;

  if v_worst_hour is not null then
    insert into public.recommendation_items (
      user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence,
      model_version, source
    ) values (
      p_user_id,
      'meal_timing',
      3,
      'Meal timing pattern',
      'Pain tends to be higher around hour ' || v_worst_hour || ' UTC in this window. Try lighter or earlier meals if that matches late eating for you.',
      jsonb_build_array(jsonb_build_object('hour_utc', v_worst_hour)),
      jsonb_build_object('worst_hour_utc', v_worst_hour, 'worst_dow', v_worst_dow),
      0.55,
      'insight-v1',
      'insight_engine'
    );
  end if;

  if v_stress_30 is not null and v_stress_30 >= 0.25 then
    insert into public.recommendation_items (
      user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence,
      model_version, source
    ) values (
      p_user_id,
      'stress_management',
      4,
      'Stress may be amplifying pain',
      'Rolling 30-day stress vs pain correlation suggests stress tracking or calming routines could help.',
      jsonb_build_array(jsonb_build_object('stress_vs_pain_score', v_stress_30)),
      jsonb_build_object('rolling_window_days', 30),
      least(1.0, 0.45 + v_stress_30),
      'insight-v1',
      'insight_engine'
    );
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 6) Orchestration
-- -----------------------------------------------------------------------------

create or replace function public.refresh_user_insight_engine(
  p_user_id uuid,
  p_start date,
  p_end date
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  t0 timestamptz := clock_timestamp();
  step text;
  steps jsonb := '[]'::jsonb;
begin
  if p_user_id is null or p_start is null or p_end is null or p_start > p_end then
    raise exception 'refresh_user_insight_engine: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  step := 'refresh_trigger_scores';
  perform public.refresh_trigger_scores(p_user_id, p_start, p_end);
  steps := steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
  t0 := clock_timestamp();

  step := 'refresh_food_scores';
  perform public.refresh_food_scores(p_user_id, p_start, p_end);
  steps := steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
  t0 := clock_timestamp();

  step := 'refresh_time_patterns';
  perform public.refresh_time_patterns(p_user_id, p_start, p_end);
  steps := steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
  t0 := clock_timestamp();

  step := 'refresh_remedy_scores';
  perform public.refresh_remedy_scores(p_user_id, p_start, p_end);
  steps := steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
  t0 := clock_timestamp();

  step := 'refresh_daily_feature_rollups';
  perform public.refresh_daily_feature_rollups(p_user_id, p_start, p_end);
  steps := steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
  t0 := clock_timestamp();

  step := 'refresh_rolling_feature_snapshots';
  perform public.refresh_rolling_feature_snapshots(p_user_id, p_end);
  steps := steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
  t0 := clock_timestamp();

  step := 'refresh_insight_model_features';
  perform public.refresh_insight_model_features(p_user_id, p_end, p_start, p_end, 14);
  steps := steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
  t0 := clock_timestamp();

  step := 'refresh_insight_predictions';
  perform public.refresh_insight_predictions(p_user_id, p_end, p_start, p_end);
  steps := steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
  t0 := clock_timestamp();

  step := 'refresh_insight_recommendation_items';
  perform public.refresh_insight_recommendation_items(p_user_id, p_end, p_start, p_end);
  steps := steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));

  insert into public.recommendation_cache as rc (user_id, cache_version, generated_at, payload)
  values (
    p_user_id,
    'insight-engine-meta',
    now(),
    jsonb_build_object(
      'insight_engine_last_run',
      jsonb_build_object(
        'at', now(),
        'window_start', p_start,
        'window_end', p_end,
        'steps', steps
      )
    )
  )
  on conflict (user_id, cache_version) do update set
    generated_at = now(),
    payload = coalesce(rc.payload, '{}'::jsonb) || excluded.payload;

  return jsonb_build_object(
    'ok', true,
    'user_id', p_user_id,
    'window', jsonb_build_object('start', p_start, 'end', p_end),
    'steps', steps
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- 7) Indexes
-- -----------------------------------------------------------------------------

create index if not exists idx_analytics_food_scores_user_window
  on public.analytics_food_scores (user_id, window_end desc, co_occurrence_pain_avg desc nulls last);

create index if not exists idx_analytics_trigger_scores_user_delta
  on public.analytics_trigger_scores (user_id, window_end desc, pain_delta desc nulls last);

create index if not exists idx_analytics_time_patterns_user_bucket
  on public.analytics_time_patterns (user_id, window_end desc, bucket_type, bucket_value);

create index if not exists idx_prediction_outputs_user_model
  on public.prediction_outputs (user_id, model_version, predicted_at desc);

create index if not exists idx_recommendation_items_user_source
  on public.recommendation_items (user_id, source, generated_at desc);

-- -----------------------------------------------------------------------------
-- Grants
-- -----------------------------------------------------------------------------

revoke all on function public.refresh_trigger_scores(uuid, date, date) from public;
revoke all on function public.refresh_food_scores(uuid, date, date) from public;
revoke all on function public.refresh_time_patterns(uuid, date, date) from public;
revoke all on function public.refresh_remedy_scores(uuid, date, date) from public;
revoke all on function public.refresh_daily_feature_rollup(uuid, date) from public;
revoke all on function public.refresh_rolling_feature_snapshot(uuid, date, integer) from public;
revoke all on function public.refresh_insight_model_features(uuid, date, date, date, integer) from public;
revoke all on function public.refresh_insight_predictions(uuid, date, date, date) from public;
revoke all on function public.refresh_insight_recommendation_items(uuid, date, date, date) from public;
revoke all on function public.refresh_user_insight_engine(uuid, date, date) from public;

grant execute on function public.refresh_trigger_scores(uuid, date, date) to authenticated;
grant execute on function public.refresh_food_scores(uuid, date, date) to authenticated;
grant execute on function public.refresh_time_patterns(uuid, date, date) to authenticated;
grant execute on function public.refresh_remedy_scores(uuid, date, date) to authenticated;
grant execute on function public.refresh_daily_feature_rollup(uuid, date) to authenticated;
grant execute on function public.refresh_rolling_feature_snapshot(uuid, date, integer) to authenticated;
grant execute on function public.refresh_insight_model_features(uuid, date, date, date, integer) to authenticated;
grant execute on function public.refresh_insight_predictions(uuid, date, date, date) to authenticated;
grant execute on function public.refresh_insight_recommendation_items(uuid, date, date, date) to authenticated;
grant execute on function public.refresh_user_insight_engine(uuid, date, date) to authenticated;

comment on function public.refresh_user_insight_engine(uuid, date, date) is
  'Runs insight pipeline: granular analytics, daily/rolling features, model_features row, predictions, insight recommendations; merges run metadata into recommendation_cache (cache_version insight-engine-meta).';
