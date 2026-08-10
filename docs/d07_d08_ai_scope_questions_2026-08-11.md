# LegalHub — D-07/D-08 AI-Scope Question Sheet (decision-support) — DRAFT (2026-08-11)

> **Record type:** Decision-support question sheet for the owner —
> converts the two open AI decision rows (**D-07**, **D-08**) into
> answerable questions whose answers define the AI scope. **Status:
> DRAFT — no decision taken, no code, no live-system effect.** Per
> `docs/p14_plan_complete_2026-08-08.md`, AI is the only remaining §14
> path, owner-blocked on "D-07/D-08 + undefined scope" — this sheet is
> the minimal first step: answer the questions, and the AI scope note can
> be written. **Owner:** Project Owner (+ counsel/vendor-legal where the
> rows say so).

---

## 1. Provenance

- **D-07** (`docs/legalhub_specification.md` line 44) — "Legal research
  data source/license/freshness" — **open (legal review)**; owner +
  vendor/legal; gates the research spec; affects research, citations,
  statutory browser.
- **D-08** (line 45) — "AI usage policy (store/show/rely; review)" —
  **open (legal review)**; owner + counsel; gates the AI/drafting spec;
  affects AI research, legal drafting.
- **Designed surface** (line 167) — `legal_research_ai_assistant,
  citation_manager, statutory_research_browser, legal_draft_workspace,
  legal_library` — **Deferred (D-07/D-08)**; "preserve citation/source
  metadata".
- **Dependencies** (lines 203–204) — "Legal research / statutory
  browser" → D-03, D-07; "AI assistant / legal drafting" → D-07, D-08.
- **The p14 close** (`docs/p14_plan_complete_2026-08-08.md`) — "there is
  no AI feature spec, so there is nothing to plan. When/if the owner
  defines an AI scope, it enters the same T1–T8 per-feature discipline…
  This is a product-scope gate, **not** a codebase blocker."
- **Demo posture** — the p0 framing (portfolio/demo, synthetic data
  only, no real clients) applies to AI the same way it applied to every
  un-deferred slice: **synthetic outputs, never real legal analysis**.

## 2. What answering these unlocks

Filled-in answers become the **AI scope note** — the missing artifact the
p14 close names. From there the slice enters the standard pipeline:
scope note ratified → RLS-gate/mechanism review → artifacts (table/RLS/
RPC) → policy battery → rehearsal r1 → dated apply-approval → apply →
matrix addendum → env-gated client swap (fake-gateway first).

## 3. Questions (answer inline — each maps to a decision row or the scope)

### A. Scope — which surfaces (feeds D-08 + spec:167)

| # | Question | Options (default in **bold**) |
|---|---|---|
| A-1 | Which of the five designed screens are in the AI v1 scope? | **research assistant only** / assistant + citation manager / all five (`legal_library` last) |
| A-2 | What is the demo corpus the AI reads from? | **a small synthetic corpus** (curated demo docs, no real data) / reuse shipped demo matters/documents / external sample corpus |
| A-3 | Do AI outputs touch real client data in any path? | **never** (synthetic only) / read shipped demo data read-only |

### B. D-07 — data source / license / freshness

| # | Question | Options (default in **bold**) |
|---|---|---|
| B-1 | Where does the corpus come from and under what license? | **in-repo synthetic corpus, repo license** / third-party licensed corpus (name it) |
| B-2 | Freshness policy for the corpus? | **static per demo build** (versioned, no auto-refresh) / dated refresh on deploy |
| B-3 | Is citation/source metadata preserved on every output (spec:167)? | **yes — every claim carries its synthetic source row** / citations on research rows only, none on drafting |

### C. D-08 — store / show / rely / review

| # | Question | Options (default in **bold**) |
|---|---|---|
| C-1 | Does the app **store** prompts or outputs? | **no persistence** (session-only, nothing in the audit trail) / store redacted metadata only |
| C-2 | Does it **show** sources to the user? | **yes, always** (the citation row) / toggleable |
| C-3 | Can the user **rely** on outputs (disclaimer posture)? | **explicit "AI-suggested, not legal advice" surface on every AI screen** (the no-clearance-copy rule, spec §4.4/§4.5) / weaker inline note |
| C-4 | **Human review** workflow (D-08 "review")? | **none in v1 — outputs are advisory-only, never auto-applied** / a review step before any output can be copied into a matter |

### D. Engineering posture (feeds the future slice plan)

| # | Question | Options (default in **bold**) |
|---|---|---|
| D-1 | Model/provider in the demo? | **none — synthetic response generator behind an `AiGateway` seam** (fake-gateway pattern, like every shipped slice) / a real hosted model behind `env.isConfigured` with the sandbox keys |
| D-2 | Which of the existing seams does AI read through? | **the shipped gateway seams only** (documents/matters read) / a new AI-only corpus table |
| D-3 | Should the AI slice include any write path? | **no writes in v1** (advisory outputs only) / save-to-matter is a later slice |

### E. Open checklist (confirm before the scope note is written)

- [ ] A-1…A-3 answered → the surface list
- [ ] B-1…B-3 answered → the D-07 decision text (source/license/freshness)
- [ ] C-1…C-4 answered → the D-08 decision text (store/show/rely/review)
- [ ] D-1…D-3 answered → the slice plan shape
- [ ] Scope note drafted and dated, citing this sheet + D-07/D-08 rows

## 4. Defaults in one paragraph (if the owner wants a starting proposal)

AI v1 = the **research assistant screen only**, reading a **small
synthetic in-repo corpus** (never real client data), with **citation
metadata on every output**, **no prompt/output persistence**, an
**explicit "AI-suggested, not legal advice"** surface, **no
auto-apply/review workflow** (outputs advisory-only), and a
**synthetic `AiGateway` seam** behind the fake-gateway pattern — no model
provider, no writes. That is a decision-complete scope note with zero
legal-data risk, matching the demo posture of every shipped slice.

## 5. Ledger

- DRAFTED 2026-08-11 (question sheet only); no decision taken, no code,
  no live-system effect. Status remains DRAFT until the owner answers
  §3 and the AI scope note is written from those answers.
