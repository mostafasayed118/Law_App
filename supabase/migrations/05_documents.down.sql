-- 05_documents.down.sql — backout for 05_documents.sql (REHEARSAL-READY — not run on dev)
-- Clean inverse: drop the table. The inline document_type CHECK dies with
-- the table — unlike 04's matter_status enum, there is no type object to
-- drop.

begin;

drop table if exists public.documents;

commit;
