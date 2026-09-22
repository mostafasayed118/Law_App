# P1.1 — Moving the four direct gateway calls behind cubits

> **Record type:** implementation plan for audit finding **H-4** / roadmap item **P1.1**
> (`docs/audit/LegalHub_AUDIT_2026-09-21.md` §4, §8).
> **Status:** PLAN — awaiting owner sign-off on the owner-mapping (below). No code changed yet.
> **Date:** 2026-09-22 · **Author:** audit session

## 1. The finding

Four presentation widgets call `OrganizationGateway` directly and orchestrate with local
`setState`, bypassing the cubit layer `INSTRUCTIONS.md` §4.1 mandates. Verified by grep:
`await serviceLocator<` appears in `lib/features/` **exactly four times**, all
`OrganizationGateway`:

| # | Site | Call | Kind |
|---|---|---|---|
| 1 | `profile_screen.dart:131` | `deleteMyAccount()` | **destructive** (deletes the account) |
| 2 | `accept_invitation_screen.dart:72` | `acceptInvitation(...)` | consequential (joins an org) |
| 3 | `invite_member_sheet.dart:204` | `inviteMember(...)` | consequential (mints an invite) |
| 4 | `matter_create_screen.dart:106` | `listMembers(...)` | **read** (assignee picker) |

Why it matters (audit §4, H-4): those flows have no cubit, so the project's own `bloc_test`
doctrine cannot apply to them; duplicate-submission guards are hand-rolled three times; and the same
`OrgFailureKind` maps to three different affordances (SnackBar / `errorText` / inline `Text`) because
no orchestration layer owns the mapping. `profile_screen.dart`'s own class docstring at `:20-21`
claims *"It never calls a gateway"* — falsified at `:131` in the same file.

## 2. Owner mapping — the part that needs sign-off

The audit recommended "extend `OrgCubit` (already owns roster writes) with
`acceptInvitation` / `inviteMember`; add a `ProfileCubit` or `AuthCubit.deleteAccount()`; move
`_members` into `MatterCreateCubit`". Investigating the actual call sites **confirms three of those
and corrects one**.

| # | Flow | Recommended owner | Evidence |
|---|---|---|---|
| 4 | `listMembers` | **`MatterCreateCubit`** (already exists) | The screen already has a cubit; this is a read; the screen already filters to active members (F2-D4). Lowest risk — do first. |
| 3 | `inviteMember` | **`OrgCubit`** ✔ audit correct | The sheet is a **modal opened from the roster** (`member_roster_screen.dart:139`), so the roster's cubit is the owning surface. |
| 2 | `acceptInvitation` | **`AuthCubit`** ⚠️ **audit corrected** | The audit said `OrgCubit`, but this is a **standalone route** (`router.dart:321`, a deep-link target) with **session-level effects** on success (`auth.hydrate()` + `ActiveOrgStore.select()`), and no roster is on screen. `OrgCubit` models roster/create state — it does not fit. `AuthCubit` already owns `hydrate`. |
| 1 | `deleteMyAccount` | **`AuthCubit`** (recommended) | It is a **session-ending** operation — the screen's success path already calls `context.read<AuthCubit>().signOut()`. A one-method `ProfileCubit` would add a third cubit for no gain. The alternative (`ProfileCubit`) stays open if you prefer profile-scoped ownership. |

**Question for the owner:** approve this mapping — in particular (a) `AuthCubit` for
`acceptInvitation` instead of the audit's `OrgCubit`, and (b) `AuthCubit` rather than a new
`ProfileCubit` for `deleteAccount`?

## 3. Mechanism per flow

The repository already has the shape this needs: cubit action methods **return the typed result**
(`OrgFailureKind?`, or `OrgInviteActionResult` for token-returning actions) while the *screen* keeps
the affordance (dialog, SnackBar, inline text). `OrgCubit.resendInvitation` is the precedent.

1. **`MatterCreateCubit.loadMembers(organizationId)`** — move the fetch + the active-member filter
   (`F2-D4`) out of `_loadMembers`; the screen reads `_members` from cubit state. The screen already
   resolves the org via `ActiveOrgStore`, which stays.
2. **`OrgCubit.inviteMember({organizationId, email, role}) → Future<OrgInviteActionResult>`** —
   non-emitting (there is no roster row to mark in flight), mirroring `resendInvitation`'s return
   type. `showInviteMemberSheet` gains a cubit parameter and wraps the sheet body in
   `BlocProvider.value`, because a modal's context sits under the Navigator, not under the caller's
   provider scope. The sheet keeps its **ephemeral UI state** (form validity, `_sending`, the
   one-shot token) — that is presentation state, not business state.
3. **`AuthCubit.acceptInvitation(invitationId) → Future<OrgFailureKind?>`** — wraps the gateway call
   plus the existing `hydrate()` + `ActiveOrgStore.select()` sequence, so the screen becomes a
   `BlocBuilder`/`BlocListener` over the cubit.
4. **`AuthCubit.deleteAccount() → Future<OrgFailureKind?>`** — the cubit calls the gateway and, on
   success, ends the session; the screen keeps the confirmation dialog and the failure SnackBar.
   **Highest consequence — do last, with the most test care.**

## 4. Shape fork discovered while scoping flow 1 (needs the same sign-off)

Reading `MatterCreateCubit` to start the lowest-risk flow surfaced a second question the audit did
not address — **where does the new state live?** The cubit's state is a sealed *submit* lifecycle
(`initial` / `submitting` / `success` / `failure`) that the form screen renders. The assignee options
are a different concern, so the options are:

| Option | Shape | Trade-off |
|---|---|---|
| **a** | Add `members` to each `MatterCreateState` variant | Mangles a clean sealed lifecycle; every variant carries an unrelated field. **Not recommended.** |
| **b** | A dedicated `MatterAssigneeCubit` (loading / loaded / failed) | Cleanest separation and full `bloc_test` coverage of the picker — at the cost of a third cubit for one dropdown. |
| **c** *(recommended)* | Non-emitting cubit method — `Future<List<OrgMember>> loadMembers(organizationId)` returning the active members (empty on failure), with the screen keeping `_members` as local state | Fixes the actual violation (gateway access moves behind the cubit, and the fetch + active-member filter become unit-testable) without touching the sealed submit lifecycle. Mirrors the returning-method convention already used by `OrgCubit`'s actions. |

The same fork applies to flows 2 and 3: `OrgCubit` and `AuthCubit` both carry sealed state
machines of their own, so "add the flow to the cubit" means deciding whether the flow gets its own
states (visible to every listener of that cubit) or a returning method the screen renders itself.
**Recommendation for all three:** the returning-method shape, except where the flow already has a
natural state to emit (`inviteMember` has none; `acceptInvitation` can reuse the auth lifecycle).

## 5. Test impact (cheaper than it looks)

All four screens' tests already resolve dependencies through the service locator, so the rewiring
does not require a new injection strategy:

- `profile_screen_test.dart:35` registers `OrganizationGateway` in the locator and already provides
  `AuthCubit`;
- `matter_create_screen_test.dart:22` uses `serviceLocator<ActiveOrgStore>()`;
- `accept_invitation_screen_test.dart:31-33` uses `serviceLocator<AuthGateway>()` +
  `serviceLocator<MembershipRepository>()` and a `MultiBlocProvider`;
- `invite_member_sheet_test.dart:112` currently drives the gateway stub directly.

New cubit-level `blocTest`s cover the state machines (including the failure-kind → affordance
mapping that is hand-rolled today). Test count will change → README lockstep + ledger re-run.

## 6. Suggested sequencing

| Order | Flow | Risk | Why this order |
|---|---|---|---|
| 1 | `listMembers` → `MatterCreateCubit` | lowest | a read; the cubit already exists |
| 2 | `inviteMember` → `OrgCubit` | low | non-emitting method + modal cubit passing |
| 3 | `acceptInvitation` → `AuthCubit` | medium | session-level effects must be preserved exactly |
| 4 | `deleteAccount` → `AuthCubit` | highest consequence | destructive; confirm-then-signOut flow must survive |

Each lands as its own commit with the full gate set (`dart format`, `flutter analyze`,
`flutter test`, `scripts/verify_ledger.sh`).

## 7. Not in scope

- **P1.3** (admin RPC `LIMIT`) — a SQL apply slice.
- **H-7's second half** (~500 lines of per-feature failure enums/exceptions).
- **P1.9** (`CubitListSurface` extraction + the remaining eager lists).
- The **iOS half of P1.2** — needs the `flutter_secure_storage` dependency decision.
