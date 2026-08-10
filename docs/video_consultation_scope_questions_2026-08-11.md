# LegalHub — Video-Consultation Scope Question Sheet (decision-support) — DRAFT (2026-08-11)

> **Record type:** Decision-support question sheet for the owner —
> converts the open video-consultation row (**spec D-11 — video
> consultation provider & data-handling**) into answerable questions
> whose answers define the video scope. **Status: DRAFT — no decision
> taken, no code, no live-system effect.** Same shape as the AI sheet
> (`docs/d07_d08_ai_scope_questions_2026-08-11.md`) and the conflict
> sheet (`docs/d03_d06_conflict_scope_questions_2026-08-11.md`), closing
> the decision-ready set for every open deferred row. **Owner:** Project
> Owner (+ counsel for data-handling).

---

## 1. Provenance

- **Spec row** (`docs/legalhub_specification.md` line 47) — "D-11 |
  Video consultation provider & data-handling | open | Product owner |
  Before video spec | Video consultation".
- **Placement** (line 60) — video consultation is **v1 (after MVP)**, the
  same bucket as billing/invoices, collaboration task board, notification
  delivery, and the compliance audit-trail viewer.
- **Designed screen** (line 159) — `video_consultation` — "Maybe | Yes |
  **Defer (D-11)**".
- **Dependency** (line 206) — "Video consultation → D-11, D-04"
  (D-04 = data residency & cross-border transfer — video data and any
  provider infrastructure are the residency question in play).
- **Label-collision note (must be resolved by the owner):** the spec's
  decision table assigns **D-11 to video consultation**, but the repo's
  `docs/d11_billing_payments_decision_2026-08-08.md` uses the **D-11
  label for billing/payments** (that record supersedes the spec's D-09
  payment row). `docs/p0_decision_capture.md` has **no D-11 entry**.
  So the video row is open under a label that collides with a decided
  record. This sheet references the row as "spec D-11 (video)" and asks
  the owner to renumber if the collision matters (suggest: video becomes
  **D-15**).
- **Demo posture** — the p0 framing applies: synthetic demo only, no real
  consultations, no real video data.

## 2. What answering these unlocks

Filled-in answers become the **video-consultation scope note** — the
missing artifact that lets the v1-after-MVP bucket plan. From there any
slice enters the standard pipeline: scope note ratified → mechanism/RLS
review → artifacts → battery → rehearsal r1 → dated apply-approval →
apply → matrix addendum → env-gated client swap (fake first).

## 3. Questions (answer inline — each maps to a decision row or the scope)

### A. Scope — the surface (feeds spec:159)

| # | Question | Options (default in **bold**) |
|---|---|---|
| A-1 | Is the `video_consultation` screen in the demo at all? | **no — v1-after-MVP, stays deferred** (spec:60) / a stub "video consultation" tile that shows a local-only note |
| A-2 | If stubbed, where does it live? | **beside the booking entry** (Phase 5 is the natural host — "book" → "join call" would be the real shape) / a standalone entry |
| A-3 | Booking integration? | **reuse the booking draft/fake only** (the consultation slot/topic shape) / independent — no coupling |

### B. Provider & data-handling (the spec D-11 row)

| # | Question | Options (default in **bold**) |
|---|---|---|
| B-1 | Provider for any future real integration? | **undecided — record one like D-11-did-for-Paymob when the slice is planned** / decide now (e.g. a hosted WebRTC/telehealth vendor) |
| B-2 | Where does the video stream flow? | **never through our servers** — hosted provider infrastructure (mirrors Paymob-hosted tokenization: data goes directly to the provider) / any other path is a new decision |
| B-3 | Recording / retention? | **no recording, no retention in any demo path** (D-05-adjacent: retention rules are a separate open row) / recording is a later slice |
| B-4 | Residency (D-04)? | **synthetic demo only — no real cross-border constraints** (the D-04-as-decided posture); a real product re-visits D-04 for the provider's infra |

### C. Engineering posture (feeds the future slice plan)

| # | Question | Options (default in **bold**) |
|---|---|---|
| C-1 | Demo implementation? | **synthetic `VideoGateway` seam** (fake-gateway pattern — a "join call" that renders a local-only demo state, no network) / real hosted SDK behind `env.isConfigured` |
| C-2 | Does the demo ever touch real media? | **never** — no camera/mic permission requests, no media streams, no WebRTC |
| C-3 | Write path? | **zero writes** — no call records, no audit entries from a demo call (audit is for real server outcomes only) |

### D. Open checklist (confirm before the scope note is written)

- [ ] A-1…A-3 answered → the surface decision (defer vs stub)
- [ ] B-1…B-4 answered → the provider/data-handling decision text (spec D-11 + D-04 dependency)
- [ ] C-1…C-3 answered → the slice plan shape
- [ ] **Label collision resolved** — renumber spec D-11 (video) or amend the billing record's label, so the register is unambiguous
- [ ] Scope note drafted and dated, citing this sheet + spec:47/60/159/206

## 4. Defaults in one paragraph (if the owner wants a starting proposal)

Video v1 = **stay deferred** (spec:60 puts it in v1-after-MVP — no screen,
not even a stub, in the current demo), with a **future decision recorded
the D-11-billing way** (a named provider + the hosted-infra posture: the
stream never touches our servers, no recording/retention, D-04 revisited
only for a real product) and, when the slice eventually runs, a
**synthetic `VideoGateway` seam** with zero real media and zero writes.
That keeps the deferred row honest and decision-ready without touching
the current demo surface.

## 5. Ledger

- DRAFTED 2026-08-11 (question sheet only); no decision taken, no code,
  no live-system effect. Status remains DRAFT until the owner answers §3
  (incl. the D-11 label-collision resolution) and the video scope note is
  written from those answers.
