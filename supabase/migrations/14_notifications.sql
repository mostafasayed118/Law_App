-- 14_notifications.sql — notification-feed read table (DRAFT — T3 artifacts, NOT applied)
-- Source of truth: docs/notification_feed_scope_2026-08-11.md (D-N1..D-N7, DECIDED)
--                + docs/notification_feed_gate_review_2026-08-11.md (Q1-Q6, REVIEWED).
-- Rollback: 14_notifications.down.sql (same directory).
--
-- The notification-feed READ surface: a NEW surface (D-N1, the spec has no
-- feed row), org-scoped, read-only in v1 (D-N2 — no push/FCM/device
-- delivery; that stays deferred per roadmap line 484, so no provider
-- decision is needed). Row shape is REDACTED METADATA by construction
-- (D-N3, review Q1 — made STRUCTURAL, the D-BI1 mirror): the table has
-- NO user-identity column, NO content column, NO raw-text column — only
-- category, type, summary (synthetic demo copy, never PII), server
-- timestamp, is_read, and the org FK. Categories are the three generic
-- prefs categories (D-N4 — the honest bridge to NotificationPrefs):
-- 'appointment' / 'activity' / 'system', enforced by a CHECK (the client
-- Notification.category mapping contract). is_read is DISPLAY METADATA
-- ONLY in v1 (D-N6 — seeded false, never mutated; the read-flag RPC is a
-- future write slice under the same discipline).
--
-- Org scoping: notifications are ORG METADATA, not matter content
-- (review Q2) — every ACTIVE MEMBER of the org reads the org's feed. The
-- grant is the proven organizations-gate (public.is_active_member), the
-- same predicate the org-audit / member surfaces use — NOT the
-- matter-assignment exists-subquery (which would wrongly hide org-wide
-- system notifications from members not assigned to the triggering
-- matter). The policy follows in policies/notifications.sql.
--
-- Read path: DIRECT PostgREST read, no new RPC (review Q5 — the
-- matters/documents posture): the policy gates the table directly,
-- newest-first ordering is a query concern, and the matrix row is the
-- SELECT cell. No INSERT/UPDATE/DELETE grant and no write policy of any
-- kind (D-N2/D-N6, review Q4): this slice cannot create, mutate, or
-- delete a row; server-generated rows come from a future producer slice.

begin;

-- 14.1 notifications — org-scoped, redacted-metadata, read-only (D-N3/D-N4/D-N6)
create table public.notifications (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  category         text not null
    check (category in ('appointment', 'activity', 'system')),  -- D-N4: the prefs' three generic categories (CHECK = mapping contract)
  type             text not null,          -- e.g. 'matter_updated', 'message_received', 'invoice_status' (D-N3)
  summary          text not null default '',  -- synthetic demo copy only; NEVER PII by convention (D-N3/D-N7)
  server_timestamp timestamptz not null default now(),  -- server clock, never client clock (D-N3)
  is_read          boolean not null default false          -- D-N6: display metadata only in v1; no read-flag RPC
);

-- The feed read shape: org-scoped list read, newest-first (the review Q5
-- query concern). The composite index serves both the org gate and the
-- ordering in one covering scan.
create index notifications_org_ts on public.notifications (organization_id, server_timestamp desc);

-- RLS on (default deny: with no policy, all access is denied).
alter table public.notifications enable row level security;

-- Default-deny baseline: strip the hosting default grants (the 01 pattern).
revoke all on public.notifications from anon, authenticated;

-- Narrow direct SELECT grant per Q5 (row-scoped reads only; there is no
-- write path in this slice). Grants alone do nothing without policies;
-- the policy follows in policies/notifications.sql.
grant select on public.notifications to authenticated;

commit;
