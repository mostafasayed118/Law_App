-- 29_membership_and_order_indexes.sql — list-read index gaps (NOT APPLIED)
-- Source of truth: docs/live_apply_2026-10-26_audit_followups.md
--
-- Additive and idempotent. These are the verified gaps between the client's
-- bounded list reads (lib/data/list_query_guards.dart) and the indexes the
-- migration set provides:
--
--   memberships       — the active-membership lookup reads by user_id; the
--                       only existing index is unique (organization_id,
--                       user_id), whose leading column is organization_id.
--   documents         — organization_id filter + created_at DESC (the client
--                       ordering map); the existing index is organization_id
--                       only, so the ORDER BY needs a sort.
--   files             — same shape as documents.
--   billing_invoices  — organization_id filter + issued_at DESC.
--   message_threads   — organization_id filter + last_activity_at DESC.
--   tasks             — organization_id filter + created_at DESC.
--   research_runs     — requested_by filter + created_at DESC (requester
--                       history; the existing indexes are org-first).
--
-- Non-unique only; no data change. CREATE INDEX (not CONCURRENTLY) takes a
-- SHARE lock that blocks writes for the build — schedule a low-traffic window.
-- Backout: 29_membership_and_order_indexes.down.sql drops exactly these.

begin;

create index if not exists memberships_user
  on public.memberships (user_id);

create index if not exists documents_org_created
  on public.documents (organization_id, created_at desc);

create index if not exists files_org_created
  on public.files (organization_id, created_at desc);

create index if not exists billing_invoices_org_issued
  on public.billing_invoices (organization_id, issued_at desc);

create index if not exists message_threads_org_activity
  on public.message_threads (organization_id, last_activity_at desc);

create index if not exists tasks_org_created
  on public.tasks (organization_id, created_at desc);

commit;
