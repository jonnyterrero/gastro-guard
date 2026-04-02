-- =============================================================================
-- Insight engine run log: one row per refresh_user_insight_engine invocation.
-- Wraps orchestration to record success/failure (avoids silent pipeline death).
--
-- On failure: the inner BEGIN/EXCEPTION block rolls back pipeline writes; run row is
-- updated to status=error; function returns {"ok": false, ...} (no RAISE) so
-- the audit row commits. Callers should check the returned jsonb "ok" field.
-- =============================================================================

create table if not exists public.insight_engine_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null default 'running'
    check (status in ('running', 'ok', 'error')),
  error text,
  window_start date not null,
  window_end date not null,
  steps jsonb
);

create index if not exists idx_insight_engine_runs_user_started
  on public.insight_engine_runs (user_id, started_at desc);

comment on table public.insight_engine_runs is
  'Audit row for each refresh_user_insight_engine run: timing, per-step JSON, or error text.';

alter table public.insight_engine_runs enable row level security;

drop policy if exists "insight_engine_runs_select" on public.insight_engine_runs;
drop policy if exists "insight_engine_runs_insert" on public.insight_engine_runs;
drop policy if exists "insight_engine_runs_update" on public.insight_engine_runs;
drop policy if exists "insight_engine_runs_delete" on public.insight_engine_runs;

create policy "insight_engine_runs_select"
  on public.insight_engine_runs for select
  using (auth.uid() is not null and auth.uid() = user_id);

create policy "insight_engine_runs_insert"
  on public.insight_engine_runs for insert
  with check (auth.uid() is not null and auth.uid() = user_id);

create policy "insight_engine_runs_update"
  on public.insight_engine_runs for update
  using (auth.uid() is not null and auth.uid() = user_id);

create policy "insight_engine_runs_delete"
  on public.insight_engine_runs for delete
  using (auth.uid() is not null and auth.uid() = user_id);

grant select, insert, update, delete on public.insight_engine_runs to authenticated;

-- -----------------------------------------------------------------------------
-- Orchestration: insert run row + update on success/failure
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
  v_run_id uuid;
  t0 timestamptz := clock_timestamp();
  step text := '(init)';
  v_steps jsonb := '[]'::jsonb;
  v_err text;
begin
  if p_user_id is null or p_start is null or p_end is null or p_start > p_end then
    raise exception 'refresh_user_insight_engine: invalid arguments';
  end if;
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Unauthorized';
  end if;

  insert into public.insight_engine_runs (user_id, window_start, window_end, status)
  values (p_user_id, p_start, p_end, 'running')
  returning id into v_run_id;

  begin
    step := 'refresh_trigger_scores';
    perform public.refresh_trigger_scores(p_user_id, p_start, p_end);
    v_steps := v_steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
    t0 := clock_timestamp();

    step := 'refresh_food_scores';
    perform public.refresh_food_scores(p_user_id, p_start, p_end);
    v_steps := v_steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
    t0 := clock_timestamp();

    step := 'refresh_time_patterns';
    perform public.refresh_time_patterns(p_user_id, p_start, p_end);
    v_steps := v_steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
    t0 := clock_timestamp();

    step := 'refresh_remedy_scores';
    perform public.refresh_remedy_scores(p_user_id, p_start, p_end);
    v_steps := v_steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
    t0 := clock_timestamp();

    step := 'refresh_daily_feature_rollups';
    perform public.refresh_daily_feature_rollups(p_user_id, p_start, p_end);
    v_steps := v_steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
    t0 := clock_timestamp();

    step := 'refresh_rolling_feature_snapshots';
    perform public.refresh_rolling_feature_snapshots(p_user_id, p_end);
    v_steps := v_steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
    t0 := clock_timestamp();

    step := 'refresh_insight_model_features';
    perform public.refresh_insight_model_features(p_user_id, p_end, p_start, p_end, 14);
    v_steps := v_steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
    t0 := clock_timestamp();

    step := 'refresh_insight_predictions';
    perform public.refresh_insight_predictions(p_user_id, p_end, p_start, p_end);
    v_steps := v_steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));
    t0 := clock_timestamp();

    step := 'refresh_insight_recommendation_items';
    perform public.refresh_insight_recommendation_items(p_user_id, p_end, p_start, p_end);
    v_steps := v_steps || jsonb_build_array(jsonb_build_object('step', step, 'ms', extract(milliseconds from clock_timestamp() - t0)::int));

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
          'steps', v_steps,
          'run_id', v_run_id
        )
      )
    )
    on conflict (user_id, cache_version) do update set
      generated_at = now(),
      payload = coalesce(rc.payload, '{}'::jsonb) || excluded.payload;

    update public.insight_engine_runs
    set
      completed_at = now(),
      status = 'ok',
      steps = v_steps
    where id = v_run_id;

    return jsonb_build_object(
      'ok', true,
      'run_id', v_run_id,
      'user_id', p_user_id,
      'window', jsonb_build_object('start', p_start, 'end', p_end),
      'steps', v_steps
    );
  exception
    when others then
      v_err := sqlerrm;
      update public.insight_engine_runs
      set
        completed_at = now(),
        status = 'error',
        error = left(v_err, 8000),
        steps = v_steps
      where id = v_run_id;
      return jsonb_build_object(
        'ok', false,
        'run_id', v_run_id,
        'user_id', p_user_id,
        'window', jsonb_build_object('start', p_start, 'end', p_end),
        'error', v_err,
        'failed_step', step,
        'steps_completed', v_steps
      );
  end;
end;
$$;

comment on function public.refresh_user_insight_engine(uuid, date, date) is
  'Runs insight pipeline; logs each invocation to insight_engine_runs. On step failure, inner block rollback clears partial work; error row + ok=false JSON (HTTP 200).';
