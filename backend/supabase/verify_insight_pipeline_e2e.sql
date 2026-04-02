-- =============================================================================
-- GastroGuard: insight pipeline E2E checks (read-only queries + instructions)
--
-- RPCs (`refresh_user_insight_engine`, `refresh_user_analytics`, …) are
-- SECURITY INVOKER and require auth.uid() = p_user_id. You cannot validate
-- them from the SQL Editor as postgres unless you simulate a JWT:
--
--   select set_config('request.jwt.claim.sub', '<YOUR_USER_UUID>', true);
--   select set_config('request.jwt.claim.role', 'authenticated', true);
--   select public.refresh_user_insight_engine('<YOUR_USER_UUID>'::uuid,
--     current_date - 30, current_date);
--
-- Prefer the app: log a few entries, then rely on triggerFullRefresh() or call
-- the RPCs from the browser Supabase client with the user session.
--
-- After a successful run, replace USER_UUID below and run the SELECT blocks.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Run audit (latest orchestration attempts)
-- -----------------------------------------------------------------------------
-- select id, started_at, completed_at, status, error, window_start, window_end
-- from public.insight_engine_runs
-- where user_id = 'USER_UUID'::uuid
-- order by started_at desc
-- limit 10;

-- -----------------------------------------------------------------------------
-- 2) Normalized events (filled by triggers on log_entries — not by refresh RPCs)
-- -----------------------------------------------------------------------------
-- select count(*) as meal_events from public.meal_events where user_id = 'USER_UUID'::uuid;
-- select count(*) as symptom_events from public.symptom_events where user_id = 'USER_UUID'::uuid;
-- select count(*) as remedy_events from public.remedy_events where user_id = 'USER_UUID'::uuid;
-- select count(*) as trigger_events from public.trigger_events where user_id = 'USER_UUID'::uuid;

-- -----------------------------------------------------------------------------
-- 3) Analytics + rollups (after refresh_user_analytics or refresh_user_insight_engine)
-- -----------------------------------------------------------------------------
-- select * from public.analytics_trigger_scores where user_id = 'USER_UUID'::uuid order by window_end desc limit 20;
-- select * from public.analytics_food_scores where user_id = 'USER_UUID'::uuid order by window_end desc limit 20;
-- select * from public.analytics_time_patterns where user_id = 'USER_UUID'::uuid order by window_end desc limit 30;
-- select * from public.analytics_remedy_scores where user_id = 'USER_UUID'::uuid order by window_end desc limit 20;

-- select * from public.daily_feature_rollups where user_id = 'USER_UUID'::uuid order by feature_date desc limit 14;
-- select * from public.rolling_feature_snapshots where user_id = 'USER_UUID'::uuid order by snapshot_date desc limit 8;

-- -----------------------------------------------------------------------------
-- 4) ML / predictions (insight path — filter feature_set_version / model_version)
-- -----------------------------------------------------------------------------
-- select id, feature_set_version, created_at from public.model_features
--   where user_id = 'USER_UUID'::uuid order by created_at desc limit 5;

-- select prediction_type, score, label, model_version, predicted_at
--   from public.prediction_outputs
--   where user_id = 'USER_UUID'::uuid and model_version = 'rules-insight-v1'
--   order by predicted_at desc limit 10;

-- -----------------------------------------------------------------------------
-- 5) Recommendations (v3 vs insight_engine use different `source` values)
-- -----------------------------------------------------------------------------
-- select title, source, recommendation_type, confidence, generated_at
--   from public.recommendation_items
--   where user_id = 'USER_UUID'::uuid
--   order by generated_at desc limit 20;

-- select cache_version, generated_at, payload
--   from public.recommendation_cache
--   where user_id = 'USER_UUID'::uuid and cache_version in ('v1', 'insight-engine-meta');

-- -----------------------------------------------------------------------------
-- 6) Expectations (sanity — not hard failures)
-- -----------------------------------------------------------------------------
-- • insight_engine_runs: latest row status = ok after success; error text if ok=false JSON from RPC.
-- • prediction_outputs (rules-insight-v1): typically 3 rows per successful insight run.
-- • recommendation_items where source = 'insight_engine': may be empty if thresholds not met
--   (pain_delta, food scores, etc.) — check insight-engine-meta payload steps still ran.
-- • model_features: rows with feature_set_version = 'insight-engine-v2' from insight path;
--   'v3-rules-1' from optional build_model_features RPC only.

select 'verify_insight_pipeline_e2e.sql: uncomment queries above; see header for JWT/RPC notes.' as note;
