# LegalHub — Video-Consultation Scope Decision (spec D-15, demo-posture) — DECIDED 2026-08-11

> **Record type:** Dated owner decision capture (the p0/D-45.1 convention)
> produced by answering the defaults in
> `docs/video_consultation_scope_questions_2026-08-11.md` §4 — the same
> flow that produced the AI and conflict scope notes. **Status: DECIDED
> 2026-08-11 (demo-posture).** The video row (**spec D-15**, renumbered
> from D-11 per tracked_deviations D-T8) closes at the demo level and
> **re-opens for a real product**. **Owner:** Project Owner
> (github.com/mostafasayed118). **Blocks:** the video consultation
> surface — now a **decided deferral** with a recorded future posture; no
> code, no live-system effect in this record.

---

## 1. Provenance

- **Spec row** (`docs/legalhub_specification.md` line 47) — "D-15 |
  Video consultation provider & data-handling | open | Product owner |
  Before video spec | Video consultation" (renumbered 2026-08-11 — D-T8).
- **Placement** (line 60) — video consultation is **v1 (after MVP)**, the
  same bucket as billing/invoices, collaboration task board, notification
  delivery, and the compliance audit-trail viewer.
- **Designed screen** (line 159) — `video_consultation` — "Defer (D-15)".
- **Dependency** (line 206) — "Video consultation → D-15, D-04"
  (D-04 = data residency & cross-border transfer).
- **The question sheet** (`docs/video_consultation_scope_questions_2026-08-11.md`)
  — 10 owner-answerable questions; this record ratifies its §4 defaults
  wholesale.
- **The billing precedent** — `docs/d11_billing_payments_decision_2026-08-08.md`
  (Paymob, hosted tokenization, no-live-in-MVP) is the pattern this
  decision mirrors for a future video provider.

## 2. Decision (the answers, mapped to the questions)

| Q | Answer (default ratified) |
|---|---|
| A-1 | **Stays deferred — no screen in the current demo** (spec:60 puts it in v1-after-MVP; not even a stub) |
| A-2 | When the surface is eventually built, it lives **beside the booking entry** (Phase 5 is the natural host — "book" → "join call") |
| A-3 | Booking integration **reuses the booking draft/fake only** — no coupling |
| B-1 | Provider **undecided until the slice is planned** — then recorded the way the billing record (D-11) recorded Paymob |
| B-2 | The stream **never flows through our servers** — hosted provider infrastructure (the Paymob-hosted-tokenization mirror) |
| B-3 | **No recording, no retention in any demo path** |
| B-4 | **Synthetic demo only** — no real cross-border constraints; a real product re-visits D-04 for the provider's infra |
| C-1 | **Synthetic `VideoGateway` seam** — the fake-gateway pattern (a "join call" that renders a local-only demo state, no network) |
| C-2 | **Never real media** — no camera/mic permission requests, no media streams, no WebRTC |
| C-3 | **Zero writes** — no call records, no audit entries from a demo call (audit is for real server outcomes only) |

## 3. Decision text (spec D-15 — provider & data-handling, demo-posture)

**DECIDED 2026-08-11 (demo-posture):** video consultation is a **decided
deferral** — no screen, not even a stub, in the current demo (spec:60
places it in v1-after-MVP). When the surface is eventually planned, the
provider decision is recorded **the D-11-billing way** (a named provider
chosen at slice-planning time), with the **hosted-infrastructure
posture**: the stream never touches our servers, no recording, no
retention, and D-04 revisited only for a real product. In any demo
implementation, the surface is a **synthetic `VideoGateway` seam** — zero
real media (no camera/mic/permissions/WebRTC) and zero writes. For a real
product, this row re-opens with counsel.

## 4. Effect on the roadmap / plans

- **The video row** changes from an *open* deferred row to a **decided**
  deferral — the same status F-02/F-05/F-07 reached ("ACCEPTED AS
  DEMO-POSTURE"). Nothing is un-built or un-deferred; the ambiguity is
  removed: the demo will not carry a video surface, and the future slice
  has a recorded posture to plan against.
- **v1-after-MVP bucket:** video joins billing/invoices (decided posture,
  Paymob) as a row whose future shape is decided at the demo level.
- **Question sheet:** §4's defaults are now ratified; the sheet's D
  checklist (incl. the D-11 label-collision resolution, D-T8) is answered
  by this record + the renumbering record.

## 5. Ledger

- DECIDED 2026-08-11 by the Project Owner (ratifying the question sheet's
  §4 defaults); recorded `docs/video_scope_decision_2026-08-11.md`;
  citing `docs/video_consultation_scope_questions_2026-08-11.md`, the
  spec D-15 row (D-T8 renumbering), and the D-11 billing precedent.
  Demo-posture only — no code, no live-system effect; the row re-opens
  for a real product.
