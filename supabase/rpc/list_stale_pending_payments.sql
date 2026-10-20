-- rpc/list_stale_pending_payments.sql — reconciliation sweep
-- (NOT APPLIED — rehearsal only).
-- Source of truth: the payments slice. Backout: 20_payments.down.sql /
-- rpc/_down.sql.
--
-- SERVICE-ROLE ONLY: a scheduled reconciler lists pending attempts older than
-- the threshold so it can query Paymob and expire/abandon them. Read-only.
--
-- Projection: id, provider_order_id, amount_cents, currency, created_at —
-- the minimum the reconciler needs. No invoice/org/PII columns.

create or replace function public.list_stale_pending_payments(
  p_older_than interval default '15 minutes',
  p_limit      integer default 50
) returns setof jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_cutoff timestamptz;
  v_limit  integer;
begin
  v_cutoff := now() - coalesce(p_older_than, interval '15 minutes');
  v_limit  := case when p_limit is null or p_limit < 1 then 50 else p_limit end;

  return query
    select jsonb_build_object(
             'id',               p.id,
             'provider_order_id', p.provider_order_id,
             'amount_cents',     p.amount_cents,
             'currency',         p.currency,
             'created_at',       p.created_at)
      from public.payments p
     where p.status = 'pending'
       and p.created_at < v_cutoff
     order by p.created_at asc
     limit v_limit;
end;
$$;

revoke execute on function public.list_stale_pending_payments(interval, integer)
  from public, anon, authenticated;
grant execute on function public.list_stale_pending_payments(interval, integer)
  to service_role;
