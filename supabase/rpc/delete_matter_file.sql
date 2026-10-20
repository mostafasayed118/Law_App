-- rpc/delete_matter_file.sql — audited matter-file metadata delete.
-- Source of truth: the ratified matter-files write design for this wave.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- The cleanup half of the upload path. The metadata row is deleted here; the
-- returned storage_path lets the caller remove the bytes through the storage
-- API (authorized by the files_storage_delete policy, the exact SELECT gate
-- re-used as USING). public.files has no DELETE grant/policy: this RPC is
-- the ONLY metadata delete path.
--
-- Gate: resolve the file through its matter with org equality AND an active
-- membership in that org AND an assignment (client or attorney) on the
-- matter — the files_select_assigned authorization re-asserted inside the
-- definer body. A missing/unreadable file is the same typed denial (no
-- existence oracle).
--
-- §8 audit: one redacted 'file:delete/allowed' row with the org and file id.
-- Returns the deleted row's storage_path.

create or replace function public.delete_matter_file(p_file_id uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_org  uuid;
  v_path text;
begin
  select f.organization_id
    into v_org
    from public.files f
    join public.matters m
      on m.id = f.matter_id
     and m.organization_id = f.organization_id
   where f.id = p_file_id
     and public.is_active_member(f.organization_id)
     and (m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid());
  if v_org is null then
    raise exception 'permission denied';
  end if;

  delete from public.files
   where id = p_file_id
  returning storage_path into v_path;
  if v_path is null then
    raise exception 'permission denied';
  end if;

  -- §8 audit (contract): redacted summary only.
  perform public.write_audit(
    'file:delete', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'file',
    p_resource_id      => p_file_id,
    p_redacted_summary => 'file deleted'
  );

  return v_path;
end;
$$;

revoke execute on function public.delete_matter_file(uuid) from public, anon;
grant execute on function public.delete_matter_file(uuid) to authenticated;
