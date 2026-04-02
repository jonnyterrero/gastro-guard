-- =============================================================================
-- Insight layer: pre-aggregated analytics (refreshed by jobs / functions, not row triggers)
-- =============================================================================

create table if not exists public.analytics_trigger_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trigger_name text not null,
  window_start date not null,
  window_end date not null,
  sample_count integer not null default 0,
  avg_pain_when_present numeric,
  avg_pain_when_absent numeric,
  correlation_hint numeric,
  updated_at timestamptz not null default now(),
  unique (user_id, trigger_name, window_start, window_end)
);

create table if not exists public.analytics_remedy_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  remedy_name text not null,
  window_start date not null,
  window_end date not null,
  avg_effectiveness numeric,
  usage_count integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, remedy_name, window_start, window_end)
);

create table if not exists public.analytics_food_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  food_tag text not null,
  window_start date not null,
  window_end date not null,
  co_occurrence_pain_avg numeric,
  entry_count integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, food_tag, window_start, window_end)
);

create table if not exists public.analytics_time_patterns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket_type text not null check (bucket_type in ('hour_of_day','dow')),
  bucket_value smallint not null,
  window_start date not null,
  window_end date not null,
  avg_pain numeric,
  entry_count integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, bucket_type, bucket_value, window_start, window_end)
);

create table if not exists public.weekly_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  entry_count integer not null default 0,
  avg_pain numeric,
  avg_stress numeric,
  top_triggers jsonb default '[]'::jsonb,
  top_remedies jsonb default '[]'::jsonb,
  top_symptoms jsonb default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  unique (user_id, week_start)
);

create index if not exists idx_analytics_trigger_user_window
  on public.analytics_trigger_scores (user_id, window_end desc);
create index if not exists idx_analytics_remedy_user_window
  on public.analytics_remedy_scores (user_id, window_end desc);
create index if not exists idx_weekly_summaries_user_week
  on public.weekly_summaries (user_id, week_start desc);

alter table public.analytics_trigger_scores enable row level security;
alter table public.analytics_remedy_scores enable row level security;
alter table public.analytics_food_scores enable row level security;
alter table public.analytics_time_patterns enable row level security;
alter table public.weekly_summaries enable row level security;

create policy "analytics_trigger_scores_select" on public.analytics_trigger_scores
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_trigger_scores_insert" on public.analytics_trigger_scores
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_trigger_scores_update" on public.analytics_trigger_scores
  for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_trigger_scores_delete" on public.analytics_trigger_scores
  for delete using (auth.uid() is not null and auth.uid() = user_id);

create policy "analytics_remedy_scores_select" on public.analytics_remedy_scores
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_remedy_scores_insert" on public.analytics_remedy_scores
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_remedy_scores_update" on public.analytics_remedy_scores
  for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_remedy_scores_delete" on public.analytics_remedy_scores
  for delete using (auth.uid() is not null and auth.uid() = user_id);

create policy "analytics_food_scores_select" on public.analytics_food_scores
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_food_scores_insert" on public.analytics_food_scores
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_food_scores_update" on public.analytics_food_scores
  for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_food_scores_delete" on public.analytics_food_scores
  for delete using (auth.uid() is not null and auth.uid() = user_id);

create policy "analytics_time_patterns_select" on public.analytics_time_patterns
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_time_patterns_insert" on public.analytics_time_patterns
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_time_patterns_update" on public.analytics_time_patterns
  for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "analytics_time_patterns_delete" on public.analytics_time_patterns
  for delete using (auth.uid() is not null and auth.uid() = user_id);

create policy "weekly_summaries_select" on public.weekly_summaries
  for select using (auth.uid() is not null and auth.uid() = user_id);
create policy "weekly_summaries_insert" on public.weekly_summaries
  for insert with check (auth.uid() is not null and auth.uid() = user_id);
create policy "weekly_summaries_update" on public.weekly_summaries
  for update using (auth.uid() is not null and auth.uid() = user_id);
create policy "weekly_summaries_delete" on public.weekly_summaries
  for delete using (auth.uid() is not null and auth.uid() = user_id);

comment on table public.analytics_trigger_scores is 'Precomputed trigger vs pain correlations; refresh via refresh_user_analytics.';
comment on table public.analytics_remedy_scores is 'Precomputed remedy effectiveness aggregates.';
comment on table public.analytics_food_scores is 'Precomputed food tag vs pain aggregates.';
comment on table public.analytics_time_patterns is 'Hour-of-day / day-of-week pain patterns.';
comment on table public.weekly_summaries is 'Weekly rollups for dashboard and recommendations.';
