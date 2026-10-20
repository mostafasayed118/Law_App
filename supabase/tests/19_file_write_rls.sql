-- ============================================================================
-- supabase/tests/19_file_write_rls.sql — matter-files write battery
--
-- Pins the write slice (supabase/migrations/19_storage_write.sql +
-- supabase/policies/storage_objects.sql insert/delete policies +
-- supabase/rpc/register_matter_file.sql + delete_matter_file.sql):
--   - register positives for the assigned client and assigned attorney,
--     using the EXISTING fixture objects (00_fixtures.sql paths), with the
--     returned jsonb row + matter title and the §8 file:create audit rows;
--   - validation denies: blank name/mime, negative size, path-prefix
--     mismatch, and a non-existent object (all check_violation);
--   - the matter-assignment gate denies: org-role-alone, cross-org,
--     suspended, owner, and anon (privilege layer);
--   - the direct-write posture: authenticated has NO INSERT/UPDATE/DELETE
--     on public.files (has_table_privilege = false);
--   - the storage policy inventory: exactly three policies on
--     storage.objects (select + insert + delete, no update);
--   - the bucket envelope pins: 25 MiB and the seven-type allow-list;
--   - delete positive removes the metadata row and returns its path, with
--     one file:delete audit row; a non-assigned delete is denied;
--   - the §8 negative: denied writes write no audit row.
--
-- The whole battery runs in ONE transaction and ROLLS BACK — it has no
-- side effects on the rehearsal baseline. Fixture anchors:
-- client-a …-0003 (assigned matter 1) · partner-a …-0002 (assigned matters
-- 1–3) · partner-b …-0004 (org-b only) · suspended-a …-0005 (matter 6) ·
-- orphan …-0007 (matter 4) · owner …-0001 · org-a 2000…-0001 · matters
-- 4000…-0001/0002/0004/0006 · objects 8000…-0001/0002 with metadata
-- size 1024/2048 and mimetype application/pdf.
--
-- Role handling: RPC blocks run under `set role authenticated` with JWT
-- impersonation (the 01/02/03 pattern); privilege, policy, bucket and audit
-- reads run as the connection role.
-- ============================================================================

\set ON_ERROR_STOP on

begin;

-- ############################################################################
-- 19.01 — POS (assigned client): client-a registers the existing matter-1
-- fixture object. Returns the persisted file row + matter title; the row is
-- readable (files_select_assigned).
-- ############################################################################
set role authenticated;
do $$
declare
  v_row jsonb;
  v_id  uuid;
  v_cnt bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  v_row := public.register_matter_file(
    '40000000-0000-4000-8000-000000000001',
    'file-1.pdf',
    'application/pdf',
    1024,
    '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf');
  v_id := (v_row -> 'file' ->> 'id')::uuid;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 19.01: register_matter_file returned a null file id';
  end if;
  if v_row -> 'file' ->> 'storage_path'
       is distinct from '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf'
     or v_row -> 'file' ->> 'mime_type' is distinct from 'application/pdf'
     or v_row -> 'file' ->> 'size_bytes' is distinct from '1024'
     or v_row ->> 'matter_title' is distinct from 'Matter 1' then
    raise exception 'POLICY-BATTERY FAIL 19.01: register projection drift: %', v_row;
  end if;
  if v_id = '70000000-0000-4000-8000-000000000001' then
    raise exception 'POLICY-BATTERY FAIL 19.01: register returned the fixture row id';
  end if;
  select count(*) into v_cnt from public.files where id = v_id;
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 19.01: registered file not readable (want 1 row, got %)', v_cnt;
  end if;
end $$;
reset role;

-- ############################################################################
-- 19.02 — POS (assigned attorney): partner-a registers the existing matter-2
-- fixture object; the returned matter title is Matter 2.
-- ############################################################################
set role authenticated;
do $$
declare
  v_row jsonb;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  v_row := public.register_matter_file(
    '40000000-0000-4000-8000-000000000002',
    'file-2.pdf',
    'application/pdf',
    2048,
    '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000002/file-2.pdf');
  if (v_row -> 'file' ->> 'id') is null
     or v_row ->> 'matter_title' is distinct from 'Matter 2'
     or v_row -> 'file' ->> 'size_bytes' is distinct from '2048' then
    raise exception 'POLICY-BATTERY FAIL 19.02: attorney register projection drift: %', v_row;
  end if;
end $$;
reset role;

-- ############################################################################
-- 19.03 — POS (§8 audit): exactly two file:create/allowed rows, each with
-- the org, the new resource id, and the redacted summary 'file uploaded'.
-- ############################################################################
do $$
declare
  v_cnt bigint; v_bad bigint;
begin
  select count(*) into v_cnt
    from public.audit_events
   where action = 'file:create'
     and outcome = 'allowed'
     and organization_id = '20000000-0000-4000-8000-000000000001'
     and redacted_summary = 'file uploaded'
     and resource_type = 'file';
  if v_cnt <> 2 then
    raise exception 'POLICY-BATTERY FAIL 19.03: file:create audit rows = %, want exactly 2', v_cnt;
  end if;
  select count(*) into v_bad
    from public.audit_events a
   where a.action = 'file:create'
     and a.outcome = 'allowed'
     and not exists (
       select 1 from public.files f
        where f.id = a.resource_id
          and f.id <> '70000000-0000-4000-8000-000000000001'
          and f.id <> '70000000-0000-4000-8000-000000000002');
  if v_bad <> 0 then
    raise exception 'POLICY-BATTERY FAIL 19.03: % file:create audit resource id(s) do not resolve to the two new rows', v_bad;
  end if;
end $$;

-- ############################################################################
-- 19.04 — NEG (validation): a blank name is refused with check_violation.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000001', '   ', 'application/pdf', 1024,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.04: blank-name register succeeded';
  exception when check_violation then
    null; -- expected: name gate
  end;
end $$;
reset role;

-- ############################################################################
-- 19.05 — NEG (validation): a blank MIME type is refused with
-- check_violation.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000001', 'file-1.pdf', '   ', 1024,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.05: blank-mime register succeeded';
  exception when check_violation then
    null; -- expected: mime gate
  end;
end $$;
reset role;

-- ############################################################################
-- 19.06 — NEG (validation): a negative size is refused with check_violation
-- (the files.size_bytes CHECK mapping contract).
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000001', 'file-1.pdf', 'application/pdf', -1,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.06: negative-size register succeeded';
  exception when check_violation then
    null; -- expected: size gate
  end;
end $$;
reset role;

-- ############################################################################
-- 19.07 — NEG (path gate): a storage path under a different matter than the
-- claimed matter id is refused with check_violation.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000001', 'file-2.pdf', 'application/pdf', 2048,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000002/file-2.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.07: mismatched-prefix register succeeded';
  exception when check_violation then
    null; -- expected: {org}/{matter}/ prefix gate
  end;
end $$;
reset role;

-- ############################################################################
-- 19.08 — NEG (object gate): a path with the right prefix but no storage
-- object is refused with check_violation.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000001', 'missing.pdf', 'application/pdf', 1024,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/missing.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.08: missing-object register succeeded';
  exception when check_violation then
    null; -- expected: storage.objects existence gate
  end;
end $$;
reset role;

-- ############################################################################
-- 19.09 — NEG (org role alone): partner-a is an active org-a partner but is
-- NOT assigned on matter 4 — register is denied.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000004', 'file-4.pdf', 'application/pdf', 4096,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000004/file-4.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.09: org-role-alone register succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: in-function permission denied
  end;
end $$;
reset role;

-- ############################################################################
-- 19.10 — NEG (cross-org): partner-b is assigned attorney on org-a matter 5
-- but an ACTIVE member of org-b only — register on matter 1 is denied.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004"}', false);
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000001', 'file-1.pdf', 'application/pdf', 1024,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.10: cross-org register succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: in-function permission denied
  end;
end $$;
reset role;

-- ############################################################################
-- 19.11 — NEG (stale access): suspended-a is assigned attorney on matter 6
-- but its org-a membership is suspended — register is denied.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005"}', false);
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000006', 'file-6.pdf', 'application/pdf', 6144,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000006/file-6.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.11: suspended register succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: in-function permission denied
  end;
end $$;
reset role;

-- ############################################################################
-- 19.12 — NEG (platform_owner_admin): the owner is never assigned anywhere
-- — register on matter 1 is denied with no carve-out.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001"}', false);
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000001', 'file-1.pdf', 'application/pdf', 1024,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.12: owner register succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: in-function permission denied
  end;
end $$;
reset role;

-- ############################################################################
-- 19.13 — NEG (unauthenticated): anon holds no EXECUTE grant on the write
-- RPCs (register + delete grant authenticated only).
-- ############################################################################
set role anon;
do $$
begin
  begin
    perform public.register_matter_file(
      '40000000-0000-4000-8000-000000000001', 'file-1.pdf', 'application/pdf', 1024,
      '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf');
    raise exception 'POLICY-BATTERY FAIL 19.13: anon register succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
  begin
    perform public.delete_matter_file('70000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 19.13: anon delete succeeded';
  exception when insufficient_privilege then
    null; -- expected: no EXECUTE grant
  end;
end $$;
reset role;

-- ############################################################################
-- 19.14 — NEG (no direct INSERT): authenticated has no INSERT grant on
-- public.files (metadata writes are RPC-only).
-- ############################################################################
do $$
begin
  if has_table_privilege('authenticated', 'public.files', 'INSERT') then
    raise exception 'POLICY-BATTERY FAIL 19.14: authenticated holds INSERT on public.files';
  end if;
end $$;

-- ############################################################################
-- 19.15 — NEG (no direct UPDATE): authenticated has no UPDATE grant on
-- public.files.
-- ############################################################################
do $$
begin
  if has_table_privilege('authenticated', 'public.files', 'UPDATE') then
    raise exception 'POLICY-BATTERY FAIL 19.15: authenticated holds UPDATE on public.files';
  end if;
end $$;

-- ############################################################################
-- 19.16 — NEG (no direct DELETE): authenticated has no DELETE grant on
-- public.files.
-- ############################################################################
do $$
begin
  if has_table_privilege('authenticated', 'public.files', 'DELETE') then
    raise exception 'POLICY-BATTERY FAIL 19.16: authenticated holds DELETE on public.files';
  end if;
end $$;

-- ############################################################################
-- 19.17 — PIN (policy inventory): exactly three policies on storage.objects
-- — the read policy + the insert/delete write policies; no UPDATE policy.
-- ############################################################################
do $$
declare
  v_total bigint; v_named bigint; v_update bigint;
begin
  select count(*) into v_total
    from pg_policies
   where schemaname = 'storage' and tablename = 'objects';
  select count(*) into v_named
    from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname in ('files_storage_select', 'files_storage_insert', 'files_storage_delete');
  select count(*) into v_update
    from pg_policies
   where schemaname = 'storage' and tablename = 'objects' and cmd = 'UPDATE';
  if v_total <> 3 or v_named <> 3 or v_update <> 0 then
    raise exception 'POLICY-BATTERY FAIL 19.17: storage policies total %, named %, update % — want 3/3/0',
      v_total, v_named, v_update;
  end if;
end $$;

-- ############################################################################
-- 19.18 — PIN (bucket envelope): matter-files is 25 MiB with the exact
-- seven-type allow-list.
-- ############################################################################
do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from storage.buckets
   where id = 'matter-files'
     and file_size_limit = 26214400
     and array_length(allowed_mime_types, 1) = 7
     and allowed_mime_types @> array[
       'application/pdf',
       'application/msword',
       'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
       'text/plain',
       'text/csv',
       'image/png',
       'image/jpeg'
     ];
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 19.18: matter-files bucket limits drift (25 MiB + 7 MIME types)';
  end if;
end $$;

-- ############################################################################
-- 19.19 — POS (delete cleanup): client-a deletes the 19.01 metadata row.
-- The RPC returns its storage_path, the row is gone, the fixture row on the
-- same path remains, and exactly one file:delete/allowed audit row exists.
-- ############################################################################
set role authenticated;
do $$
declare
  v_id   uuid;
  v_path text;
  v_cnt  bigint;
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003"}', false);
  select id into v_id
    from public.files
   where storage_path = '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf'
     and id <> '70000000-0000-4000-8000-000000000001'
   order by created_at desc
   limit 1;
  if v_id is null then
    raise exception 'POLICY-BATTERY FAIL 19.19: 19.01 registered row missing (non-vacuity broken)';
  end if;
  v_path := public.delete_matter_file(v_id);
  if v_path is distinct from '20000000-0000-4000-8000-000000000001/40000000-0000-4000-8000-000000000001/file-1.pdf' then
    raise exception 'POLICY-BATTERY FAIL 19.19: delete returned path %, want the file-1.pdf path', v_path;
  end if;
  select count(*) into v_cnt from public.files where id = v_id;
  if v_cnt <> 0 then
    raise exception 'POLICY-BATTERY FAIL 19.19: deleted metadata row still present';
  end if;
  select count(*) into v_cnt
    from public.files
   where id = '70000000-0000-4000-8000-000000000001';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 19.19: delete removed the wrong file (fixture row missing)';
  end if;
end $$;
reset role;

do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from public.audit_events
   where action = 'file:delete'
     and outcome = 'allowed'
     and organization_id = '20000000-0000-4000-8000-000000000001'
     and redacted_summary = 'file deleted';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 19.19: file:delete audit rows = %, want exactly 1', v_cnt;
  end if;
end $$;

-- ############################################################################
-- 19.20 — NEG (non-assigned delete): orphan is assigned on matter 4, not
-- matter 1 — deleting the matter-1 fixture file is denied and the row stays.
-- ############################################################################
set role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007"}', false);
  begin
    perform public.delete_matter_file('70000000-0000-4000-8000-000000000001');
    raise exception 'POLICY-BATTERY FAIL 19.20: non-assigned delete succeeded';
  exception when raise_exception then
    if sqlerrm like '%POLICY-BATTERY FAIL%' then
      raise;
    end if;
    null; -- expected: in-function permission denied
  end;
end $$;
reset role;

do $$
declare
  v_cnt bigint;
begin
  select count(*) into v_cnt
    from public.files
   where id = '70000000-0000-4000-8000-000000000001';
  if v_cnt <> 1 then
    raise exception 'POLICY-BATTERY FAIL 19.20: denied delete removed the fixture row';
  end if;
end $$;

-- ############################################################################
-- 19.21 — NEG (§8 negative): after every deny row, exactly the two
-- file:create positives and the one file:delete positive are audited; no
-- denied write wrote an audit row.
-- ############################################################################
do $$
declare
  v_create bigint; v_delete bigint; v_denied bigint;
begin
  select count(*) into v_create
    from public.audit_events where action = 'file:create' and outcome = 'allowed';
  select count(*) into v_delete
    from public.audit_events where action = 'file:delete' and outcome = 'allowed';
  select count(*) into v_denied
    from public.audit_events where action like 'file:%' and outcome <> 'allowed';
  if v_create <> 2 or v_delete <> 1 or v_denied <> 0 then
    raise exception 'POLICY-BATTERY FAIL 19.21: audit rows after denies (create %, delete %, denied %) — want 2/1/0',
      v_create, v_delete, v_denied;
  end if;
end $$;

rollback;
