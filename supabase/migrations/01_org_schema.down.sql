-- 01_org_schema.down.sql — backout for 01_org_schema.sql (REVIEWED — rollback standby; not run on dev)

begin;

drop table if exists public.audit_events;
drop table if exists public.platform_config;
drop table if exists public.invitations;
drop table if exists public.memberships;
drop table if exists public.organizations;
drop table if exists public.profiles;

drop type if exists public.invitation_status;
drop type if exists public.membership_status;
drop type if exists public.org_role;

-- pgcrypto left in place deliberately: it may be shared with other features
-- and is not owned by this slice. (Its presence is non-destructive.)

commit;
