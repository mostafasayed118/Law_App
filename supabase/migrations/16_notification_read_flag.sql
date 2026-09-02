-- 16_notification_read_flag.sql — notification read-flag write RPC (DRAFT — T3 artifacts, NOT applied)
-- Source of truth: docs/notification_read_flag_slice_plan_2026-09-02.md (D-F1..D-F7, owner-approved 2026-09-02).
-- Rollback: 16_notification_read_flag.down.sql (drop function; the blanket revoke covers the grant).
--
-- The D-N6 follow-up: `is_read` becomes writable through exactly ONE RPC —
--   D-F1 — security definer + an explicit in-function gate (RLS does NOT
--           apply inside a definer function, so the gate IS the sole write
--           authorization): every targeted row must belong to an org where
--           the caller is_active_member (the same organizations gate as the
--           notifications_select_org read policy — org-wide metadata, NOT
--           the matter-assignment subquery). Rows in other orgs are
--           silently untouched; the function returns the flipped count and
--           never errors on foreign ids.
--   D-F2 — contract §8 audit: one notification:mark_read / allowed row per
--           distinct org TOUCHED (i.e. of the rows actually flipped),
--           redacted generic summary — never ids in the summary, never
--           content. Same implicit transaction as the update (an audit
--           failure rolls the mark back).
--   D-F3 — NO new table grant and NO new RLS policy (the send_message
--           D-SM3 posture mirrored): the RPC is the ONLY write path;
--           applied counts stay 13 tables / 13 RLS / 12 public policies.
--           EXECUTE revoked from public/anon, granted to authenticated
--           (RPC-EXECUTE pin 20 -> 21).
--   D-F4 — idempotent: only is_read = false rows flip; re-marking read
--           rows returns 0. The mark-read audit action is OUTSIDE the
--           producer's D-P2 map, so marking read never re-produces a feed
--           row (battery 16 pins the interplay).

begin;

create or replace function public.mark_notifications_read(
  p_notification_ids uuid[]
) returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_flipped int;
  v_orgs    uuid[];
  v_org     uuid;
begin
  -- D-F1 gate: flip only the caller's own-org, still-unread rows. The
  -- is_active_member predicate is the sole write authorization (definer
  -- bypasses RLS); foreign-org ids are invisible to this update.
  with target as (
    select n.id, n.organization_id
      from public.notifications n
     where n.id = any(p_notification_ids)
       and n.is_read = false
       and public.is_active_member(n.organization_id)
     for update
  ), flipped as (
    update public.notifications n
       set is_read = true
      from target t
     where n.id = t.id
    returning n.organization_id as org
  )
  select count(*)::int,
         coalesce(array_agg(distinct org) filter (where org is not null), '{}')
    into v_flipped, v_orgs
    from flipped;

  if v_flipped = 0 then
    return 0;
  end if;

  -- D-F2 audit: one redacted row per distinct org of the FLIPPED rows. The
  -- producer trigger fires on this insert but the action is outside its
  -- D-P2 map — no feed row is produced (battery 16 pins it).
  foreach v_org in array v_orgs loop
    perform public.write_audit(
      'notification:mark_read', 'allowed',
      p_organization_id  => v_org,
      p_resource_type    => 'notification',
      p_resource_id      => null,
      p_redacted_summary => 'notification read state updated'
    );
  end loop;

  return v_flipped;
end;
$$;

revoke execute on function public.mark_notifications_read(uuid[]) from public, anon;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;

commit;
