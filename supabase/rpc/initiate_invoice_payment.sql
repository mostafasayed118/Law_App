-- rpc/initiate_invoice_payment.sql — audited payment initiation
-- (NOT APPLIED — rehearsal only).
-- Source of truth: the payments slice (Paymob hosted checkout, fake-gateway
-- posture). Backout: 20_payments.down.sql / rpc/_down.sql.
--
-- The client's only payment write. Gate (the invoices + send_message D-SM1
-- shape, anchored on the invoice's matter):
--   - auth.uid() is not null;
--   - the invoice resolves through its matter with the THREE-WAY org
--     equality (invoice org = matter org = the org whose membership is
--     tested), the caller is an ACTIVE member of that org, and the caller is
--     assigned client or attorney on the matter. Anything else is a typed
--     'permission denied' (no existence oracle).
--   - the invoice is payable: status 'issued', amount_cents > 0, currency
--     'EGP' (check_violation, the Batch B convention).
--
-- Concurrency: the invoice row is locked FOR UPDATE, then the single pending
-- attempt (partial unique index) is locked. Concurrent initiates serialize on
-- the invoice row, so a double-tap yields the SAME pending payment — the
-- second caller gets the existing id and writes NO second audit row.
--
-- §8 audit: an INSERT writes exactly one 'payment:initiate'/'allowed' row
-- with the invoice's org, resource 'payment', and the generic summary
-- 'invoice payment initiated'. Returning an existing pending attempt writes
-- nothing.
--
-- Response: payment_id, invoice_id, invoice_number, amount_cents, currency,
-- status, provider_order_id. The provider order id is returned so
-- paymob-initiate can reuse an already-attached Paymob order on retry and
-- skip a second attach; the shipped client calls that edge function, not this
-- RPC, and the RPC stays authenticated-only. The order id is an opaque
-- provider handle with no transaction or card data.

create or replace function public.initiate_invoice_payment(
  p_invoice_id uuid
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_inv   record;
  v_pay   record;
begin
  if v_uid is null then
    raise exception 'permission denied';
  end if;

  -- Authorization gate + invoice lock in one statement. The matter join
  -- carries the org equality; the assignment columns live on the matter.
  select i.id, i.organization_id, i.invoice_number,
         i.amount_cents, i.currency, i.status
    into v_inv
    from public.billing_invoices i
    join public.matters m
      on m.id = i.matter_id
     and m.organization_id = i.organization_id
   where i.id = p_invoice_id
     and public.is_active_member(i.organization_id)
     and (m.assigned_client_id = v_uid
          or m.assigned_attorney_id = v_uid)
     for update of i;

  if not found then
    raise exception 'permission denied';
  end if;

  if v_inv.status <> 'issued' then
    raise exception 'invoice is not payable' using errcode = 'check_violation';
  end if;
  if v_inv.amount_cents <= 0 then
    raise exception 'invoice amount must be positive' using errcode = 'check_violation';
  end if;
  if v_inv.currency <> 'EGP' then
    raise exception 'invoice currency is not supported' using errcode = 'check_violation';
  end if;

  -- Idempotent pending reuse: the invoice lock guarantees this read is the
  -- serialized truth. Same id, no new row, no new audit.
  select p.id, p.status, p.amount_cents, p.currency, p.provider_order_id
    into v_pay
    from public.payments p
   where p.invoice_id = p_invoice_id
     and p.status = 'pending'
   order by p.created_at desc, p.id desc
   limit 1
   for update;

  if found then
    return jsonb_build_object(
      'payment_id',     v_pay.id,
      'invoice_id',     v_inv.id,
      'invoice_number', v_inv.invoice_number,
      'amount_cents',   v_pay.amount_cents,
      'currency',       v_pay.currency,
      'status',         v_pay.status,
      'provider_order_id', v_pay.provider_order_id
    );
  end if;

  insert into public.payments
    (invoice_id, initiated_by, amount_cents, currency, status, provider)
  values
    (p_invoice_id, v_uid, v_inv.amount_cents, v_inv.currency, 'pending', 'paymob')
  returning id, status, provider_order_id into v_pay;

  perform public.write_audit(
    'payment:initiate', 'allowed',
    p_organization_id  => v_inv.organization_id,
    p_resource_type    => 'payment',
    p_resource_id      => v_pay.id,
    p_redacted_summary => 'invoice payment initiated'
  );

  return jsonb_build_object(
    'payment_id',     v_pay.id,
    'invoice_id',     v_inv.id,
    'invoice_number', v_inv.invoice_number,
    'amount_cents',   v_inv.amount_cents,
    'currency',       v_inv.currency,
    'status',         v_pay.status,
    'provider_order_id', v_pay.provider_order_id
  );
end;
$$;

revoke execute on function public.initiate_invoice_payment(uuid) from public, anon, authenticated;
grant execute on function public.initiate_invoice_payment(uuid) to authenticated;
