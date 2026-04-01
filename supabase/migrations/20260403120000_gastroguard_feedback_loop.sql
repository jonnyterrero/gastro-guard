-- =============================================================================
-- GastroGuard feedback loop: user ratings on recommendations and prediction outcomes.
-- Used later for calibration, ranking, and offline evaluation (not wired in this migration).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- recommendation_feedback
-- -----------------------------------------------------------------------------
create table if not exists public.recommendation_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  recommendation_item_id uuid not null references public.recommendation_items (id) on delete cascade,

  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- 1-5 Likert usefulness; optional if user only answers was_helpful
  usefulness_score smallint
    check (usefulness_score is null or (usefulness_score >= 1 and usefulness_score <= 5)),
  -- Quick thumbs up/down; can be combined with usefulness_score
  was_helpful boolean,

  notes text,

  unique (user_id, recommendation_item_id)
);

create index if not exists idx_recommendation_feedback_user_submitted
  on public.recommendation_feedback (user_id, submitted_at desc);

create index if not exists idx_recommendation_feedback_item
  on public.recommendation_feedback (recommendation_item_id);

comment on table public.recommendation_feedback is
  'User feedback on a specific recommendation row. Join to recommendation_items for type/title; '
  'aggregates inform future ranking and rule tuning.';

comment on column public.recommendation_feedback.usefulness_score is
  'Optional 1-5 usefulness rating.';

comment on column public.recommendation_feedback.was_helpful is
  'Optional binary signal (e.g. quick dismiss vs helpful).';

-- -----------------------------------------------------------------------------
-- prediction_accuracy
-- -----------------------------------------------------------------------------
create table if not exists public.prediction_accuracy (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  prediction_output_id uuid not null references public.prediction_outputs (id) on delete cascade,

  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- User-reported alignment with what happened (0 = wrong, 1 = right); optional
  correctness_score numeric
    check (correctness_score is null or (correctness_score >= 0 and correctness_score <= 1)),
  -- e.g. flare occurred, pain level bucket â€” optional structured follow-up
  outcome_observed jsonb not null default '{}'::jsonb,

  notes text,

  unique (user_id, prediction_output_id)
);

create index if not exists idx_prediction_accuracy_user_submitted
  on public.prediction_accuracy (user_id, submitted_at desc);

create index if not exists idx_prediction_accuracy_prediction
  on public.prediction_accuracy (prediction_output_id);

create index if not exists idx_prediction_accuracy_user_model_eval
  on public.prediction_accuracy (user_id, submitted_at desc)
  include (correctness_score);

comment on table public.prediction_accuracy is
  'Ground-truth or subjective labels for a prediction_outputs row; used to compute calibration '
  'and error rates per model_version / prediction_type.';

comment on column public.prediction_accuracy.correctness_score is
  'Optional 0â€“1 score: how correct the prediction felt vs outcome (or derived from outcome_observed).';

comment on column public.prediction_accuracy.outcome_observed is
  'Structured outcome (e.g. flare_occurred, peak_pain) for richer offline metrics.';

-- -----------------------------------------------------------------------------
-- Sync user_id from parent (prevents spoofing); must match auth user for RLS
-- -----------------------------------------------------------------------------
create or replace function public.sync_recommendation_feedback_user_id()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select ri.user_id into v_owner
  from public.recommendation_items ri
  where ri.id = new.recommendation_item_id;

  if v_owner is null then
    raise exception 'recommendation_item_id not found';
  end if;

  new.user_id := v_owner;
  return new;
end;
$$;

create or replace function public.sync_prediction_accuracy_user_id()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select po.user_id into v_owner
  from public.prediction_outputs po
  where po.id = new.prediction_output_id;

  if v_owner is null then
    raise exception 'prediction_output_id not found';
  end if;

  new.user_id := v_owner;
  return new;
end;
$$;

drop trigger if exists tr_recommendation_feedback_sync_user on public.recommendation_feedback;
create trigger tr_recommendation_feedback_sync_user
  before insert or update of recommendation_item_id
  on public.recommendation_feedback
  for each row execute function public.sync_recommendation_feedback_user_id();

drop trigger if exists tr_prediction_accuracy_sync_user on public.prediction_accuracy;
create trigger tr_prediction_accuracy_sync_user
  before insert or update of prediction_output_id
  on public.prediction_accuracy
  for each row execute function public.sync_prediction_accuracy_user_id();

create trigger recommendation_feedback_updated_at
  before update on public.recommendation_feedback
  for each row execute function public.set_updated_at();

create trigger prediction_accuracy_updated_at
  before update on public.prediction_accuracy
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.recommendation_feedback enable row level security;

drop policy if exists "recommendation_feedback_select" on public.recommendation_feedback;
drop policy if exists "recommendation_feedback_insert" on public.recommendation_feedback;
drop policy if exists "recommendation_feedback_update" on public.recommendation_feedback;
drop policy if exists "recommendation_feedback_delete" on public.recommendation_feedback;

create policy "recommendation_feedback_select" on public.recommendation_feedback
  for select using (auth.uid() is not null and auth.uid() = user_id);

create policy "recommendation_feedback_insert" on public.recommendation_feedback
  for insert with check (auth.uid() is not null and auth.uid() = user_id);

create policy "recommendation_feedback_update" on public.recommendation_feedback
  for update using (auth.uid() is not null and auth.uid() = user_id);

create policy "recommendation_feedback_delete" on public.recommendation_feedback
  for delete using (auth.uid() is not null and auth.uid() = user_id);

alter table public.prediction_accuracy enable row level security;

drop policy if exists "prediction_accuracy_select" on public.prediction_accuracy;
drop policy if exists "prediction_accuracy_insert" on public.prediction_accuracy;
drop policy if exists "prediction_accuracy_update" on public.prediction_accuracy;
drop policy if exists "prediction_accuracy_delete" on public.prediction_accuracy;

create policy "prediction_accuracy_select" on public.prediction_accuracy
  for select using (auth.uid() is not null and auth.uid() = user_id);

create policy "prediction_accuracy_insert" on public.prediction_accuracy
  for insert with check (auth.uid() is not null and auth.uid() = user_id);

create policy "prediction_accuracy_update" on public.prediction_accuracy
  for update using (auth.uid() is not null and auth.uid() = user_id);

create policy "prediction_accuracy_delete" on public.prediction_accuracy
  for delete using (auth.uid() is not null and auth.uid() = user_id);

comment on function public.sync_recommendation_feedback_user_id() is
  'Sets user_id from recommendation_items so feedback cannot be filed under another account.';

comment on function public.sync_prediction_accuracy_user_id() is
  'Sets user_id from prediction_outputs so labels cannot be filed under another account.';