# LegalHub — Attorney Discovery Scope Note (Phase 6, 2026-08-03)

> **APPROVED 2026-08-03** (owner ratification of D-A1…D-A6 + roadmap Phase 6
> row). Prepared per the governance-first flow (the Phase 5 pattern):
> verified spec basis → decision record → scope → acceptance criteria →
> assumptions & non-goals → risks → exit. Implementation begins with slice
> 6.1 behind the standard slice gate.

## 1. Provenance

- Date: 2026-08-03.
- Basis: `docs/legalhub_specification.md` §4 (MVP bullet "Attorney discovery
  (read-only)") and §6 remediation row for `attorney_search,
  attorney_profile`.
- Pre-committed integration: `docs/booking_scope_2026-08-03.md` §3 **D-B7**
  (decided 2026-08-03: standalone; **LANDED** in `05f13c8`/`0eb7ec9`) — a
  future discovery phase adds an **optional `attorneyId`** to
  `BookingRequest` + a "book from attorney profile" entry behind the same
  `BookingGateway` seam. This phase is that future phase.
- Precedent: the Phase 5 booking phase (`docs/booking_scope_2026-08-03.md`)
  — same scope-note structure, same fake-domain discipline, same
  AC↔test-map requirement at landing.

## 2. Spec basis (verified — no fictional citations)

| Spec source | What it says | How this phase honors it |
|---|---|---|
| §4 MVP | "Attorney discovery (read-only)" is an in-scope MVP bullet | Discovery ships read-only: search + profile surfaces, no attorney-initiated actions |
| §6 design set row 152 | `attorney_search, attorney_profile` — "(B) Maybe, (T) Yes"; "Remove any legal-advice/compliance-claim copy" | All copy follows the repo's theme + l10n rules; zero legal-advice / compliance-claim wording |
| §6 booking row 153 | Booking flow has **no attorney step** | Discovery does not insert an attorney step into the standalone booking wizard (D-B7 standalone); `attorneyId` is an optional pre-fill only |
| D-B7 (booking scope note) | Optional `attorneyId` + "book from attorney profile" behind `BookingGateway` | The additive slice lands here as D-A3 |

## 3. Decision record (owner ratifies each before implementation)

| ID | Decision | State |
|---|---|---|
| D-A1 | Discovery is **read-only**: no availability, no booking initiation, no attorney-messaging, no consultation modes from discovery surfaces | **ratified 2026-08-03** |
| D-A2 | **Fake-domain**: synthetic attorney list via an `AttorneyGateway` seam + dev fake (the Phase 5 D-B3 pattern); no backend, no schema/RLS/policy, no matrix addendum (no server change) | **ratified 2026-08-03** |
| D-A3 | **Booking integration (in scope):** "Book with this attorney" on the profile surface routes to `/book` pre-filled with an **optional `attorneyId`** in `BookingRequest` (the D-B7 additive slice). The standalone booking flow (no attorney context) remains fully functional — `attorneyId` is optional and never blocks the wizard | **ratified 2026-08-03** |
| D-A4 | Attorney profile preview carries **synthetic, non-PII data only**: name, locale, practice area, short bio — no phone/email/address/credentials | **ratified 2026-08-03** |
| D-A5 | Search is a **client-side filter** over the fake list (name / practice area); no server search RPC | **ratified 2026-08-03** |
| D-A6 | Role gating: discovery + book-from-profile visible to every bootstrap role (navigation hint only, never authorization — same posture as `canBookConsultation`) | **ratified 2026-08-03** |

## 4. Scope

- Read-only attorney discovery: a search surface (query + practice-area
  filter) over the fake list, and a profile surface per attorney.
- "Book with this attorney" entry: routes to the existing `/book` wizard
  with `BookingRequest.attorneyId` pre-filled (D-A3).
- EN/AR/TR l10n for all new strings (repo rule: no hardcoded strings).
- Client-only. No server change, no payment, no availability logic, no
  attorney messaging.

## 5. Acceptance criteria (testable against the actual code)

| # | AC | Mapped test (at landing, every AC must map to a named test) |
|---|---|---|
| AC-1 | The discovery surface lists the synthetic attorneys from the fake gateway | `attorney_gateway_test.dart` (fetch list shape) + discovery screen widget test |
| AC-2 | Search filters by name and practice area; an empty result set renders the localized empty state | discovery screen widget test (query + filter + empty) |
| AC-3 | Opening an attorney profile renders name, practice area, and bio — no private PII fields | profile screen widget test (field assertions) |
| AC-4 | "Book with this attorney" navigates to `/book` and the booking draft carries the optional `attorneyId` | router test (navigation) + `booking_request_test.dart` (attorneyId field pin) |
| AC-5 | The standalone booking flow (no attorney context) still completes end-to-end — `attorneyId` is optional | existing booking screen/cubit tests unchanged + one regression pin with `attorneyId` absent |
| AC-6 | All new strings resolve in EN/AR/TR (no hardcoded copy; discovery copy carries no legal-advice/compliance claim) | l10n 6.3 pin (per-locale resolution + "not a silent copy of EN") |

## 6. Assumptions & non-goals

- Fake-domain: the real attorney data contract is deferred to P2/P3; this
  phase adds no backend, no availability logic, no attorney-schedule rules,
  no payment, no messaging (D-A1/D-A2).
- Attorney profiles preview synthetic non-PII data only (D-A4).
- Search is a client-side filter, not a server search (D-A5).
- The booking wizard keeps its 4-step standalone shape; discovery never
  injects an attorney *step* into it (D-B7 standalone / spec row 153).

## 7. Risks

- **R1 — fake-domain honesty:** the synthetic attorney list must never read
  as real availability or a real directory; the profile surfaces carry the
  local-only demo note wording like the booking flow (D-A2/D-A4).
- **R2 — attorneyId optionality:** the additive `attorneyId` must not break
  the standalone booking path (AC-5 pins this); the `BookingRequest`
  redaction contract is extended without weakening it.
- **R3 — legal-advice copy:** any new discovery copy that implies legal
  advice, clearance, or compliance claims is out (spec §6 row 152); the
  l10n 6.3 pin asserts the copy is local-only wording.
- **R4 — scope creep:** "read-only" is the line — no attorney messaging, no
  appointment with a real attorney, no availability surfacing.

## 8. Exit

Roadmap Phase 6 row advanced → decision record ratified (D-A1…D-A6) → the
three slices built (6.1 seam+search, 6.2 profile+booking hook, 6.3 l10n) →
four checks green → suite/README count in lockstep → owner push approval.
