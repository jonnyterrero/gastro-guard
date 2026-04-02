-- =============================================================================
-- GastroGuard insight pipeline v2: documented flare rules, richer model_features,
-- and expanded recommendation_items (analytics + predictions + profile_conditions).
-- Replaces functions from 20260330120000_insight_engine_layer.sql in-place.
-- =============================================================================

comment on column public.daily_feature_rollups.flare_flag is
  'Explainable rule for the calendar day: true when max_pain >= 7 OR '
  '(avg_pain >= 6 AND symptom_count >= 3), computed in refresh_daily_feature_rollups.';

comment on column public.daily_feature_rollups.flare_score is
  'Explainable scalar: if max_pain >= 7 then max_pain/10; else avg_pain/10 + symptom_count*0.05 '
  '(bounded components; not a clinical score).';

create index if not exists idx_daily_feature_rollups_user_feature_date
  on public.daily_feature_rollups (user_id, feature_date desc);

comment on function public.refresh_daily_feature_rollups(uuid, date, date) is
  'Upserts daily_feature_rollups per calendar day: aggregates log_entries + normalized events + food tag exposure text match.';

comment on function public.refresh_daily_feature_rollup(uuid, date) is
  'Thin wrapper: calls refresh_daily_feature_rollups for a single feature_date.';

comment on function public.refresh_rolling_feature_snapshots(uuid, date) is
  'Upserts rolling_feature_snapshots for snapshot_date for windows 7/14/30/60 from daily_feature_rollups.';

comment on function public.refresh_rolling_feature_snapshot(uuid, date, integer) is
  'Upserts one rolling_feature_snapshots row for snapshot_date and window_days in (7,14,30,60).';

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
  v_top_remedy_eff numeric;
  v_exposure jsonb;
  v_sleep_q numeric;
  v_sleep_h numeric;
  v_ex_lvl numeric;
  v_flare_days bigint;
  v_symptom_days bigint;
begin
  if p_user_id is null or p_as_of_date is null or p_window_start is null or p_window_end is null then
    raise exception 'refresh_insight_model_features: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  v_start := p_as_of_date - (coalesce(p_window_days, 14) - 1);

  select coalesce(
    jsonb_object_agg(
      r.window_days::text,
      to_jsonb(r) - 'id' - 'user_id' - 'created_at'
    ),
    '{}'::jsonb
  )
  into v_roll
  from public.rolling_feature_snapshots r
  where r.user_id = p_user_id
    and r.snapshot_date = p_as_of_date
    and r.window_days in (7, 14, 30, 60);

  select to_jsonb(d) - 'id' - 'user_id' - 'created_at' - 'updated_at'
  into v_daily
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

  select max(ars.avg_effectiveness) into v_top_remedy_eff
  from public.analytics_remedy_scores ars
  where ars.user_id = p_user_id
    and ars.window_start = p_window_start
    and ars.window_end = p_window_end;

  select
    jsonb_build_object(
      'spicy_exposure', coalesce(sum(d2.spicy_exposure_count), 0),
      'acidic_exposure', coalesce(sum(d2.acidic_exposure_count), 0),
      'dairy_exposure', coalesce(sum(d2.dairy_exposure_count), 0),
      'caffeine_exposure', coalesce(sum(d2.caffeine_exposure_count), 0),
      'fried_exposure', coalesce(sum(d2.fried_exposure_count), 0)
    ),
    avg(d2.sleep_quality_avg),
    avg(d2.sleep_hours_avg),
    avg(d2.exercise_level_avg),
    count(*) filter (where d2.flare_flag),
    count(*) filter (where d2.symptom_count > 0)
  into v_exposure, v_sleep_q, v_sleep_h, v_ex_lvl, v_flare_days, v_symptom_days
  from public.daily_feature_rollups d2
  where d2.user_id = p_user_id
    and d2.feature_date between v_start and p_as_of_date;

  v_target := jsonb_build_object(
    'label_date', p_as_of_date + 1,
    'flare_next_day', coalesce(v_next_flare, false),
    'avg_pain_next_day', v_next_pain,
    'pain_risk_next_day', case
      when v_next_pain is null then null
      else least(1.0, greatest(0.0, v_next_pain / 10.0))
    end,
    'high_pain_next_day', case
      when v_next_pain is null then null
      else v_next_pain >= 6
    end
  );

  v_features := jsonb_build_object(
    'as_of', p_as_of_date,
    'window_days', coalesce(p_window_days, 14),
    'rolling_snapshots_by_window', coalesce(v_roll, '{}'::jsonb),
    'daily_as_of', coalesce(v_daily, '{}'::jsonb),
    'exposure_totals_in_window', coalesce(v_exposure, '{}'::jsonb),
    'sleep_quality_avg_in_window', v_sleep_q,
    'sleep_hours_avg_in_window', v_sleep_h,
    'exercise_level_avg_in_window', v_ex_lvl,
    'flare_days_in_window', v_flare_days,
    'symptom_days_in_window', v_symptom_days,
    'top_trigger_pain_delta', v_top_td,
    'top_food_pain_avg', v_top_food,
    'top_remedy_avg_effectiveness', v_top_remedy_eff,
    'remedy_effectiveness_rolling_7d',
    (select r.remedy_effectiveness_score
     from public.rolling_feature_snapshots r
     where r.user_id = p_user_id
       and r.snapshot_date = p_as_of_date
       and r.window_days = 7
     limit 1)
  );

  insert into public.model_features (
    user_id, feature_set_version, features, target, source_window_days
  )
  values (
    p_user_id,
    'insight-engine-v2',
    v_features,
    v_target,
    coalesce(p_window_days, 14)
  )
  returning id into v_id;

  return v_id;
end;
$$;

comment on function public.refresh_insight_model_features(uuid, date, date, date, integer) is
  'Writes one model_features row: rolling snapshots (7/14/30/60), window exposure totals, sleep/exercise avgs, '
  'analytics tops, targets for next-day flare and high-pain risk. Version insight-engine-v2.';

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
  v_preds jsonb;
  v_conditions jsonb;
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

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'prediction_type', po.prediction_type,
        'score', po.score,
        'label', po.label,
        'explanation', po.explanation
      )
    ),
    '[]'::jsonb
  )
  into v_preds
  from public.prediction_outputs po
  where po.user_id = p_user_id
    and po.model_version = 'rules-insight-v1'
    and (po.expires_at is null or po.expires_at > now());

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'condition_name', pc.condition_name,
        'condition_code', pc.condition_code,
        'is_active', pc.is_active
      )
    ),
    '[]'::jsonb
  )
  into v_conditions
  from public.profile_conditions pc
  where pc.user_id = p_user_id
    and coalesce(pc.is_active, true);

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
      'sample_count', ats.sample_count,
      'predictions_snapshot', v_preds,
      'profile_conditions', v_conditions
    ),
    least(1.0, greatest(0.3, coalesce(ats.pain_delta, 0) / 10.0 + 0.35)),
    'insight-v2',
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
    'food_exposure_risk',
    2,
    'Food tag pattern: ' || afs.food_tag,
    'Higher average pain on days this tag appears in your log window — worth testing reduction or better timing.',
    jsonb_build_array(
      jsonb_build_object('metric', 'co_occurrence_pain_avg', 'value', afs.co_occurrence_pain_avg)
    ),
    jsonb_build_object(
      'food_tag', afs.food_tag,
      'co_occurrence_pain_avg', afs.co_occurrence_pain_avg,
      'entry_count', afs.entry_count,
      'predictions_snapshot', v_preds,
      'profile_conditions', v_conditions
    ),
    least(1.0, greatest(0.35, coalesce(afs.co_occurrence_pain_avg, 0) / 10.0)),
    'insight-v2',
    'insight_engine'
  from public.analytics_food_scores afs
  where afs.user_id = p_user_id
    and afs.window_start = p_window_start
    and afs.window_end = p_window_end
    and afs.co_occurrence_pain_avg is not null
    and afs.co_occurrence_pain_avg >= 5
  order by afs.co_occurrence_pain_avg desc
  limit 3;

  insert into public.recommendation_items (
    user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence,
    model_version, source
  )
  select
    p_user_id,
    'remedy_effectiveness',
    3,
    'Remedy working well: ' || ars.remedy_name,
    'Higher average helpfulness when this remedy is logged.',
    jsonb_build_array(jsonb_build_object('metric', 'avg_effectiveness', 'value', ars.avg_effectiveness)),
    jsonb_build_object(
      'remedy_name', ars.remedy_name,
      'usage_count', ars.usage_count,
      'predictions_snapshot', v_preds,
      'profile_conditions', v_conditions
    ),
    least(1.0, greatest(0.4, coalesce(ars.avg_effectiveness, 0) / 10.0)),
    'insight-v2',
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
      4,
      'Meal timing pattern',
      'Pain tends to be higher around hour ' || v_worst_hour || ' UTC in this window. Try lighter or earlier meals if that matches late eating for you.',
      jsonb_build_array(jsonb_build_object('hour_utc', v_worst_hour)),
      jsonb_build_object(
        'worst_hour_utc', v_worst_hour,
        'worst_dow', v_worst_dow,
        'predictions_snapshot', v_preds,
        'profile_conditions', v_conditions
      ),
      0.55,
      'insight-v2',
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
      5,
      'Stress may be amplifying pain',
      'Rolling 30-day stress vs pain correlation suggests stress tracking or calming routines could help.',
      jsonb_build_array(jsonb_build_object('stress_vs_pain_score', v_stress_30)),
      jsonb_build_object(
        'rolling_window_days', 30,
        'predictions_snapshot', v_preds,
        'profile_conditions', v_conditions
      ),
      least(1.0, 0.45 + v_stress_30),
      'insight-v2',
      'insight_engine'
    );
  end if;

  insert into public.recommendation_items (
    user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence,
    model_version, source
  )
  select
    p_user_id,
    'model_risk_signal',
    6,
    case po.prediction_type
      when 'flare_risk' then 'Elevated flare risk signal'
      when 'food_tag_risk' then 'Food-related pain signal'
      when 'reflux_symptom_risk' then 'Reflux symptom risk signal'
      else 'Model risk signal'
    end,
    'Rule-based model score: ' || round(po.score::numeric, 2) || ' (' || coalesce(po.label, 'n/a') || ').',
    jsonb_build_array(jsonb_build_object('source', 'prediction_outputs', 'type', po.prediction_type)),
    jsonb_build_object(
      'prediction', to_jsonb(po) - 'id',
      'profile_conditions', v_conditions
    ),
    least(1.0, greatest(0.35, coalesce(po.score, 0))),
    'insight-v2',
    'insight_engine'
  from public.prediction_outputs po
  where po.user_id = p_user_id
    and po.model_version = 'rules-insight-v1'
    and (po.expires_at is null or po.expires_at > now())
    and po.score >= 0.45
  order by po.score desc
  limit 3;

  insert into public.recommendation_items (
    user_id, recommendation_type, priority, title, summary, rationale, evidence, confidence,
    model_version, source
  )
  select
    p_user_id,
    'condition_context',
    7,
    'Align tracking with: ' || pc.condition_label,
    'Your profile lists this condition — patterns for reflux-related foods and late meals may matter more for you.',
    jsonb_build_array(jsonb_build_object('condition_code', pc.condition_code)),
    jsonb_build_object(
      'condition_name', pc.condition_name,
      'condition_label', pc.condition_label,
      'predictions_snapshot', v_preds
    ),
    0.5,
    'insight-v2',
    'insight_engine'
  from public.profile_conditions pc
  where pc.user_id = p_user_id
    and coalesce(pc.is_active, true)
    and (
      lower(coalesce(pc.condition_name, '') || ' ' || coalesce(pc.condition_code, ''))
        ~* '(gerd|reflux|heartburn|barrett)'
    )
  limit 2;
end;
$$;

comment on function public.refresh_insight_recommendation_items(uuid, date, date, date) is
  'Deletes prior insight_engine rows; inserts explainable recs from analytics_trigger_scores, analytics_food_scores, '
  'analytics_remedy_scores, analytics_time_patterns, prediction_outputs, profile_conditions (GERD/reflux heuristic).';