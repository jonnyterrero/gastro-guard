-- Grant SELECT on v_user_timeline so authenticated users can query it
grant select on public.v_user_timeline to anon;
grant select on public.v_user_timeline to authenticated;
