-- =============================================================================
-- resolve_api_key(p_api_key text) → uuid
-- Used by /api/* routes to authenticate external integrations.
-- SECURITY DEFINER so it can search all profiles rows without a user session.
-- Returns the user_id if the key exists, NULL otherwise.
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

-- Allow anon + authenticated to call it (API routes use anon key on server)
grant execute on function public.resolve_api_key(text) to anon, authenticated;
