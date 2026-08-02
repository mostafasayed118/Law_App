-- 02_rls_functions.sql — P2 reviewed migration (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Helper functions + signup trigger + expiry cleanup (security definer).
-- Source of truth: docs/p2_schema_rls_design.md §5.1 + §4.2 (gate-approved).
-- Rollback: 02_rls_functions.down.sql (same directory).

begin;

-- 5.1 Helper: single unambiguous active-membership rule (contract §3.3).
-- Suspended/removed memberships never authorize anything (status = 'active').
-- SETOF (amended, rehearsal finding R-2): a single-composite return made
-- `exists(select 1 from fn())` always true even when no row matched — the
-- cross-tenant SELECT leak. SETOF yields zero rows on no match, so
-- is_active_member()/has_org_role() correctly return false for non-members.
create or replace function public.active_membership(p_org uuid)
returns setof public.memberships
language sql stable security definer set search_path = public as $$
  select * from public.memberships
  where organization_id = p_org
    and user_id = auth.uid()
    and status = 'active'
  limit 1
$$;

create or replace function public.is_active_member(p_org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.active_membership(p_org))
$$;

create or replace function public.has_org_role(p_org uuid, p_role public.org_role)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.active_membership(p_org)
                 where role = p_role)
$$;

create or replace function public.is_platform_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_config where owner_user_id = auth.uid())
$$;

-- Audit writer helper: single append-only insert path used by every RPC and
-- trigger, so redaction and the null-actor/system-actor convention (Q6) are
-- enforced in one place. Security definer: callers may insert into audit
-- even though they hold no direct grant.
create or replace function public.write_audit(
  p_action           text,
  p_outcome          text,
  p_organization_id  uuid default null,
  p_resource_type    text default null,
  p_resource_id      uuid default null,
  p_correlation_id   uuid default null,
  p_redacted_summary text default null,
  p_actor            uuid default auth.uid()  -- pass NULL for machine events (Q6)
) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_events (
    actor_user_id, action, outcome, organization_id,
    resource_type, resource_id, correlation_id, redacted_summary
  ) values (
    p_actor, p_action, p_outcome, p_organization_id,
    p_resource_type, p_resource_id, p_correlation_id, p_redacted_summary
  );
end;
$$;

-- 4.2 signup trigger: profile row created server-side (contract §7 INSERT
-- rule). Security definer so it can write profiles; Q6: machine-generated
-- event with null actor + 'system:' prefix.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, display_name, locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.email),
    coalesce(new.raw_user_meta_data ->> 'locale', 'en')
  );
  perform public.write_audit(
    'system:profile_created', 'allowed',
    p_resource_type => 'profile', p_resource_id => new.id,
    p_redacted_summary => 'profile row created from signup trigger',
    p_actor => null
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Invitation-expiry cleanup (Q6): flips stale pending invites to 'expired'.
-- Callable only by a privileged path (pg_cron or a reviewed maintenance RPC);
-- acceptance also re-checks expiry server-side, so cleanup is belt-and-braces.
create or replace function public.expire_stale_invitations()
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_count integer;
begin
  update public.invitations
     set status = 'expired'
   where status = 'pending' and expires_at <= now();
  get diagnostics v_count = row_count;
  if v_count > 0 then
    perform public.write_audit(
      'system:invitation_expired', 'allowed',
      p_resource_type => 'invitation',
      p_redacted_summary => v_count || ' invitation(s) expired',
      p_actor => null
    );
  end if;
  return v_count;
end;
$$;

-- Default-deny on EXECUTE: Postgres grants EXECUTE to PUBLIC on new functions
-- unless revoked, and Supabase hosting additionally grants EXECUTE to anon,
-- authenticated and service_role on every new public function via
-- pg_default_acl (rehearsal finding R-3). Every one of these is security
-- definer, so a client-executable helper would let anon or authenticated call
-- them. write_audit in particular would let any caller forge audit rows
-- claiming any actor (audit-integrity break, contract §8) and
-- expire_stale_invitations would let anyone flip invite statuses. Default-deny:
-- nothing is granted to authenticated here; service_role retains EXECUTE
-- (trusted backend role). RPCs and triggers call these helpers from definer
-- context — no client grant is needed for them. Two read-only helpers are
-- re-opened below because RLS policy quals need them (R-4).
revoke execute on function public.write_audit(
  text, text, uuid, text, uuid, uuid, text, uuid
) from public, anon, authenticated;
revoke execute on function public.expire_stale_invitations() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.active_membership(uuid) from public, anon, authenticated;
revoke execute on function public.is_active_member(uuid) from public, anon, authenticated;
revoke execute on function public.has_org_role(uuid, public.org_role) from public, anon, authenticated;
revoke execute on function public.is_platform_owner() from public, anon, authenticated;

-- Policy-evaluation grants (R-4, amended 2026-08-01): Postgres RLS policy quals
-- execute as the QUERYING role, so a function called inside a policy requires
-- that role's EXECUTE — SECURITY DEFINER changes the body's privilege context,
-- not the caller's right to invoke. The policy quals reference exactly two
-- read-only, auth.uid()-self-scoped helpers:
--   organizations_select_active_member  -> is_active_member(id)
--   memberships_select_org_roster       -> is_active_member(organization_id)
--   invitations_select_partner          -> has_org_role(organization_id,'partner')
-- Without these grants every policy-gated read errors (r3 rehearsal finding
-- R-4). active_membership is NOT granted — it is only invoked from inside the
-- security-definer bodies above, so no client grant is needed.
-- NOTE: these grants also expose both helpers as PostgREST /rpc/ endpoints.
-- Intentional and safe: both are auth.uid()-self-scoped (a caller can only
-- learn facts about themselves; no cross-tenant data, no forge surface).
grant execute on function public.is_active_member(uuid) to authenticated;
grant execute on function public.has_org_role(uuid, public.org_role) to authenticated;

-- Hardening (R-3): revoke the hosting's default EXECUTE grant so future public
-- functions created by this role do not inherit anon/authenticated EXECUTE.
-- service_role and postgres are intentionally left intact (trusted backend);
-- explicit grants remain possible. Paired revert in the .down.sql.
alter default privileges in schema public
  revoke execute on functions from anon, authenticated;

commit;
