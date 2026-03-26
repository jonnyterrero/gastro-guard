-- =============================================================================
-- GastroGuard — SQL Editor extras (idempotent)
--
-- Use when:
--   • You need resolve_api_key for /api/* routes but did not run the migration file
--   • You want read-only checks after applying the full v3 migration
--
-- Full v3 DDL + RPCs (run separately if not already applied):
--   migrations/20260325150000_gastroguard_v3_schema_and_rpcs.sql
--
-- API key RPC (duplicate of migrations/20260325140000_resolve_api_key_rpc.sql):
-- =============================================================================

create or replace function public.resolve_api_key(p_api_key text)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select user_id
  from public.profiles
  where integrations @> jsonb_build_array(
    jsonb_build_object('apiKey', p_api_key)
  )
  limit 1;
$$;

comment on function public.resolve_api_key(text) is
  'Resolves an integration API key (gg_...) to the owning user_id. '
  'Returns NULL if the key is not found. Called by /api/* routes.';

grant execute on function public.resolve_api_key(text) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Read-only verification (optional — expect non-zero rows where noted)
-- -----------------------------------------------------------------------------
-- Function exists
-- select proname from pg_proc where proname = 'resolve_api_key';

-- v3 tables exist
-- select table_name from information_schema.tables
--   where table_schema = 'public'
--     and table_name in (
--       'daily_feature_rollups',
--       'rolling_feature_snapshots',
--       'recommendation_items',
--       'model_features',
--       'prediction_outputs',
--       'food_tags'
--     )
--   order by table_name;

-- Sample: rollups for your user (replace USER_UUID)
-- select * from public.daily_feature_rollups where user_id = 'USER_UUID'::uuid order by feature_date desc limit 5;

-- Sample: recommendation rows
-- select title, recommendation_type, confidence, generated_at
--   from public.recommendation_items where user_id = 'USER_UUID'::uuid order by generated_at desc limit 10;
