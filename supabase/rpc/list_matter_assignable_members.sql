-- rpc/list_matter_assignable_members.sql — matter-scoped assignable-member read
-- (NOT APPLIED — rehearsal only)
-- Source of truth: task/approval-writes Gate 3 spec (2026-09-27).
-- Backout: drop function (rpc/_down.sql amendment is out of scope for this slice).
--
-- Read-only roster for the task-assignment picker. The matter is the
-- authorization anchor: the caller must BOTH be an active member of the
-- matter's org AND be assigned client or attorney on that matter — exactly the
-- create_task/assign_task gate. A failed gate returns ZERO ROWS rather than a
-- typed denial: the picker treats "not allowed" and "nothing to assign"
-- identically, so the RPC is not an existence oracle for matter ids.
--
-- Rows are ACTIVE memberships of the matter's org only (status = 'active';
-- suspended/removed never appear), joined to profiles for the display name.
-- Display-name semantics follow list_org_members_metadata (LEFT JOIN +
-- COALESCE so an orphaned membership still appears), with this list's
-- fallback label 'Member' for a missing profile or a null/blank name. The
-- platform owner is never assignable (the create_task F2-D2 rule) and is
-- excluded from the roster.
--
-- Projection is deliberately minimal: user_id + display_name only — no email,
-- no invitation token, no role. Read-only: this path writes NO audit row (§8
-- audits writes; the roster read has no side effects).
--
-- Bounded 2026-10-24 (D2): p_limit/p_offset default to 200/0 and are clamped
-- server-side to 1..500 and >= 0; the existing p_matter_id call stays valid.

create or replace function public.list_matter_assignable_members(
  p_matter_id uuid,
  p_limit     int default 200,
  p_offset    int default 0
)
returns table (
  user_id      uuid,
  display_name text
)
language sql stable security definer set search_path = public as $$
  with gate as (
    select m.organization_id as organization_id
      from public.matters m
     where m.id = p_matter_id
       and public.is_active_member(m.organization_id)
       and (m.assigned_client_id = auth.uid()
            or m.assigned_attorney_id = auth.uid())
  )
  select mb.user_id,
         coalesce(nullif(btrim(p.display_name), ''), 'Member') as display_name
    from gate g
    join public.memberships mb
      on mb.organization_id = g.organization_id
     and mb.status = 'active'
    left join public.profiles p
      on p.user_id = mb.user_id
   where not exists (
     select 1
       from public.platform_config pc
      where pc.owner_user_id = mb.user_id
   )
   order by coalesce(nullif(btrim(p.display_name), ''), 'Member'), mb.user_id
   limit least(greatest(coalesce(p_limit, 200), 1), 500)
   offset greatest(coalesce(p_offset, 0), 0)
$$;

drop function if exists public.list_matter_assignable_members(uuid);

revoke execute on function public.list_matter_assignable_members(uuid, int, int) from public, anon;
grant execute on function public.list_matter_assignable_members(uuid, int, int) to authenticated;
