-- =============================================================================
-- GastroGuard: transactional smoke test — log_entries → normalized tables
--
-- Prerequisites: at least one row in auth.users (sign up once in the app).
-- Run in SQL Editor. Uses ROLLBACK so no permanent rows are left in log_entries.
--
-- Expect: assertion_ok = true for each check after the insert inside the txn.
-- =============================================================================

begin;

do $$
declare
  v_user uuid;
  v_entry uuid;
  v_log_day int;
  v_meals int;
  v_symptoms int;
  v_remedies int;
  v_triggers int;
begin
  select id into v_user from auth.users order by created_at asc limit 1;
  if v_user is null then
    raise exception 'No auth.users row — create an account in the app first.';
  end if;

  insert into public.log_entries (
    user_id,
    entry_at,
    entry_date,
    pain_score,
    stress_score,
    meal_name,
    meal_notes,
    symptoms,
    triggers,
    remedies
  ) values (
    v_user,
    now(),
    current_date,
    4,
    3,
    'Verify meal',
    'smoke test',
    '["nausea", {"name": "bloating", "severity": 5}]'::jsonb,
    '["stress"]'::jsonb,
    '["ginger tea"]'::jsonb
  )
  returning id into v_entry;

  select count(*) into v_log_day
  from public.log_days
  where user_id = v_user and log_date = current_date;

  select count(*) into v_meals from public.meal_events where source_entry_id = v_entry;
  select count(*) into v_symptoms from public.symptom_events where source_entry_id = v_entry;
  select count(*) into v_remedies from public.remedy_events where source_entry_id = v_entry;
  select count(*) into v_triggers from public.trigger_events where source_entry_id = v_entry;

  if v_log_day < 1 then
    raise exception 'Expected log_days row for user/date; got %', v_log_day;
  end if;
  if v_meals < 1 then
    raise exception 'Expected meal_events for meal_name; got %', v_meals;
  end if;
  if v_symptoms < 2 then
    raise exception 'Expected 2 symptom_events; got %', v_symptoms;
  end if;
  if v_remedies < 1 then
    raise exception 'Expected remedy_events; got %', v_remedies;
  end if;
  if v_triggers < 1 then
    raise exception 'Expected trigger_events; got %', v_triggers;
  end if;

  raise notice 'Smoke test passed: log_day=%, meals=%, symptoms=%, remedies=%, triggers=%',
    v_log_day, v_meals, v_symptoms, v_remedies, v_triggers;
end $$;

rollback;

select 'verify_log_entry_sync: transaction rolled back; if no error above, triggers work.' as result;
