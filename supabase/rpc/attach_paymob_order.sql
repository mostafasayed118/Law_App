-- rpc/attach_paymob_order.sql — bind a provider order to a pending payment
-- (NOT APPLIED — rehearsal only).
-- Source of truth: the payments slice. Backout: 20_payments.down.sql /
-- rpc/_down.sql.
--
-- SERVICE-ROLE ONLY: the checkout backend creates the Paymob order and binds
-- its opaque id here. No client grant exists — the revoke below removes the
-- hosting default and no authenticated grant is added.
--
-- Rules:
--   - only a PENDING attempt may be attached (terminal attempts are final);
--   - idempotent: re-attaching the SAME order returns the row unchanged;
--   - a DIFFERENT order on an already-attached attempt is check_violation;
--   - an order id already used by another payment is check_violation (the
--     unique constraint is the backstop).
-- No audit row: the initiation audit already records the intent; this call
-- carries no money movement.

create or replace function public.attach_paymob_order(
  p_payment_id        uuid,
  p_provider_order_id text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_pay record;
begin
  if p_provider_order_id is null or trim(p_provider_order_id) = '' then
    raise exception 'provider order id is required' using errcode = 'check_violation';
  end if;

  select p.id, p.status, p.provider_order_id
    into v_pay
    from public.payments p
   where p.id = p_payment_id
     for update;

  if not found then
    raise exception 'payment not found' using errcode = 'check_violation';
  end if;

  if v_pay.status <> 'pending' then
    raise exception 'payment is not pending' using errcode = 'check_violation';
  end if;

  if v_pay.provider_order_id is not null then
    if v_pay.provider_order_id = p_provider_order_id then
      return jsonb_build_object(
        'payment_id',         v_pay.id,
        'payment_status',     v_pay.status,
        'provider_order_id',  v_pay.provider_order_id,
        'attached',           false
      );
    end if;
    raise exception 'payment already attached to a different provider order'
      using errcode = 'check_violation';
  end if;

  if exists (
    select 1 from public.payments p
     where p.provider_order_id = p_provider_order_id
       and p.id <> p_payment_id
  ) then
    raise exception 'provider order id is already used' using errcode = 'check_violation';
  end if;

  update public.payments
     set provider_order_id = p_provider_order_id,
         updated_at = now()
   where id = p_payment_id;

  return jsonb_build_object(
    'payment_id',        p_payment_id,
    'payment_status',    'pending',
    'provider_order_id', p_provider_order_id,
    'attached',          true
  );
end;
$$;

revoke execute on function public.attach_paymob_order(uuid, text) from public, anon, authenticated;
grant execute on function public.attach_paymob_order(uuid, text) to service_role;
