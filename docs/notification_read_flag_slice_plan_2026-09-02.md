# Plan: Notification Read-Flag Write Slice (D-N6) — the feed becomes markable (2026-09-02)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> **notification read-flag write** — the D-N6 follow-up named by the shipped
> feed scope (`docs/notification_feed_scope_2026-08-11.md` §3 D-N6: "the
> read-flag RPC is a future write slice") and the §14 close's follow-up
> list (`docs/p14_plan_complete_2026-08-11.md` addendum: "read-flag writes
> (D-N6) remain future slices"). **Status: RATIFIED 2026-09-02** — the
> owner approved continuing the remaining project work ("أعمل push وانا
> موافق علي كل حاجه", this session), which un-blocks this slice under the
> standard T1–T8 discipline; the dev-project apply still runs the dated
> runbook and records its execution below. **D-N2 (push/FCM/device
> delivery) stays OUT** — it needs a provider decision (the D-11
> payments-precedent), never invented here (D-N7).
>
> **Branch: main (owner-directed direct commits, 2026-09-02 convention).**
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Give the shipped, non-vacuous feed an **org-scoped write path**: an active
member marks feed rows read, the server tracks `is_read` (already the D-N6
column), the mark is §8-audited, and the feed renders the read/unread
state honestly. "Done" = the shipped read battery (14) and producer battery
(15) stay green, the new battery 16 proves the gate (member marks own-org
rows; cross-org/anon/non-member denied; the mark-read audit does **not**
re-produce a feed row), and the client feed renders tappable rows that
flip to read through the env-gated seam.

## 2. Gap (verified)

| Claim | Verified fact |
|---|---|
| `is_read` exists but never mutates | `migrations/14_notifications.sql` line 46 — "display metadata only in v1; no read-flag RPC" |
| No write grant exists | the migration revokes all from anon/authenticated and grants SELECT only; `policies/notifications.sql` ships exactly one SELECT policy |
| The client VO already carries the flag | `Notification.isRead` (mapped + guarded in the Supabase impl); the feed renders it, rows carry **no tap** (D-C2/D-N2 pin in `notification_feed_screen.dart`) |
| Producer interplay is safe to extend | the producer's D-P2 map is exactly `{matter:create, message:create}` — a `notification:mark_read` audit action is outside the map, so no feed row is produced from a mark (battery-pinned) |
| Harness | `scripts/verify_policy_tests.sh` BATTERY_FILES enumerates 00–15 explicitly; battery 16 is an additive list entry |

## 3. Design decisions (owner-approved 2026-09-02)

- **D-F1 — one RPC, the send_message posture:** `mark_notifications_read(
  p_notification_ids uuid[])` returns `integer` (rows flipped).
  `security definer` + explicit in-function gate (RLS does NOT apply inside
  a definer function — the gate IS the sole write authorization): every
  targeted row must belong to an org where the caller `is_active_member`
  (the same organizations gate as the read policy — org-wide metadata, not
  the matter-assignment subquery). Rows in other orgs are silently
  untouched (the function updates what it may and returns the count —
  never an error surface for cross-org ids).
- **D-F2 — §8 audit, redacted:** every successful call writes one
  `notification:mark_read` / `allowed` audit row **per distinct org
  touched**, with the redacted generic summary `notification read state
  updated` — never ids in the summary, never content. Same implicit
  transaction as the update (an audit failure rolls the mark back).
- **D-F3 — no new table grant, no new policy (D-F1 mirror):** the RPC is
  the ONLY write path; no UPDATE grant on `notifications` and no new RLS
  policy — applied counts stay **13 tables / 13 RLS / 12 public policies**
  (the trigger precedent: the write is a server mechanism behind the
  function's gate). EXECUTE: revoked from `public`/`anon`, granted to
  `authenticated` — the RPC-EXECUTE pin moves **20 → 21**.
- **D-F4 — idempotent, count-honest:** `is_read = true` is only written
  to `is_read = false` rows; re-marking already-read rows returns 0 (the
  client reloads after the mark, so the count is informational).
- **D-F5 — client seam mirrors the read discipline:**
  `NotificationGateway.markNotificationsRead(List<String> ids)` →
  `Result<int>`; the fake flips its in-memory synthetic rows
  deterministically; the Supabase impl calls the RPC through the
  `SupabaseNotificationApi` seam (typed denied/unavailable/unknown
  mapping). No store, no prefs, no persistence beyond the server column.
- **D-F6 — the feed row becomes deliberately tappable (re-scope):** tapping
  an unread row marks it read (single id) and the screen reloads. The
  D-C2/D-N2 "no row tap" pin is re-scoped exactly the way 12.1 re-scoped
  D-MSG3: read rows stay non-interactive; unread rows carry a shape+weight
  unread marker (never color alone) and a semantics label. No "mark all"
  affordance in v1 (YAGNI — a future additive slice).
- **D-F7 — matrix §4 addendum:** the "View notifications (metadata)" row
  gains the write half: `mark_notifications_read` — member SHIP (own-org
  rows only, in-function gate), non-member/anon deny.

## 4. Artifacts (rehearsal-ready)

- **`supabase/migrations/16_notification_read_flag.sql`** — create the
  function (security definer, `set search_path = public`, in-function
  `is_active_member` gate, per-org audit rows, returns flipped count);
  `revoke execute … from public, anon` + `grant execute … to
  authenticated`.
- **`supabase/migrations/16_notification_read_flag.down.sql`** — drop the
  function (the rollback-pairing contract).
- **`supabase/tests/16_notification_read_flag.sql`** — battery 16,
  delta-based POLICY-BATTERY blocks: member marks own-org rows (count
  exact, `is_read` persists), idempotent re-mark → 0, cross-org id → 0,
  non-member/anon → EXECUTE denial or 0 rows, the audit row is written
  with the redacted summary, and the mark-read audit produces **no** feed
  row (D-F4/D-P2 interplay).
- **Harness:** battery 16 appended to `scripts/verify_policy_tests.sh`
  BATTERY_FILES.

## 5. Client slice

- `SupabaseNotificationApi.markNotificationsRead(List<String> ids)` seam
  method + impl (PostgREST RPC caller, exact-param pin).
- `NotificationGateway.markNotificationsRead` + fake mirror + Supabase
  gateway (typed failure mapping).
- `NotificationCubit.markRead(String id)` → gateway call → `load()`
  refetch (honest; the count is not surfaced).
- `NotificationFeedScreen`: unread rows tappable + shape/weight unread
  marker + semantics label; read rows stay non-interactive; the D-C2/D-N2
  pin tests re-scoped deliberately.
- l10n: `notificationsFeedUnreadSemantics` EN/AR/TR + resolution pins.
- No change to settings/prefs (the D-N5 filtering line stays out).

## 6. Acceptance criteria (testable)

- **AC-1 (RPC gate):** an active member marks own-org rows — exact flipped
  count; `is_read` persists; the audit row carries the redacted summary;
  **no** feed row is produced from the mark-read audit (D-F4).
- **AC-2 (denials):** cross-org ids → 0 flips, no error surface to the
  caller's own rows; non-member/anon → denied (EXECUTE grant shape pinned;
  battery denies the function to anon); already-read re-mark → 0.
- **AC-3 (client contract):** the fake mirrors marks deterministically;
  the Supabase impl pins the exact RPC param shape; failures map to typed
  `AppError`s; the cubit reloads after a successful mark.
- **AC-4 (screen):** unread rows are tappable and flip to read (row +
  marker update after reload); read rows are non-interactive; the unread
  marker is shape+weight with a semantics label (never color alone); the
  no-mark-all pin.
- **AC-5 (l10n):** the new key resolves in EN/AR/TR with no silent-EN copy.
- **AC-6 (gate stack):** format 0-changed · analyze clean · full suite
  green · ledger PASS · README lockstep; battery 16 green on the rehearsal
  project before the dated apply; the applied counts stay 13/13/12 + RPC
  EXECUTE 21.

## 7. Gate sequence (T1–T8, this slice)

1. Plan ratified (owner, 2026-09-02 — recorded above) ✅
2. Mechanism/gate review — folded into §3 (the send_message posture is the
   reviewed precedent; this plan cites it row-for-row)
3. Artifacts: migration 16 + down + battery 16 + harness entry
4. Battery 16 + harness — static `--check` green
5. Rehearsal r1 on the linked dev project — genuinely executed, dated
6. Dated apply-approval (owner, 2026-09-02) → apply via the producer
   runbook (`supabase db query --linked`), per-step output captured
7. Matrix §4 + applied-surface addenda
8. Env-gated client swap + tests + the full gate stack + README lockstep

## 8. Non-goals

Push/FCM/device delivery (D-N2 — needs a provider decision, deferred);
prefs filtering (D-N5 — separate additive slice); mark-all affordance;
any settings/prefs change; any content column (redaction stays
structural); matter/document/invoice producers (D-N7 — no invented
events).

## 9. Ledger

- PLANNED + RATIFIED 2026-09-02
  (`docs/notification_read_flag_slice_plan_2026-09-02.md`), citing the
  shipped feed scope D-N6 and the owner's 2026-09-02 approval; execution
  records appended by the apply step.
