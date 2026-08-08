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
-- storage.objects rows are independent of the public tables (no FK) but
-- must be cleared before re-seed so the objects-layer counts are exact.
delete from storage.objects where bucket_id = 'matter-files';
delete from public.messages;
delete from public.files;
delete from public.message_threads;
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

-- ---- 9. Message threads (real-messages slice — the 06_message_rls.sql battery) ------
-- Six threads, each referencing one of the six fixture matters (the
-- assignment source of truth) — exercising every policy branch of
-- message_threads_select_assigned (docs/messages_rls_gate_review_2026-08-07.md
-- §4): the counts the battery asserts are client-a (assigned on matters 1,2)
-- sees the threads on matters 1,2 = 2; partner-a (assigned attorney on matters
-- 1,2,3) sees 3; orphan (matter 4) sees 1. Participants are GENERIC demo
-- display names only (D-MSR3/D-MSG4) — never an identity/availability claim,
-- no real PII by convention; message_count is the client
-- MessageThread.messageCount mapping contract.
insert into public.message_threads
  (id, organization_id, matter_id, title, participants, message_count, created_at, updated_at)
values
  ('60000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'Thread 1', '{"Demo client","Demo attorney"}', 1, now(), now()),
  ('60000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000002', 'Thread 2', '{"Demo client","Demo attorney"}', 2, now(), now()),
  ('60000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000003', 'Thread 3', '{"Demo attorney"}',             3, now(), now()),
  ('60000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000004', 'Thread 4', '{"Demo client"}',                4, now(), now()),
  ('60000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000005', 'Thread 5', '{"Demo partner"}',               5, now(), now()),
  ('60000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000006', 'Thread 6', '{"Demo counsel"}',               6, now(), now());

-- Reserved throwaway ids used by 06_message_rls.sql (deliberately NEVER
-- seeded): 60000000-0000-4000-8000-00000000ffff (the message_count
-- CHECK-violation insert — fails before any row exists) and the org-mismatch
-- pair 40000000-0000-4000-8000-00000000fffd (temp org-b matter) +
-- 60000000-0000-4000-8000-00000000fffe (its org-mismatched thread). Listed
-- here so the harness's static fixture cross-ref resolves them.

-- Sanity: exactly six threads seeded (the 06 count expectations depend on
-- it; the org-mismatch temp rows are rolled back inside the battery and
-- never reach the seeded baseline).
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt from public.message_threads;
  if v_cnt <> 6 then
    raise exception 'FIXTURE ERROR: message_threads must hold 6 rows, got %', v_cnt;
  end if;
end $$;

-- ---- 10. Files (real-storage slice — the 07_storage_rls.sql battery) ------
-- Six file METADATA rows, each referencing one of the six fixture matters
-- (the assignment source of truth) — exercising every policy branch of
-- files_select_assigned (docs/storage_rls_gate_review_2026-08-08.md §4):
-- the counts the battery asserts are client-a (assigned on matters 1,2)
-- sees the files on matters 1,2 = 2; partner-a (assigned attorney on
-- matters 1,2,3) sees 3; orphan (matter 4) sees 1. storage_path is the
-- SINGLE source of truth linking the row to its storage object (D-STR3):
-- `{org_id}/{matter_id}/{filename}` in canonical lowercase hyphenated
-- uuid::text (review §5 pin) — it MUST equal the object's `name` in the
-- objects fixture below so the follow-up download(storage_path) resolves.
insert into public.files
  (id, organization_id, matter_id, name, mime_type, size_bytes, storage_path, created_at, updated_at)
values
  ('70000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'file-1.pdf', 'application/pdf', 1024, '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf', now(), now()),
  ('70000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000002', 'file-2.pdf', 'application/pdf', 2048, '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000002/file-2.pdf', now(), now()),
  ('70000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000003', 'file-3.pdf', 'application/pdf', 3072, '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000003/file-3.pdf', now(), now()),
  ('70000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000004', 'file-4.pdf', 'application/pdf', 4096, '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000004/file-4.pdf', now(), now()),
  ('70000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000005', 'file-5.pdf', 'application/pdf', 5120, '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000005/file-5.pdf', now(), now()),
  ('70000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000006', 'file-6.pdf', 'application/pdf', 6144, '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000006/file-6.pdf', now(), now());

-- ---- 11. Storage objects (real-storage slice — the 07_storage_rls.sql battery) ------
-- Six objects in the `matter-files` bucket, one per fixture matter, with
-- `name` = the file's storage_path (the D-STR4 path encoding). The insert
-- provides ONLY the columns the platform schema accepts (verified live via
-- a read-only information_schema probe on 2026-08-08): id, bucket_id,
-- name, metadata — every column is nullable in this version, and
-- `path_tokens` is a generated column (cannot be inserted; computed from
-- name). The storage.objects RLS policy (files_storage_select) parses the
-- path segments, so the org/matter encoding here is what the battery
-- asserts on the objects layer.
insert into storage.objects (id, bucket_id, name, metadata, created_at, updated_at)
values
  ('80000000-0000-4000-8000-000000000001', 'matter-files', '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf', '{"size":1024,"mimetype":"application/pdf"}', now(), now()),
  ('80000000-0000-4000-8000-000000000002', 'matter-files', '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000002/file-2.pdf', '{"size":2048,"mimetype":"application/pdf"}', now(), now()),
  ('80000000-0000-4000-8000-000000000003', 'matter-files', '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000003/file-3.pdf', '{"size":3072,"mimetype":"application/pdf"}', now(), now()),
  ('80000000-0000-4000-8000-000000000004', 'matter-files', '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000004/file-4.pdf', '{"size":4096,"mimetype":"application/pdf"}', now(), now()),
  ('80000000-0000-4000-8000-000000000005', 'matter-files', '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000005/file-5.pdf', '{"size":5120,"mimetype":"application/pdf"}', now(), now()),
  ('80000000-0000-4000-8000-000000000006', 'matter-files', '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000006/file-6.pdf', '{"size":6144,"mimetype":"application/pdf"}', now(), now());

-- Reserved throwaway ids used by 07_storage_rls.sql (deliberately NEVER
-- seeded): 70000000-0000-4000-8000-00000000ffff (the size_bytes
-- CHECK-violation file insert — fails before any row exists); the
-- org-mismatch trio 40000000-0000-4000-8000-00000000fffc (temp org-b
-- matter) + 70000000-0000-4000-8000-00000000fffe (its org-mismatched
-- file) + 80000000-0000-4000-8000-00000000fffd (its org-mismatched
-- object); 80000000-0000-4000-8000-00000000fffe (the guessed-path
-- object — matrix §6 row 1, unknown matter id, never a real matter); and
-- the guessed path's nonexistent matter id 99999999-9999-4999-8999-999999999999
-- (deliberately NOT a fixture — the point is that no matter has it). Listed
-- here so the harness's static fixture cross-ref resolves them.

-- Sanity: exactly six files + six matter-files objects + the bucket seeded
-- (the 07 count expectations depend on it; the org-mismatch + guessed-path
-- temp rows are rolled back inside the battery and never reach the seeded
-- baseline).
do $$
declare
  v_files bigint; v_objs bigint; v_buckets bigint;
begin
  select count(*) into v_files from public.files;
  if v_files <> 6 then
    raise exception 'FIXTURE ERROR: files must hold 6 rows, got %', v_files;
  end if;
  select count(*) into v_objs from storage.objects where bucket_id = 'matter-files';
  if v_objs <> 6 then
    raise exception 'FIXTURE ERROR: matter-files must hold 6 objects, got %', v_objs;
  end if;
  select count(*) into v_buckets from storage.buckets where id = 'matter-files';
  if v_buckets <> 1 then
    raise exception 'FIXTURE ERROR: matter-files bucket must exist (07_storage.sql), got %', v_buckets;
  end if;
end $$;

-- ---- 12. Individual messages (realtime slice — the 08_message_rls.sql battery) ------
-- Messages referencing the six fixture threads (which reference the six
-- fixture matters — the assignment source of truth), exercising every policy
-- branch of messages_select_assigned (docs/realtime_rls_gate_review_2026-08-08.md
-- §4). The count per thread EQUALS the thread's own message_count column
-- (thread-1: 1 … thread-6: 6) — the schema-as-mapping-contract decision: the
-- seeded reality must match the thread metadata the client renders, and the
-- battery pins the per-thread totals (08.01 client-a sees its threads'
-- messages 1+2 = 3; 08.02 partner-a 1+2+3 = 6; 08.03 orphan 4) plus the
-- mapping-consistency check (08.12). Bodies are GENERIC non-PII demo copy
-- (D-RT4 author display names + neutral text) — never real case content by
-- convention; the body CHECK rejects empty bodies structurally.
insert into public.messages
  (id, organization_id, thread_id, author_display_name, body, sent_at, created_at, updated_at)
values
  ('90000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Demo client',  'Demo message 1-1: status update.',       now(), now(), now()),
  ('90000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000002', 'Demo client',  'Demo message 2-1: draft review.',         now(), now(), now()),
  ('90000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000002', 'Demo attorney', 'Demo message 2-2: follow-up notes.',       now(), now(), now()),
  ('90000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000003', 'Demo attorney', 'Demo message 3-1: procedural note.',       now(), now(), now()),
  ('90000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000003', 'Demo attorney', 'Demo message 3-2: reminder.',             now(), now(), now()),
  ('90000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000003', 'Demo attorney', 'Demo message 3-3: confirmation.',         now(), now(), now()),
  ('90000000-0000-4000-8000-000000000007', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000004', 'Demo client',  'Demo message 4-1: consultation request.',  now(), now(), now()),
  ('90000000-0000-4000-8000-000000000008', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000004', 'Demo client',  'Demo message 4-2: document upload note.',  now(), now(), now()),
  ('90000000-0000-4000-8000-000000000009', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000004', 'Demo client',  'Demo message 4-3: scheduling.',            now(), now(), now()),
  ('90000000-0000-4000-8000-000000000010', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000004', 'Demo client',  'Demo message 4-4: closing note.',          now(), now(), now()),
  ('90000000-0000-4000-8000-000000000011', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000005', 'Demo partner', 'Demo message 5-1: advisory draft.',        now(), now(), now()),
  ('90000000-0000-4000-8000-000000000012', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000005', 'Demo partner', 'Demo message 5-2: terms outline.',         now(), now(), now()),
  ('90000000-0000-4000-8000-000000000013', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000005', 'Demo partner', 'Demo message 5-3: next steps.',            now(), now(), now()),
  ('90000000-0000-4000-8000-000000000014', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000005', 'Demo partner', 'Demo message 5-4: review copy.',           now(), now(), now()),
  ('90000000-0000-4000-8000-000000000015', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000005', 'Demo partner', 'Demo message 5-5: final draft.',           now(), now(), now()),
  ('90000000-0000-4000-8000-000000000016', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000006', 'Demo counsel', 'Demo message 6-1: internal note.',         now(), now(), now()),
  ('90000000-0000-4000-8000-000000000017', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000006', 'Demo counsel', 'Demo message 6-2: status note.',           now(), now(), now()),
  ('90000000-0000-4000-8000-000000000018', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000006', 'Demo counsel', 'Demo message 6-3: procedural note.',       now(), now(), now()),
  ('90000000-0000-4000-8000-000000000019', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000006', 'Demo counsel', 'Demo message 6-4: reminder.',             now(), now(), now()),
  ('90000000-0000-4000-8000-000000000020', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000006', 'Demo counsel', 'Demo message 6-5: confirmation.',         now(), now(), now()),
  ('90000000-0000-4000-8000-000000000021', '20000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000006', 'Demo counsel', 'Demo message 6-6: closing note.',          now(), now(), now());

-- Reserved throwaway ids used by 08_message_rls.sql (deliberately NEVER
-- seeded): 90000000-0000-4000-8000-00000000ffff (the body CHECK-violation
-- insert — fails before any row exists) and the org-mismatch trio
-- 40000000-0000-4000-8000-00000000fffb (temp org-b matter) +
-- 60000000-0000-4000-8000-00000000fffd (its org-b thread) +
-- 90000000-0000-4000-8000-00000000fffe (its org-a message — the mismatch).
-- Listed here so the harness's static fixture cross-ref resolves them.

-- Sanity: exactly 21 messages seeded (1+2+3+4+5+6 — matching the six
-- threads' message_count columns, the mapping contract), and every thread's
-- message count equals its message_count column (08.12 pins it again
-- dynamically). The org-mismatch temp rows are rolled back inside the
-- battery and never reach the seeded baseline.
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt from public.messages;
  if v_cnt <> 21 then
    raise exception 'FIXTURE ERROR: messages must hold 21 rows, got %', v_cnt;
  end if;
end $$;
