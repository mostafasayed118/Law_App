-- rpc/get_invoice_payment_status.sql — payment status poll
-- (NOT APPLIED — rehearsal only).
-- Source of truth: the payments slice. Backout: 20_payments.down.sql /
-- rpc/_down.sql.
--
-- Same AUTHORIZATION gate as initiate_invoice_payment: authenticated, the
-- invoice resolves through its matter with the org equality, the caller is
-- an ACTIVE member of that org, and the caller is assigned client or
-- attorney on the matter. A failure is the same typed 'permission denied'
-- (no existence oracle).
--
-- Deliberately NOT re-applying the payability checks (status 'issued',
-- amount > 0, currency 'EGP'): this endpoint exists to poll the outcome, so
-- it must keep working after a successful attempt settles the invoice to
-- 'paid'. The payability gates belong to initiation only.
--
-- Response: payment_id, status, updated_at — nothing else. No invoice
-- amount, no provider identifiers, no failure detail. Returns NULL jsonb
-- when the invoice has no payment attempt yet.

create or replace function public.get_invoice_payment_status(
  p_invoice_id uuid
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_inv   uuid;
  v_pay   record;
begin
  if v_uid is null then
    raise exception 'permission denied';
  end if;

  select i.id into v_inv
    from public.billing_invoices i
    join public.matters m
      on m.id = i.matter_id
     and m.organization_id = i.organization_id
   where i.id = p_invoice_id
     and public.is_active_member(i.organization_id)
     and (m.assigned_client_id = v_uid
          or m.assigned_attorney_id = v_uid);

  if v_inv is null then
    raise exception 'permission denied';
  end if;

  select p.id, p.status, p.updated_at
    into v_pay
    from public.payments p
   where p.invoice_id = p_invoice_id
   order by p.created_at desc, p.id desc
   limit 1;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'payment_id', v_pay.id,
    'status',     v_pay.status,
    'updated_at', v_pay.updated_at
  );
end;
$$;

revoke execute on function public.get_invoice_payment_status(uuid) from public, anon, authenticated;
grant execute on function public.get_invoice_payment_status(uuid) to authenticated;
