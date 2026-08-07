-- ============================================================================
-- supabase/tests/07_storage_rls.sql — real-storage policy battery (T3)
-- Source: docs/storage_rls_gate_review_2026-08-08.md §4 (the deny-rows
-- contract) + docs/storage_real_data_plan_2026-08-08.md (D-STR1/D-STR2).
--
-- Proves `files_select_assigned` (public.files metadata) AND
-- `files_storage_select` (storage.objects bytes) against the matrix §4
-- file rows (files are matter content — line 143/148) + §6 storage rows
-- (guessed-path download denied). EVERY positive and deny row is asserted
-- on BOTH layers:
--   - assigned client / assigned attorney ON THE FILE'S MATTER, active
--     member of the file's org -> the ONLY grant (positives + row-count
--     pins on both layers: client-a 2, partner-a 3, orphan 1);
--   - org role alone (member, no matter assignment) -> deny, every role;
--   - org-mismatch (D-STR2 load-bearing clause): a file row whose
--     organization_id != its matter's org, and an object whose PATH org
--     segment != its matter's org, deny for every role (a file/object is
--     never readable when its matter is not) — privileged temp-row half,
--     NON-VACUOUS: client-a demonstrably reads files/objects on org-a
--     matters (07.01 counts 2), so the 07.05 deny is specifically the
--     clause;
--   - cross-org (assigned on an org-a matter, member of org-b only) -> deny;
--   - suspended membership -> deny (stale access — the is_active_member
--     arm is load-bearing on the objects layer too: fixture matter 6
--     assigns suspended-a, so the objects deny genuinely requires it);
--   - platform_owner_admin (never assigned) -> deny, always (Q4 residual);
--   - unauthenticated -> deny: public.files has NO grant (insufficient
--     privilege); storage.objects HAS the platform SELECT grant, so the
--     RLS policy must deny (0 rows) — verified live via a read-only
--     has_table_privilege probe on the dev project (2026-08-08);
--   - guessed-path (matrix §6 row 1): an object under an unknown matter id
--     denies for every role (privileged temp-row half, non-vacuous);
--   - size_bytes CHECK (mapping contract) -> a write path cannot insert a
--     negative size (privileged-path half; the client has no INSERT grant);
--   - matter-delete cascade -> dropping the matter removes its files rows
--     (FK on delete cascade), pinned in a rolled-back txn (storage.objects
--     has no matters FK — the temp objects are deleted in the same txn).
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh (which applies 07_storage.sql +
-- policies/files.sql + policies/storage_objects.sql to the rehearsal
-- project first — the storage schema + matter-files bucket must exist).
-- Same impersonation pattern as 01/02/03/04/05/06: set_config
-- request.jwt.* for auth.uid().
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- Privileged-path half (runs as the connection role — postgres): the facts
-- no client role can observe because it holds no INSERT/DELETE grant.
-- ############################################################################

-- CHECK 07.10 — NEG (privileged half): the size_bytes CHECK is the mapping
-- contract — a negative size is rejected even by a privileged writer, so no
-- future write path (RPC/seed) can ever insert a size the client's
-- FileMetadata.sizeBytes (non-negative) cannot map.
begin;
do $$
begin
  begin
    insert into public.files
      (id, organization_id, matter_id, name, size_bytes, storage_path)
    values
      ('70000000-0000-4000-8000-00000000ffff', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'Bad size', -1, '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/bad.pdf');
    raise exception 'POLICY-BATTERY FAIL 07.10: size_bytes CHECK accepted a negative size';
  exception when check_violation then
    null; -- expected: CHECK rejected -1
  end;
end $$;
rollback;

-- CHECK 07.11 — POS (privileged half): matter-delete cascade — dropping the
-- matter removes its files rows (FK on delete cascade), so a matter teardown
-- can never strand orphaned file metadata. Deletes matter-1 (which holds
-- fixture file-1) so the cascade is actually exercised, not vacuous.
begin;
do $$
declare
  v_cnt bigint;
begin
  delete from public.matters where id = '40000000-0000-4000-8000-000000000001';
  select count(*) into v_cnt
    from public.files
   where matter_id = '40000000-0000-4000-8000-000000000001';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.11: % files survived the matter delete', v_cnt;
  end if;
end $$;
rollback;

-- CHECK 07.05 — NEG (privileged half, org-mismatch / D-STR2 load-bearing
-- clause, BOTH layers): insert a temp org-b matter assigned to client-a,
-- then a temp file whose organization_id (org-a) does NOT match its matter's
-- org (org-b) and a temp object whose PATH org segment (org-a) does not
-- match its matter's org (org-b). Client-a is an org-a member AND assigned
-- on the matter — without the org-equality clauses the exists would grant;
-- the clauses must deny on both layers, proving "a file/object is never
-- readable when its matter is not" (matrix line 148). NON-VACUOUS: client-a
-- reads files/objects on org-a matters generally (07.01 -> 2), so this deny
-- is the clause, not blanket non-access. All temp rows roll back.
begin;
insert into public.matters
  (id, organization_id, title, practice_area, status, assigned_client_id, created_at, updated_at)
values
  ('40000000-0000-4000-8000-00000000fffc', '20000000-0000-4000-8000-000000000002', 'Mismatch matter', 'civil', 'open', '10000000-0000-4000-8000-000000000003', now(), now());
insert into public.files
  (id, organization_id, matter_id, name, mime_type, size_bytes, storage_path, created_at, updated_at)
values
  ('70000000-0000-4000-8000-00000000fffe', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-00000000fffc', 'mismatch.pdf', 'application/pdf', 1, '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-00000000fffc/mismatch.pdf', now(), now());
insert into storage.objects (id, bucket_id, name, metadata, created_at, updated_at)
values
  ('80000000-0000-4000-8000-00000000fffd', 'matter-files', '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-00000000fffc/mismatch.pdf', '{"size":1,"mimetype":"application/pdf"}', now(), now());
set role authenticated;
do $$
declare
  v_files bigint; v_objs bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_files
    from public.files
   where id = '70000000-0000-4000-8000-00000000fffe';
  if v_files <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.05: org-mismatch file was readable';
  end if;
  select count(*) into v_objs
    from storage.objects
   where id = '80000000-0000-4000-8000-00000000fffd';
  if v_objs <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.05: org-mismatch object (path org != matter org) was readable';
  end if;
end $$;
reset role;
rollback;

-- CHECK 07.12 — NEG (privileged half, matrix §6 row 1 — guessed path): a
-- temp object whose path names an UNKNOWN matter id under an org-a folder.
-- The object EXISTS (privileged count 1 — non-vacuous); partner-a is an
-- active org-a member (the is_active_member arm passes) but the exists
-- finds no matter with that id -> denied. The same policy arms deny every
-- role by construction (owner/anon asserted separately in 07.08/07.09).
begin;
insert into storage.objects (id, bucket_id, name, metadata, created_at, updated_at)
values
  ('80000000-0000-4000-8000-00000000fffe', 'matter-files', '20000000-0000-4000-8000-000000000001/99999999-9999-4999-8999-999999999999/evil.pdf', '{"size":1,"mimetype":"application/pdf"}', now(), now());
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from storage.objects
   where id = '80000000-0000-4000-8000-00000000fffe';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 07.12: guessed-path object missing (non-vacuity broken)';
  end if;
end $$;
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from storage.objects
   where id = '80000000-0000-4000-8000-00000000fffe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.12: guessed-path object was readable (matrix §6 row 1)';
  end if;
end $$;
reset role;
rollback;

set role authenticated;

-- ############################################################################
-- Positives — assigned client / assigned attorney ON THE FILE'S MATTER,
-- active member of the file's org (the ONLY grant, matrix §4), asserted on
-- BOTH the public.files layer and the storage.objects layer.
-- ############################################################################

-- CHECK 07.01 — POS: client-a (org-a, client/active) sees exactly its two
-- assigned-client matters' files AND objects (matters 1, 2) and no others.
do $$
declare
  v_files bigint; v_objs bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_files from public.files;
  if v_files <> 2 then
    raise exception 'POLICY-BATTERY FAIL 07.01: assigned client saw % files, want 2', v_files;
  end if;
  select count(*) into v_objs from storage.objects where bucket_id = 'matter-files';
  if v_objs <> 2 then
    raise exception 'POLICY-BATTERY FAIL 07.01: assigned client saw % objects, want 2', v_objs;
  end if;
end $$;

-- CHECK 07.02 — POS: partner-a (org-a, partner/active) sees exactly its
-- three assigned-attorney matters' files AND objects (matters 1, 2, 3) —
-- the count proves no blanket org access (file/object-4, on the matter
-- partner-a is not assigned to, is NOT visible on either layer).
do $$
declare
  v_files bigint; v_objs bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_files from public.files;
  if v_files <> 3 then
    raise exception 'POLICY-BATTERY FAIL 07.02: assigned attorney saw % files, want 3', v_files;
  end if;
  select count(*) into v_objs from storage.objects where bucket_id = 'matter-files';
  if v_objs <> 3 then
    raise exception 'POLICY-BATTERY FAIL 07.02: assigned attorney saw % objects, want 3', v_objs;
  end if;
end $$;

-- CHECK 07.03 — POS: orphan (org-a, client/active) sees exactly the file
-- AND object of its one assigned-client matter (4) — a row is granted by
-- matter assignment, not by membership breadth.
do $$
declare
  v_files bigint; v_objs bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  select count(*) into v_files from public.files;
  if v_files <> 1 then
    raise exception 'POLICY-BATTERY FAIL 07.03: assigned client (orphan) saw % files, want 1', v_files;
  end if;
  select count(*) into v_objs from storage.objects where bucket_id = 'matter-files';
  if v_objs <> 1 then
    raise exception 'POLICY-BATTERY FAIL 07.03: assigned client (orphan) saw % objects, want 1', v_objs;
  end if;
end $$;

-- ############################################################################
-- Negatives — the matrix §4/§6 deny rows, each on BOTH layers.
-- ############################################################################

-- CHECK 07.04 — NEG (org role alone): partner-a is an ACTIVE org-a partner
-- but has NO assignment on matter-4 — its file-4/object-4 are denied,
-- proving "an org role alone never grants file access" (deny for every
-- role).
do $$
declare
  v_files bigint; v_objs bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_files
    from public.files
   where id = '70000000-0000-4000-8000-000000000004';
  if v_files <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.04: org-role-alone partner read an unassigned matter''s file';
  end if;
  select count(*) into v_objs
    from storage.objects
   where id = '80000000-0000-4000-8000-000000000004';
  if v_objs <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.04: org-role-alone partner read an unassigned matter''s object';
  end if;
end $$;

-- CHECK 07.06 — NEG (cross-org): partner-b is assigned as attorney on an
-- org-a matter (5) but is an active member of org-b ONLY — membership is
-- tested against the file's org (the matter's authoritative org), so the
-- assignment grants nothing on either layer. Proves the reverse direction
-- of the matrix line "a matter in org-a cannot be accessed by an
-- otherwise-authorized member of org-b" applied to its files/objects.
do $$
declare
  v_files bigint; v_objs bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_files from public.files;
  if v_files <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.06: cross-org user saw % files, want 0', v_files;
  end if;
  select count(*) into v_objs from storage.objects where bucket_id = 'matter-files';
  if v_objs <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.06: cross-org user saw % objects, want 0', v_objs;
  end if;
end $$;

-- CHECK 07.07 — NEG (stale access): suspended-a is ASSIGNED as attorney on
-- matter-6 but its org-a membership is 'suspended' — is_active_member is
-- the status = 'active' rule, so the assignment grants nothing on EITHER
-- layer. This is the load-bearing is_active_member arm on the objects
-- layer (the plan reviewer fold bad9641): without it, the path exists
-- alone would leak file-6/object-6 to the suspended user.
do $$
declare
  v_files bigint; v_objs bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_files from public.files;
  if v_files <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.07: suspended member saw % files, want 0', v_files;
  end if;
  select count(*) into v_objs from storage.objects where bucket_id = 'matter-files';
  if v_objs <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.07: suspended member saw % objects (is_active_member arm), want 0', v_objs;
  end if;
end $$;

-- CHECK 07.08 — NEG (platform_owner_admin): the owner (0001) is never
-- assigned on any matter, so the matter gate denies its files/objects
-- always, on both layers. RESIDUAL (design review Q4, recorded): if an
-- owner account were ever assigned on a matter, both policies WOULD grant —
-- the categorical matrix deny is an operational invariant, not a policy
-- guarantee; fixtures never create that state.
do $$
declare
  v_files bigint; v_objs bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_files from public.files;
  if v_files <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.08: platform_owner_admin saw % files, want 0', v_files;
  end if;
  select count(*) into v_objs from storage.objects where bucket_id = 'matter-files';
  if v_objs <> 0 then
    raise exception 'POLICY-BATTERY FAIL 07.08: platform_owner_admin saw % objects, want 0', v_objs;
  end if;
end $$;

-- CHECK 07.09 — NEG (unauthenticated): public.files holds NO grant (the
-- 01-pattern default-deny revoke in 07_storage.sql), so a raw read is
-- denied at the privilege layer. On storage.objects the outcome depends on
-- the storage schema version: the HOSTED dev project grants anon SELECT
-- (verified live via a read-only probe on 2026-08-08 — then RLS must deny,
-- auth.uid() null -> the policy arms are false -> 0 rows), while older
-- local storage schemas revoke anon entirely (insufficient_privilege).
-- BOTH outcomes are "unauthenticated denied" and each is accepted below;
-- the rehearsal host's exact posture is T4-verified, not assumed.
set role anon;
do $$
declare
  v_objs bigint;
begin
  begin
    perform count(*) from public.files;
    raise exception 'POLICY-BATTERY FAIL 07.09a: anon raw SELECT on public.files succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
  begin
    select count(*) into v_objs from storage.objects where bucket_id = 'matter-files';
    if v_objs <> 0 then
      raise exception 'POLICY-BATTERY FAIL 07.09b: anon read % objects via RLS, want 0', v_objs;
    end if;
  exception when insufficient_privilege then
    null; -- also a deny (older storage schemas revoke anon on storage.objects)
  end;
end $$;
set role authenticated;
