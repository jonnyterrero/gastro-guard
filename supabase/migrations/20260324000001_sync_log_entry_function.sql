-- =============================================================================
-- Replace sync_log_entry_to_normalized: episode/meal times, food_tags, richer JSON
-- =============================================================================

create or replace function public.sync_log_entry_to_normalized(p_entry public.log_entries)
returns void as $$
declare
  v_log_day_id uuid;
  v_symptom jsonb;
  v_remedy jsonb;
  v_trigger jsonb;
  v_food_elem jsonb;
  v_name text;
  v_severity int;
  v_helpfulness int;
  v_effectiveness int;
  v_notes text;
  v_subtype text;
  v_body_region text;
  v_onset_min int;
  v_intensity int;
  v_effective_at timestamptz;
  v_meal_at timestamptz;
  v_symptom_at timestamptz;
  v_has_meal boolean;
  v_food_tags jsonb;
begin
  v_effective_at := coalesce(p_entry.episode_at, p_entry.entry_at);
  v_meal_at := coalesce(p_entry.meal_occurred_at, v_effective_at);
  v_food_tags := coalesce(p_entry.food_tags, '[]'::jsonb);

  -- 1. Upsert log_days (still keyed by entry_date on the flat row)
  insert into public.log_days (user_id, log_date)
  values (p_entry.user_id, p_entry.entry_date)
  on conflict (user_id, log_date) do update set updated_at = now()
  returning id into v_log_day_id;

  if v_log_day_id is null then
    select id into v_log_day_id from public.log_days
    where user_id = p_entry.user_id and log_date = p_entry.entry_date;
  end if;

  v_has_meal :=
    coalesce(trim(p_entry.meal_name), '') != ''
    or coalesce(trim(p_entry.meal_notes), '') != ''
    or jsonb_array_length(v_food_tags) > 0;

  -- 2. Meal event
  if v_has_meal then
    insert into public.meal_events (
      user_id, log_day_id, source_entry_id, occurred_at, meal_name, notes, food_tags
    )
    values (
      p_entry.user_id, v_log_day_id, p_entry.id, v_meal_at,
      p_entry.meal_name, p_entry.meal_notes, v_food_tags
    );
  end if;

  -- 2b. Upsert meal_tags lookup from food_tags
  for v_food_elem in select * from jsonb_array_elements(v_food_tags)
  loop
    v_name := coalesce(nullif(trim(v_food_elem->>'tag'), ''), nullif(trim(v_food_elem#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      insert into public.meal_tags (user_id, name)
      values (p_entry.user_id, v_name)
      on conflict (user_id, name) do nothing;
    end if;
  end loop;

  -- 3. Symptom events
  for v_symptom in select * from jsonb_array_elements(p_entry.symptoms)
  loop
    v_name := coalesce(nullif(trim(v_symptom->>'name'), ''), nullif(trim(v_symptom#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      v_severity := (v_symptom->>'severity')::int;
      v_notes := v_symptom->>'notes';
      v_subtype := v_symptom->>'subtype';
      v_body_region := v_symptom->>'body_region';
      v_onset_min := (v_symptom->>'onset_after_meal_minutes')::int;
      if v_onset_min is not null then
        v_symptom_at := v_effective_at + (v_onset_min * interval '1 minute');
      else
        v_symptom_at := v_effective_at;
      end if;
      insert into public.symptom_events (
        user_id, log_day_id, source_entry_id, occurred_at,
        symptom_name, severity, notes, subtype, body_region, onset_after_meal_minutes
      )
      values (
        p_entry.user_id, v_log_day_id, p_entry.id, v_symptom_at,
        v_name, v_severity, v_notes, v_subtype, v_body_region, v_onset_min
      );
    end if;
  end loop;

  -- 4. Remedy events
  for v_remedy in select * from jsonb_array_elements(p_entry.remedies)
  loop
    v_name := coalesce(nullif(trim(v_remedy->>'name'), ''), nullif(trim(v_remedy#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      v_effectiveness := coalesce(
        (v_remedy->>'effectiveness')::int,
        (v_remedy->>'effectiveness_score')::int,
        (v_remedy->>'helpfulness')::int
      );
      v_helpfulness := coalesce((v_remedy->>'helpfulness')::int, v_effectiveness);
      v_notes := v_remedy->>'notes';
      insert into public.remedy_events (
        user_id, log_day_id, source_entry_id, occurred_at,
        remedy_name, helpfulness, effectiveness_score, notes
      )
      values (
        p_entry.user_id, v_log_day_id, p_entry.id, v_effective_at,
        v_name, v_helpfulness, v_effectiveness, v_notes
      );
    end if;
  end loop;

  -- 5. Trigger events
  for v_trigger in select * from jsonb_array_elements(p_entry.triggers)
  loop
    v_name := coalesce(nullif(trim(v_trigger->>'name'), ''), nullif(trim(v_trigger#>>'{}'), ''));
    if v_name is not null and v_name != '' then
      v_notes := v_trigger->>'notes';
      v_intensity := (v_trigger->>'intensity')::int;
      insert into public.trigger_events (
        user_id, log_day_id, source_entry_id, source_type, source_ref_id,
        occurred_at, trigger_name, notes, intensity
      )
      values (
        p_entry.user_id, v_log_day_id, p_entry.id, 'entry', null,
        v_effective_at, v_name, v_notes, v_intensity
      );
    end if;
  end loop;
end;
$$ language plpgsql security invoker;
