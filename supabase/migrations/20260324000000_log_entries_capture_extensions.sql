-- =============================================================================
-- GastroGuard: capture extensions on log_entries + normalized columns
-- Hybrid rule: frontend still writes log_entries only; triggers fill the rest.
-- =============================================================================

-- A1. log_entries: structured capture (all optional / defaults)
alter table public.log_entries
  add column if not exists food_tags jsonb not null default '[]'::jsonb;
comment on column public.log_entries.food_tags is
  'Array of strings or objects {tag, category?, confidence?} for meal-linked food tagging.';

alter table public.log_entries
  add column if not exists episode_at timestamptz;
comment on column public.log_entries.episode_at is
  'When the GI episode occurred; if null, triggers use entry_at (retroactive = set both from client).';

alter table public.log_entries
  add column if not exists meal_occurred_at timestamptz;
comment on column public.log_entries.meal_occurred_at is
  'Optional meal time for this log row; if null, meal_events use coalesce(episode_at, entry_at).';

-- A2. meal_events: link tags
alter table public.meal_events
  add column if not exists food_tags jsonb not null default '[]'::jsonb;
comment on column public.meal_events.food_tags is 'Denormalized copy of tags from parent log_entries.';

-- A3. symptom_events: subtype and onset relative to meal
alter table public.symptom_events
  add column if not exists subtype text,
  add column if not exists body_region text,
  add column if not exists onset_after_meal_minutes integer
    check (onset_after_meal_minutes is null or onset_after_meal_minutes >= 0);

-- A4. remedy_events: explicit effectiveness (keep helpfulness for backward compat)
alter table public.remedy_events
  add column if not exists effectiveness_score integer
    check (effectiveness_score is null or (effectiveness_score >= 0 and effectiveness_score <= 10));
comment on column public.remedy_events.effectiveness_score is
  'Preferred analytics column; coalesce with helpfulness in queries.';

-- A5. trigger_events: optional intensity
alter table public.trigger_events
  add column if not exists intensity integer
    check (intensity is null or (intensity >= 0 and intensity <= 10));

create index if not exists idx_log_entries_user_episode_at
  on public.log_entries (user_id, episode_at desc)
  where episode_at is not null;

create index if not exists idx_symptom_events_onset_meal
  on public.symptom_events (user_id, onset_after_meal_minutes)
  where onset_after_meal_minutes is not null;
