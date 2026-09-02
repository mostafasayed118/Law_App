# Plan: AI Research Assistant Slice — demo-posture, no provider (2026-09-02)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> **AI research-assistant surface** — the last §14 deferred path, scoped by
> the ratified decision `docs/ai_scope_decision_2026-08-11.md` (D-07/D-08
> closed at demo-posture; §4 defaults A-1…D-3) plus two owner decisions
> taken 2026-09-02 (D-R1, D-R2 below). **Client-only — zero dev-project
> effect**: nothing here applies anything to the dev Supabase project (no
> table, no RLS, no RPC, no battery, no matrix addendum — same posture as
> the client-only Phases 5–12). **Branch: `feat/ai-research-assistant`.**
>
> **Gate state (why this slice is now plannable):** the scope blocker is
> **MET** — `docs/p14_plan_complete_2026-08-08.md` §4 named the missing
> AI spec; `docs/ai_scope_decision_2026-08-11.md` ratified it. This plan
> is the T-pipeline's client half; the server halves (battery/rehearsal/
> apply) do not run because D-1 decided **no model provider and no new
> server surface** — the synthetic gateway is the demo's terminal posture,
> exactly like every shipped fake-gateway seam.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Ship the **`legal_research_ai_assistant`** surface (spec §6 row 167) as a
read-only, advisory-only research screen: the user submits a natural-language
question, a **synthetic response generator** behind a new `AiGateway` seam
matches it against the **shipped gateway seams' rows** (`DocumentGateway` +
`MatterGateway` — D-2: shipped seams only, no AI-only corpus table), and
returns a deterministic list of `AiFinding`s — each carrying its **citation
source rows** (B-3/C-2). Every render carries the persistent
**"AI-suggested, not legal advice"** banner (C-3). Nothing is persisted,
logged, audited, or written anywhere (C-1/D-3). "Done" = the three
research-facing roles see the home entry; every finding cites its synthetic
source; the honest empty state is a first-class outcome.

## 2. Gap (verified)

| Claim | Verified fact |
|---|---|
| No research feature exists | `lib/features/` has no `research/` directory; no `AiGateway`, no `ai_` symbols anywhere in `lib/` (verified 2026-09-02) |
| Scope was the blocker | `docs/p14_plan_complete_2026-08-08.md` §4 — "AI is the only remaining §14 path… no build, nothing committed" |
| Scope now decided | `docs/ai_scope_decision_2026-08-11.md` — D-07/D-08 closed at demo-posture; the row is plannable |
| Shipped seams to read | `DocumentGateway` (5 deterministic synthetic metadata rows, D-V2) + `MatterGateway` (synthetic matter rows, D-M2) — the corpus |
| Capability surface | `RoleCapability` currently has no research flag; the slice adds `canUseAiResearch` |
| No persistence hooks | C-1 requires no store, no prefs, no audit row — the feature adds zero write paths |

## 3. Design decisions

Ratified from `docs/ai_scope_decision_2026-08-11.md` §2 (cited by letter):

- **A-1 — research assistant only.** No citation manager, statutory
  browser, draft workspace, or legal library in this slice.
- **A-2/B-1/B-2 — the corpus is the shipped synthetic demo rows.** The
  "small in-repo synthetic corpus" (repo license, static per build) is
  realized by reading `DocumentGateway`/`MatterGateway` deterministically —
  no asset file, no new table (D-2's shipped-seams-only answer binds).
- **B-3/C-2 — citations always on, never toggleable.** Every finding
  carries ≥1 source row; the citation row renders unconditionally.
- **C-1 — no persistence.** No store, no SharedPreferences, no audit
  trail, no logging of prompts or outputs.
- **C-3 — the banner is on every render.** Persistent localized
  "AI-suggested, not legal advice" surface; no clearance copy, never
  color-only (spec §4.4/§4.5).
- **C-4/D-3 — advisory-only, no writes.** No save-to-matter, no
  auto-apply, no review workflow, no composer affordances.
- **D-1 — synthetic generator, no provider.** The fake-gateway pattern is
  the v1 posture; an env-gated real provider is a future slice behind the
  same seam.

Decided by the owner 2026-09-02 (this session):

- **D-R1 — role gate:** the home entry + `/research` route are gated by a
  new `canUseAiResearch` capability hint, `true` for **attorney,
  researchAnalyst, partner**; `false` for client, complianceOfficer, admin.
  Navigation/visibility hint only — like every flag, it is not
  authorization (the seam itself is client-side synthetic).
- **D-R2 — last answer only:** the screen renders the **latest** query's
  findings; no session transcript. Nothing survives leaving the screen
  (cubit state is feature-scoped and discarded on route exit).

## 4. Client slice sequence

| # | Slice | Scope | New files (sketch) |
|---|---|---|---|
| 1.0 | Gateway + VO + engine | `AiSource`/`AiFinding` VOs + `AiGateway` seam + `SyntheticAiGateway`: tokenize query → case-insensitive match against document title/type + matter title/practice-area rows via the injected gateways → findings with citations; determinism, honest empty, typed failure passthrough; synthetic-only copy (no PII) | `features/research/domain/ai_finding.dart`, `domain/ai_gateway.dart`, `data/synthetic_ai_gateway.dart` |
| 1.1 | State + screen + wiring | `AiResearchCubit`/`AiResearchState` (idle/loading/success/empty/error; duplicate-submit guard; retry) + `AiResearchScreen` (field, persistent banner, findings list with citation rows, no save/apply affordances) + `canUseAiResearch` on `RoleCapability` (D-R1 roles) + `/research` route + home `AppEntryCard` entry + DI registration | `features/research/presentation/ai_research_state.dart`, `presentation/ai_research_cubit.dart`, `presentation/ai_research_screen.dart`, `presentation/ai_research_entry_card.dart`; `core/roles/user_role.dart`, `app/router.dart`, `app/service_locator.dart`, `features/home/presentation/home_screen.dart` |
| 1.2 | l10n + docs + ledger | EN/AR/TR keys (title, banner, field hint, submit, empty, error, retry, citation labels, finding labels) + per-locale resolution pins + README suite/coverage sync + ledger gate | `lib/l10n/*.arb` + generated; `README.md`; test pins |

## 5. Acceptance criteria (testable)

- **AC-1 (gateway contract):** `SyntheticAiGateway.research` returns
  `Result.ok(List<AiFinding>)` for a matching query; the same query yields
  byte-identical findings twice (determinism); findings always carry ≥1
  source (B-3/C-2 structural pin); all copy is synthetic (no-PII pin).
- **AC-2 (shipped-seams-only):** the gateway composes `DocumentGateway` +
  `MatterGateway` rows only; matching hits title/type/practice-area fields;
  no-match query → empty list (honest empty, never fabricated rows).
- **AC-3 (failure mapping):** any upstream gateway failure → the seam maps
  to a typed failure; the screen renders the `ViewStateView` error arm with
  retry.
- **AC-4 (cubit):** emissions follow loading → success/empty/error;
  duplicate submit while loading is a no-op; retry re-issues the fetch.
- **AC-5 (screen):** the "AI-suggested, not legal advice" banner is
  persistent on the screen itself — present in every render state
  (idle/loading/success/empty/error; C-3's "every AI screen" read
  literally); the citation row renders unconditionally under each finding
  (C-2); no save/apply/export affordance exists anywhere on the surface
  (C-4/D-3 pin).
- **AC-6 (gating, D-R1):** attorney/researchAnalyst/partner see the home
  entry and reach `/research`; client/complianceOfficer/admin do not (router
  redirect + entry-card tests).
- **AC-7 (last-answer, D-R2):** submitting a second query replaces the
  first answer; no transcript widget exists; no store/prefs class is
  registered for the feature (C-1 DI pin).
- **AC-8 (l10n):** all new user-facing strings resolve in EN, AR, TR with
  no silent-EN fallback (per-locale resolution pins); RTL verified in the
  widget tests.
- **AC-9 (gate stack):** `dart format` 0-changed, `flutter analyze` clean,
  full suite green, ledger PASS, README count in lockstep.

## 6. Non-goals

Real models/providers (D-1); any server artifact or matrix addendum (the
dev project is untouched); citation manager/statutory browser/draft
workspace/legal library (A-1); save-to-matter, exports, review workflows
(C-4/D-3); transcript/history (D-R2); push or background anything; real
legal data in any path (A-3).

## 7. Gate stack (exit)

Owner plan review → slices 1.0 → 1.1 → 1.2 → full gate stack (format /
analyze / full suite / ledger PASS / README lockstep) → owner push
approval. No commit or push without the owner's explicit approval per
`INSTRUCTIONS.md` §2.

## 8. Ledger

- PLANNED 2026-09-02 (`docs/ai_research_slice_plan_2026-09-02.md`),
  citing the ratified `docs/ai_scope_decision_2026-08-11.md` and the
  owner's 2026-09-02 session decisions D-R1/D-R2. Client-only; no
  live-system effect.
