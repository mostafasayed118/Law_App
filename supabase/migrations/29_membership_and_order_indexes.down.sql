-- 29_membership_and_order_indexes.down.sql — explicit inverse of 29
-- (NOT APPLIED). Drops exactly the six non-unique indexes 29 creates.
-- No data change; the pre-existing single-column indexes are untouched.

begin;

drop index if exists public.memberships_user;
drop index if exists public.documents_org_created;
drop index if exists public.files_org_created;
drop index if exists public.billing_invoices_org_issued;
drop index if exists public.message_threads_org_activity;
drop index if exists public.tasks_org_created;

commit;
