-- =============================================================================
-- GastroGuard: deployment verification (read-only)
-- Run in Supabase Dashboard → SQL Editor as postgres (or any role that can read
-- pg_catalog). Expect every row to show ok = true.
--
-- Does NOT modify data. If anything is missing, apply migrations from
-- supabase/migrations/ in order (see BACKEND_README.md).
-- =============================================================================

with
fn as (
  select p.proname as name
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
),
expected_fn as (
  select unnest(array[
    'set_updated_at',
    'handle_new_user',
    'sync_log_entry_to_normalized',
    'sync_log_entry_on_insert',
    'sync_log_entry_on_update',
    'sync_log_entry_on_delete',
    'refresh_user_analytics',
    'refresh_user_recommendations',
    'resolve_api_key',
    'refresh_daily_feature_rollups',
    'refresh_rolling_feature_snapshots',
    'refresh_recommendation_items_v3',
    'build_model_features',
    'rebuild_meal_event_food_tags_cache',
    'refresh_trigger_scores',
    'refresh_food_scores',
    'refresh_time_patterns',
    'refresh_remedy_scores',
    'refresh_daily_feature_rollup',
    'refresh_rolling_feature_snapshot',
    'refresh_insight_model_features',
    'refresh_insight_predictions',
    'refresh_insight_recommendation_items',
    'refresh_user_insight_engine'
  ]) as name
),
tr as (
  select t.tgname as name
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  where c.relname = 'log_entries'
    and not t.tgisinternal
),
expected_tr as (
  select unnest(array[
    'tr_sync_log_entry_insert',
    'tr_sync_log_entry_update',
    'tr_sync_log_entry_delete',
    'log_entries_updated_at'
  ]) as name
),
views_ok as (
  select
    exists (
      select 1
      from information_schema.views v
      where v.table_schema = 'public'
        and v.table_name = 'v_user_timeline'
    ) as v_user_timeline,
    exists (
      select 1
      from information_schema.views v
      where v.table_schema = 'public'
        and v.table_name = 'v_profile_health_legacy'
    ) as v_profile_health_legacy
),
tables_ok as (
  select
    exists (
      select 1
      from information_schema.tables t
      where t.table_schema = 'public'
        and t.table_name = 'insight_engine_runs'
    ) as insight_engine_runs
),
rls as (
  select c.relname as table_name, c.relrowsecurity as rls_enabled
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  where c.relkind = 'r'
    and c.relname in ('profiles', 'log_entries', 'log_days', 'meal_events')
)
select 'function' as kind, e.name as object_name, (f.name is not null) as ok
from expected_fn e
left join fn f on f.name = e.name
union all
select 'trigger_on_log_entries', e.name, (t.name is not null)
from expected_tr e
left join tr t on t.name = e.name
union all
select 'view', 'v_user_timeline', v_user_timeline from views_ok
union all
select 'view', 'v_profile_health_legacy', v_profile_health_legacy from views_ok
union all
select 'table', 'insight_engine_runs', insight_engine_runs from tables_ok
union all
select 'rls', r.table_name || ' (rowsecurity)', r.rls_enabled
from rls r
order by 1, 2;
