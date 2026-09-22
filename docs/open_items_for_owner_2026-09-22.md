# Open items — what I need from you

> **Generated:** 2026-09-22 05:15 (audit session close)
> **Context:** `docs/audit/LegalHub_AUDIT_2026-09-21.md` · **P1.1 plan:** `docs/p1_1_gateway_call_migration_plan_2026-09-22.md`
> **How to use:** §1 is actions only you can take. §2 is the decisions that unblock the next slice. §3 is a menu. §4 is optional polish. §5 lists what I deliberately will **not** do without an answer.

---

## 0. Where things stand (30-second version)

- **7 commits, working tree clean, nothing pushed.** `origin/main` is 7 commits behind.
- **All gates green at HEAD:** `flutter analyze` clean · **1381 tests pass** · `dart format` clean · `scripts/verify_ledger.sh` **PASS 115/0/0** · README lockstep 1378/1381.
- **Done:** all 5 P0 items; P1.5, P1.6, P1.7, P1.8, P1.10; the Android half of P1.2; a first slice of P1.4 (H-7); P2.2 (H-2); P2.4 (as D-T9).
- **Open:** 1 action-blocking item (§1), 5 decisions (§2), and the rest of the roadmap (§3).
- **Incident:** `lib/` was deleted from disk at 21:50:25–36 on 2026-09-21 by an **unidentified external process**; 322 files were recovered intact from the Recycle Bin and every gate re-certified. Record: audit doc §12.

The 7 commits, oldest first:

| Commit | What |
|---|---|
| `86f6241` | audit P0/P1 — compile fix, ordering reversal, demo gate, N+1, backup hygiene, store move, `copyWith` |
| `8f6c9df` | the recovered in-flight perf slice (bounded SELECTs, lazy lists, scoped rebuilds) |
| `4e87cf5` | the audit record + raw findings |
| `1c292ff` | P1.7 — typed `AppError.kind` → real `ViewOffline`/`ViewUnauthorized` producers |
| `c4607aa` | H-7 first slice (shared denial classifier) + H-2 (adapter-placement rule) |
| `76d381a` | the two in-flight-clear pins + `tracked_deviations.md` D-T9 |
| `776a946` | the P1.1 plan |

---

## 1. Actions only you can take

### 1.1 Push the 7 commits — **highest priority**
Pushing is owner-gated per `INSTRUCTIONS.md`, so I have not. Until it is pushed, the recovered in-flight work exists in exactly three places: your working tree, the local git objects, and the Recycle Bin.
*Say the word and I will run `git push` — or push it yourself.*

### 1.2 Identify what deleted `lib/` at 21:50 on 2026-09-21
An 11-second sweep across `lib/`, `build/` and `ios/Flutter/ephemeral/` sent 322 files to the Recycle Bin. It was **not** this session (git deletes bypass the Recycle Bin, and my last disk operation preceded it). The same thing could happen again.
*Check: antivirus quarantine log · disk-cleanup utilities · Task Scheduler · any other AI/agent session running on this machine.*

### 1.3 Do not empty the Recycle Bin
Specifically the entries deleted around 21:50 on 2026-09-21, until 1.1 is done and you have confirmed the tree.

### 1.4 (Informational) `flutter test` needs a proxy override on this machine
The sandbox exports `HTTP_PROXY` with an **empty** `NO_PROXY`, so the flutter_tester's localhost WebSocket is routed through the proxy and every test run dies with `WebSocketException: Invalid WebSocket upgrade request`. The working invocation:

```bash
NO_PROXY="localhost,127.0.0.1" no_proxy="localhost,127.0.0.1" flutter test
```

A real compile error reports `Compilation failed for testPath=…`; the WebSocket error means compilation already **succeeded**. Worth fixing in your shell profile so future sessions (human or agent) do not misread it as a code failure.

---

## 2. Decisions that unblock the next slice

### D1 — P1.1: approve the owner-mapping (4 flows)
Four presentation widgets call `OrganizationGateway` directly and orchestrate with local `setState`. My audit recommended owners; verifying the call sites **confirmed three and corrected one**:

| Flow | Site | Recommended owner | Note |
|---|---|---|---|
| `listMembers` (a **read**) | `matter_create_screen.dart:106` | `MatterCreateCubit` | the cubit already exists |
| `inviteMember` | `invite_member_sheet.dart:204` | `OrgCubit` | ✔ audit correct — the sheet is a modal opened *from the roster* |
| `acceptInvitation` | `accept_invitation_screen.dart:72` | **`AuthCubit`** | ⚠️ **audit corrected** — it is a standalone *route* with session-level effects, no roster on screen, so `OrgCubit` does not fit |
| `deleteMyAccount` (**destructive**) | `profile_screen.dart:131` | **`AuthCubit`** | **← the open question.** Session-ending; the screen's success path already calls `signOut()`. Alternative: a new `ProfileCubit`. |

**What I need:** approve the table, and answer the one open cell — **`AuthCubit` or a new `ProfileCubit` for `deleteAccount`?**

### D2 — P1.1: approve the shape
`MatterCreateCubit`, `OrgCubit` and `AuthCubit` all carry sealed state machines of their own, so "add the flow to the cubit" means choosing:

- **(a) Returning method** *(recommended)* — e.g. `Future<OrgInviteActionResult> inviteMember(...)`; the screen renders the affordance. Mirrors `OrgCubit`'s existing action convention; leaves the sealed lifecycles untouched.
- **(b) Emitted states** — new states on the cubit, visible to *every* listener of that cubit. Fuller `bloc_test` coverage of the flow, but it puts sheet/screen concerns into shared state.

**What I need:** (a) or (b).

### D3 — P1.2's iOS half: approve a new dependency?
The Android half is done (`android:allowBackup="false"`). The iOS half needs `flutter_secure_storage` (Keychain) so the refresh token stops living in `NSUserDefaults` — i.e. **adding a package**, which is an owner-gated decision in this repo.

**What I need:** approve the dependency, defer it, or accept the risk in writing (the current state is the plaintext session store).

### D4 — P1.3: approve the SQL apply slice
Four platform-admin RPCs are unbounded (`list_members_metadata`, `read_platform_audit`, `read_org_audit`, plus the org-name map). Fixing them means `p_limit`/`p_offset` migration changes, and the repo treats SQL as apply-gated (rehearsal → apply → battery re-run). Note: the session CLI account is not a member of the `law_project` org, so the apply itself may have to be run by you.

**What I need:** approve the slice and tell me who applies it.

### D5 — `tracked_deviations.md` D-T9: two trigger conditions
I recorded rather than deleted the two dead declared foundations. Each needs a future call:

- `lib/shared/responsive/responsive_breakpoints.dart` (46 lines, zero references) — **delete at the next responsive slice if no feature adopts it**, or keep it as planned foundation?
- `lib/core/use_cases/use_case.dart` — a layer *named in `INSTRUCTIONS.md` §4.1* with no consumer. **Implement one real use case, or drop the line from §4.1?** (Right now the documented architecture and the code disagree.)

---

## 3. Priorities — pick what is next

Everything below is ready to start; I have flagged my ranking. Effort is the audit's estimate.

| Rank | Item | Effort | Risk | Note |
|---|---|---|---|---|
| 1 | **P1.1** the 4 cubit moves | medium | medium | blocked on D1 + D2; includes one destructive flow |
| 2 | **P1.9** `CubitListSurface` + route the remaining lists through `ViewStateList` | medium | low | pure structure; 21 raw `ListView(` vs 3 builder |
| 3 | **H-7 second half** — the `_mapFailure` bodies, 10 enums, 9 exception classes (~500 lines) | medium | medium | carries per-feature codes/copy; wants its own reviewed slice |
| 4 | **P1.3** admin RPC bounds | medium | medium | blocked on D4 (SQL) |
| 5 | **P2.6** `test/support/pump_app.dart` + migrate 19 local helpers | small | low | pays for itself on every future widget test |
| 6 | **P2.10** `runApp` before auth hydration | small | medium | startup-path change |
| 7 | **P2.12** `RoleCapability` table → exhaustive switch | small | low | compile-time exhaustiveness |
| 8 | **P2.8** route the 7 raw `debugPrint` sites through `ErrorReporter` | small | low | observability hygiene |

Also open from the roadmap, lower value or riskier: P2.1, P2.3, P2.5, P2.7, P2.9, P2.11, P2.13, P2.14 (see audit §8 for the full table with finding IDs).

---

## 4. Optional polish (your call, all low-risk)

1. **`.gitignore` the tooling dirs.** `git status` shows these untracked: `.agents/`, `.cluster/`, `.flutter`, `.flutter_tool_state`, `.openclaw/`, `.opencode/`, `.workbuddy-ai/`, plus the workspace identity files (`AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md`, `HEARTBEAT.md`). Adding them prevents an accidental `git add -A` from committing agent state. *(`.workbuddy-ai/` also holds my memory notes and the incident recovery logs.)*
2. **P0.5 as a checklist line.** The audit's P0.5 was "run `flutter analyze` + `flutter test` before leaving any slice" — a habit, not a task. Want it written into `INSTRUCTIONS.md` Gate 5 so it is enforced rather than remembered? It is the single item that would have caught the compile error before it blocked 1356 tests.
3. **Flutter version constraint.** The recovered in-flight change loosened the Flutter constraint to a range (local toolchain is `3.48.0-pre`; CI pins `3.44.4` / Dart `3.12.2`). Keep the range, or tighten back to the CI pin?
4. **Commit trailer.** I used `Co-Authored-By: WorkBuddy AI <noreply@workbuddy.ai>` to match your existing `Co-Authored-By: Claude` convention. Say if you would rather I drop it.

---

## 5. What I will not do without an explicit answer

- **The 4-flow cubit refactor** (P1.1) — it moves consequential writes, one of which deletes a user's account; D1 and D2 are design choices, not implementation details.
- **Any SQL apply** (P1.3) — apply-gated by your own rules.
- **Adding a dependency** (D3) — package additions are owner-gated here.
- **Deleting declared foundations** (D5) — recording is reversible; deleting is a judgement about intent I cannot make for you.
- **Pushing to `origin/main`** — always yours.
- **Rewriting or restructuring the recovered commits** — they are the first durable copy of your in-flight work; if you want them squashed or split differently, say so and I will do it as an explicit operation.
