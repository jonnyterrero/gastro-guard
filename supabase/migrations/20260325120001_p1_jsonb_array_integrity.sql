-- =============================================================================
-- P1 Type integrity: normalize JSONB array columns, then named CHECK constraints.
-- Run order: UPDATE first (data migration), then constraints.
-- Rollback: ALTER TABLE ... DROP CONSTRAINT chk_* (listed in comments below).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- log_entries
-- -----------------------------------------------------------------------------
update public.log_entries
  set symptoms = '[]'::jsonb
  where symptoms is null or jsonb_typeof(symptoms) <> 'array';

update public.log_entries
  set triggers = '[]'::jsonb
  where triggers is null or jsonb_typeof(triggers) <> 'array';

update public.log_entries
  set remedies = '[]'::jsonb
  where remedies is null or jsonb_typeof(remedies) <> 'array';

update public.log_entries
  set food_tags = '[]'::jsonb
  where food_tags is null or jsonb_typeof(food_tags) <> 'array';

-- -----------------------------------------------------------------------------
-- profiles (array-shaped JSONB)
-- -----------------------------------------------------------------------------
update public.profiles
  set allergies = '[]'::jsonb
  where allergies is null or jsonb_typeof(allergies) <> 'array';

update public.profiles
  set dietary_restrictions = '[]'::jsonb
  where dietary_restrictions is null or jsonb_typeof(dietary_restrictions) <> 'array';

update public.profiles
  set triggers = '[]'::jsonb
  where triggers is null or jsonb_typeof(triggers) <> 'array';

update public.profiles
  set effective_remedies = '[]'::jsonb
  where effective_remedies is null or jsonb_typeof(effective_remedies) <> 'array';

update public.profiles
  set integrations = '[]'::jsonb
  where integrations is null or jsonb_typeof(integrations) <> 'array';

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'conditions'
  ) then
    execute $q$
      update public.profiles
        set conditions = '[]'::jsonb
        where conditions is null or jsonb_typeof(conditions) <> 'array'
    $q$;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'medications'
  ) then
    execute $q$
      update public.profiles
        set medications = '[]'::jsonb
        where medications is null or jsonb_typeof(medications) <> 'array'
    $q$;
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- weekly_summaries
-- -----------------------------------------------------------------------------
update public.weekly_summaries
  set top_triggers = '[]'::jsonb
  where top_triggers is null or jsonb_typeof(top_triggers) <> 'array';

update public.weekly_summaries
  set top_remedies = '[]'::jsonb
  where top_remedies is null or jsonb_typeof(top_remedies) <> 'array';

update public.weekly_summaries
  set top_symptoms = '[]'::jsonb
  where top_symptoms is null or jsonb_typeof(top_symptoms) <> 'array';

-- -----------------------------------------------------------------------------
-- Named CHECK constraints (idempotent by constraint name)
-- Rollback: ALTER TABLE ... DROP CONSTRAINT <name>;
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'log_entries' and c.conname = 'chk_log_entries_symptoms_jsonb_array'
  ) then
    alter table public.log_entries add constraint chk_log_entries_symptoms_jsonb_array
      check (jsonb_typeof(symptoms) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'log_entries' and c.conname = 'chk_log_entries_triggers_jsonb_array'
  ) then
    alter table public.log_entries add constraint chk_log_entries_triggers_jsonb_array
      check (jsonb_typeof(triggers) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'log_entries' and c.conname = 'chk_log_entries_remedies_jsonb_array'
  ) then
    alter table public.log_entries add constraint chk_log_entries_remedies_jsonb_array
      check (jsonb_typeof(remedies) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'log_entries' and c.conname = 'chk_log_entries_food_tags_jsonb_array'
  ) then
    alter table public.log_entries add constraint chk_log_entries_food_tags_jsonb_array
      check (jsonb_typeof(food_tags) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_allergies_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_allergies_jsonb_array
      check (jsonb_typeof(allergies) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_dietary_restrictions_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_dietary_restrictions_jsonb_array
      check (jsonb_typeof(dietary_restrictions) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_triggers_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_triggers_jsonb_array
      check (jsonb_typeof(triggers) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_effective_remedies_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_effective_remedies_jsonb_array
      check (jsonb_typeof(effective_remedies) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_integrations_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_integrations_jsonb_array
      check (jsonb_typeof(integrations) = 'array');
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'conditions'
  ) and not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_conditions_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_conditions_jsonb_array
      check (jsonb_typeof(conditions) = 'array');
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'medications'
  ) and not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'profiles' and c.conname = 'chk_profiles_medications_jsonb_array'
  ) then
    alter table public.profiles add constraint chk_profiles_medications_jsonb_array
      check (jsonb_typeof(medications) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'weekly_summaries' and c.conname = 'chk_weekly_summaries_top_triggers_jsonb_array'
  ) then
    alter table public.weekly_summaries add constraint chk_weekly_summaries_top_triggers_jsonb_array
      check (jsonb_typeof(top_triggers) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'weekly_summaries' and c.conname = 'chk_weekly_summaries_top_remedies_jsonb_array'
  ) then
    alter table public.weekly_summaries add constraint chk_weekly_summaries_top_remedies_jsonb_array
      check (jsonb_typeof(top_remedies) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and t.relname = 'weekly_summaries' and c.conname = 'chk_weekly_summaries_top_symptoms_jsonb_array'
  ) then
    alter table public.weekly_summaries add constraint chk_weekly_summaries_top_symptoms_jsonb_array
      check (jsonb_typeof(top_symptoms) = 'array');
  end if;
end;
$$;
