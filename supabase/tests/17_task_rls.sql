-- ============================================================================
-- supabase/tests/17_task_rls.sql — task-writes battery (Gate 3 spec 2026-09-27)
--
-- Pins the task slice (supabase/migrations/17_tasks.sql +
-- supabase/policies/tasks.sql + supabase/rpc/create_task.sql +
-- advance_task_status.sql + assign_task.sql + acknowledge_task.sql):
--   - the assignment gate (active member + assigned on the matter — the
--     send_message D-SM1 shape, one hop): org-role-alone / cross-org /
--     suspended / owner / anon denies (17.04–17.08);
--   - the validation gates with the check_violation SQLSTATE (Batch B
--     convention): empty/whitespace title, unknown status, illegal
--     transition, done-terminal, dead assignee, owner assignee
--     (17.09–17.12, 17.19, 17.20);
--   - the acknowledge gate (assignee-only first-person statement — a
--     matter-assigned non-assignee is denied, 17.13) + guessed-id deny
--     (17.14), and reassignment clearing the receipt (17.21);
--   - the read policy (assigned sees fixture + committed rows; suspended /
--     cross-org see nothing, 17.16) + the org-mismatch invariant (17.17);
--   - §8: allowed writes are audited with redacted summaries; denied writes
--     write no audit row (17.01–17.03 commit exactly 4 audit rows; 17.15
--     pins the count after all deny rows).
--
-- Runs LAST in the run_battery loop (17.01–17.03 COMMIT their rows — no
-- other battery's counts are affected). Fixture anchors (00_fixtures.sql):
-- owner 10000000-…-0001 · partner-a …-0002 (org-a partner, assigned on
-- matters 1–3) · client-a …-0003 (assigned on matters 1, 2) · partner-b
-- …-0004 (org-b ONLY, assigned attorney on org-a matter 5) · suspended-a
-- …-0005 (suspended, assigned attorney on matter 6) · orphan …-0007
-- (org-a client, assigned on matter 4) · org-a 20000000-…-0001 · matters
-- 1–6 · fixture tasks c0000000-…-0001/0002 (matter 1) + …-0003 (matter 6,
-- assigned to suspended-a).
--
-- Role handling: RPC blocks run under `set role authenticated` with JWT
-- impersonation (the 01/02/03 pattern); the org-mismatch insert (17.17)
-- runs as the connection role (authenticated holds NO INSERT grant on
-- tasks — RPC-only writes — so the temp row must be seeded privileged,
-- the 13.05 pattern).
-- ============================================================================

\set ON_ERROR_STOP on

-- ############################################################################
-- 17.01 — POS: partner-a (org-a partner, assigned attorney on matter 1)
-- creates a task on matter 1 assigned to client-a. Returns the persisted
-- jsonb row (id + embedded matter title); the row persists readable.
-- COMMITTED: its audit row is asserted by 17.15.
-- ############################################################################
set role authenticated;
do $$
declare
  v_row jsonb;
  v_id  uuid;
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_row := public.create_task(
    '40000000-0000-4000-8000-000000000001', '17.01 probe',
    '10000000-0000-4000-8000-000000000003');
  v_id := (v_row->>'id')::uuid;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 17.01: create_task returned a null id';
  end if;
  if v_row->>'status' <> 'todo'
     or v_row->'matters'->>'title' is distinct from 'Matter 1' then
    raise exception 'POLICY-BATTERY FAIL 17.01: create_task row shape drift: %', v_row;
  end if;
  select count(*) into v_cnt from public.tasks where id = v_id;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 17.01: created task not readable by its creator (want 1 row, got %)', v_cnt;
  end if;
end $$;
reset role;
-- (committed — the 17.02/17.03 chain and the 17.15 audit pin need the row.)

-- ############################################################################
-- 17.02 — POS: client-a (assigned client on matter 1) advances the 17.01
-- task todo -> in_progress. Returns the new status. COMMITTED (audit row).
-- ############################################################################
set role authenticated;
do $$
declare
  v_id     uuid;
  v_status text;
  v_row    jsonb;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select id into v_id from public.tasks where title = '17.01 probe';
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 17.02: 17.01 probe task missing (non-vacuity broken)';
  end if;
  v_row := public.advance_task_status(v_id, 'in_progress');
  v_status := v_row->>'status';
  if v_status <> 'in_progress' or v_row->>'id' is distinct from v_id::text then
    raise exception 'POLICY-BATTERY FAIL 17.02: advance returned %, want in_progress row', v_row;
  end if;
end $$;
reset role;
-- (committed.)

-- ############################################################################
-- 17.03 — POS: partner-a re-assigns the 17.01 task to itself, then
-- acknowledges as the assignee. COMMITTED (2 audit rows: assign +
-- acknowledge).
-- ############################################################################
set role authenticated;
do $$
declare
  v_id  uuid;
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select id into v_id from public.tasks where title = '17.01 probe';
  perform public.assign_task(v_id, '10000000-0000-4000-8000-000000000002');
  perform public.acknowledge_task(v_id);
  select count(*) into v_cnt from public.tasks
   where id = v_id and acknowledged_by = '10000000-0000-4000-8000-000000000002'
     and acknowledged_at is not null;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 17.03: acknowledgement stamp missing (want 1 row, got %)', v_cnt;
  end if;
end $$;
reset role;
-- (committed — 4 task:* audit rows now exist: create/advance/assign/ack.)

-- ############################################################################
-- DENY ROWS — the in-function gates. Each denial raises BEFORE anything is
-- written; the battery matches by exception class so its own FAIL raise
-- always propagates (the 10.04 pattern).
-- ############################################################################

-- CHECK 17.04 — NEG (org role alone): partner-a is an ACTIVE org-a partner
-- but has NO assignment on matter 4 — creating there is denied.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_task('40000000-0000-4000-8000-000000000004', 'Org-role-alone create attempt', null);
    raise exception 'POLICY-BATTERY FAIL 17.04: org-role-alone create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: the in-function permission-denied raise
  end;
end $$;
reset role;

-- CHECK 17.05 — NEG (cross-org): partner-b is assigned attorney on org-a
-- matter 5 but an ACTIVE member of org-b ONLY — creating on matter 1 is
-- denied (the gate tests the matter's org).
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.create_task('40000000-0000-4000-8000-000000000001', 'Cross-org create attempt', null);
    raise exception 'POLICY-BATTERY FAIL 17.05: cross-org create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: the in-function permission-denied raise
  end;
end $$;
reset role;

-- CHECK 17.06 — NEG (stale access): suspended-a IS the assigned attorney on
-- matter 6 (and the assignee of fixture task 6-1) but its org-a membership
-- is 'suspended' — advancing that task is denied.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  begin
    perform public.advance_task_status('c0000000-0000-4000-8000-000000000003', 'in_progress');
    raise exception 'POLICY-BATTERY FAIL 17.06: suspended advance succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: the in-function permission-denied raise
  end;
end $$;
reset role;

-- CHECK 17.07 — NEG (platform_owner_admin): the owner (0001) is never
-- assigned anywhere — creating on matter 1 is denied with no carve-out.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.create_task('40000000-0000-4000-8000-000000000001', 'Owner create attempt', null);
    raise exception 'POLICY-BATTERY FAIL 17.07: platform_owner_admin create succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: the in-function permission-denied raise
  end;
end $$;
reset role;

-- CHECK 17.08 — NEG (unauthenticated): anon holds NO EXECUTE grant on the
-- task RPCs (each RPC file grants authenticated only), so the call is
-- denied at the privilege layer before the function body runs.
set role anon;
do $$
begin
  begin
    perform public.create_task('40000000-0000-4000-8000-000000000001', 'Anon create attempt', null);
    raise exception 'POLICY-BATTERY FAIL 17.08: anon create succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
set role authenticated;

-- CHECK 17.09 — NEG (title validation through the RPC): an empty title AND
-- a whitespace-only title are rejected with the check_violation SQLSTATE
-- (the Batch B convention — the whitespace arm is the RPC gate; the empty
-- arm matches the title CHECK mapping contract). Nothing is written.
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_task('40000000-0000-4000-8000-000000000001', '', null);
    raise exception 'POLICY-BATTERY FAIL 17.09: empty-title create succeeded';
  exception when check_violation then
    null; -- expected: title gate
  end;
  begin
    perform public.create_task('40000000-0000-4000-8000-000000000001', '   ', null);
    raise exception 'POLICY-BATTERY FAIL 17.09: whitespace-title create succeeded';
  exception when check_violation then
    null; -- expected: title trim gate
  end;
end $$;
reset role;

-- CHECK 17.10 — NEG (illegal transition): on a FRESH in-txn probe task
-- (status todo), jumping straight to done is refused with check_violation.
-- (Rolled back.)
begin;
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := (public.create_task('40000000-0000-4000-8000-000000000001', '17.10 probe', null)->>'id')::uuid;
  begin
    perform public.advance_task_status(v_id, 'done');
    raise exception 'POLICY-BATTERY FAIL 17.10: illegal todo->done transition succeeded';
  exception when check_violation then
    null; -- expected: transition gate
  end;
end $$;
reset role;
rollback;

-- CHECK 17.11 — NEG (dead assignee, F2-D4): partner-b is an ACTIVE member
-- of org-b ONLY — assigning them to the matter-1 probe task is refused
-- with check_violation (a non-member assignee could never read the task).
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select id into v_id from public.tasks where title = '17.01 probe';
  begin
    perform public.assign_task(v_id, '10000000-0000-4000-8000-000000000004');
    raise exception 'POLICY-BATTERY FAIL 17.11: dead-assignee assign succeeded';
  exception when check_violation then
    null; -- expected: F2-D4 active-member guard
  end;
end $$;
reset role;

-- CHECK 17.12 — NEG (owner assignee, F2-D2): assigning the platform owner
-- is refused with check_violation (the Q4 residual state cannot be created
-- through this RPC either).
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select id into v_id from public.tasks where title = '17.01 probe';
  begin
    perform public.assign_task(v_id, '10000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 17.12: owner-assignee assign succeeded';
  exception when check_violation then
    null; -- expected: F2-D2 owner refusal
  end;
end $$;
reset role;

-- CHECK 17.13 — NEG (acknowledge is first-person): client-a IS assigned on
-- matter 1 but is NOT the assignee of the 17.01 probe task (partner-a is,
-- since 17.03) — acknowledging is denied with permission denied.
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select id into v_id from public.tasks where title = '17.01 probe';
  begin
    perform public.acknowledge_task(v_id);
    raise exception 'POLICY-BATTERY FAIL 17.13: non-assignee acknowledge succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: assignee-only gate
  end;
end $$;
reset role;

-- CHECK 17.14 — NEG (guessed id): advancing a nonexistent task id is denied
-- (no existence oracle — same typed denial as an unauthorized row).
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.advance_task_status('c0000000-0000-4000-8000-00000000ffff', 'in_progress');
    raise exception 'POLICY-BATTERY FAIL 17.14: guessed-id advance succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: permission denied (Q4: no oracle)
  end;
end $$;
reset role;

-- CHECK 17.15 — NEG (§8 negative): after all the deny rows, exactly the
-- four POS writes' audit rows exist — a denied write writes NO audit row
-- (every gate raises before the insert/update and the write_audit call).
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from public.audit_events
   where action like 'task:%';
  if v_cnt <> 4 then
    raise exception 'POLICY-BATTERY FAIL 17.15: task:* audit rows = % after the deny rows, want exactly 4 (only successful writes are audited)', v_cnt;
  end if;
end $$;

-- ############################################################################
-- READ ROWS — the tasks_select_assigned policy on the committed + fixture
-- rows.
-- ############################################################################

-- CHECK 17.16 — POS + NEG (read): client-a (assigned client on matter 1)
-- sees exactly the 3 matter-1 tasks (2 fixtures + the 17.01 probe);
-- partner-b (org-b only) and suspended-a (suspended) see ZERO tasks.
set role authenticated;
do $$
declare
  v_client bigint; v_cross bigint; v_susp bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_client from public.tasks;
  if v_client <> 3 then
    raise exception 'POLICY-BATTERY FAIL 17.16: client-a sees % tasks, want 3 (2 fixtures + 17.01 probe)', v_client;
  end if;
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  select count(*) into v_cross from public.tasks;
  if v_cross <> 0 then
    raise exception 'POLICY-BATTERY FAIL 17.16: partner-b (cross-org) sees % tasks, want 0', v_cross;
  end if;
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  select count(*) into v_susp from public.tasks;
  if v_susp <> 0 then
    raise exception 'POLICY-BATTERY FAIL 17.16: suspended-a sees % tasks, want 0 (incl. its matter-6 fixture row)', v_susp;
  end if;
end $$;
reset role;

-- CHECK 17.17 — NEG (privileged half, org-mismatch): a temp org-b matter
-- with a temp task whose organization_id (org-a) does NOT match its
-- matter's org (org-b). Client-a is an org-a member AND assigned on
-- matter 1 — without the org-equality clause the exists COULD grant via
-- matter 1? No: the exists anchors on the task's OWN matter (the temp
-- org-b one), on which client-a is not assigned — plus the org clause
-- denies first. Count 0 proves "a task is never readable when its matter
-- is not". All temp rows roll back.
begin;
insert into public.matters
  (id, organization_id, title, practice_area, status, assigned_client_id, created_at, updated_at)
values
  ('40000000-0000-4000-8000-00000000fff9', '20000000-0000-4000-8000-000000000002', 'Mismatch matter', 'civil', 'open', '10000000-0000-4000-8000-000000000003', now(), now());
insert into public.tasks
  (id, organization_id, matter_id, title, status, created_at, updated_at)
values
  ('c0000000-0000-4000-8000-00000000fff2', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-00000000fff9', 'mismatch task', 'todo', now(), now());
set role authenticated;
do $$
declare
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select count(*) into v_cnt
    from public.tasks
   where id = 'c0000000-0000-4000-8000-00000000fff2';
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 17.17: org-mismatch task (path org != matter org) was readable';
  end if;
end $$;
reset role;
rollback;

-- CHECK 17.18 — NEG (connection role, title CHECK): a DIRECT INSERT with an
-- empty title is refused by the title CHECK — the mapping contract holds at
-- the data layer for ANY path, this RPC included. (Rolled back.)
begin;
do $$
begin
  begin
    insert into public.tasks
      (organization_id, matter_id, title, status)
    values
      ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '', 'todo');
    raise exception 'POLICY-BATTERY FAIL 17.18: empty-title direct INSERT bypassed the CHECK';
  exception when check_violation then
    null; -- expected: tasks_title_check
  end;
end $$;
rollback;

-- CHECK 17.19 — NEG (done is terminal): an in-txn probe task walks the full
-- legal chain todo -> in_progress -> done, then one more advance is refused
-- with check_violation. (Rolled back.)
begin;
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_id := (public.create_task('40000000-0000-4000-8000-000000000001', '17.19 probe', null)->>'id')::uuid;
  perform public.advance_task_status(v_id, 'in_progress');
  perform public.advance_task_status(v_id, 'done');
  begin
    perform public.advance_task_status(v_id, 'todo');
    raise exception 'POLICY-BATTERY FAIL 17.19: advance from done succeeded';
  exception when check_violation then
    null; -- expected: terminal-state gate
  end;
end $$;
reset role;
rollback;

-- CHECK 17.20 — NEG (unknown status): advancing to a value outside the enum
-- is refused with check_violation before the transition logic runs.
set role authenticated;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select id into v_id from public.tasks where title = '17.01 probe';
  begin
    perform public.advance_task_status(v_id, 'archived');
    raise exception 'POLICY-BATTERY FAIL 17.20: unknown-status advance succeeded';
  exception when check_violation then
    null; -- expected: status-domain gate
  end;
end $$;
reset role;

-- CHECK 17.21 — POS (reassignment clears the receipt): partner-a assigns the
-- 17.01 task to client-a, client-a acknowledges, then partner-a re-assigns it
-- back to itself. The new assignee must not inherit the previous receipt.
-- (Rolled back — the committed 17.01 row is unchanged.)
begin;
set role authenticated;
do $$
declare
  v_id  uuid;
  v_ack timestamptz;
  v_by  uuid;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  select id into v_id from public.tasks where title = '17.01 probe';
  perform public.assign_task(v_id, '10000000-0000-4000-8000-000000000003');
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  perform public.acknowledge_task(v_id);
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  perform public.assign_task(v_id, '10000000-0000-4000-8000-000000000002');
  select acknowledged_at, acknowledged_by into v_ack, v_by
    from public.tasks where id = v_id;
  if v_ack is not null or v_by is not null then
    raise exception 'POLICY-BATTERY FAIL 17.21: reassignment inherited the previous receipt (%, %)', v_ack, v_by;
  end if;
end $$;
reset role;
rollback;
