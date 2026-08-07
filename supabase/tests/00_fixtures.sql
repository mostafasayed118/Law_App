-- ============================================================================
-- supabase/tests/00_fixtures.sql — P0C.1 policy-test battery fixtures (D-P0C2)
-- ============================================================================
-- Deterministic, idempotent fixture seeding for the P0-closure policy-test
-- battery (docs/p0_closure_scope_2026-08-05.md slice P0C.1, AC-1..AC-4).
--
-- Runs as the connection role (the ephemeral project's postgres/superuser),
-- NOT under `set role authenticated` — fixtures need privileged writes
-- (auth.users, platform_config) that no client role may perform. Every
-- battery invocation starts by re-running this file, so all 01/02/03 checks
-- see the exact baseline below regardless of how many times the battery runs
-- against the same project.
--
-- Idempotency: the file begins by deleting every fixture row (dependency-safe
-- order), then re-inserts. It may be run repeatedly with no accumulation.
--
-- Fixed UUIDs make every battery expectation readable and exact (the
-- P2 r1–r5 rehearsal evidence used deterministic synthetic identities; this
-- battery hardens that pattern into a committed artifact).
--
-- Owner row note: 03_platform_config_seed.sql carries the APPLY-TIME owner
-- token for the dev project. This battery seeds its OWN fixture owner row
-- directly (the owner of the rehearsal project), because the battery's job is
-- to prove the POSTURE — the single-account bound (D-P0C3), the grant
-- absence, the deny-rows (D-P0C1) — not to replay the dev migration mechanics.
-- ============================================================================

-- ---- 0. Reset (dependency-safe delete order: children before parents) ----
delete from public.documents;
delete from public.matters;
delete from public.memberships;
delete from public.invitations;
delete from public.organizations;
delete from public.audit_events;
delete from public.profiles;
delete from public.platform_config;
delete from auth.users;

-- ---- 1. Users (auth.users) -----------------------------------------------
-- The handle_new_user trigger (02_rls_functions.sql) fires on auth.users
-- INSERT and creates each profile row server-side; the explicit profiles
-- insert below is belt-and-braces (idempotent, independent of trigger state).
-- Dummy encrypted_password: never used for sign-in in this battery.

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
values
  ('10000000-0000-4000-8000-000000000001', 'owner@legalhub.test',   now(), '{"display_name":"Owner"}',        now(), now()),
  ('10000000-0000-4000-8000-000000000002', 'partner-a@org-a.test',  now(), '{"display_name":"Partner A"}',    now(), now()),
  ('10000000-0000-4000-8000-000000000003', 'client-a@org-a.test',   now(), '{"display_name":"Client A"}',     now(), now()),
  ('10000000-0000-4000-8000-000000000004', 'partner-b@org-b.test',  now(), '{"display_name":"Partner B"}',    now(), now()),
  ('10000000-0000-4000-8000-000000000005', 'suspended@org-a.test',  now(), '{"display_name":"Suspended A"}',  now(), now()),
  ('10000000-0000-4000-8000-000000000006', 'demo@legalhub.test',    now(), '{"display_name":"Demo Account"}', now(), now()),
  ('10000000-0000-4000-8000-000000000007', 'orphan@org-a.test',     now(), '{"display_name":"Orphan Member"}', now(), now());

-- ---- 2. Profiles (belt-and-braces; on conflict = trigger already created) --
insert into public.profiles (user_id, display_name, locale, created_at, updated_at)
values
  ('10000000-0000-4000-8000-000000000001', 'Owner',        'en', now(), now()),
  ('10000000-0000-4000-8000-000000000002', 'Partner A',    'en', now(), now()),
  ('10000000-0000-4000-8000-000000000003', 'Client A',     'en', now(), now()),
  ('10000000-0000-4000-8000-000000000004', 'Partner B',    'en', now(), now()),
  ('10000000-0000-4000-8000-000000000005', 'Suspended A',  'en', now(), now()),
  ('10000000-0000-4000-8000-000000000006', 'Demo Account', 'en', now(), now()),
  ('10000000-0000-4000-8000-000000000007', 'Orphan Member','en', now(), now())
on conflict (user_id) do nothing;

-- ---- 3. Organizations ------------------------------------------------------
insert into public.organizations (id, name, created_at)
values
  ('20000000-0000-4000-8000-000000000001', 'Org A', now()),
  ('20000000-0000-4000-8000-000000000002', 'Org B', now());

-- ---- 4. Memberships --------------------------------------------------------
-- org-a: partner_a (partner/active), member_a (client/active),
--        suspended_a (partner/SUSPENDED — proves stale access denies),
--        orphan_member (client/active — profile deleted by the 02 orphan check)
-- org-b: partner_b (partner/active)
insert into public.memberships (organization_id, user_id, role, status, created_by, created_at, updated_at)
values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'partner', 'active',    '10000000-0000-4000-8000-000000000002', now(), now()),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'client',  'active',    '10000000-0000-4000-8000-000000000002', now(), now()),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000005', 'partner', 'suspended', '10000000-0000-4000-8000-000000000002', now(), now()),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000007', 'client',  'active',    '10000000-0000-4000-8000-000000000002', now(), now()),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000004', 'partner', 'active',    '10000000-0000-4000-8000-000000000004', now(), now());

-- ---- 5. Invitations --------------------------------------------------------
-- One pending invite in org-a (partner-visible; feeds the 01 RPC roster check
-- and the 02 revoke/resend positives).
insert into public.invitations (id, organization_id, email, role, status, token_hash, expires_at, created_by, created_at)
values (
  '30000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'invite-pending@org-a.test',
  'client',
  'pending',
  repeat('a', 64),                          -- sha-256 of a token; hash only, never the literal
  now() + interval '7 days',
  '10000000-0000-4000-8000-000000000002',
  now()
);

-- ---- 6. platform_config (single-account bound, D-P0C3) ---------------------
insert into public.platform_config (owner_user_id)
values ('10000000-0000-4000-8000-000000000001');

-- Sanity: exactly one owner row (the PK/check constraint enforces it).
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt from public.platform_config;
  if v_cnt <> 1 then
    raise exception 'FIXTURE ERROR: platform_config must hold exactly 1 row, got %', v_cnt;
  end if;
end $$;

-- Sanity: org-a has exactly 4 memberships and org-b exactly 1 (the 01/02
-- roster-count expectations depend on these).
do $$
declare
  v_a bigint; v_b bigint;
begin
  select count(*) into v_a from public.memberships where organization_id = '20000000-0000-4000-8000-000000000001';
  select count(*) into v_b from public.memberships where organization_id = '20000000-0000-4000-8000-000000000002';
  if v_a <> 4 or v_b <> 1 then
    raise exception 'FIXTURE ERROR: org-a must hold 4 memberships and org-b 1, got %/%', v_a, v_b;
  end if;
end $$;

-- ---- 7. Matters (real-matters slice — the 04_matter_rls.sql battery) ------
-- Six matters exercising every policy branch of matters_select_assigned
-- (docs/matters_rls_gate_review_2026-08-07.md §4): assigned client, assigned
-- attorney, attorney-only assignment, unassigned-to-partner org-a row,
-- cross-org assignment (partner-b assigned on an org-a matter while a member
-- of org-b only), and stale-access assignment (suspended-a). All practice
-- areas come from the client PracticeArea set (the CHECK contract).
insert into public.matters
  (id, organization_id, title, practice_area, status, assigned_client_id, assigned_attorney_id, created_at, updated_at)
values
  ('40000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Matter 1', 'corporate', 'active', '10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002', now(), now()),
  ('40000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', 'Matter 2', 'civil',     'open',    '10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002', now(), now()),
  ('40000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', 'Matter 3', 'criminal',  'closed',  null,                                         '10000000-0000-4000-8000-000000000002', now(), now()),
  ('40000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', 'Matter 4', 'family',    'open',    '10000000-0000-4000-8000-000000000007', null,                                         now(), now()),
  ('40000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000001', 'Matter 5', 'corporate', 'active',  null,                                         '10000000-0000-4000-8000-000000000004', now(), now()),
  ('40000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000001', 'Matter 6', 'civil',     'open',    null,                                         '10000000-0000-4000-8000-000000000005', now(), now());

-- Reserved throwaway id used by 04_matter_rls.sql CHECK 04.09 for the
-- practice_area CHECK-violation insert: deliberately NEVER seeded (the
-- 'tax' insert fails the CHECK before any row exists). Listed here so the
-- harness's static fixture cross-ref resolves it.
--   reserved: 40000000-0000-4000-8000-00000000ffff

-- Sanity: exactly six matters seeded (the 04 count expectations depend on it).
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt from public.matters;
  if v_cnt <> 6 then
    raise exception 'FIXTURE ERROR: matters must hold 6 rows, got %', v_cnt;
  end if;
end $$;

-- ---- 8. Documents (real-documents slice — the 05_document_rls.sql battery) ------
-- Six documents, each referencing one of the six fixture matters (the
-- assignment source of truth) — exercising every policy branch of
-- documents_select_assigned (docs/documents_rls_gate_review_2026-08-07.md
-- §4): the counts the battery asserts are client-a (assigned on matters 1,2)
-- sees the docs on matters 1,2 = 2; partner-a (assigned attorney on matters
-- 1,2,3) sees 3; orphan (matter 4) sees 1. All document types come from the
-- client DocumentType set (the CHECK contract).
insert into public.documents
  (id, organization_id, matter_id, title, document_type, created_at, updated_at)
values
  ('50000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'Doc 1', 'contract',       now(), now()),
  ('50000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000002', 'Doc 2', 'brief',          now(), now()),
  ('50000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000003', 'Doc 3', 'evidence',       now(), now()),
  ('50000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000004', 'Doc 4', 'correspondence', now(), now()),
  ('50000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000005', 'Doc 5', 'contract',       now(), now()),
  ('50000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000006', 'Doc 6', 'brief',          now(), now());

-- Reserved throwaway ids used by 05_document_rls.sql (deliberately NEVER
-- seeded): 50000000-0000-4000-8000-00000000ffff (the document_type
-- CHECK-violation insert — fails before any row exists) and the org-mismatch
-- pair 40000000-0000-4000-8000-00000000fffe (temp org-b matter) +
-- 50000000-0000-4000-8000-00000000fffe (its org-mismatched document). Listed
-- here so the harness's static fixture cross-ref resolves them.

-- Sanity: exactly six documents seeded (the 05 count expectations depend on
-- it; the org-mismatch temp rows are rolled back inside the battery and
-- never reach the seeded baseline).
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt from public.documents;
  if v_cnt <> 6 then
    raise exception 'FIXTURE ERROR: documents must hold 6 rows, got %', v_cnt;
  end if;
end $$;
