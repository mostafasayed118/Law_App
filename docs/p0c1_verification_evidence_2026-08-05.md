# LegalHub — P0C.1 Verification & Evidence Record (2026-08-05)

> **Record type:** Slice P0C.1 close-out evidence
> (`docs/p0_closure_scope_2026-08-05.md` §4, D-P0C2) — records exactly what
> was **verified** about the committed policy-test battery
> (`supabase/tests/` + `scripts/verify_policy_tests.sh`, landing commit
> `c33374b`) and exactly what is **still pending**, with no claim beyond what
> was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: PARTIAL — static verification COMPLETE; ephemeral-project battery
> run PENDING (infra-blocked on this machine).** P0C.2 (server amendment) is
> **NOT triggered** — the static review found no defect.

---

## 1. What this record covers

Slice P0C.1 = the committed SQL battery + harness. Its acceptance evidence is
the battery running **green against an ephemeral rehearsal project**
(AC-1, `docs/p0_closure_scope_2026-08-05.md` §5). That full run requires a
Docker-backed local Postgres (or a throwaway remote rehearsal project) and
`psql`. This record separates what was verified without a database from what
still needs the database run.

## 2. Verified (actually run/read this session, 2026-08-05)

### 2.1 Harness static check — `bash scripts/verify_policy_tests.sh --check`

**Result: PASS — 20 passed, 0 warnings, 0 failures** (exit 0).

- Battery files present + non-empty (00/01/02/03).
- Every fixture UUID referenced by 01/02/03 resolves in `00_fixtures.sql`
  (11 UUIDs checked).
- Every battery check block carries the `POLICY-BATTERY FAIL` marker —
  harness counts **111 named blocks** (01: 24, 02: 52, 03: 35).
- Harness bash syntax clean; `supabase/README.md` battery section and
  `scripts/README.md` harness row present.

### 2.2 Static review of the battery SQL against the committed schema/RPCs

Full review of all four files against `supabase/migrations/01–03`,
`supabase/policies/`, and `supabase/rpc/` as committed at `c33374b`:

| File | Distinct numbered checks | Coverage |
|---|---|---|
| `00_fixtures.sql` | — (deterministic seeds + 2 sanity guards) | idempotent reset, 7 synthetic identities, 2 orgs, 5 memberships (incl. suspended + orphan), 1 pending invite, 1 owner row (D-P0C3 single-account bound) |
| `01_identity_session.sql` | 15 (01.01–01.15) | matrix §2 own-profile pos/neg, D-T6 own-row-only pair, `list_org_members_metadata` pos (roster 5 rows, display-name/locale resolution, invited row, no token material) + 4 denials (client, cross-org, suspended, owner), orphan-membership defense, anon deny |
| `02_organization_membership.sql` | 29 (02.01–02.29) | matrix §3 roster/org visibility pos/neg, cross-org, suspended-stale, invite/resend/revoke/change-role/suspend/remove pos + neg + 2026-08-03 hardening (existing-member, last-partner, self-removal), create-org pos, owner-via-partner-path denials (4) |
| `03_platform_owner_boundary.sql` | 27 (03.01–03.27 + 03.D-P0C3a) | matrix §5 owner positives (list orgs/members, platform suspend/reactivate any-org, delete demo account, audited-with-owner-actor), D-P0C1(a) owner deny-rows (own profile only; 0 membership/org/invitation rows; raw `audit_events`/`platform_config` denied; helpers not client-callable), D-P0C3 both halves, D-P0C4 self-audit + append-only pins + non-owner denials, self-delete refusal |

**Consistency pins verified (battery expectations vs. committed RPC bodies —
exact string/reference matches):**

- `'organization must retain at least one active partner'` → `change_member_role.sql`
- `'cannot remove yourself; use delete_my_account'` → `remove_membership.sql`
- `'user already has a membership in this organization'` → `invite_member.sql`
- `'cannot delete your own account via this path; use delete_my_account'` → `delete_demo_account.sql`
- `'partner:list_org_members'` → `list_org_members_metadata.sql:35`
- `'platform:read_audit'` → `read_platform_audit.sql:31`; `'audit:read_org'` → `read_org_audit.sql:28`
- resend rotation + 7-day expiry reset → `resend_invitation.sql:34–35`
- helper EXECUTE revokes (`write_audit`, `active_membership`, `is_platform_owner`, `has_org_role`, …) → `02_rls_functions.sql:132–140` (battery 03.10–03.14 expect `insufficient_privilege`)

**Conclusion: no defect found → P0C.2 (server amendments) NOT triggered.**
The battery is structurally consistent with the applied baseline and the
2026-08-01 R-4 grant posture.

## 3. Pending (honestly NOT run — do not read as verified)

- **The battery run against an ephemeral rehearsal project** (AC-1 evidence,
  the `--apply` + full-run mode) has **not been executed**. Reason:
  infra-blocked — this machine has **no `docker` and no `psql`** in PATH
  (Supabase CLI 2.109.1 is present but `supabase db start` requires Docker).
- No battery claim is made about a live project. The harness **never** runs
  against the dev project (D-P0C2 / harness header) — the ephemeral rehearsal
  is the P2 r1–r5 pattern.

## 4. Acceptance-criteria status (scope note §5)

| AC | Status | Evidence |
|---|---|---|
| AC-1 harness + battery green on ephemeral project; every matrix row ≥1 pos + ≥1 neg | **PENDING (infra)** — static half complete | §2.1/§2.2 + §3 |
| AC-2a owner deny-rows proven via battery run | **PENDING (infra)** — rows exist + reviewed (01.09–01.12, 02.26–02.29, 03.06–03.15) | §2.2 |
| AC-2b content-table forward pin referenced by matrix addendum | ✅ VERIFIED | matrix §5 addendum 2026-08-05 (ratified `f8d774a`) |
| AC-3 single-account bound proven | **PENDING (infra)** — both halves present (00 sanity + 03.D-P0C3a + 03.17) | §2.2 |
| AC-4 audit RPC-only + self-audit | **PARTIAL** — no-grant + revoke pins verified statically (03.10, 03.13, 03.22/23, `02_rls_functions.sql`); live self-audit rows pending the run (03.18/19) | §2.2 |
| AC-5 dated matrix addendum + P0-close record + roadmap §14 CLOSED | **PENDING** — matrix addendum ✅ (`f8d774a`); P0-close record + roadmap update await the battery run + owner's dated close decision | — |

## 5. Exact commands to complete the remaining verification (P0C.1 exit)

On a machine with Docker + psql (or a throwaway remote rehearsal project):

```bash
# 1. Local ephemeral project from the committed supabase/ files
supabase init          # once, scratch dir
supabase db start      # Docker-backed local Postgres
# 2. Build the project from the committed files + run the full battery
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@localhost:5432/postgres \
  bash scripts/verify_policy_tests.sh --apply
# 3. Record the run: cite the commit, the exit code, and the PASS counts in
#    the P0-close record (docs/p0_close_decision_2026-08-05.md, P0C.3 slice)
```

The owner's dated close decision then advances the P0C.3 slice.

## 6. Ledger impact

None: no `lib/` or `test/` change (README count 703 untouched); the battery
is SQL. `scripts/verify_ledger.sh` unaffected by this record.

## 7. Owner attention needed

- Decide/approve the ephemeral rehearsal run (infra) and the P0C.3 dated
  P0-close decision once the battery is green.
