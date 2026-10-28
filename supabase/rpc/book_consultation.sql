-- rpc/book_consultation.sql — audited consultation booking.
-- Source of truth: the ratified booking design for this wave.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- The only write path for consultations. Follows the send_message /
-- create_task precedents:
--   gate — the caller must be authenticated (auth.uid() is not null); a
--          booking has no org/member gate in this slice.
--   claim — the slot is selected FOR UPDATE with the availability predicate
--          and then stamped booked_at in the same transaction, so two
--          concurrent bookers cannot both win. A missing/unavailable slot
--          raises unique_violation ('slot unavailable') — the same class as
--          the partial unique index backstop.
--   validation — category is the CHECK contract allow-list; topic and
--          attorney_ref are trimmed and length-capped at 2000/100, all
--          raised with check_violation (the Batch B convention).
--   reference — server-generated 'LH-' + 8 uppercase hex chars; never
--          client-supplied.
--   §8 audit — one redacted 'consultation:book/allowed' row with a NULL
--          organization_id (bookings are not org-scoped) and the resource id.
--   response — ONLY the non-PII projection: id, reference_id, slot_id,
--          starts_at, duration_minutes, category, status, attorney_ref.
--          topic and client_user_id are never returned.

create or replace function public.book_consultation(
  p_slot_id      uuid,
  p_category     text,
  p_topic        text,
  p_attorney_ref text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_slot         public.consultation_slots%rowtype;
  v_topic        text;
  v_attorney_ref text;
  v_id           uuid;
  v_reference    text;
begin
  if auth.uid() is null then
    raise exception 'permission denied';
  end if;

  if p_category is null
     or p_category not in ('general', 'follow_up', 'urgent') then
    raise exception 'invalid consultation category' using errcode = 'check_violation';
  end if;

  v_topic := nullif(trim(p_topic), '');
  if v_topic is not null and char_length(v_topic) > 2000 then
    raise exception 'consultation topic too long' using errcode = 'check_violation';
  end if;

  v_attorney_ref := nullif(trim(p_attorney_ref), '');
  if v_attorney_ref is not null and char_length(v_attorney_ref) > 100 then
    raise exception 'attorney reference too long' using errcode = 'check_violation';
  end if;

  -- Atomic claim: the row lock serializes competing bookers, and the
  -- predicate is re-checked for the winner. No slot = typed denial.
  select * into v_slot
    from public.consultation_slots
   where id = p_slot_id
     and is_active
     and booked_at is null
   for update;
  if not found then
    raise exception 'slot unavailable' using errcode = 'unique_violation';
  end if;

  update public.consultation_slots
     set booked_at = now()
   where id = p_slot_id;

  v_reference := 'LH-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.consultations
    (client_user_id, slot_id, category, topic, attorney_ref, status, reference_id)
  values
    (auth.uid(), p_slot_id, p_category, v_topic, v_attorney_ref, 'booked', v_reference)
  returning id into v_id;

  -- §8 audit (contract): redacted summary only — never the topic.
  perform public.write_audit(
    'consultation:book', 'allowed',
    p_organization_id  => null,
    p_resource_type    => 'consultation',
    p_resource_id      => v_id,
    p_redacted_summary => 'consultation booked'
  );

  -- Non-PII projection only: no topic, no client_user_id.
  return jsonb_build_object(
    'id',               v_id,
    'reference_id',     v_reference,
    'slot_id',          v_slot.id,
    'starts_at',        v_slot.starts_at,
    'duration_minutes', v_slot.duration_minutes,
    'category',         p_category,
    'status',           'booked',
    'attorney_ref',     v_attorney_ref
  );
end;
$$;

revoke execute on function public.book_consultation(uuid, text, text, text) from public, anon;
grant execute on function public.book_consultation(uuid, text, text, text) to authenticated;
