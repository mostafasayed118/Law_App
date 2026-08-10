-- 07_storage.down.sql — backout for 07_storage.sql (REVIEWED — rollback standby; not run on dev)
-- Clean inverse: drop the files table, then delete the private bucket.
-- The inline size_bytes CHECK dies with the table — like 05/06, there is
-- no type object to drop. The bucket delete cascades its objects via the
-- platform FK (storage.objects.bucket_id -> storage.buckets.id ON DELETE
-- CASCADE, storage-api schema).

begin;

drop table if exists public.files;
delete from storage.buckets where id = 'matter-files';

commit;
