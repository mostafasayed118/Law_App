-- 34_polish_profile_and_deletion.sql — profile update + honest account deletion
-- (NOT APPLIED — rehearse on a disposable cluster first)
--
-- Two changes needed by the Polish pass:
--
-- 1. update_my_profile(): migration 30 made `profiles` mutations RPC-only, and
--    no RPC ever filled the gap. The profile screen is read-only in the shipped
--    app because there is no server path for a display-name edit. This RPC owns
--    the caller from auth.uid() and audits the change, as handle_new_user and
--    delete_my_account already do.
--
-- 2. delete_my_account(): the existing RPC hard-deletes auth.users and the FK
--    cascades remove profiles, memberships and library user data. Executed
--    against a disposable Postgres on 2026-11-16, that left two gaps:
--      * storage.objects rows owned by the caller SURVIVED (orphaned bytes),
--        and so did their public.files metadata;
--      * the membership cascade BYPASSED remove_membership's last-active-partner
--        guard, so an org could be left with zero active partners;
--      * the platform owner could not delete at all (raw 23503 from
--        platform_config.owner_user_id).
--    This version removes the caller's own bytes and metadata first, refuses
--    the two governance-invalid cases with stable codes, and only then deletes
--    the identity. It is still a SECURITY DEFINER RPC, so an authenticated
--    client using the anon key can call it — no service role is involved.
--
--    It does NOT delete objects owned by other people in the caller's orgs, and
--    it cannot touch provider-side data (LiveKit rooms, Paymob records, AI
--    research runs at the provider). The in-app message must say what actually
--    happened rather than claiming a generic "fully deleted" (ADR-0011).
--
-- The body is kept byte-identical to supabase/rpc/delete_my_account.sql, which
-- is applied later by a fresh rehearsal: migration = deployed delta, rpc file =
-- canonical current definition. If one changes, both must change.
--
-- Rollback: 34_polish_profile_and_deletion.down.sql.

begin;

create or replace function public.update_my_profile(p_display_name text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text := btrim(p_display_name);
begin
  if v_name is null or length(v_name) < 2 or length(v_name) > 120 then
    raise exception 'legal_profile_invalid_display_name' using errcode = '22023';
  end if;
  if v_name ~ '[[:cntrl:]]' then
    raise exception 'legal_profile_invalid_display_name' using errcode = '22023';
  end if;

  update public.profiles
     set display_name = v_name,
         updated_at   = now()
   where user_id = auth.uid();
  if not found then
    raise exception 'legal_profile_not_found' using errcode = 'P0002';
  end if;

  perform public.write_audit(
    'profile:update', 'allowed',
    p_resource_type => 'profile',
    p_resource_id => auth.uid(),
    p_redacted_summary => 'profile display name updated; value not logged'
  );
end;
$$;

revoke all on function public.update_my_profile(text) from public, anon;
grant execute on function public.update_my_profile(text) to authenticated;

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

  -- The platform owner row is NOT NULL and references auth.users. Refuse early
  -- with a stable code so the UI can say "transfer ownership first" instead of
  -- showing a raw foreign-key violation.
  if exists (select 1 from public.platform_config where owner_user_id = v_user) then
    raise exception 'account_deletion_platform_owner' using errcode = '23514';
  end if;

  -- remove_membership enforces this for a normal removal, but the cascade from
  -- auth.users would skip that RPC. Do not leave an organization ownerless.
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

  -- Audit before deletion: the actor FK is ON DELETE SET NULL, so the redacted
  -- summary survives with the actor reference cleared (contract §8).
  perform public.write_audit(
    'account:delete', 'allowed',
    p_resource_type => 'profile',
    p_resource_id => v_user,
    p_redacted_summary => 'account deleted; audit retained (actor reference cleared)'
  );

  -- Metadata first, scoped to objects THIS user owns: deleting every orphaned
  -- files row would destroy another member's metadata as collateral.
  delete from public.files f
   where exists (
     select 1 from storage.objects o
      where o.name = f.storage_path
        -- storage.objects.owner_id is TEXT on hosted Supabase but UUID on
        -- some local shapes; casting both sides keeps the predicate valid.
        and (o.owner = v_user or o.owner_id::text = v_user::text)
   );

  -- Bytes this user uploaded. Objects owned by others in the same orgs are
  -- deliberately left alone.
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

  -- Profiles, memberships and migration-33 library rows cascade from here.
  delete from auth.users where id = v_user;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

commit;
