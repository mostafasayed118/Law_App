-- rpc/apply_paymob_transaction.sql — settle a payment from a provider
-- callback (NOT APPLIED — rehearsal only).
-- Source of truth: the payments slice. Backout: 20_payments.down.sql /
-- rpc/_down.sql.
--
-- SERVICE-ROLE ONLY: the callback handler verifies the Paymob signature and
-- then applies the outcome here. No client grant exists.
--
-- Rules:
--   - lock the attempt by provider_order_id (the idempotency key);
--   - validate the amount, the currency and the outcome allow-list BEFORE
--     any state change (check_violation);
--   - pending -> succeeded | failed | expired | cancelled | refunded;
--   - terminal attempts are IMMUTABLE, with ONE exception: a signed
--     late success may move 'expired' -> 'succeeded' while the invoice is
--     still 'issued' (the provider key outlives the stale sweep; refusing
--     it would collect money with no recorded settlement) (audit H1);
--     the same outcome is an idempotent replay (already_processed = true,
--     NO second audit, NO invoice change); any other conflict is
--     check_violation;
--   - ONLY 'succeeded' settles the invoice (billing_invoices 'issued' ->
--     'paid'); every other outcome leaves the invoice issued, so a fresh
--     attempt can be initiated (the retry path);
--   - exactly ONE audit row per terminal transition ('payment:<outcome>' /
--     'allowed'), machine actor (NULL), redacted summary only — never the
--     provider transaction/order id, never a raw failure payload.
--
-- Response: payment_id, payment_status, invoice_status, already_processed.

create or replace function public.apply_paymob_transaction(
  p_provider_order_id       text,
  p_provider_transaction_id text,
  p_outcome                 text,
  p_amount_cents            bigint,
  p_currency                text,
  p_failure_code            text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_pay            record;
  v_invoice_status text;
begin
  if p_outcome is null
     or p_outcome not in ('succeeded', 'failed', 'expired', 'cancelled', 'refunded') then
    raise exception 'unsupported payment outcome' using errcode = 'check_violation';
  end if;
  if p_provider_order_id is null or trim(p_provider_order_id) = '' then
    raise exception 'provider order id is required' using errcode = 'check_violation';
  end if;
  if p_provider_transaction_id is null or trim(p_provider_transaction_id) = '' then
    raise exception 'provider transaction id is required' using errcode = 'check_violation';
  end if;

  -- Join the invoice for its authoritative org/status; lock only the payment.
  select p.id, p.invoice_id, p.amount_cents, p.currency, p.status,
         i.organization_id as invoice_org, i.status as invoice_status
    into v_pay
    from public.payments p
    join public.billing_invoices i on i.id = p.invoice_id
   where p.provider_order_id = p_provider_order_id
     for update of p;

  if not found then
    raise exception 'payment not found' using errcode = 'check_violation';
  end if;

  if p_amount_cents is distinct from v_pay.amount_cents then
    raise exception 'payment amount mismatch' using errcode = 'check_violation';
  end if;
  if p_currency is distinct from v_pay.currency then
    raise exception 'payment currency mismatch' using errcode = 'check_violation';
  end if;

  -- Terminal idempotency: same outcome = replay; different = contradiction.
  -- Exception: a signed late success may settle an attempt the stale sweeper
  -- already expired (the provider checkout key is valid longer than the
  -- sweep window). The money was collected, so refusing it loses the
  -- settlement record while the invoice stays 'issued' (audit H1).
  if v_pay.status <> 'pending' then
    if v_pay.status = p_outcome then
      return jsonb_build_object(
        'payment_id',        v_pay.id,
        'payment_status',    v_pay.status,
        'invoice_status',    v_pay.invoice_status,
        'already_processed', true
      );
    end if;
    if not (v_pay.status = 'expired' and p_outcome = 'succeeded') then
      raise exception 'payment is already final' using errcode = 'check_violation';
    end if;
  end if;

  if exists (
    select 1 from public.payments p
     where p.provider_transaction_id = p_provider_transaction_id
       and p.id <> v_pay.id
  ) then
    raise exception 'provider transaction id is already used' using errcode = 'check_violation';
  end if;

  update public.payments
     set status                  = p_outcome,
         provider_transaction_id = p_provider_transaction_id,
         failure_code            = case when p_outcome = 'succeeded' then null else p_failure_code end,
         settled_at              = now(),
         updated_at              = now()
   where id = v_pay.id;

  if p_outcome = 'succeeded' then
    update public.billing_invoices
       set status = 'paid'
     where id = v_pay.invoice_id
       and status = 'issued';
  end if;

  select i.status into v_invoice_status
    from public.billing_invoices i
   where i.id = v_pay.invoice_id;

  -- One audit row per terminal outcome. Machine event: NULL actor, generic
  -- summary — no provider ids, no failure reason.
  perform public.write_audit(
    'payment:' || p_outcome, 'allowed',
    p_organization_id  => v_pay.invoice_org,
    p_resource_type    => 'payment',
    p_resource_id      => v_pay.id,
    p_redacted_summary => 'payment ' || p_outcome,
    p_actor            => null
  );

  return jsonb_build_object(
    'payment_id',        v_pay.id,
    'payment_status',    p_outcome,
    'invoice_status',    v_invoice_status,
    'already_processed', false
  );
end;
$$;

revoke execute on function public.apply_paymob_transaction(text, text, text, bigint, text, text)
  from public, anon, authenticated;
grant execute on function public.apply_paymob_transaction(text, text, text, bigint, text, text)
  to service_role;
