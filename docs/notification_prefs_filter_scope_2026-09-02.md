# Scope Note: Notification Prefs Filtering (D-N5) — the feed honors the toggles (2026-09-02)

> **Record type:** Spec-lite scope note for the **D-N5 follow-up** named by
> the shipped feed scope (`docs/notification_feed_scope_2026-08-11.md`
> §3 D-N5: "prefs filtering is a later additive slice"). **Status:
> APPROVED 2026-09-02** — the owner approved continuing the remaining
> project work ("كمل شغل", this session). Client-only — zero dev-project
> effect (no migration, no RPC, no policy, no matrix addendum): filtering
> is a **presentation** concern over the already-shipped read surface.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Consume the D-N4 bridge: the feed **honors the device-local
`NotificationPrefs` toggles** — rows whose category is disabled in the
user's prefs are hidden from the feed. The prefs screen stays the
single source for the toggles; the feed reflects them on every load.

## 2. Design decisions (owner-approved 2026-09-02)

- **D-PF1 — presentation-only filter (never authorization):** the cubit
  filters the fetched rows by the enabled categories before emitting.
  The server read path is untouched (`notifications_select_org` still
  returns the org's rows; the device-local prefs carry no backend meaning
  — the `NotificationPrefs` contract, verbatim).
- **D-PF2 — read at each load, no live stream:** the cubit reads the
  prefs store once per `load()`; the feed reflects toggle changes on the
  next open/load. The settings screen keeps its own cubit/store wiring
  (untouched — the existing tests pin the regression).
- **D-PF3 — the honest muted state:** when the server returned rows but
  **every** row was hidden by the toggles, the feed renders a distinct
  localized "muted" note — never the plain "No notifications" copy, which
  would be false (rows exist). A genuinely empty feed keeps the existing
  empty copy. Partial hiding renders no extra note (that is exactly what
  the toggles asked for).
- **D-PF4 — no prefs write changes:** `NotificationPrefs`,
  `NotificationPrefsStore`, the settings screen, and the prefs cubit are
  untouched; the feed resolves the **registered** store (the same
  SharedPreferences/in-memory pair) read-only.

## 3. Acceptance criteria (testable)

- **AC-1:** with `activityUpdates = false`, activity rows are hidden and
  the other categories render (cubit-level, in-memory store).
- **AC-2:** with every toggle off, the visible list is empty AND the
  state carries the muted signal; the screen renders the muted note, not
  the plain empty copy.
- **AC-3:** a genuinely empty fetch still renders the plain empty copy
  (the muted note is not a false "everything is muted").
- **AC-4:** a null/unavailable store changes nothing (defaults = all
  enabled — the existing behavior is pinned).
- **AC-5:** the muted key resolves in EN/AR/TR with no silent-EN copy.
- **AC-6:** the gate stack (format/analyze/full suite/ledger/README
  lockstep) stays green.

## 4. Non-goals

Per-category server-side filtering (the read path is unchanged); any
prefs write path change; a "N hidden" counter (minimal surface — the
muted-all case is the only honesty hazard); delivery (D-N2 stays out);
any change to the settings screen.

## 5. Ledger

- APPROVED 2026-09-02 (`docs/notification_prefs_filter_scope_2026-09-02.md`),
  citing the shipped feed scope D-N5 and the owner's 2026-09-02 session
  approval. Client-only; no live-system effect.
