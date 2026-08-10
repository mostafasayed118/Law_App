# LegalHub — D-03/D-06 Conflict-Check Scope Question Sheet (decision-support) — DRAFT (2026-08-11)

> **Record type:** Decision-support question sheet for the owner —
> converts the two open high-risk decision rows (**D-03**, **D-06**) into
> answerable questions whose answers define the conflict-check / waiver /
> ethical-wall / filing scope. **Status: DRAFT — no decision taken, no
> code, no live-system effect.** This is the same shape as the AI sheet
> (`docs/d07_d08_ai_scope_questions_2026-08-11.md`) for the next open
> high-risk cluster. **Owner:** Project Owner (+ counsel per D-03,
> compliance/partner owner per D-06).

---

## 1. Provenance

- **D-03** (`docs/legalhub_specification.md` line 40) — "Target
  jurisdiction(s) + legal-policy owner" — **open (legal review)**; owner
  + counsel; "Before any high-risk spec"; affects conflicts, waivers,
  filings, compliance.
- **D-06** (line 43) — "Human review/approval authority
  (conflicts/waivers/walls/filings)" — **open**; compliance/partner
  owner; "Before high-risk workflow spec"; affects high-risk workflows.
- **Deferred list** (line 62) — Conflict check/disclosure/analytics
  (D-03/D-06) · Waivers (D-06) · Ethical walls (D-06) · Regulatory
  filing submission (D-03) · Global compliance map / risk & advanced
  analytics (validated data + D-03).
- **Designed screens** (lines 161–166) — `conflict_check_search`,
  `conflict_disclosure_*` (matter_selection, party_identification,
  analysis_findings, final_review), `conflict_report_details`,
  `conflict_resolution_dashboard`/`overview`, `conflict_analytics_*`,
  `alert_detail_conflict_detected`, `request_conflict_waiver`,
  `waiver_approval_detail`, `conflict_waiver_status`,
  `approval_detail_conflict_waiver`,
  `resolution_action_ethical_wall`, `take_action_conflict_resolution`,
  `regulatory_filings_dashboard`, `filing_submission_workspace`.
- **Safety constraints already in the spec** (must survive any scope):
  - line 161 — conflict check must **remove the green "Clear" badge and
    the "prevent professional ethical breaches" copy** (violates §4.4).
  - line 163 — "correct any **'clearance' language**".
  - line 166 — regulatory filings: **no "submitted" without a provider
    response**.
  - line 108 — status must never rely on color alone; conflict results
    must **not** be labeled "Clear"/clearance; use semantic status tokens
    (`status-info`/`status-attention`/`status-critical`) with **text +
    icon**.

## 2. What answering these unlocks

Filled-in answers become the **conflict-check scope note** (the same
missing-artifact problem the p14 close names for AI, applied to the
D-03/D-06 cluster). From there any slice enters the standard pipeline:
scope note ratified → RLS-gate/mechanism review → artifacts → policy
battery → rehearsal r1 → dated apply-approval → apply → matrix addendum →
env-gated client swap (fake-gateway first).

## 3. Questions (answer inline — each maps to a decision row or the scope)

### A. Scope — which surfaces (feeds spec:161–166)

| # | Question | Options (default in **bold**) |
|---|---|---|
| A-1 | Which conflict surfaces are in v1? | **check + disclosure + report only** / + resolution dashboard / + analytics (last) |
| A-2 | Are waivers / ethical walls in v1? | **no — separate later slice** (D-06 is their gate) / waiver-request flow only, approval deferred |
| A-3 | Are regulatory filings in v1? | **no** (D-03 + provider-response rule) / filing dashboard read-only, submission deferred |
| A-4 | Demo data posture? | **synthetic parties/matters only, never real client identities** (the p0 framing) / reuse shipped demo matters |

### B. D-03 — jurisdiction + legal-policy owner

| # | Question | Options (default in **bold**) |
|---|---|---|
| B-1 | Which jurisdiction's conflict rules apply to the check engine? | **a single declared synthetic jurisdiction** (stated on the surface, e.g. Egypt — the D-04/D-11 market) / multi-jurisdiction flags per matter |
| B-2 | Who is the **legal-policy owner** the spec names? | **the Project Owner for the demo** (no real legal claim) / named counsel (must be recorded) |
| B-3 | What is a "conflict" in demo terms? | **overlapping synthetic party/person metadata on a matter** (declared, transparent) / no definition in v1 — check stays advisory |

### C. D-06 — human review / approval authority

| # | Question | Options (default in **bold**) |
|---|---|---|
| C-1 | Who reviews conflict findings before any action? | **no auto-action in v1 — findings are advisory, the partner/compliance owner reviews** (D-06 names compliance/partner owner) / a review step inside the app |
| C-2 | Can a finding be acted on (declined matter, wall raised) in v1? | **no — zero write actions** (disclosure + report only) / matter-decline is a separate future slice |
| C-3 | Waiver approval workflow (if A-2 includes waivers)? | **approval is a human step, never automated** (D-06) / deferred with the waiver slice |

### D. Engineering posture (feeds the future slice plan)

| # | Question | Options (default in **bold**) |
|---|---|---|
| D-1 | Check engine in the demo? | **synthetic `ConflictGateway` seam** (deterministic fake, the fake-gateway pattern) / real rules engine behind `env.isConfigured` |
| D-2 | Status vocabulary? | **semantic tokens with text + icon** (`status-attention`/`status-critical`), **never "Clear"/clearance, never color-alone** (spec:108, mandatory — not optional) |
| D-3 | Any write path? | **no writes in v1** / disclosure save-to-matter is a later slice |

### E. Open checklist (confirm before the scope note is written)

- [ ] A-1…A-4 answered → the surface list
- [ ] B-1…B-3 answered → the D-03 decision text (jurisdiction + legal-policy owner)
- [ ] C-1…C-3 answered → the D-06 decision text (human review/approval authority)
- [ ] D-1…D-3 answered → the slice plan shape (incl. the mandatory no-clearance-copy rule)
- [ ] Scope note drafted and dated, citing this sheet + D-03/D-06 rows + the spec:161/163/166/108 safety constraints

## 4. Defaults in one paragraph (if the owner wants a starting proposal)

Conflict v1 = **check + disclosure + report only** (waivers, ethical
walls, filings all deferred — D-06/D-03 gates), on **synthetic demo
parties only**, under a **single declared synthetic jurisdiction** with
the **Project Owner as the legal-policy owner for the demo** (no real
legal claim), findings **advisory-only with zero write actions** and
human review by the compliance/partner owner, backed by a **synthetic
`ConflictGateway` seam**, and every result rendered with **semantic
status tokens — text + icon, never "Clear"/clearance, never color-alone**
(spec:108, non-negotiable). That is a decision-complete scope note with
zero legal-data risk, matching the demo posture of every shipped slice.

## 5. Ledger

- DRAFTED 2026-08-11 (question sheet only); no decision taken, no code,
  no live-system effect. Status remains DRAFT until the owner answers §3
  and the conflict-check scope note is written from those answers.
