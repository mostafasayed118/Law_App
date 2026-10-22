-- rpc/deactivate_attorney_profile.sql — owner-only directory write (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §2
--                + docs/superpowers/plans/2026-10-22-discovery.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- PLATFORM-OWNER ONLY. Soft delete: the row stays for audit/history, the read
-- policy stops exposing it, and get_attorney_profile returns 'not found' to
-- non-owners. Only an ACTIVE row transitions; a missing or already-inactive id
-- raises — the RPC is not silently idempotent.
--
-- §8 audit: redacted summary only ('attorney profile deactivated').

create or replace function public.deactivate_attorney_profile(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_cnt bigint;
begin
  if not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;

  update public.attorney_profiles
     set status     = 'inactive',
         updated_at = now()
   where id = p_id
     and status = 'active';
  get diagnostics v_cnt = row_count;
  if v_cnt = 0 then
    raise exception 'attorney profile not found or already inactive';
  end if;

  perform public.write_audit(
    'attorney_profile:deactivate', 'allowed',
    p_resource_type    => 'attorney_profile',
    p_resource_id      => p_id,
    p_redacted_summary => 'attorney profile deactivated'
  );
end;
$$;

revoke execute on function public.deactivate_attorney_profile(uuid) from public, anon;
grant execute on function public.deactivate_attorney_profile(uuid) to authenticated;
