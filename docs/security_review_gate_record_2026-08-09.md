# P4 Security-Review Gate — Status Record (2026-08-09)

> **Record type:** Status record for the **P4 slice — Security review +
> controlled rollout** (row in `docs/p0_decision_capture.md` §3, resolved
> 2026-08-09 to **DEMO-READY (non-production)** — see
> `docs/p4_release_readiness_2026-08-09.md`). This record does **not**
> authorize a production release and does **not** claim a completed
> security review — it pins what was verified during the 2026-08-09 audit
> and what remains owner-gated. Owner: Project Owner
> (github.com/mostafasayed118).

## 1. Verified facts (2026-08-09, whole-tree gate)

| Check | Result | Evidence |
|---|---|---|
| `flutter analyze` | **0 issues** | run on `main` @ `5f62121` |
| `dart format` | clean | 321 files, 0 changed |
| `flutter test` | **1112 pass** | full suite |
| `scripts/verify_ledger.sh` | **PASS 115/0/0** | README count lockstep |
| CI | present (`format + analyze + test` on push-to-main + PR) | `.github/workflows/ci.yml` |
| Env hygiene | `.env`, `.env.*`, `*.env` git-ignored | `.gitignore` lines 48–51 |
| Secrets in tree | none committed (audit greps + history; `.env` untracked) | git status clean |
| Dependency displacement | 11 direct dependencies, no new ad-hoc package introduced by 2026-08-09 slices | `pubspec.yaml` |
| ADR log | present (0001–0008); decisions dated + owned | `docs/adr/` |
| Deep-link surface | code present but inert until console **Redirect URL** is added (owner action) | roadmap 4.1 R1 |

## 2. What P4 still requires (owner-gated, do NOT raise to "done" until reviewed)

1. **Threat-model / threat-mod review** — at least STRIDE-style pass over the
   applied Supabase surface (12 tables / 12 RLS / 11+ policies / 19 RPCs /
   Realtime + storage bucket) and the auth/org seam. The policy batteries
   (`supabase/tests/*.sql`) exercise matrix rows positively + negatively; P4
   would add a consolidated cross-surface threat write-up.
2. **Dependency / config review** — locked versions, `supabase_flutter`
   major-version pin per `INSTRUCTIONS.md` §4.6; verify upgrade policy holds.
3. **Controlled rollout rehearsal** — rollback rehearsal under
   `docs/rollback_plan.md`; a staging environment or evidence the dev
   project doubles as the only non-prod surface.
4. **Release approval** — dated owner sign-off naming what ships where.

**Nothing above was performed during the 2026-08-09 audit; this record flags
the gate as OPEN at the time.** (The decision-capture P4 row is now
`DEMO-READY (non-production)` per `docs/p4_release_readiness_2026-08-09.md`
— the dated demo-scoped release approval, item 4.)

## 4. Work completed for P4 (2026-08-09, evidence-grounded — reviewable, not self-approved)

> These are the *reviewable inputs* listed under §2 items 1–2. They do **not**
> close the gate: item 3 (rehearsal) and item 4 (dated release approval)
> remain owner-only. All claims below are reproducible from the repo.

### 4.1 Dependency / configuration review (P4 §2)

Locked at `pubspec.lock` (2026-08-09, `main`):

| Package | Locked | Constraint | UPGRADES notice |
|---|---|---|---|
| supabase_flutter | 2.16.0 | `^2.16.0` (major pinned per INSTRUCTIONS §4.6) | no action |
| flutter_bloc | 9.1.1 | `^9.1.1` | — |
| bloc | 9.2.1 | `^9.2.1` | — |
| go_router | 17.3.0 | `^17.3.0` | — |
| get_it | 9.2.1 | `^9.2.1` | — |
| equatable | 2.1.0 | `^2.1.0` | — |
| intl | 0.20.2 | pinned exact | — |
| mocktail | 1.0.5 | `^1.0.5` | — |
| app_links | 7.2.1 | `^7.2.1` major-pinned | verify against deep-link slice |

`flutter pub outdated` reports **0 breaking updates within constraints** for
the direct set (18 packages have newer versions *incompatible with
constraints* — i.e. niche majors that would require an upgrade slice;
recorded, not acted on, per §4.6 no-major rule).

Env-hygiene recheck: `.gitignore` excludes `.env`, `.env.*`, `*.env`; the
dev URL + anon key live only in the ignored `.env`; no service-role key or
secret string present in `lib/`, `test/`, `supabase/` history scanned on
2026-08-09 (CI + pre-push scans).

### 4.2 STRIDE-lite sketch (reviewable input, NOT a completed assessment)

| Threat class | Where | Current control (evidence) | Gap |
|---|---|---|---|
| Spoofing | Auth/org seam | GoTrue email+password; typed `AuthGateway` seam; sessions `Session` DTO-free (contract §5) | MFA/SSO deferred to v1 (D-07) |
| Tampering | RPCs — `security definer` in-function gates | applied-ing (batteries: matters / documents / threads / storage / messages / billing) | audit-event write is RPC-only; no raw `audit_events` SELECT ever (D-P0C4) |
| Repudiation | Audits | every mutation RPC writes audit row; `delete_demo_account` refuses self; audit read = redacted only | partner org-audit UI shipped 2026-08-09 |
| Information disclosure | RLS (12 tables) + storage + realtime | default-deny; matrix §4 rows exercised by batteries (incl. cross-org 0, anon denied) | `org role alone never grants matter access` invariant — tested |
| DoS / availability | Realtime publication `messages` only | 1 link, nothing else (battery pin) | provider-side limits not in scope of client |
| Elevation of privilege | Platform-admin | owner-only `platform_owner_admin` gate + never-self | P4 threat write-up required — **not yet written** |

### 4.3 Outstanding P4 mechanics

- **Rollout rehearsal**: `docs/rollback_plan.md` pairs every apply slice with a
  `_down.sql`; a dry-run rehearsed rollback is still owner-gated (needs a
  staging/dev-project cycle).
- **Release approval**: a dated owner sign-off naming where the client ships
  (dev/staging/store) — not yet granted.
- **P4 row**: see §5.

> Bridge note: this annex made P4 *reviewable*; it did not claim it done.
> The decision-capture P4 row is now `DEMO-READY (non-production)` per
> `docs/p4_release_readiness_2026-08-09.md` (dated 2026-08-09, explicitly
> scoped as non-production).

## 5. Logged owner actions referenced by other records

- Supabase console: add `com.legalhub.app://auth/v1/callback` under Auth →
  URL Configuration (deep-link recovery + invite links otherwise inert).
- P0 `§3` P4 row: assign Owner + date to close.
- D-45.1 provider-loop Phase 2 (controlled inbox).