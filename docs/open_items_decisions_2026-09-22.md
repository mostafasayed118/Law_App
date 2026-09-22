# LegalHub — Open Items Owner Decisions (2026-09-22)

> **Record type:** Dated owner decision capture for
> [`open_items_for_owner_2026-09-22.md`](open_items_for_owner_2026-09-22.md)
> (the p0/D-45.1 convention).
>
> **Status: ALL DECIDED (2026-09-22).** The five §2 decisions (D1–D5), the
> §3 priority choice, and the four §4 polish calls are closed below. The two
> §1 owner-only actions that remain are execution tasks, not decisions
> (§5). Nothing in this record authorizes a push, a SQL apply, or a
> dependency add by itself — each still follows the per-step discipline in
> `INSTRUCTIONS.md` §2/§3.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Decided on:** 2026-09-22.
>
> **Context:** Portfolio/ CV project (synthetic data only). Decisions are
> scoped to engineering correctness and CV-defensibility; they do not change
> the product scope or any `p0_decision_capture.md` D-02–D-10 decision.

---

## 1. Decisions

### OI-D1 — Owner of `deleteMyAccount` (P1.1)

- **Question:** Which cubit owns the destructive `deleteMyAccount` flow from
  `profile_screen.dart:131` — `AuthCubit` or a new `ProfileCubit`?
- **Owner:** Project Owner.
- **Decision:** **`AuthCubit`.** The flow ends the session and the screen's
  success path already calls `signOut()`; a separate `ProfileCubit` would
  split session-ending logic across two cubits for no gain.
- **Decided on:** 2026-09-22.
- **Blocks slice:** P1.1 (the four cubit moves).
- **Evidence / notes:** Owner answer 2026-09-22; recommended cell in
  `open_items_for_owner_2026-09-22.md` §2 D1 table.

### OI-D2 — Shape of the P1.1 cubit methods

- **Question:** For P1.1, do gateway-orchestrated flows become (a) methods
  returning results, or (b) new emitted states on each cubit?
- **Owner:** Project Owner.
- **Decision:** **(a) Returning method** — e.g.
  `Future<OrgInviteActionResult> inviteMember(...)`; the screen renders the
  affordance. Mirrors `OrgCubit`'s existing action convention and leaves the
  sealed state lifecycles untouched.
- **Decided on:** 2026-09-22.
- **Blocks slice:** P1.1.
- **Evidence / notes:** Owner accepted the audit's recommendation
  (2026-09-22); rationale in `open_items_for_owner_2026-09-22.md` §2 D2.

### OI-D3 — iOS refresh-token storage (`flutter_secure_storage`)

- **Question:** Add `flutter_secure_storage` (Keychain) for the iOS half of
  P1.2, or defer / accept plaintext `NSUserDefaults`?
- **Owner:** Project Owner.
- **Decision:** **Approved — add the dependency now.** The refresh token
  stops living in plaintext `NSUserDefaults`; this closes the iOS half of
  P1.2 alongside the already-done `android:allowBackup="false"`.
- **Decided on:** 2026-09-22.
- **Blocks slice:** P1.2 (iOS half).
- **Evidence / notes:** Owner answer 2026-09-22. Dependency add still
  follows the normal package-addition review in the implementing slice;
  this record is the owner gate that was missing.

### OI-D4 — P1.3 SQL apply slice and applier

- **Question:** Approve the `p_limit`/`p_offset` migration for the four
  unbounded platform-admin RPCs, and who executes the apply?
- **Owner:** Project Owner.
- **Decision:** **Slice approved. The implementing agent applies it under
  this authorization** after the standard rehearsal → apply → battery
  re-run flow. The session CLI account is not a member of `law_project`;
  the agent will run the apply with the owner-provided path (owner remains
  accountable per `INSTRUCTIONS.md` human-accountability rules).
- **Decided on:** 2026-09-22.
- **Blocks slice:** P1.3.
- **Evidence / notes:** Owner answer 2026-09-22; plan context in
  `open_items_for_owner_2026-09-22.md` §2 D4. Apply still requires the
  normal rehearsal evidence before any dev-project mutation.

### OI-D5 — Dead foundations in `tracked_deviations.md` D-T9

- **Question:** For the two dead declared foundations — keep/delete
  `responsive_breakpoints.dart`, and what to do about
  `lib/core/use_cases/use_case.dart` vs `INSTRUCTIONS.md` §4.1?
- **Owner:** Project Owner.
- **Decision:**
  1. `lib/core/use_cases/use_case.dart` — **implement one real use case**
     so the documented §4.1 layer has a consumer; the docs/code mismatch
     closes by making the architecture true, not by deleting the line.
  2. `lib/shared/responsive/responsive_breakpoints.dart` — **no call in
     this batch.** It stays recorded under D-T9 until the next responsive
     slice adopts or deletes it (unchanged from the audit's note).
- **Decided on:** 2026-09-22.
- **Blocks slice:** a small follow-up slice for the use-case exemplar;
  breakpoints decision deferred to the next responsive slice.
- **Evidence / notes:** Owner answer 2026-09-22; D-T9 entry in
  `docs/tracked_deviations.md`.

### OI-D6 — Next-slice priority

- **Question:** What is the primary ordering goal after the audit close?
- **Owner:** Project Owner.
- **Decision:** **Continue the roadmap in the audit's rank order:**
  P1.1 → P1.9 → H-7 second half → P1.3 → … (table in
  `open_items_for_owner_2026-09-22.md` §3). CV/readiness polish (§4 below)
  rides along in the same slices or a single small cleanup slice — it does
  not reorder the technical roadmap.
- **Decided on:** 2026-09-22.
- **Blocks slice:** sequencing only; no slice is blocked by this row.
- **Evidence / notes:** Owner answer 2026-09-22.

### OI-D7 — §4 polish calls (batched)

- **Question:** The four optional polish items — `.gitignore`, P0.5 gate
  line, Flutter version constraint, commit trailer?
- **Owner:** Project Owner.
- **Decision:**
  1. **`.gitignore` the tooling/identity dirs** (`.agents/`, `.cluster/`,
     `.flutter`, `.flutter_tool_state`, `.openclaw/`, `.opencode/`,
     `.workbuddy-ai/`, `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`,
     `IDENTITY.md`, `HEARTBEAT.md`) so an accidental `git add -A` cannot
     commit agent state.
  2. **Write P0.5 into `INSTRUCTIONS.md` Gate 5** — run `flutter analyze` +
     `flutter test` before leaving any slice (enforced, not remembered).
  3. **Tighten the Flutter constraint back to the CI pin** (CI: Flutter
     `3.44.4` / Dart `3.12.2`); reproducibility beats a wide local range
     for a portfolio repo.
  4. **Keep the `Co-Authored-By: WorkBuddy AI <noreply@workbuddy.ai>`
     trailer** as-is (matches the existing `Co-Authored-By: Claude`
     convention).
- **Decided on:** 2026-09-22.
- **Blocks slice:** none; fold into the next docs/cleanup touch or the
  first implementing slice that already edits the same files.
- **Evidence / notes:** Owner answers 2026-09-22; item text in
  `open_items_for_owner_2026-09-22.md` §4.

### OI-D8 — Immediate execution of §1.1 (push)

- **Question:** Push the seven recovered/audit commits to `origin/main`?
- **Owner:** Project Owner.
- **Decision:** **Approved — push is authorized.** Until pushed, the
  recovered in-flight work exists only in the working tree, local git
  objects, and the Recycle Bin. The implementing agent (or the owner) may
  run `git push` under this record; no history rewrite is authorized (see
  §5).
- **Decided on:** 2026-09-22.
- **Blocks slice:** nothing — this is the highest-priority §1 action.
- **Evidence / notes:** Owner instruction 2026-09-22; risk statement in
  `open_items_for_owner_2026-09-22.md` §1.1.

---

## 2. What this record does **not** decide

Carried forward unchanged from `open_items_for_owner_2026-09-22.md` §1/§5:

- **§1.2 — who deleted `lib/` (2026-09-21 21:50):** still an owner
  investigation (antivirus quarantine, disk-cleanup tools, Task Scheduler,
  other agent sessions). Not a decision; an open action.
- **§1.3 — do not empty the Recycle Bin** for the ~21:50 entries until the
  push is done and the tree is confirmed. Standing constraint.
- **§1.4 — `NO_PROXY` for `flutter test`:** informational; fixing the shell
  profile is recommended but not gated on this record.
- **No history rewrite** of the seven recovered commits — squash/split, if
  ever wanted, is a separate explicit operation.
- **No SQL apply, dependency add, or push happens solely because this file
  exists** — each still needs its slice-level rehearsal/approval path;
  this file supplies the missing owner answers that were blocking those
  paths.

---

## 3. Ledger

- **2026-09-22:** OI-D1–OI-D8 recorded; all five open decisions from
  `open_items_for_owner_2026-09-22.md` §2 plus §3 priority and §4 polish
  are **Decided**. P1.1 is unblocked (OI-D1 + OI-D2). P1.2 iOS is
  unblocked (OI-D3). P1.3 is unblocked at the decision level (OI-D4).
  Push is authorized (OI-D8).
- Follow the implementing slices for evidence of execution; this file is
  the decision layer only.
