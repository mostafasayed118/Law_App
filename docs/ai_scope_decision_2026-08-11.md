# LegalHub — AI Scope Decision (D-07/D-08, demo-posture) — DECIDED 2026-08-11

> **Record type:** Dated owner decision capture (the p0/D-45.1 convention)
> produced by answering the defaults in
> `docs/d07_d08_ai_scope_questions_2026-08-11.md` §4 — the flow the
> question sheet's §2 describes: answers become the **AI scope note**, the
> missing artifact the §14 close names. **Status: DECIDED 2026-08-11
> (demo-posture).** D-07/D-08 close at the demo level; both rows **re-open
> if the product ever handles real client data** (the p0 framing: this
> project is a portfolio/demo — synthetic data only). **Owner:** Project
> Owner (github.com/mostafasayed118). **Blocks:** the AI §14 path — now
> un-blocked for planning under the standard T1–T8 discipline; no code, no
> live-system effect in this record.

---

## 1. Provenance

- **D-07** (`docs/legalhub_specification.md` line 44) — "Legal research
  data source/license/freshness" — was open (legal review).
- **D-08** (line 45) — "AI usage policy (store/show/rely; review)" — was
  open (legal review).
- **Designed surface** (line 167) — `legal_research_ai_assistant,
  citation_manager, statutory_research_browser, legal_draft_workspace,
  legal_library` — deferred (D-07/D-08); "preserve citation/source
  metadata".
- **The §14 close** (`docs/p14_plan_complete_2026-08-08.md`) — "there is
  no AI feature spec, so there is nothing to plan… product-scope gate,
  not a codebase blocker."
- **The question sheet** (`docs/d07_d08_ai_scope_questions_2026-08-11.md`)
  — 14 owner-answerable questions; this record ratifies its §4 defaults
  wholesale.
- **Demo-posture precedent** — the same framing already applied to
  F-02/F-05/F-07 ("ACCEPTED AS DEMO-POSTURE, 2026-08-09") and to the
  D-11/Paymob posture ("no live payment in MVP"): decisions at the demo
  level carry no real-client obligation.

## 2. Decision (the answers, mapped to the questions)

| Q | Answer (default ratified) |
|---|---|
| A-1 | **Research assistant only** — `legal_research_ai_assistant`; citation manager, statutory browser, draft workspace, and legal library stay deferred |
| A-2 / A-3 | **Small synthetic in-repo corpus**; never real client data, never real legal analysis |
| B-1 | **In-repo synthetic corpus, repo license** — no third-party licensed data in the demo |
| B-2 | **Static per demo build** — versioned, no auto-refresh, freshness is the build date |
| B-3 | **Citation/source metadata on every output** (spec:167) — every claim carries its synthetic source row |
| C-1 | **No prompt/output persistence** — session-only; nothing in the audit trail, nothing stored |
| C-2 | **Sources always shown** — the citation row is not toggleable |
| C-3 | **Explicit "AI-suggested, not legal advice" surface on every AI screen** (the no-clearance-copy rule, spec §4.4/§4.5) |
| C-4 | **No auto-apply, no review workflow in v1** — outputs advisory-only, never applied to a matter |
| D-1 | **Synthetic response generator behind an `AiGateway` seam** — the fake-gateway pattern; no model provider |
| D-2 | **Reads through the shipped gateway seams only** (documents/matters read) — no AI-only corpus table |
| D-3 | **No writes in v1** — advisory outputs only; save-to-matter is a later slice |

## 3. D-07 decision text (data source / license / freshness)

**DECIDED 2026-08-11 (demo-posture):** the AI corpus is a small,
in-repo, **synthetic dataset under the repo license**, versioned per demo
build (static, no auto-refresh — freshness = build date). Every output
**carries citation/source metadata** pointing at its synthetic source row
(spec:167). **No third-party or real legal data** enters any demo path.
For a real product, D-07 re-opens (vendor/license/freshness with
counsel).

## 4. D-08 decision text (store / show / rely / review)

**DECIDED 2026-08-11 (demo-posture):**

- **Store:** **no persistence** — prompts and outputs are session-only;
  nothing is stored, logged, or audited.
- **Show:** **sources always shown** (the citation row on every output);
  the "AI-suggested, not legal advice" surface is on **every AI screen**
  (spec §4.4/§4.5 — results are never labeled "Clear"/clearance and
  never rely on color alone).
- **Rely:** outputs are **advisory-only** — users must not treat them as
  legal advice or clearance.
- **Review:** **no automated review/approval workflow in v1**; outputs
  are never auto-applied to a matter. If a review step is wanted later,
  it is a separate additive slice.

For a real product, D-08 re-opens with counsel.

## 5. Engineering posture (feeds the future slice plan)

- `AiGateway` seam (`research` → `Result<AiFinding>`, synthetic response
  generator behind the fake-gateway pattern), env-gated Supabase impl
  only if a provider is ever added.
- Reads through the **shipped gateway seams only**; no new corpus table,
  no writes, no media, no persistence.
- The slice, when scheduled, runs the standard pipeline: this scope note
  ratified → mechanism/RLS-gate review → artifacts → battery → rehearsal
  r1 → dated apply-approval → apply → matrix addendum → env-gated client
  swap.

## 6. Effect on the roadmap / plans

- **§14 AI row:** the "undefined scope" blocker is **MET** — the scope
  note now exists (this record). The row stays deferred as an
  implementation until the owner schedules the slice; it is now
  **plannable** under T1–T8, the same status the billing row reached via
  D-11.
- **`p14_plan_complete`:** the "no AI feature spec, so nothing to plan"
  statement is superseded for the demo level (re-opens for a real
  product).
- **Question sheet:** §4's defaults are now ratified; the sheet's E
  checklist is answered by this record.

## 7. Ledger

- DECIDED 2026-08-11 by the Project Owner (ratifying the question sheet's
  §4 defaults); recorded `docs/ai_scope_decision_2026-08-11.md`; citing
  `docs/d07_d08_ai_scope_questions_2026-08-11.md` and the D-07/D-08 spec
  rows. Demo-posture only — no code, no live-system effect; D-07/D-08
  re-open for a real product.
