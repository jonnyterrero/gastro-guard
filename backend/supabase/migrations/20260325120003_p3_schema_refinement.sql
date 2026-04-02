-- =============================================================================
-- P3 Schema refinement: profile defaults, column contracts, meal cache trigger.
--
-- Semantics (clinical):
-- NULL means "not yet provided" for optional profile fields.
-- Zero or empty string can be valid clinical values and must not be overloaded
-- as "unknown" in application logic — only NULL should mean unknown where used.
--
-- Rollback: DROP TRIGGER tr_rebuild_meal_food_tags; DROP FUNCTION rebuild_*;
--           restore profile column defaults from prior migration snapshot.
-- =============================================================================

-- Nullable profile fields: drop accidental defaults (safe if no default exists)
alter table public.profiles alter column age drop default;
alter table public.profiles alter column age set default null;

alter table public.profiles alter column height drop default;
alter table public.profiles alter column height set default null;

alter table public.profiles alter column weight drop default;
alter table public.profiles alter column weight set default null;

alter table public.profiles alter column gender drop default;
alter table public.profiles alter column gender set default null;

comment on column public.meal_events.food_tags is
  'Cache: denormalized snapshot for read/query. SoT for tag membership is meal_tags + meal_event_meal_tags; refresh via tr_rebuild_meal_food_tags or app sync.';

comment on column public.symptom_events.symptom_name is
  'Canonical symptom identifier (slug or registry key). Must match app symptom vocabulary.';

comment on column public.symptom_events.subtype is
  'Granularity qualifier within a symptom (e.g. sharp vs dull for pain). Free text; validate at app layer.';

comment on table public.symptom_tags is
  'Classification labels (e.g. GI, neurological). Array of distinct tag names per user; use with symptom_event_symptom_tags for filtering/grouping.';

comment on table public.symptom_event_symptom_tags is
  'Links symptom_events to symptom_tags for classification and filtering.';

-- Rebuild meal_events.food_tags from normalized junction + meal_tags (read-optimized cache)
create or replace function public.rebuild_meal_event_food_tags_cache()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_meal uuid;
begin
  v_meal := coalesce(new.meal_event_id, old.meal_event_id);
  if v_meal is null then
    return null;
  end if;

  update public.meal_events me
  set food_tags = coalesce(
    (
      select jsonb_agg(jsonb_build_object('tag', mt.name) order by mt.name)
      from public.meal_event_meal_tags memt
      join public.meal_tags mt on mt.id = memt.meal_tag_id
      where memt.meal_event_id = v_meal
    ),
    '[]'::jsonb
  )
  where me.id = v_meal;

  return null;
end;
$$;

drop trigger if exists tr_rebuild_meal_food_tags on public.meal_event_meal_tags;
create trigger tr_rebuild_meal_food_tags
  after insert or update or delete on public.meal_event_meal_tags
  for each row execute function public.rebuild_meal_event_food_tags_cache();

comment on function public.rebuild_meal_event_food_tags_cache() is
  'Keeps meal_events.food_tags in sync with meal_event_meal_tags for read-optimized queries.';

-- =============================================================================
-- Post-migration checklist (verification)
-- -----------------------------------------------------------------------------
-- Risk: Frontend still reads profiles.conditions / profiles.medications JSONB.
-- Verify P1: SELECT count(*) FROM log_entries WHERE jsonb_typeof(symptoms) <> 'array';
--        expect 0.
-- Verify P0: SELECT grantee FROM information_schema.role_table_grants
--        WHERE table_name='v_user_timeline' AND grantee='anon'; expect 0 rows.
-- Rollback P0: restore refresh_* bodies from backup; GRANT anon if emergency.
-- Rollback P1: ALTER TABLE ... DROP CONSTRAINT chk_* (names in p1 migration).
-- =============================================================================
