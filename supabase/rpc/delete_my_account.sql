-- rpc/delete_my_account.sql — P2 reviewed RPC (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Source of truth: docs/p2_schema_rls_design.md §5.3 + §4.6 (D-05, contract §8).
-- Backout: rpc/_down.sql.
--
-- D-05 hard-delete of the caller's identity. The audit row is written BEFORE
-- the deletion: actor FK is on delete set null, so the redacted summary
-- survives with the actor reference cleared (audit survives account deletion,
-- contract §8). profiles/memberships cascade; organizations.created_by and
-- actor columns are on delete set null, so no FK blocks the hard-delete.
-- No direct DELETE policy exists anywhere — this RPC is the only removal path.

create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.write_audit(
    'account:delete', 'allowed',
    p_resource_type => 'profile',
    p_resource_id => auth.uid(),
    p_redacted_summary => 'account deleted; audit retained (actor reference cleared)'
  );

  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
