-- 10_billing_invoices.down.sql — backout for 10_billing_invoices.sql (REHEARSAL-READY — not run on dev)
-- Clean inverse: drop the billing_invoices table. The inline amount_cents
-- / status CHECKs die with the table — like 04/05/06, there is no type
-- object to drop. The policy (policies/invoices.sql) is backed out via
-- git revert (rollback_plan.md design §7), and any demo rows via the
-- apply-time cleanup step (T5).

begin;

drop table if exists public.billing_invoices;

commit;
