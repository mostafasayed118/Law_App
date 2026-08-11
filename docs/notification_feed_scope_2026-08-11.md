# LegalHub — Notification Feed Scope Note (read surface, no provider) — DECIDED (2026-08-11)

> **Record type:** Spec-lite scope note for a **new surface** (the feed is
> NOT enumerated in `docs/legalhub_specification.md` — verified below).
> **Status: DECIDED 2026-08-11 (owner ratified §3, D-N1…D-N7; the new
> surface is authorized).** The slice is **un-blocked** to start the
> T1–T8 pipeline (slice plan `docs/notification_feed_slice_plan_2026-08-11.md`).
> **No code, no live-system effect in this record** — every external
> step stays behind the owner's dated approval (INSTRUCTIONS §2.1/§5).
> The feed is a **read surface** — server-generated notification rows
> fetched like the shipped read slices; **no push/delivery provider is
> needed for v1** (delivery stays out, exactly as `docs/features_roadmap_2026-08-03.md`
> line 484 excludes it from messaging). **Owner:** Project Owner
> (github.com/mostafasayed118), ratified 2026-08-11.

---

## 1. Provenance

- Today the only notifications surface is **settings + device-local
  prefs**: `NotificationPrefs` (`appointmentReminders` /
  `activityUpdates` / `systemAlerts`), `NotificationPrefsStore`
  (in-memory + SharedPreferences — the locale-store pattern),
  `NotificationPrefsCubit`, route `/notifications` →
  `notification_settings_screen.dart`. D-T7
  (`docs/tracked_deviations.md`, 2026-08-09) records that this is the
  only notifications surface; the prefs model itself documents
  "Notification *delivery* is a v1 capability" and "nothing here promises
  delivery."
- The spec enumerates only `notification_settings,
  partner_notification_settings` (§6 row 157); there is **no
  notification-feed / inbox row** — a feed is a new surface this note
  designs for owner decision.
- Roadmap line 484 (matter messaging) excludes
  "realtime/delivery/notifications" — the project's posture is: a feed
  read surface and push delivery are separate capabilities, and delivery
  stays deferred.

## 2. Spec basis (verified)

| Source | What it authorizes / constrains |
|---|---|
| `docs/legalhub_specification.md` §6 row 157 | Only notification **settings** is designed; a feed needs this note + owner authorization |
| `docs/tracked_deviations.md` D-T7 | The settings screen is the only notifications surface today — unchanged by this note |
| `lib/features/notifications/domain/notification_prefs.dart` | Prefs categories are generic (appointment/activity/system) with no delivery promise — the feed must not pretend delivery |
| `docs/features_roadmap_2026-08-03.md` line 484 | Delivery/notifications excluded from messaging slices — push delivery stays deferred |
| The nine shipped read slices (matters → billing invoices) | The T1–T8 per-feature pipeline a feed slice would run: artifacts → battery → rehearsal r1 → dated apply-approval → apply → matrix addendum → env-gated client swap |

## 3. Proposed decisions (for owner ratification)

| ID | Question | Proposed decision |
|---|---|---|
| D-N1 | Surface authorization | **New feed surface approved** — a `/notifications/feed` read list + entry from the home shell (the spec has no row; this note is the first design step) |
| D-N2 | Delivery posture | **Read-only v1.** Server-generated rows, fetched on open; **no push/FCM/device delivery** — that stays a separate deferred capability (roadmap line 484), so **no provider decision is needed** for this slice |
| D-N3 | Row shape | Redacted metadata, the audit discipline: type + category + short summary + server timestamp + org scope; no message content, no PII field names, no raw text beyond the synthetic summary |
| D-N4 | Categories | Rows carry the same three generic categories as the prefs (`appointment` / `activity` / `system`) — the honest bridge: prefs record what the user wants; the feed is where categories would eventually be honored |
| D-N5 | Prefs filtering | **Not in v1.** The feed renders all rows; wiring prefs to filter rows is a later additive slice (no silent coupling to a not-yet-approved behavior) |
| D-N6 | Unread state | **Server-tracked** read/unread column (org-scoped, like every shipped row) — device-local unread would drift across sessions; the read-flag RPC is a future write slice, v1 renders the feed read-only |
| D-N7 | Row provenance | Synthetic demo rows first (the fake-gateway pattern); real events per shipped surface (matter updates, messages, invoice status, approvals) are decided slice-by-slice — never invented here |

## 4. Scope (planning boundary)

**In scope:** the feed design (§5), a `NotificationGateway` seam shape
(`fetchNotifications` → `Result<List<Notification>>`, fake + env-gated
Supabase impl — the matter/document/booking pattern), a `Notification`
VO (redacted metadata per D-N3), the feed list screen + home-shell entry,
and the T1–T8 gate sequence (§7).

**Explicitly out:** push/FCM/device delivery (deferred, D-N2), prefs
filtering (D-N5), read/ack writes (D-N6), any change to the shipped
settings surface or `NotificationPrefs`, and any notification content
that references an unapproved data slice.

## 5. Feed design (the future slice)

1. **Row** — `Notification` VO: `id`, `category` (appointment/activity/
   system), `type` (e.g. `matter_updated`, `message_received`,
   `invoice_status`), redacted summary, `serverTimestamp`, `orgId`.
2. **Gateway** — `NotificationGateway.fetchNotifications()` →
   `Result<List<Notification>>`, newest-first; fake returns synthetic
   demo rows; the Supabase impl runs the RPC read path behind
   `env.isConfigured` (the established DI flip).
3. **Screen** — feed list under the existing `/notifications` route
   family (settings stays; feed is a sibling entry), reusing the shared
   list-state vocabulary (`ViewStateSwitch`/`AppTile` from the refactor
   barrel — empty/error/loading arms included).
4. **Redaction** — the summary is synthetic-only and the row never
   renders message bodies or document names (contract §8 posture).

## 6. Acceptance criteria (testable)

1. Feed renders newest-first rows with category + type + summary + date.
2. Loading / empty / error (with retry) arms behave like the shipped list
   screens (the shared `ViewStateSwitch` contract).
3. The fake returns deterministic synthetic rows; the env-gated Supabase
   impl is exercised only when configured.
4. No delivery language anywhere ("no push" copy rule, mirroring
   "no live-payment copy").
5. The settings screen and `NotificationPrefs` are untouched (regression
   pinned by the existing tests).
6. Arabic RTL + large-text + narrow-width no-overflow (the shared-widget
   tests already pin the components).

## 7. Gate sequence (T1–T8, the established per-feature discipline)

1. **This scope note ratified + owner authorization** of the new surface
   (D-N1) — the step that makes the slice real
2. Mechanism/RLS-gate review — dated review note (server row shape, org
   scoping, redaction)
3. Artifacts: `supabase/migrations/NN_notifications.sql` (+ `.down`) +
   policy + read RPC — rehearsal-ready
4. Policy battery + harness wiring — static `--check` green
5. Ephemeral rehearsal r1 — genuinely executed, dated evidence
6. Dated apply-approval (owner) → apply to the dev project
7. Dated permission-matrix §4 + applied-surface §6 addenda
8. Env-gated client swap (gateway seam behind `env.isConfigured`; fake
   for demo runs) + tests + the full gate stack

**This note authorizes nothing beyond design** — steps 2–8 run only after
the owner ratifies §3 and approves the slice.

## 8. Open questions for the owner

- **Authorize the surface?** A feed is not in the spec — D-N1 is the gate.
- **Row sources:** synthetic demo rows only (D-N7), or should the first
  slice also map real events from already-shipped surfaces (e.g.,
  messages/invoices)?
- **Home-shell entry:** a notifications icon/badge on the home app bar,
  or an entry card in the grid (the `AppEntryCard` pattern)?
- **Server slice now or later:** the pure-client fake feed first (fastest
  demo value), with the table/RLS/RPC slice in a follow-up — or the full
  server slice in one pass (the nine-slice shape)?

## 9. Ledger

- DRAFTED 2026-08-11; **DECIDED 2026-08-11 by the Project Owner**
  (ratified §3, D-N1…D-N7; new surface authorized). No code, no
  live-system effect, nothing applied. The slice is un-blocked to start
  T1 (mechanism/RLS-gate review) per the slice plan.
