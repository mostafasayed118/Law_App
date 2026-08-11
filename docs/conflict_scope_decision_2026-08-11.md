# LegalHub — Conflict-Check Scope Decision (D-03/D-06, demo-posture) — DECIDED 2026-08-11

> **Record type:** Dated owner decision capture (the p0/D-45.1 convention)
> produced by answering the defaults in
> `docs/d03_d06_conflict_scope_questions_2026-08-11.md` §4 — the same
> flow that produced the AI scope note
> (`docs/ai_scope_decision_2026-08-11.md`). **Status: DECIDED 2026-08-11
> (demo-posture).** D-03 and D-06 close at the demo level; both **re-open
> if the product ever handles real client data** (the p0 framing:
> portfolio/demo — synthetic data only). **Owner:** Project Owner
> (github.com/mostafasayed118). **Blocks:** the conflict/waiver/wall/
> filing cluster — now plannable at the demo level; no code, no
> live-system effect in this record.

---

## 1. Provenance

- **D-03** (`docs/legalhub_specification.md` line 40) — "Target
  jurisdiction(s) + legal-policy owner" — was open (legal review); gates
  conflicts, waivers, filings, compliance.
- **D-06** (line 43) — "Human review/approval authority
  (conflicts/waivers/walls/filings)" — was open; compliance/partner
  owner; gates high-risk workflow specs.
- **Deferred list** (line 62) — conflict check/disclosure/analytics,
  waivers, ethical walls, regulatory filing submission, global compliance
  map — all gated on D-03/D-06.
- **Designed screens** (lines 161–166) — the full conflict group:
  `conflict_check_search`, `conflict_disclosure_*`, report/resolution/
  analytics rows, waiver rows, ethical-wall rows, filing rows.
- **Mandatory safety constraints** (spec:161/163/166/108) — no green
  "Clear" badge, no "clearance" language, no "submitted" without a
  provider response, semantic status tokens (never color-alone).
- **The question sheet** (`docs/d03_d06_conflict_scope_questions_2026-08-11.md`)
  — 13 owner-answerable questions; this record ratifies its §4 defaults
  wholesale.
- **Demo-posture precedent** — F-02/F-05/F-07, the Paymob posture, and
  the AI scope decision all used the same framing.

## 2. Decision (the answers, mapped to the questions)

| Q | Answer (default ratified) |
|---|---|
| A-1 | **Check + disclosure + report only** — `conflict_check_search`, `conflict_disclosure_*`, `conflict_report_details`; resolution dashboard and analytics stay deferred |
| A-2 | **Waivers / ethical walls NOT in v1** — separate later slice (D-06 is their gate) |
| A-3 | **Regulatory filings NOT in v1** — D-03 + the no-"submitted"-without-provider-response rule |
| A-4 | **Synthetic parties/matters only** — never real client identities, never real legal analysis |
| B-1 | **Single declared synthetic jurisdiction** (Egypt — the D-04/D-11 market), stated on the surface |
| B-2 | **Project Owner as the legal-policy owner for the demo** — no real legal claim |
| B-3 | **"Conflict" = overlapping synthetic party/person metadata on a matter** — declared, transparent, no legal definition |
| C-1 | **No auto-action in v1** — findings are advisory; the compliance/partner owner reviews (D-06) |
| C-2 | **Zero write actions in v1** — disclosure + report only |
| C-3 | **Waiver approval is a human step, never automated** (deferred with the waiver slice) |
| D-1 | **Synthetic `ConflictGateway` seam** — deterministic fake, the fake-gateway pattern |
| D-2 | **Semantic status tokens, text + icon** — `status-attention`/`status-critical`, **never "Clear"/clearance, never color-alone** (spec:108, non-negotiable) |
| D-3 | **No writes in v1** |

## 3. D-03 decision text (jurisdiction + legal-policy owner)

**DECIDED 2026-08-11 (demo-posture):** the demo conflict surface declares
a **single synthetic jurisdiction** (Egypt — the D-04/D-11 market), with
the **Project Owner as the legal-policy owner** for the demo. A "conflict"
is defined transparently as **overlapping synthetic party/person metadata
on a matter** — no legal definition, no clearance claim. This closes D-03
at the demo level; the dependent rows (waivers, ethical walls, filings,
compliance map) stay deferred as implementations but become **plannable**.
For a real product, D-03 re-opens with counsel.

## 4. D-06 decision text (human review / approval authority)

**DECIDED 2026-08-11 (demo-posture):** findings are **advisory-only with
zero auto-actions**; **human review by the compliance/partner owner**
(D-06) is the only path to any action, and **no action surface exists in
v1** (disclosure + report only). Any future waiver approval is a human
step, never automated. This closes D-06 at the demo level; the
waiver/wall workflow specs become plannable. For a real product, D-06
re-opens.

## 5. Engineering posture (feeds the future slice plan)

- `ConflictGateway` seam (`check` → `Result<ConflictFinding>`, synthetic
  response generator behind the fake-gateway pattern), reading synthetic
  party/matter metadata.
- **Status rendering is mandatory-contract:** semantic tokens with text +
  icon — never "Clear"/clearance language, never color alone (spec:108);
  the spec's other safety notes (no green "Clear" badge, no "prevent
  professional ethical breaches" copy) are carried into the slice
  acceptance criteria.
- No writes, no persistence, no real identities.
- The slice, when scheduled, runs the standard pipeline: this scope note
  ratified → mechanism/RLS-gate review → artifacts → battery → rehearsal
  r1 → dated apply-approval → apply → matrix addendum → env-gated client
  swap.

## 6. Effect on the roadmap / plans

- **§14-adjacent cluster:** the D-03/D-06 scope blocker is **MET at the
  demo level** — conflict surfaces are now **plannable** (implementation
  still deferred, exactly the status AI reached via its scope decision).
- **Dependent rows:** waivers (D-06), ethical walls (D-06), regulatory
  filings (D-03 + provider rule), and the compliance map (validated data
  + D-03) inherit the un-block for *planning*; each still needs its own
  scope note before any slice.
- **Question sheet:** §4's defaults are now ratified; the sheet's E
  checklist is answered by this record.

## 7. Ledger

- DECIDED 2026-08-11 by the Project Owner (ratifying the question sheet's
  §4 defaults); recorded `docs/conflict_scope_decision_2026-08-11.md`;
  citing `docs/d03_d06_conflict_scope_questions_2026-08-11.md` and the
  D-03/D-06 spec rows. Demo-posture only — no code, no live-system
  effect; D-03/D-06 re-open for a real product.
