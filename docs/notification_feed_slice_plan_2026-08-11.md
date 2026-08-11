# Plan: Notification-Feed (Read) Slice — a NEW surface, no provider (2026-08-11)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> **notification-feed read surface** — a NEW surface (not a §14
> un-deferral), scoped in `docs/notification_feed_scope_2026-08-11.md`
> (D-N1…D-N7). **Docs-only planning — zero dev-project effect**: nothing
> here applies anything to the dev Supabase project; every external step
> stays behind the owner's dated approval (INSTRUCTIONS.md §2.1/§5 hard
> gates). **Branch: `feat/notification-feed-read`.**
>
> **Gate state (why this slice is now plannable):** the scope note is
> **DECIDED 2026-08-11** (`docs/notification_feed_scope_2026-08-11.md` —
> owner ratified §3, D-N1…D-N7; the new surface is authorized, D-N1).
> **Step 0 is MET** — the slice starts at T1 (mechanism/RLS-gate
> review). No provider decision is needed for a read feed
> (no push/FCM/device delivery — roadmap line 484 keeps delivery out;
> D-N2). The nine shipped slices
> (matters → billing invoices) established the per-feature pipeline this
> plan runs. The dev project's applied tables/RLS/policies are the
> harness baseline to extend.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Move the **notification surface** from "settings + device-local prefs
only" (D-T7) to a real, org-scoped, **read-only feed**: a
`public.notifications` table + RLS + a read RPC, and a client
`NotificationGateway` seam behind `env.isConfigured` (the established DI
flip; fake for env-less/demo runs). "Done" = an **active member of an
org** reads exactly the **redacted metadata rows** for their org —
category, type, synthetic summary, server timestamp — newest-first; every
other read (non-member, cross-org, unauthenticated, `platform_owner_admin`
deny-always posture) is denied and policy-tested. **No push, no delivery,
no provider, no read-flag writes in v1** (D-N2/D-N6); prefs filtering is a
later additive slice (D-N5). The matrix gains a §4 "View notifications
(metadata)" row.

## 2. Gap (verified)

| Claim | Verified fact |
|---|---|
| Only settings/prefs exists | `lib/features/notifications/` = prefs model + stores (in-memory/SharedPreferences) + cubit + `notification_settings_screen.dart`; D-T7 records it as the only notifications surface |
| No feed designed | spec §6 has no notification-feed row — the surface is NEW (owner authorization required, D-N1) |
| No table/RLS/RPC/matrix rows | zero notifications references in `supabase/migrations/`, `supabase/policies/`, `supabase/rpc/`, `docs/permission_matrix.md` (verified 2026-08-11) |
| Delivery explicitly out | roadmap line 484 ("no realtime/delivery/notifications" in messaging); the prefs model itself says "nothing here promises delivery" |
| Harness baseline | 12 tables / 12 RLS / 11 public + 1 storage policies / publication exactly messages / 19–20 EXECUTE RPCs / batteries 01–13 (current applied surface) |

## 3. Design decisions (D-N1…D-N7 — ratified from the scope note §3; the T1 mechanism review answers on these)

- **D-N1 — NEW surface authorized** (the gate): the feed is not in the
  spec; this plan only runs after the owner ratifies the scope note.
- **D-N2 — read-only v1:** server-generated rows fetched on open; **no
  push/FCM/device delivery** — that stays a separate deferred capability
  (roadmap line 484), so **no provider decision is needed**.
- **D-N3 — redacted metadata rows:** type + category + synthetic summary
  + server timestamp + org scope; no message content, no PII field names
  (the audit-row discipline, contract §8).
- **D-N4 — categories:** rows carry the same three generic categories as
  the prefs (`appointment` / `activity` / `system`).
- **D-N5 — no prefs filtering in v1:** the feed renders all rows; wiring
  prefs to filter is a later additive slice.
- **D-N6 — server-tracked unread column, read-only in v1:** `is_read`
  exists (seeded `false`) but **no read-flag RPC in v1** — a future write
  slice; the feed renders rows without mutating.
- **D-N7 — synthetic demo rows first:** the fake seeds deterministic
  synthetic rows; real-event mapping per shipped surface is decided
  slice-by-slice, never invented here.

## 4. Artifact sketch (rehearsal-ready when approved)

- **Table `public.notifications`:** `id` (uuid PK), `organization_id`
  (FK → `organizations` cascade), `category` (text CHECK in
  `('appointment','activity','system')`), `type` (text — e.g.
  `matter_updated`), `summary` (text — synthetic demo copy only, never
  PII), `server_timestamp` (timestamptz), `is_read` (bool default
  `false`). **No user identity, no content columns** — the redaction
  posture made structural.
- **RLS `notifications_select_org`:** `is_active_member(organization_id)`
  — any active member of the org reads the org's notifications;
  non-member / cross-org / anon denied (the organizations-gate pattern,
  battery-tested precedent).
- **Read RPC (or direct PostgREST read):** newest-first rows for the
  caller's org, metadata only. Matrix row: member **SHIP**; non-member
  deny; `platform_owner_admin` deny-always posture.
- **Battery additions (e.g. `14_notification_rls.sql`):** member positive
  (own org), non-member denied, cross-org denied, anon denied,
  category-CHECK violation rejected, cascade on org delete.

## 5. Client slice (env-gated swap)

- `Notification` VO (id, category, type, redacted summary,
  serverTimestamp, isRead) + `NotificationGateway` seam
  (`fetchNotifications()` → `Result<List<Notification>>`): fake with
  deterministic synthetic rows; Supabase impl behind `env.isConfigured`.
- Feed screen under the `/notifications` route family (settings stays; a
  sibling feed entry), reusing the shared barrel (`ViewStateSwitch` /
  `AppTile` — loading/empty/error-with-retry arms included).
- **No delivery language anywhere** ("no push" copy rule, mirroring
  "no live-payment copy"); the settings surface and `NotificationPrefs`
  untouched (existing tests pin the regression).

## 6. Gate sequence (T1–T8)

1. **Scope note ratified + D-N1 authorization** (owner) — the gate
2. Mechanism/RLS-gate review — dated review note (row shape, org
   scoping, redaction, category CHECK)
3. Artifacts: `supabase/migrations/14_notifications.sql` (+ `.down`) +
   `policies/notifications.sql` + read RPC — rehearsal-ready
4. Battery + harness wiring — static `--check` green (selftest 6/6)
5. Ephemeral rehearsal r1 — genuinely executed, dated evidence
6. Dated apply-approval (owner) → apply to the dev project, per-step
   output captured
7. Dated matrix §4 addendum + applied-surface §6 addendum
8. Env-gated client swap (gateway seam + feed screen + entry) + tests +
   the full gate stack (format/analyze/suite/ledger/policy)

## 7. Acceptance criteria (testable)

1. Feed renders newest-first metadata rows (category/type/summary/date).
2. Loading / empty / error-with-retry arms follow the shared
   `ViewStateSwitch` contract.
3. Fake returns deterministic synthetic rows; Supabase impl only when
   configured; RLS denies are battery-pinned.
4. No delivery/push language anywhere; no read-flag writes.
5. Settings + prefs untouched (regression pinned).
6. RTL / large-text / narrow-width no-overflow (shared-widget tests).

## 8. Risks & open questions

- **D-N1 is MET (2026-08-11)** — the surface is not in the spec, but the
  owner ratified the scope note and authorized it; the remaining §8
  questions (row sources, home-shell entry, server-now-vs-later) are
  slice-shape choices, not gates.
- **Row sources:** synthetic-only (D-N7) or should the first slice also
  map real events from shipped surfaces (messages/invoices)?
- **Home-shell entry:** an icon/badge on the home app bar or an
  `AppEntryCard` in the grid?
- **Server slice now or later:** the pure-client fake feed first (fastest
  demo value) with table/RLS/RPC as a follow-up — or the full server
  slice in one pass (the nine-slice shape)?

## 9. Ledger

- PLANNED 2026-08-11; step 0 (scope ratification + D-N1 authorization)
  **MET 2026-08-11**. Docs-only so far; zero dev-project effect. Nothing
  applies without the owner's dated approval of steps 5/6/7.
