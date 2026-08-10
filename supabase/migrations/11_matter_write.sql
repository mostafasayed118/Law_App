-- 11_matter_write.sql — matter-write trigger hardening (REVIEWED & APPLIED — dev project, 2026-08-09)
-- Source of truth: docs/f01_step2_matter_write_design_2026-08-09.md (F2-D3)
--                + docs/p4_findings_register_2026-08-09.md (F-01 step 2).
-- Rollback: 11_matter_write.down.sql (drop trigger + function).
--
-- F2-D3 — the CATEGORICAL layer of the F-01 step 2 guarantee: no path can
-- assign the platform-owner id to a matter. The create_matter RPC (F2-D2)
-- refuses it at the RPC boundary; this trigger makes the same refusal a
-- DATA-LAYER guarantee for EVERY path — the RPC, future policy-gated
-- INSERTs, seeds, and manual fixes — because it fires for the connection
-- role too (postgres bypasses RLS, but triggers fire regardless).
--
-- The trigger is deliberately NARROW (owner-assignment only): the existing
-- demo-seed path (non-owner assignees, 04/00_fixtures) continues to work —
-- the 13 battery pins both the refusal (13.04) and the narrowness (13.05).
--
-- The function is EXECUTE-revoked from client roles; it is invoked by the
-- trigger only (the handle_new_user pattern in 02_rls_functions.sql).

begin;

create or replace function public.refuse_platform_owner_assignment()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  if new.assigned_client_id = v_owner or new.assigned_attorney_id = v_owner then
    raise exception 'platform owner cannot be assigned to a matter';
  end if;
  return new;
end;
$$;

-- Trigger-invoked only; never client-callable (the 02 helper pattern).
revoke execute on function public.refuse_platform_owner_assignment() from public, anon, authenticated;

drop trigger if exists matters_refuse_owner_assignment on public.matters;
create trigger matters_refuse_owner_assignment
  before insert or update on public.matters
  for each row execute function public.refuse_platform_owner_assignment();

commit;
