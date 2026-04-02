-- =============================================================================
-- P2 Source of truth: deprecate legacy JSONB on profiles (comments only) +
-- read-only compatibility view from profile_conditions / medications.
-- Does NOT drop columns.
-- =============================================================================

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'conditions'
  ) then
    execute $c$
      comment on column public.profiles.conditions is
        'DEPRECATED — SoT is profile_conditions. Do not write to this column from application code.'
    $c$;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'medications'
  ) then
    execute $c$
      comment on column public.profiles.medications is
        'DEPRECATED — SoT is medications. Do not write to this column from application code.'
    $c$;
  end if;
end;
$$;

create or replace view public.v_profile_health_legacy
  with (security_invoker = true)
as
select
  p.id,
  p.user_id,
  p.name,
  p.age,
  p.height,
  p.weight,
  p.gender,
  p.allergies,
  p.dietary_restrictions,
  p.triggers,
  p.effective_remedies,
  p.integrations,
  p.created_at,
  p.updated_at,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'condition_name', pc.condition_name,
          'notes', pc.notes,
          'diagnosed_at', pc.diagnosed_at
        )
        order by pc.created_at
      )
      from public.profile_conditions pc
      where pc.user_id = p.user_id
    ),
    '[]'::jsonb
  ) as conditions_from_normalized,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'medication_name', m.medication_name,
          'dosage', m.dosage,
          'frequency', m.frequency,
          'notes', m.notes
        )
        order by m.created_at
      )
      from public.medications m
      where m.user_id = p.user_id
    ),
    '[]'::jsonb
  ) as medications_from_normalized
from public.profiles p;

comment on view public.v_profile_health_legacy is
  'Read-only: profile scalars plus conditions/medications aggregated from normalized tables for legacy clients.';

grant select on public.v_profile_health_legacy to authenticated;
grant select on public.v_profile_health_legacy to service_role;
