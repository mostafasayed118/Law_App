-- ============================================================================
-- supabase/tests/05_document_rls.sql — real-documents policy battery (T3)
-- Source: docs/documents_rls_gate_review_2026-08-07.md §4 (the deny-rows
-- contract) + docs/documents_real_data_plan_2026-08-07.md (D-DR1/D-DR2).
--
-- Proves `documents_select_assigned` against the matrix §4 document rows
-- (documents are matter content — line 143/148):
--   - assigned client / assigned attorney ON THE DOCUMENT'S MATTER, active
--     member of the document's org -> the ONLY grant (positives + row-count
--     pins: client-a 2, partner-a 3, orphan 1);
--   - org role alone (member, no matter assignment) -> deny, every role;
--   - org-mismatch (D-DR2 load-bearing clause): a document whose
--     organization_id != its matter's org denies for every role (a document
--     is never readable when its matter is not) — privileged temp-row half;
--   - cross-org (assigned on an org-a matter, member of org-b only) -> deny;
--   - suspended membership -> deny (stale access);
--   - platform_owner_admin (never assigned) -> deny, always (Q4 residual);
--   - unauthenticated -> deny (no grant);
--   - document_type CHECK (mapping contract) -> a write path cannot insert
--     an unmapped value (privileged-path half; the client has no INSERT
--     grant);
--   - matter-delete cascade -> dropping the matter removes its documents
--     (FK on delete cascade), pinned in a rolled-back txn.
--
-- Run AFTER 00_fixtures.sql, under psql -v ON_ERROR_STOP=1, by
-- scripts/verify_policy_tests.sh (which applies 05_documents.sql +
-- policies/documents.sql to the rehearsal project first). Same impersonation
-- pattern as 01/02/03/04: set_config request.jwt.* for auth.uid().
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- Privileged-path half (runs as the connection role — postgres): the facts
-- no client role can observe because it holds no INSERT/DELETE grant.
-- ############################################################################

-- CHECK 05.10 — NEG (privileged half): the document_type CHECK is the mapping
-- contract — an unmapped value is rejected even by a privileged writer, so no
-- future write path (RPC/seed) can ever insert a value the client's
-- DocumentType enum cannot map.
begin;
do $$
begin
  begin
    insert into public.documents
      (id, organization_id, matter_id, title, document_type)
    values
      ('50000000-0000-4000-8000-00000000ffff', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'Bad type', 'tax');
    raise exception 'POLICY-BATTERY FAIL 05.10: document_type CHECK accepted an unmapped value';
  exception when check_violation then
    null; -- expected: CHECK rejected 'tax'
  end;
end $$;
rollback;

-- CHECK 05.11 — POS (privileged half): matter-delete cascade — dropping the
-- matter removes its documents (FK on delete cascade), so a matter teardown
-- can never strand orphaned document rows. Deletes matter-1 (which holds
-- fixture doc-1) so the cascade is actually exercised, not vacuous.
begin;
do $$
declare
  v_cnt bigint;
begin
  delete from public.matters where id = '40000000-0000-4000-8000-000000000001';
  select count(*) into v_cnt
    from public.documents
   where matter_id = '40000000-0000-4000-8000-000000000001';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 05.11: % documents survived the matter delete', v_cnt;
  end if;
end $$;
rollback;

-- CHECK 05.05 — NEG (privileged half, org-mismatch / D-DR2 load-bearing
-- clause): insert a temp org-b matter assigned to partner-a, then a temp
-- document whose organization_id (org-a) does NOT match its matter's org
-- (org-b). Partner-a is an org-a member AND assigned on the matter — without
-- the m.organization_id = documents.organization_id clause the exists would
-- grant; the clause must deny, proving "a document is never readable when
-- its matter is not" (matrix line 148). All temp rows roll back.
begin;
insert into public.matters
  (id, organization_id, title, practice_area, status, assigned_attorney_id, created_at, updated_at)
values
  ('40000000-0000-4000-8000-00000000fffe', '20000000-0000-4000-8000-000000000002', 'Mismatch matter', 'civil', 'open', '10000000-0000-4000-8000-000000000002', now(), now());
insert into public.documents
  (id, organization_id, matter_id, title, document_type, created_at, updated_at)
values
  ('50000000-0000-4000-8000-00000000fffe', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-00000000fffe', 'Mismatch doc', 'contract', now(), now());
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.documents
   where id = '50000000-0000-4000-8000-00000000fffe';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 05.05: org-mismatch document was readable';
  end if;
end $$;
reset role;
rollback;

set role authenticated;

-- ############################################################################
-- Positives — assigned client / assigned attorney ON THE DOCUMENT'S MATTER,
-- active member of the document's org (the ONLY grant, matrix §4).
-- ############################################################################

-- CHECK 05.01 — POS: client-a (org-a, client/active) sees exactly its two
-- assigned-client matters' documents (the docs on matters 1, 2) and no
-- others.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt from public.documents;
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 05.01: assigned client saw % documents, want 2', v_cnt;
  end if;
end $$;

-- CHECK 05.02 — POS: partner-a (org-a, partner/active) sees exactly its three
-- assigned-attorney matters' documents (matters 1, 2, 3) — the count proves
-- no blanket org access (doc-4, on the matter partner-a is not assigned to,
-- is NOT visible).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt from public.documents;
  if v_cnt <> 3 then
    raise exception 'POLICY-BATTERY FAIL 05.02: assigned attorney saw % documents, want 3', v_cnt;
  end if;
end $$;

-- CHECK 05.03 — POS: orphan (org-a, client/active) sees exactly the document
-- of its one assigned-client matter (4) — a row is granted by matter
-- assignment, not by membership breadth.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  select count(*) into v_cnt from public.documents;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 05.03: assigned client (orphan) saw % documents, want 1', v_cnt;
  end if;
end $$;

-- ############################################################################
-- Negatives — the matrix §4 deny rows.
-- ############################################################################

-- CHECK 05.04 — NEG (org role alone): partner-a is an ACTIVE org-a partner
-- but has NO assignment on matter-4 — its document (doc-4) is denied, proving
-- "an org role alone never grants document access" (deny for every role).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select count(*) into v_cnt
    from public.documents
   where id = '50000000-0000-4000-8000-000000000004';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 05.04: org-role-alone partner read an unassigned matter''s document';
  end if;
end $$;

-- CHECK 05.06 — NEG (cross-org): partner-b is assigned as attorney on an
-- org-a matter (5) but is an active member of org-b ONLY — membership is
-- tested against the document's org (the matter's authoritative org), so the
-- assignment grants nothing. Proves the reverse direction of the matrix line
-- "a matter in org-a cannot be accessed by an otherwise-authorized member of
-- org-b" applied to its documents.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cnt from public.documents;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 05.06: cross-org user saw % documents, want 0', v_cnt;
  end if;
end $$;

-- CHECK 05.07 — NEG (stale access): suspended-a is ASSIGNED as attorney on
-- matter-6 but its org-a membership is 'suspended' — is_active_member is the
-- status = 'active' rule, so the assignment grants nothing (the 02 hardening
-- guard extended to documents).
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_cnt from public.documents;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 05.07: suspended member saw % documents, want 0', v_cnt;
  end if;
end $$;

-- CHECK 05.08 — NEG (platform_owner_admin): the owner (0001) is never
-- assigned on any matter, so the matter gate denies its documents always.
-- RESIDUAL (design review Q4, recorded): if an owner account were ever
-- assigned on a matter, this policy WOULD grant — the categorical matrix deny
-- is an operational invariant, not a policy guarantee; fixtures never create
-- that state.
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  select count(*) into v_cnt from public.documents;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 05.08: platform_owner_admin saw % documents, want 0', v_cnt;
  end if;
end $$;

-- CHECK 05.09 — NEG (unauthenticated): anon holds NO grant on documents (the
-- 01-pattern default-deny revoke), so a raw read is denied at the privilege
-- layer — double-denied with the null-auth.uid() policy.
set role anon;
do $$
begin
  begin
    perform count(*) from public.documents;
    raise exception 'POLICY-BATTERY FAIL 05.09: anon raw SELECT on documents succeeded';
  exception when insufficient_privilege then
    null; -- expected: no grant
  end;
end $$;
set role authenticated;
