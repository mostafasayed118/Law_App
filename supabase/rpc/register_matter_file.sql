-- rpc/register_matter_file.sql — audited matter-file metadata registration.
-- Source of truth: the ratified matter-files write design for this wave.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- The upload path is two-step by construction:
--   1. the client uploads bytes to storage.objects in the private
--      `matter-files` bucket at `{org}/{matter}/{name}` — authorized by the
--      files_storage_insert policy (policies/storage_objects.sql, the exact
--      SELECT gate re-used as WITH CHECK);
--   2. this RPC verifies the uploaded object and records the public.files
--      METADATA row. public.files has no write grant/policy: this RPC is the
--      ONLY metadata write path.
--
-- Gates (in order):
--   matter gate — the matter must resolve with org equality AND the caller
--     must be an active member of its org AND assigned client/attorney on
--     it (the create_task D-SM1 shape). An unreadable matter = typed denial.
--   validation — trimmed non-empty name/mime, non-negative size (the
--     files.size_bytes CHECK mapping contract), and check_violation errcodes.
--   path gate — storage_path must start with `{org}/{matter}/` and contain
--     no '..' traversal segment.
--   object gate — the object must exist in storage.objects (bucket
--     matter-files, name = path) and its metadata size/mimetype must match
--     the supplied values. Cross-schema read inside the definer body; the
--     function owner is the applying role, which already owns the fixture
--     storage writes.
--   §8 audit — 'file:create/allowed' with the org, file id, and the fixed
--     redacted summary 'file uploaded' (never the filename/path).
--   response — the persisted row as jsonb plus the matter title (the D-SM2
--     full-row-return convention), so the client maps it without a re-read.

create or replace function public.register_matter_file(
  p_matter_id    uuid,
  p_name         text,
  p_mime_type    text,
  p_size_bytes   bigint,
  p_storage_path text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_org      uuid;
  v_title    text;
  v_prefix   text;
  v_obj_size text;
  v_obj_mime text;
  v_file     public.files%rowtype;
begin
  select m.organization_id, m.title
    into v_org, v_title
    from public.matters m
   where m.id = p_matter_id
     and public.is_active_member(m.organization_id)
     and (m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid());
  if v_org is null then
    raise exception 'permission denied';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'file name is required' using errcode = 'check_violation';
  end if;
  if p_mime_type is null or trim(p_mime_type) = '' then
    raise exception 'file mime type is required' using errcode = 'check_violation';
  end if;
  if p_size_bytes is null or p_size_bytes < 0 then
    raise exception 'file size must be non-negative' using errcode = 'check_violation';
  end if;

  v_prefix := v_org::text || '/' || p_matter_id::text || '/';
  if p_storage_path is null
     or p_storage_path = ''
     or left(p_storage_path, char_length(v_prefix)) <> v_prefix
     or position('..' in p_storage_path) > 0 then
    raise exception 'storage path does not match the matter prefix' using errcode = 'check_violation';
  end if;

  select o.metadata ->> 'size', o.metadata ->> 'mimetype'
    into v_obj_size, v_obj_mime
    from storage.objects o
   where o.bucket_id = 'matter-files'
     and o.name = p_storage_path;
  if not found then
    raise exception 'storage object not found' using errcode = 'check_violation';
  end if;
  if v_obj_size is distinct from p_size_bytes::text
     or v_obj_mime is distinct from trim(p_mime_type) then
    raise exception 'storage object metadata does not match' using errcode = 'check_violation';
  end if;

  insert into public.files
    (organization_id, matter_id, name, mime_type, size_bytes, storage_path)
  values
    (v_org, p_matter_id, trim(p_name), trim(p_mime_type), p_size_bytes, p_storage_path)
  returning * into v_file;

  -- §8 audit (contract): redacted summary only — never the filename/path.
  perform public.write_audit(
    'file:create', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'file',
    p_resource_id      => v_file.id,
    p_redacted_summary => 'file uploaded'
  );

  return jsonb_build_object(
    'file', to_jsonb(v_file),
    'matter_title', v_title
  );
end;
$$;

revoke execute on function public.register_matter_file(uuid, text, text, bigint, text) from public, anon;
grant execute on function public.register_matter_file(uuid, text, text, bigint, text) to authenticated;
