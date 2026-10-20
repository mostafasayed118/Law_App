-- rpc/record_payment_callback_rejected.sql — rejection telemetry
-- (NOT APPLIED — rehearsal only).
-- Source of truth: the payments slice. Backout: 20_payments.down.sql /
-- rpc/_down.sql.
--
-- SERVICE-ROLE ONLY: the callback handler records a rejected payload here.
-- The function NEVER raises for a bad reason value — a telemetry write must
-- not fail the webhook path — it normalizes the reason to a SHORT ALLOW-LIST
-- and writes one 'payment:callback_rejected'/'denied' audit row (machine
-- actor, no payload, no provider ids, no PII).
--
-- Allow-list: signature_mismatch, unknown_order, amount_mismatch,
-- currency_mismatch, malformed_payload, invalid_outcome,
-- missing_transaction_id, duplicate_transaction. Anything else is recorded
-- as 'unclassified'.

create or replace function public.record_payment_callback_rejected(
  p_reason text
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_reason text;
begin
  v_reason := lower(coalesce(trim(p_reason), ''));

  if v_reason not in (
    'signature_mismatch',
    'unknown_order',
    'amount_mismatch',
    'currency_mismatch',
    'malformed_payload',
    'invalid_outcome',
    'missing_transaction_id',
    'duplicate_transaction'
  ) then
    v_reason := 'unclassified';
  end if;

  perform public.write_audit(
    'payment:callback_rejected', 'denied',
    p_resource_type    => 'payment',
    p_redacted_summary => 'payment callback rejected: ' || v_reason,
    p_actor            => null
  );
end;
$$;

revoke execute on function public.record_payment_callback_rejected(text)
  from public, anon, authenticated;
grant execute on function public.record_payment_callback_rejected(text)
  to service_role;
