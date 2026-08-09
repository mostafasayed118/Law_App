-- ============================================================================
-- supabase/tests/12_owner_assignment.sql — F-01 owner-assignment invariant pin
-- (docs/p4_findings_register_2026-08-09.md, F-01 step 1 — SHIPPED 2026-08-09)
--
-- CLOSES the recorded Q4 residual that the content batteries state verbatim
-- ("if an owner account were ever assigned, this policy WOULD grant — the
-- categorical matrix deny is an operational invariant, not a policy
-- guarantee; fixtures never create that state" — 04.07 / 08.08 and every
-- per-slice RLS-gate review Q4). No content policy contains an owner-deny
-- arm (is_platform_owner() is deliberately EXECUTE-revoked, R-4), so the
-- matrix §4/§5 "platform_owner_admin -> deny, always" rows rest entirely on
-- the invariant that owner accounts are never assigned. This battery turns
-- that invariant into a PINNED, non-vacuous property: the platform owner id
-- never appears in any matter assignment column or content-table uuid
-- column, so the state the Q4 residual warns about can never be seeded
-- silently — a drift that creates it fails this file loudly.
--
-- Method:
--   - The owner id is DERIVED from public.platform_config (not hardcoded),
--     so the pin tracks whatever owner row the fixtures seed (or a real
--     project's migration-seeded owner row) — self-updating, no literal.
--   - Runs as the connection role (postgres) like the fixtures: this is a
--     data-integrity pin, NOT a permission test — it must observe the
--     unfiltered rows a client role would be RLS-filtered from.
--   - 12.01/12.02 are NON-VACUITY preconditions: the deny assertions below
--     only mean something if the owner row exists and the matter assignment
--     set is non-empty.
--   - matters is the SINGLE assignment source of truth (every content
--     policy — documents/message_threads/messages/files/billing_invoices —
--     derives its grant from matters.assigned_client_id/assigned_attorney_id
--     via an exists subquery), so the 12.03–12.05 matters checks cover the
--     whole content surface; 12.06–12.10 sweep the content tables'
--     uuid columns defensively (an owner reference in an org/matter/thread
--     position would be a cross-namespace seed bug).
--
-- Source: docs/p4_findings_register_2026-08-09.md F-01 (remediation step 1);
--         threat model docs/p4_threat_model_2026-08-09.md §4.6.
-- Run AFTER 00_fixtures.sql (and after 04/05/06/07/08/10 seeds), by
-- scripts/verify_policy_tests.sh (last in the run_battery loop).
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- 12.01 — POS precondition: exactly one platform_config owner row — the
-- owner id below is derived from it, so it must be well-defined.
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt from public.platform_config;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 12.01: platform_config owner row count %, want 1', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 12.02 — POS precondition (NON-VACUOUS): at least one matter row carries an
-- assignment, so the deny checks below assert against a non-empty assignment
-- set (a check over zero rows would prove nothing).
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from public.matters
   where assigned_client_id is not null
      or assigned_attorney_id is not null;
  if v_cnt < 1 then
    raise exception 'POLICY-BATTERY FAIL 12.02: zero matter rows carry an assignment — deny assertions vacuous';
  end if;
end $$;

-- ############################################################################
-- 12.03 — NEG: the platform owner is never the assigned CLIENT on any matter.
-- ############################################################################
do $$
declare
  v_owner uuid;
  v_cnt   bigint;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  select count(*) into v_cnt from public.matters where assigned_client_id = v_owner;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 12.03: platform owner appears as assigned client on % matter(s)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 12.04 — NEG: the platform owner is never the assigned ATTORNEY on any
-- matter.
-- ############################################################################
do $$
declare
  v_owner uuid;
  v_cnt   bigint;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  select count(*) into v_cnt from public.matters where assigned_attorney_id = v_owner;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 12.04: platform owner appears as assigned attorney on % matter(s)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 12.05 — NEG (the "any matter assignment column" statement): the platform
-- owner id never appears in EITHER assignment column, in one query.
-- ############################################################################
do $$
declare
  v_owner uuid;
  v_cnt   bigint;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  select count(*) into v_cnt
    from public.matters
   where assigned_client_id = v_owner
      or assigned_attorney_id = v_owner;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 12.05: platform owner appears in a matter assignment column on % matter(s)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 12.06–12.10 — NEG (defensive sweep): the platform owner id never appears
-- in ANY uuid column of the content tables (documents / message_threads /
-- messages / files / billing_invoices). The meaningful positions are the
-- org/matter/thread columns — an owner reference there would be a
-- cross-namespace seed bug; the id-position checks are belt-and-braces.
-- ############################################################################

-- CHECK 12.06 — documents (uuid columns: id, organization_id, matter_id)
do $$
declare
  v_owner uuid;
  v_cnt   bigint;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  select count(*) into v_cnt
    from public.documents
   where id = v_owner or organization_id = v_owner or matter_id = v_owner;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 12.06: platform owner id appears in % document row(s)', v_cnt;
  end if;
end $$;

-- CHECK 12.07 — message_threads (uuid columns: id, organization_id, matter_id)
do $$
declare
  v_owner uuid;
  v_cnt   bigint;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  select count(*) into v_cnt
    from public.message_threads
   where id = v_owner or organization_id = v_owner or matter_id = v_owner;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 12.07: platform owner id appears in % message_thread row(s)', v_cnt;
  end if;
end $$;

-- CHECK 12.08 — messages (uuid columns: id, organization_id, thread_id)
do $$
declare
  v_owner uuid;
  v_cnt   bigint;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  select count(*) into v_cnt
    from public.messages
   where id = v_owner or organization_id = v_owner or thread_id = v_owner;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 12.08: platform owner id appears in % message row(s)', v_cnt;
  end if;
end $$;

-- CHECK 12.09 — files (uuid columns: id, organization_id, matter_id)
do $$
declare
  v_owner uuid;
  v_cnt   bigint;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  select count(*) into v_cnt
    from public.files
   where id = v_owner or organization_id = v_owner or matter_id = v_owner;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 12.09: platform owner id appears in % file row(s)', v_cnt;
  end if;
end $$;

-- CHECK 12.10 — billing_invoices (uuid columns: id, organization_id, matter_id)
do $$
declare
  v_owner uuid;
  v_cnt   bigint;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  select count(*) into v_cnt
    from public.billing_invoices
   where id = v_owner or organization_id = v_owner or matter_id = v_owner;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 12.10: platform owner id appears in % invoice row(s)', v_cnt;
  end if;
end $$;
