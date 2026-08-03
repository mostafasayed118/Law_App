# LegalHub — Phase 5 Scope Note: Consultation Booking (no live payment) — DRAFT (2026-08-03)

> **Record type:** Spec-lite scope note required by the Phase 5 gate.
> **Status: DRAFT — NOT approved, NOT scheduled.** The owner shelved
> `feat/booking-flow` on 2026-08-03 (headless, unverifiable citations, 60
> commits of divergence). This note replaces the branch code comments'
> unverifiable approvals and pins the real basis (§2) and the real decisions
> (§3). **Planning owner:** Project Owner.

---

## 1. Provenance

- `feat/booking-flow` = 3 commits (`dd6aade` domain, `9c7d4cc` fake + DI,
  `cdc8845` cubit/state), 13 files, +1532/−5, ~975 test lines.
- Shelved 2026-08-03: no `booking_screen`, no router reference; approvals
  cited in code comments do not exist in any tracked document; main was 60
  commits ahead of the branch base (`618e370`).
- Landing sequence: this note ratified → UI + routing slice (roadmap Draft A2
  slices 5.1–5.3) → gate stack → owner push approval.

## 2. Spec basis (verified — replaces the fictional "AC#8"/"D2–D4"/"G1")

| Source | What it authorizes |
|---|---|
| `docs/legalhub_specification.md` §4 MVP (line 58) | "Consultation booking (no live payment)" is MVP safe-to-build |
| §6 remediation row: `consultation_type, select_date_time, review_confirm_booking, booking_success` | the 4-step machine the cubit implements; "No live payment copy" |
| §3 D-09 (open) | booking *payment* is gated on D-09; this slice has none |
| `docs/legalhub_bootstrap_specification.md` (line 26) | booking excluded from bootstrap — consistent; foundation never built it |
| Verified absence | `AC`, `D2/D3/D4` (no hyphen), `G1` → zero matches in the spec; `D-02/D-03/D-04` exist but concern legal model / jurisdiction / residency — none covers booking |

## 3. Decision record (owner ratifies each before implementation)

| ID | Decision | State on branch |
|---|---|---|
| D-B1 | Category options are exactly General / Follow-up / Urgent (enum-pinned by test) | implemented |
| D-B2 | Synthetic, availability-free slots (no cutoffs / weekend / attorney-schedule rules) | implemented |
| D-B3 | Confirm is local-only (in-memory fake); UI copy must never imply a backend promise | implemented |
| D-B4 | Single `/book` route with an internal step switcher; the draft never travels in route params / GoRouter `extra` | implemented |
| D-B5 | Review → category "Edit category" jump (an addition beyond the 4-step diagram, ratified here) | implemented |
| D-B6 | No live-payment copy anywhere (spec §6); `booking_success` wording stays local-only | implemented |
| D-B7 | **DECIDED 2026-08-03 — (a) standalone**; **LANDED 2026-08-03** in `05f13c8`/`0eb7ec9`. Attorney-discovery dependency: spec §4 lists "Attorney discovery (read-only)" before booking and the design set carries `attorney_search, attorney_profile` ahead of the booking screens, but the spec does not couple them (separate MVP bullets, separate screen groups; the booking flow row has no attorney step). Phase 5 proceeds with the shelved flow as built (category/topic/slot); a future discovery phase adds an **optional** `attorneyId` to `BookingRequest` + a "book from attorney profile" entry behind the same `BookingGateway` seam — an additive slice, not a Phase 5 blocker. | decided 2026-08-03 (a); landed (additive `attorneyId` slice deferred) |

## 4. Scope

**Reused from the branch as-is:** `BookingGateway` seam (`fetchSlots` /
`confirm` → `Result`, §D.4 convention), `BookingRequest` (`toRedactedMap`
idempotent + `toString() == '[REDACTED]'`, privacy F1), `BookingCategory` /
`BookingSlot` / `BookingConfirmation` synthetic VOs, `BookingCubit` +
`BookingState` (4 steps, stale guards, duplicate-confirm guard),
`FakeBookingGateway`, DI registration + `service_locator_test` pin.

**Built in this phase:** booking screen + wizard shell, `/book` route +
app-shell entry, EN/AR/TR strings, widget tests (roadmap Draft A2 slices
5.1–5.3).

## 5. Acceptance criteria (testable against the actual code)

1. **Step order:** category → dateTime → review → success; `back()` is
   one-step (no-op on category/success); `editCategory` jumps review →
   category with the draft (topic + slot) retained.
2. **Step guards:** advance blocked without category (step 1) / slot
   (step 2); `confirm` ignored while submitting or already succeeded; an
   errored submit is re-confirmable.
3. **Slot load:** `fetchSlots` → `ViewState` (loading → success / empty /
   error+retry); responses landing after leaving the step are dropped.
4. **Confirm:** success → success step + `BookingConfirmation` reference id;
   failure → stays on review with `submitError` surfaced and the draft
   intact.
5. **Privacy:** `BookingRequest.toRedactedMap()` is Redactor-safe and
   idempotent; `toString() == '[REDACTED]'`; no free-text topic in logs or
   errors.
6. **Fake determinism:** fixed synthetic slots; immediate resolution;
   in-memory confirmations with `LH-DEMO-XXXX` ids; `confirmedBookings`
   inspection seam.
7. **No payment copy** (spec §6) and **no draft in route params/extra**
   (D-B4).
8. **UI slice ships** the wizard from `BookingState`, `/book` registered,
   shell entry present, all strings localized EN/AR/TR (no hardcoded
   strings).
9. **Gate stack green** — `dart format` + `flutter analyze` + `flutter test`
   + `scripts/verify_ledger.sh` (README count in lockstep);
   `service_locator_test` pin retained.

**Existing-test coverage (verified against the branch, 2026-08-03):**
`booking_cubit_test.dart` (812 lines — 3 `test` + 14 `blocTest<BookingCubit,
BookingState>`) exercises AC-1–AC-4 by name (e.g. "continueFromCategory is
ignored without a category", "F3: back … preserves the selected slot",
"duplicate confirm while submitting is ignored", "confirm failure stays
on review … retry works"); `booking_request_test.dart` (5 tests) exercises
AC-5 ("toString returns [REDACTED] …", "toRedactedMap is idempotent…");
`fake_booking_gateway_test.dart` (3 tests) exercises AC-6 — its
"never persists request content — only the confirmation is stored" test
pins D-B3. **AC-7–AC-9 have no existing tests** — they are UI-slice
deliverables and must be added in slices 5.1–5.3. At landing, every AC
must map to a named test; an AC without one is not met.

## 6. Assumptions & non-goals

- Fake-domain: the real booking data contract is deferred to P2/P3; this
  phase adds no backend, no schema/RLS/policy, no matrix addendum (booking
  is not an org-surface).
- No attorney-discovery integration (D-B7 decided 2026-08-03: standalone; additive `attorneyId` slice **deferred**, see decision record), no availability logic, no payment, no
  video/phone/in-person consultation modes (D-B1).
- The four checks were **NOT** run against the branch on this machine at
  drafting time (R1) — at landing (`05f13c8`/`0eb7ec9`/`3bd3d29`) the full
  gate stack was run on the merged tree: format CLEAN, analyze clean, 521
  tests pass, ledger PASS 115.

## 7. Risks

- **R1 — branch unverified:** the four checks must run in a clean worktree
  before merge (the earlier attempt hit an occupied worktree — the branch
  is checked out in sibling `C:/flutter_projects/law_app_ui`).
- **R2 — 60-commit divergence:** real conflict surface in
  `lib/app/service_locator.dart` + `test/service_locator_test.dart`; plan a
  rebase or a careful integration pass.
- **R3 — sibling worktree:** coordinate with any session using
  `C:/flutter_projects/law_app_ui` before merging.
- **R4 — fake-domain promise discipline:** `booking_success` wording must
  stay local-only; a future backend must not inherit the fake's shapes
  silently.
- **R5 — stale synthetic dates:** fixed slot `DateTime` literals are
  accepted for the demo (the fake's own R3 note) and must not grow into
  availability logic.

## 8. Exit

Roadmap row advanced → decision record ratified (D-B1…D-B7) → UI + routing
slice built → four checks green → suite/README count in lockstep (521) →
owner push approval. **All met 2026-08-03** — Phase 5 SHIPPED.
