-- =============================================================================
-- GastroGuard: tagging model metadata, analytics orchestration notes,
-- and refresh_food_scores merge (catalog meal_event_food_tags + log_entries JSONB).
-- Additive; idempotent where possible.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Tagging model — table/column comments
-- -----------------------------------------------------------------------------

comment on table public.food_tags is
  'Global catalog of canonical food/property exposure tags (slug, label, category). '
  'Use with meal_event_food_tags for structured GI exposure analytics and rollups. '
  'Not the same as per-user meal_tags (user meal context labels).';

comment on table public.meal_tags is
  'Per-user meal context labels (free text name). Use with meal_event_meal_tags for '
  'habits, summaries, and UX grouping — not the global food_tags catalog.';

comment on table public.meal_event_food_tags is
  'Junction: meal_event → global food_tags (canonical exposure). Preferred source when '
  'the app maintains junction rows for analytics keyed by food_tags.slug.';

comment on column public.log_entries.food_tags is
  'JSONB array on the primary log write surface: strings or { tag, category?, confidence? }. '
  'Feeds refresh_food_scores together with meal_event_food_tags; values should align with '
  'food_tags.slug where possible for consistent analytics.';

comment on column public.meal_events.food_tags is
  'Denormalized JSON cache of user meal-tag names (from meal_tags via meal_event_meal_tags), '
  'maintained by rebuild_meal_event_food_tags_cache. Despite the column name, this is NOT the '
  'global food_tags catalog snapshot; use meal_event_food_tags + public.food_tags for exposure analytics.';

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'meal_event_meal_tags'
  ) then
    execute $c$
      comment on table public.meal_event_meal_tags is
        'Junction: meal_event → per-user meal_tags (user/context labels). Use for summaries and '
        'personal meal grouping; not for global food_tags.slug exposure rollups.';
    $c$;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 2) Indexes — reverse lookups for jobs and analytics
-- -----------------------------------------------------------------------------

create index if not exists idx_meal_event_food_tags_food_tag
  on public.meal_event_food_tags (food_tag_id);

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'meal_event_meal_tags'
  ) then
    execute 'create index if not exists idx_meal_event_meal_tags_meal_tag on public.meal_event_meal_tags (meal_tag_id)';
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 3) Analytics orchestration — function comments (operational contract)
-- -----------------------------------------------------------------------------

comment on function public.refresh_user_insight_engine(uuid, date, date) is
  'Runs granular refresh_* (trigger, food, time, remedy), daily/rolling features, model_features, '
  'predictions, insight recommendations. Prefer this for full insight pipeline. Overlaps with '
  'refresh_user_analytics on analytics_* rows for the same window — do not run both blindly.';

comment on function public.refresh_user_analytics(uuid, date, date) is
  'Upserts weekly_summaries and analytics_* for [p_from, p_to]. Overlaps with refresh_user_insight_engine '
  'on analytics tables — pick one orchestration path per window or accept duplicate recompute.';

comment on function public.refresh_trigger_scores(uuid, date, date) is
  'Upserts analytics_trigger_scores for one user and inclusive date window from trigger_events + log_entries.';

comment on function public.refresh_remedy_scores(uuid, date, date) is
  'Upserts analytics_remedy_scores for one user and inclusive date window from remedy_events.';

comment on function public.refresh_time_patterns(uuid, date, date) is
  'Upserts analytics_time_patterns (hour_of_day, dow) for one user and inclusive date window.';

comment on function public.refresh_food_scores(uuid, date, date) is
  'Upserts analytics_food_scores: merges canonical food_tags.slug via meal_event_food_tags with '
  'log_entries.food_tags JSONB; when both exist for the same entry, catalog slug wins (jsonb duplicate dropped).';

-- -----------------------------------------------------------------------------
-- 4) refresh_food_scores — catalog + JSONB merge
-- -----------------------------------------------------------------------------

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
  with cat as (
    select distinct
      le.id as entry_id,
      ft.slug as food_tag
    from public.meal_event_food_tags meft
    join public.food_tags ft on ft.id = meft.food_tag_id
    join public.meal_events me on me.id = meft.meal_event_id
    join public.log_entries le
      on le.id = me.source_entry_id
     and le.user_id = me.user_id
    where le.user_id = p_user_id
      and le.entry_at >= v_from_ts
      and le.entry_at < v_to_ts_excl
  ),
  jb as (
    select
      le.id as entry_id,
      case
        when jsonb_typeof(elem) = 'string' then nullif(trim(elem #>> '{}'), '')
        else nullif(trim(elem ->> 'tag'), '')
      end as raw_tag
    from public.log_entries le
    cross join lateral jsonb_array_elements(coalesce(le.food_tags, '[]'::jsonb)) as elem
    where le.user_id = p_user_id
      and le.entry_at >= v_from_ts
      and le.entry_at < v_to_ts_excl
  ),
  jb_only as (
    select distinct jb.entry_id, jb.raw_tag as food_tag
    from jb
    where jb.raw_tag is not null
      and jb.raw_tag <> ''
      and not exists (
        select 1
        from cat c
        where c.entry_id = jb.entry_id
          and lower(c.food_tag) = lower(jb.raw_tag)
      )
  ),
  all_pairs as (
    select entry_id, food_tag from cat
    union all
    select entry_id, food_tag from jb_only
  )
  select
    p_user_id,
    a.food_tag,
    p_start,
    p_end,
    avg(le.pain_score),
    count(*)::int,
    now()
  from all_pairs a
  join public.log_entries le on le.id = a.entry_id
  group by p_user_id, a.food_tag, p_start, p_end
  on conflict (user_id, food_tag, window_start, window_end) do update set
    co_occurrence_pain_avg = excluded.co_occurrence_pain_avg,
    entry_count = excluded.entry_count,
    updated_at = now();
end;
$$;
