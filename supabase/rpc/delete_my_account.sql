-- rpc/delete_my_account.sql — account deletion (Polish pass, ADR-0011)
-- Source of truth for a FRESH rehearsal apply. On a project that already ran
-- the older version, migration 34 carries the identical body as the deployed
-- delta. If one changes, both must change.
--
-- What this really does, verified on a disposable Postgres 2026-11-16:
--   hard-deletes auth.users; cascades profiles, memberships and the migration-33
--   library rows; deletes the caller's file records and their metadata;
--   attempts the caller's storage objects but tolerates the hosted Supabase
--   guard (42501) so identity deletion still completes - bytes need a
--   service-role Storage-API cleanup on hosted projects;
--   refuses the platform owner and a last-active-partner with stable codes.
-- What it does NOT do: delete other people's objects in the caller's orgs, or
-- touch provider-side data (LiveKit / Paymob / AI provider). The UI message must
-- say what actually happened (ADR-0011).
--
-- Backout: rpc/_down.sql (consolidated) or
--          34_polish_profile_and_deletion.down.sql (targeted).

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if exists (select 1 from public.platform_config where owner_user_id = v_user) then
    raise exception 'account_deletion_platform_owner' using errcode = '23514';
  end if;

  if exists (
    select 1
      from public.memberships m
     where m.user_id = v_user
       and m.status = 'active'
       and m.role = 'partner'
       and not exists (
         select 1
           from public.memberships x
          where x.organization_id = m.organization_id
            and x.status = 'active'
            and x.role = 'partner'
            and x.user_id <> v_user
       )
  ) then
    raise exception 'account_deletion_last_partner' using errcode = '23514';
  end if;

  perform public.write_audit(
    'account:delete', 'allowed',
    p_resource_type => 'profile',
    p_resource_id => v_user,
    p_redacted_summary => 'account deleted; audit retained (actor reference cleared)'
  );

  delete from public.files f
   where exists (
     select 1 from storage.objects o
      where o.name = f.storage_path
        -- storage.objects.owner_id is TEXT on hosted Supabase but UUID on
        -- some local shapes; casting both sides keeps the predicate valid.
        and (o.owner = v_user or o.owner_id::text = v_user::text)
   );

  -- Hosted Supabase forbids direct DELETE on storage.objects (SQLSTATE
  -- 42501: "Use the Storage API instead"). Attempt it for local/self-hosted
  -- shapes, but never block identity deletion when the platform guard fires.
  -- The in-app deletion contract and the ADR say this explicitly: file RECORDS
  -- are removed here; stored BYTES need the operator's Storage-API cleanup.
  begin
    delete from storage.objects
     where owner = v_user or owner_id::text = v_user::text;
  exception
    when insufficient_privilege then
      raise warning 'account deletion: storage bytes require the Storage API cleanup';
  end;

  delete from auth.users where id = v_user;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
