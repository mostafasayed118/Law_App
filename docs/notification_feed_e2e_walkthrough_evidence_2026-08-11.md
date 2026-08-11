# LegalHub — Notification-Feed E2E Walkthrough: Evidence (2026-08-11)

> **Record type:** configured-build E2E walkthrough of the notification-feed
> **client** surface (T8, `docs/notification_feed_slice_plan_2026-08-11.md`
> gate 8) against the live dev project — the first NEW surface to run the
> full T1–T8 pipeline. Executed 2026-08-11, owner-requested, after the T8
> client swap landed (`1f546fb`, suite 1303).
>
> **Status: EXECUTED + PASSED 2026-08-11 on the shared dev project**
> (`eutmvevpskerzpqmwplv`, `eu-central-1`).
>
> **Method:** the same role impersonation the repo's apply smokes and the
> 2026-08-09 final walkthrough use — `supabase db query --linked` (Management
> API SQL runner; no DB password touched), `set role authenticated` +
> `set_config('request.jwt.claims', …)` with the demo partner
> `8fa94af0-7390-4f7a-988a-3965f7da04de`, org
> `ef43087b-adf4-4480-9bb2-28c26f46ec71`. RLS applies normally, so every
> count below is the partner's **actual** policy-filtered view — the exact
> path `SupabaseNotificationGateway` takes (`notifications_select_org`,
> the organizations gate, T1 Q2/Q5).
>
> **Boundary (honest scope):** this is a server-round-trip walkthrough of
> the configured build's feed path — the read the client gateway makes, the
> empty render the app produces, and the anon denial the router/gateway
> surface. It is **not** a UI-driving pass (no emulator in this environment;
> the interactive half stays reserved for the owner per the D-45.1
> checklist posture). The client halves the SQL cannot prove — the home
> entry navigation, the feed screen's loading/empty/error arms, and the
> router's anon gate — are **pinned by the suite** (§6). The synthetic row
> demo ran inside `BEGIN … ROLLBACK` — zero residue; the walkthrough wrote
> no content and created no audit rows (the feed is a plain RLS read, no
> RPC, no §8 audit surface — D-N3).

## 0. Runbook (executed 2026-08-11, HEAD `1f546fb`)

```bash
# P1 — baseline: notifications table present, RLS on, 1 policy, 0 rows
# P2 — partner RLS read: impersonated partner → 0 rows (empty pre-producer, D-N7)
# P3 — non-vacuous positive: BEGIN; synthetic row (postgres) → partner sees 1 → ROLLBACK
# P3b — residue: rows after rollback = 0
# P4 — anon denied: set role anon → 42501 permission denied (privilege layer)
# P5 — structural subset: 13 tables / 13 RLS / 12 public policies / 0 notification rows
```

## 1. Baseline (P1, postgres role)

| Probe | Result |
|---|---|
| `notifications` table present | **1** |
| RLS enabled | **1** |
| `notifications_select_org` policy live | **1** |
| `notifications` rows | **0** — feed empty pre-producer (D-N7: no producer slice; synthetic rows arrive with a future producer or the demo fake's env-less run) |

Matches the applied-surface §1b state (13 tables / 13 RLS / 12 public
policies) exactly.

## 2. Partner RLS read (P2 — the feed's gateway path, live)

Impersonating the dev partner (active member of the demo org) via
`set role authenticated` + `request.jwt.claims`:

```
│ member_read_count │
│ 0                 │      <- grant + organizations-gate resolve; the feed renders its honest empty state
```

The app's feed screen maps this to `ViewEmpty` → the localized
"No notifications are available." arm (pinned by the feed-screen widget
suite, §6) — **empty pre-producer, exactly the ratified D-N7 posture**:
never invented rows, never a fake-success.

## 3. Non-vacuous positive (P3 — in-txn, rolled back)

The organizations-gate read path must be provably **reachable** when rows
exist, not vacuously empty. Inside `BEGIN … ROLLBACK`, one synthetic row was
inserted as postgres (the fixture shape, D-N3 metadata only) and read as the
partner:

```
│ id                                   │ category │ type           │ summary                                  │ is_read │
│ e2e00000-0000-4000-8000-000000000001 │ activity │ matter_updated │ Demo notification — matter status update │ false   │
```

The partner sees the row through `notifications_select_org` — the exact
column set the feed gateway maps (`id, category, type, summary,
server_timestamp, is_read`). `ROLLBACK` → **residue check: 0 rows**
(P3b). No content left behind; the feed is empty again.

## 4. Anon denied (P4 — the 14.07 battery check, live)

`set role anon; select count(*) from public.notifications;` →

```
ERROR: 42501: permission denied for table notifications
HINT:  Grant the required privileges to the current role with:
GRANT SELECT ON public.notifications TO anon;
```

Denied at the privilege layer (no grant — the narrow `grant select to
authenticated` only), double-denied by the policy's `auth.uid()` footing.
The app's router blocks anon at the shell gate anyway; a configured build
with no session never reaches the feed.

## 5. Structural subset (P5, live)

```
│ public_tables │ rls_tables │ public_policies │ notification_rows │
│ 13            │ 13         │ 12              │ 0                 │
```

The T7 applied-surface counts, live: **13 tables / 13 RLS / 12 public
policies / 0 notification rows**.

## 6. Client halves pinned by the suite (what the SQL cannot prove)

| Surface | Pin | Evidence |
|---|---|---|
| Home entry navigates | `NotificationFeedEntryCard` renders on the home shell (every role — matrix §4 member SHIP) and `onTap → /notifications/feed` | `test/features/home/home_screen_test.dart` (renders + hides-without-flag) · `lib/features/home/presentation/home_screen.dart` |
| Feed route + anon gate | `/notifications/feed` renders for an authenticated session; anon redirects to sign-in; the settings screen (3 toggles) is NOT on the route | `test/app/router_test.dart` (notification-feed route group) |
| Feed screen arms | loading / empty / error+retry via `ViewStateSwitch`; rows render category chip + type + summary + date; read-only posture (no tap, no actions) | `test/features/notifications/notification_feed_screen_test.dart` (7 tests) |
| Gateway mapping + failure kinds | RLS denial → `notification_read_denied`; drift → loud failure; newest-first sort | `test/data/notifications/supabase_notification_gateway_test.dart` |

## 7. Ledger

- HEAD `1f546fb` (T8 client swap, suite 1303), working tree: only this
  evidence doc untracked.
- Live probes all green (P1–P5); **no findings** — the walkthrough surfaced
  nothing (the feed is empty by design and the read path resolves).
- No trigger/rollback invoked; no audit rows created (plain RLS read).
- Ledger sweep: PASS (verified after commit).

## 8. Next steps

- The feed remains **empty pre-producer** (D-N7): real-event mapping per
  shipped surface (matter updates, message received, invoice status,
  approvals) is decided slice-by-slice — a future producer slice seeds rows
  and the same walkthrough re-runs non-vacuously.
- Prefs filtering (D-N5) and read-flag writes (D-N6) remain future slices.
