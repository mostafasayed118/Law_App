-- 23_approvals.down.sql — backout for 23_approvals.sql (NOT APPLIED — standby)
-- Clean inverse: drop the slice's RPCs first (so no definer function is left
-- pointing at a missing table), then the events table (FK child) and the
-- requests table. Indexes, inline CHECKs, and read policies die with their
-- tables. The consolidated rpc/_down.sql drop list is maintained separately
-- for the whole RPC surface; the drops here are idempotent, so running both
-- orders is safe.

begin;

drop function if exists public.create_approval_request(uuid, uuid, text, text, text);
drop function if exists public.decide_approval_request(uuid, text, text);
drop function if exists public.cancel_approval_request(uuid);
drop function if exists public.list_approval_requests(uuid, text);

drop table if exists public.approval_events;
drop table if exists public.approval_requests;

commit;
