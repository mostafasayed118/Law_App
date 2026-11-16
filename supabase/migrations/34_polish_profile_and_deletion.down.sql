-- 34_polish_profile_and_deletion.down.sql — rollback for the Polish RPC changes
-- Restores the pre-34 delete_my_account body (identity deletion only; no storage
-- cleanup, no governance guards) and drops update_my_profile. The profiles table
-- remains RPC-only as migration 30 left it.

begin;

drop function if exists public.update_my_profile(text);

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

commit;
