# LegalHub — Gate 3 Reconciliation Amendment

> **Record type:** Official amendment to the Gate 3 decision record
> (`docs/gate3_decision.md`, ACCEPTED 2026-07-28, Option C). Closes the
> paper-trail gap between that record and the repository's actual commit
> history. **Docs-only.** No code, schema, migration, RLS policy, storage
> policy, edge function, credential flow, or production configuration is
> added, changed, or authorized by this amendment.
>
> **Status:** ACCEPTED (retroactive closeout authorization recorded; §3.1
> realized file set; §4 screen reclassification; §10.2/§10.5 assigned to the
> sole project owner). Owner identity in §10 is recorded; the
> `gate3_decision.md` §2.2 rows are filled with it.
>
> **Date:** 2026-07-31.
>
> **Amends:** `docs/gate3_decision.md` §2.2, §3.1, §3.2, §3.4, §4, §5, §6, §7.
> **Does not supersede:** the P2/P3/P4 phase gating (§5 of the record),
> `docs/adr/0007-no-backend-until-p0-closes.md`, or
> `docs/auth_tenant_authorization_contract.md` §10–§12.

---

## 1. Background and purpose

`docs/gate3_decision.md` accepted the auth/tenant authorization contract as a
Gate 3 specification (design-only, Option C) on 2026-07-28. It required:

- §3.4: the permitted P1 working-tree files "must remain unstaged and
  uncommitted until the owner separately authorizes a closeout/commit";
- §3.1: an exact permitted-file list (14 files);
- §3.3: specific non-authoritative wording on `FakeAuthGateway` and the
  org-context types;
- §2.2: named owners for §10.2/§10.5, still `PLACEHOLDER` at approval time.

The backend-free P1-adjacent work was subsequently implemented and committed
on `main` (authorization was conveyed in session but never written into the
ledger), a subset of the approved file list was never created, a different
smaller design was built in its place, and screens were shipped as scaffold.
This amendment reconciles the record with the verified repository state.

## 2. Closeout authorization (recorded retroactively)

The product/legal owner authorizes closeout of the Gate 3 §3 synthetic-P1
work, effective immediately. The following commits on `main` constitute the
realized scope of that work:

| Commit | Summary | Realized Gate 3 scope |
|---|---|---|
| `06e14e9` | auth flow screens | Sign-in/sign-up/forgot-password scaffold screens (§5 reclassification) |
| `1f07b64` | onboarding screens | Onboarding scaffold (foundation UX, not contract P3) |
| `e231906` | routes/home/theme/l10n wiring | Presentation scaffold wiring behind the `AuthGateway` seam |
| `15abf59` | shared form/validation/layout widgets | Shared widgets consumed by the scaffold |
| `30adb57` | shared/ second-use refactor | ADR-0004 compliance; `OtpFieldRow` relocated to its feature |
| `9e29cf5` | brand fix | D-01/ADR-0001 enforcement across UI + l10n |
| `b873ee1` | SignUpRequest domain contract | P1-style backend-free domain contract with redaction tests |
| `e45b9a1` | PasswordRecoveryCubit + ViewStateView | Approved §3.1 file; first `ViewState` consumer (ADR-0004) |
| `cd9da84` | unit + widget tests | Test floor for the realized scope |
| `3ac1565` | README coverage map + ADR-0006 | Documentation reconciliation |
| `46bcb7c` | blocTest emission sequences | Test rigor for `AuthCubit`/`PasswordRecoveryCubit` |
| `57e60d4` | dart format | Formatting debt cleanup |
| `0d5c66d` | SignUpRequest → SignUpCubit → Gateway seam | Completed sign-up wiring (backend-free) |
| `2c05655` | p0_decision_capture + ADR-0007 | Backend gate artifact |
| `1a99df0` | Gate 3 record cherry-picked into main | The record this amendment amends |
| `83f5bbf` | email/OTP threading | Closed the D-T2 recovery half in code; `tracked_deviations.md` D-T2 itself is still stale and is scheduled for the docs-hygiene batch |

**Effect:** §3.4's "no commit authorized" constraint is superseded by this
recorded authorization for the commits above, and the §7 acknowledgment
"No commit is authorized yet" is superseded to the extent it conflicts with
this closeout authorization. All other constraints of the record remain in
force.

## 3. Amendment to §3.1 — realized file set

Verified against `git ls-tree f7621df` (approval commit) and `git ls-files`
(today):

### 3.1a Files present at approval time and still tracked (10 of 14)
`auth_gateway.dart`, `auth_state.dart`, `fake_auth_gateway.dart`,
`auth_cubit.dart`, `settings_screen.dart`, `router.dart`,
`service_locator.dart`, `main.dart`, `bootstrap_boundaries_test.dart`,
`widget_test.dart` — all **present in the tree at the approval commit
`f7621df`** (several were modified afterward, e.g. `router.dart` → `e231906`,
`bootstrap_boundaries_test.dart` → `46bcb7c`). **Correction to the record:**
these were already tracked, so §3.1's "all currently unstaged and
uncommitted" was inaccurate for this subset at approval time.

### 3.1b Approved but never created (3 of 14)
- `lib/core/auth/organization_context.dart`
- `lib/features/auth/presentation/organization_context_cubit.dart`
- `test/auth_domain_p1_test.dart`

**Why dropped:** the org-context vocabulary was deferred rather than built.
Organization selection requires a membership model that does not exist yet
(no backend, ADR-0007); implementing it as pure client state would have
risked exactly the "client-owned role as authority" shape the contract warns
against (§5). The smaller backend-free set (§3.2a) delivers the P1 intent —
provider-neutral domain contracts with tested redaction — without a
non-authoritative org picker that could be mistaken for a real boundary.
Reintroduction is a P1/P2 decision once `p0_decision_capture.md` blockers
close.

### 3.1c Approved and tracked (1 of 14)
- `lib/features/auth/presentation/password_recovery_cubit.dart` — untracked
  WIP at approval time; committed in `e45b9a1`.

### 3.1d Built in place of 3.1b (verified tracked)
- Domain: `sign_up_request.dart`, `sign_up_gateway.dart`,
  `password_recovery_request.dart`, `password_recovery_gateway.dart`
- Data: `fake_sign_up_gateway.dart`, `fake_password_recovery_gateway.dart`
- Presentation: `sign_up_cubit.dart`, `sign_up_screen.dart`,
  `sign_in_screen.dart`, `forgot_password_email_screen.dart`,
  `forgot_password_otp_screen.dart`, `forgot_password_reset_screen.dart`,
  `otp_field_row.dart`, `recovery_routing_context.dart`
- Home/onboarding: `home_screen.dart`, `onboarding_screen.dart`

## 4. Amendment to §3.2 — realized vocabulary

The approved vocabulary (`AuthOutcome<T>`, `AuthFailure(Kind)`,
`SignInRequest`, `PasswordResetRequest`, `ResetCodeRequest`,
`PasswordUpdateRequest`, `OrganizationMembership`, `MembershipStatus`,
`Session{memberships, expiresAt}`) was **not built**. The realized vocabulary
is provider-neutral and smaller:

- `Session {id, displayName, role}` — the bootstrap-era demo session shape.
  See §7.
- `SignUpRequest` / `PasswordRecoveryRequest` — pure-domain value objects
  with `toRedactedMap()` delegating to `Redactor` (ADR-0003); tested for
  redaction idempotence.
- `SignUpGateway` / `PasswordRecoveryGateway` — credential-free integration
  seams mirroring `AuthGateway`; fake implementations registered via GetIt.
- `RecoveryRoutingContext` — in-memory route-`extra` payload (email/OTP
  never travel in URLs; privacy contract documented on the type).

Required §3.3 wording: `FakeAuthGateway` carries the mandated
non-production/non-authoritative doc comment (verified verbatim in
`lib/data/auth/fake_auth_gateway.dart`). The `OrganizationContextCubit`
wording is not applicable because the type was never created (§3.1b).

## 5. Amendment to §4 — screen reclassification

The record excluded "sign-in / sign-up / recovery screens" from P1. The
screens that exist are reclassified as:

> **Bootstrap scaffold UX rendered against synthetic fakes — not contract-P3
> production UX.**

Rationale: contract P3 requires production sign-in/up/recovery against a real
provider with explicit loading, denial, offline, expiry, and retry states
(contract §11). The shipped screens validate and route against
`FakeAuthGateway`/fake gateways only; no real credential, OTP, or password
data crosses any boundary; there is no provider to deny or expire a session.
They are therefore foundation presentation (B11/B13 spirit), not the gated
P3 production work. Contract-P3 remains **not authorized** and requires the
record's §5 gating (P2 exit + explicit P3 approval) before a real provider is
wired.

## 6. §10.2 / §10.5 — sole-owner assignment

§10.2 (jurisdiction/policy owner, D-03) and §10.5 (human-authority owner,
D-06) are held by the project owner as the sole developer of this project —
see §10. The literal `[YOUR NAME / ROLE]` placeholders in `gate3_decision.md`
§2.2 are filled with that identity as part of this amendment's commit
(replacing the `PLACEHOLDER — NOT YET ASSIGNED` rows), so the contract's
human-accountability clauses now have an assignee. This assignment does not
change any P0 blocker status in
`docs/p0_decision_capture.md` (all still `OPEN`): the accountability role is
held, but the underlying §10 *decisions* (jurisdiction, policy, authority
model) remain open decisions to be made by that owner.

## 7. Session shape — tracked-deviation candidate

`Session {id, displayName, role}` is technically the shape contract §5 said a
future session must not be ("must not contain only one client-controlled
`role` as the authority"). This is **safe here** because:

- the demo session is explicitly non-production and non-authoritative
  (`FakeAuthGateway` wording, §3.3);
- the capability map is documented UX-only (`lib/core/roles/user_role.dart`);
- no server exists to be fooled by a client role.

The concern becomes live only when a production session model is introduced
(contract-P1 provider adapter), at which point the §5 session contract
(provider-derived `userId`, `memberships`, `expiresAt`) is mandatory. This
entry is proposed for the tracked-deviations ledger as **D-T4** in the
docs-hygiene batch; recording it here makes the divergence reviewable now.

## 8. What remains in force

- Contract-P2 (schema/RLS/enforcement), P3 (production UX), P4 (security
  review + rollout) remain **not authorized** — record §5 unchanged.
- `docs/adr/0007-no-backend-until-p0-closes.md` stands: no Supabase package,
  migration, RLS, storage policy, RPC, or edge function until
  `p0_decision_capture.md` closes the required blockers and its §3 approval
  table records explicit sign-off.
- `.env.example` stays names-only with empty values; no credentials exist in
  code, tests, logs, or commits (re-verified by the 2026-07-31 audit).
- The §3.3 non-authoritative wording remains a regression guard on
  `FakeAuthGateway`.

## 9. Verification evidence

- Gate 3 approval commit: `f7621df` (record says `f7621df4fc7beb9df173c726720be189f1c22f47`).
- File-existence matrices in §3 generated from `git ls-tree f7621df` and
  `git ls-files` (2026-07-31).
- All commit hashes cited in §2 verified present (`git cat-file`).
- `flutter analyze` → "No issues found!"; `flutter test` → 136/136 passed
  (2026-07-31), confirming the realized scope is healthy.

## 10. Accountability assignment

This is a solo-developer project. At this scale all §10 accountability roles
— §10.2 jurisdiction/policy owner, §10.5 human-authority owner, and the
closeout-authorizing owner — are held by the project owner:
`Project Owner (github.com/mostafasayed118)`.
Named-role delegation to separate individuals becomes necessary only if/when
P2 introduces a shared-access backend or additional contributors; until then,
separation of duties is acknowledged as *not applicable* rather than simulated.

- **Date:** 2026-07-31.

The owner identity above is recorded; this amendment and the §6/§7
references are the standing record that the Gate 3 ledger and the commit
history agree.

---

Gate 3 reconciliation adopted. This amendment is the authoritative record of
the as-built synthetic P1 slice and supersedes the unrealized §3.1 file list
in `gate3_decision.md`.
