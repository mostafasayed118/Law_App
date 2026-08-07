-- 06_message_threads.down.sql — backout for 06_message_threads.sql (REHEARSAL-READY — not run on dev)
-- Clean inverse: drop the table. The inline message_count CHECK dies with
-- the table — like 05's document_type, there is no type object to drop.

begin;

drop table if exists public.message_threads;

commit;
