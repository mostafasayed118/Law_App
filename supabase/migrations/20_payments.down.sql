-- 20_payments.down.sql — backout for 20_payments.sql (NOT APPLIED — standby)
-- Clean inverse: drop the slice's RPCs first (so no definer function is left
-- pointing at a missing table), then the payments table (its indexes and
-- inline CHECKs die with it). The consolidated rpc/_down.sql drop list is
-- maintained separately for the whole RPC surface; the drops here are
-- idempotent, so running both orders is safe.

begin;

drop function if exists public.initiate_invoice_payment(uuid);
drop function if exists public.get_invoice_payment_status(uuid);
drop function if exists public.attach_paymob_order(uuid, text);
drop function if exists public.apply_paymob_transaction(text, text, text, bigint, text, text);
drop function if exists public.record_payment_callback_rejected(text);
drop function if exists public.list_stale_pending_payments(interval, integer);

drop table if exists public.payments;

commit;
