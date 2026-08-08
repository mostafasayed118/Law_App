-- 08_messages.down.sql — backout for 08_messages.sql (REHEARSAL-READY — not run on dev)
-- Clean inverse: drop the table. The inline body CHECK dies with the
-- table — like 05/06/07, there is no type object to drop.

begin;

drop table if exists public.messages;

commit;
