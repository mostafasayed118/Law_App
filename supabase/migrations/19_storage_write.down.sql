-- 19_storage_write.down.sql — clean inverse of 19_storage_write.sql.
-- Restores the bucket's pre-write-slice default posture: no size limit and
-- no MIME allow-list. The bucket itself (and its objects) is left intact —
-- 07_storage.down.sql owns bucket deletion. RPC backout:
-- supabase/rpc/_down.sql (drop register_matter_file / delete_matter_file).

begin;

update storage.buckets
   set file_size_limit = null,
       allowed_mime_types = null
 where id = 'matter-files';

commit;
