-- 19_storage_write.sql — matter-files bucket write constraints.
-- Source of truth: the ratified matter-files write design for this wave.
-- Rollback: 19_storage_write.down.sql (same directory).
--
-- The read slice (07_storage.sql) created the private `matter-files` bucket
-- with default (unlimited) limits. The write slice pins the upload envelope
-- at the storage layer: 25 MiB max and a seven-type allow-list. These limits
-- are enforced by the storage API for every writer, independently of the
-- files_storage_insert RLS policy.
--
-- No new grants/policies on public.files: metadata writes remain RPC-only
-- (register_matter_file / delete_matter_file). The storage.objects INSERT /
-- DELETE policies live in policies/storage_objects.sql.

begin;

update storage.buckets
   set file_size_limit = 26214400,  -- 25 MiB
       allowed_mime_types = array[
         'application/pdf',
         'application/msword',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
         'text/plain',
         'text/csv',
         'image/png',
         'image/jpeg'
       ]
 where id = 'matter-files';

commit;
