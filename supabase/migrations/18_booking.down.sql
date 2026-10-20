-- 18_booking.down.sql — clean inverse of 18_booking.sql.
-- Drops the consultations table first (FK: consultations.slot_id ->
-- consultation_slots.id, ON DELETE RESTRICT), then the slots table.
-- The inline category/topic/status CHECKs, the indexes, and both SELECT
-- policies die with their tables. RPC backout: supabase/rpc/_down.sql
-- (drop function public.book_consultation(uuid, text, text, text)).

begin;

drop table if exists public.consultations;
drop table if exists public.consultation_slots;

commit;
