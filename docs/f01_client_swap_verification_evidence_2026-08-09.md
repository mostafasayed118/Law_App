# LegalHub — F-01 Client Swap: D-45.1 Write-Surface Verification Evidence (2026-08-09)

> **Record type:** D-45.1 configured-build verification evidence — the
> **write-surface** half of the F-01 chain's last gate (the client swap's
> create flow against the live dev project). Owner-approved to execute
> 2026-08-09 (the kickoff's step 2; the dev-project confirmation was given
> in-session). Mirrors the apply-execution evidence format
> (`docs/matter_write_apply_execution_2026-08-09.md`).
>
> **Status: EXECUTED + PASSED 2026-08-09 on the shared dev project**
> (`eutmvevpskerzpqmwplv`, `eu-central-1`): the partner's create flow —
> the exact `create_matter` RPC call the configured build's
> `SupabaseMatterWriteApiImpl` makes — returned a persisted uuid, the §8
> `matter:create` row was observed through the org-audit read path
> (`read_org_audit`, the exact RPC the `OrgAuditScreen` uses), the new
> matter is readable by the partner through the matters read gate (the
> RLS read-back the client's list would show), and the F2-D2 owner
> refusal fired with the exact message the client maps to
> `matter_write_owner_forbidden`.
>
> **Boundary (honest scope):** this run exercised the **server round-trip
> of the configured build's create flow** — the RPC call, the audited
> write, and the org-audit read-back — with the same role impersonation
> the repo's apply smokes use. It does **not** claim a UI-driving pass
> (no emulator run in this environment); the checklist's owner-side
> device pass (`docs/configured_build_e2e_checklist_2026-08-08.md` §3/§5)
> remains available for the read surface + full UI. The client-side
> parameter contract (exact `p_*` names) and the failure-kind mapping are
> pinned by the suite (`test/data/matters/supabase_matter_write_api_impl_test.dart`).

---

## 0. Runbook (executed 2026-08-09)

```bash
# 1. Pre-state probes (read-only) — §1
# 2. Create flow — role-impersonated RPC call as the demo partner
#    (set local role authenticated + request.jwt.claims sub = partner),
#    the EXACT named-parameter call the client makes, persisted
# 3. §8 audit-row observation via read_org_audit (the org-audit view path)
# 4. RLS read-back (matters SELECT gate as the partner)
# 5. F2-D2 negative — owner-as-assignee refusal, message captured
```

Rollback pairing standing by, **unexercised** (nothing was altered beyond
the single demo matter the verification created — itself demo data).

## 1. Pre-state (read-only)

| Check | Expected | Observed | Verdict |
|---|---|---|---|
| `create_matter` function present (RPC-EXECUTE 20 surface) | 1 | `1` | ✅ |
| `matters` in the demo org | 5 (4 seeded + the apply-session `d28f1f05-…`) | `5` | ✅ |
| demo org `ef43087b-adf4-4480-9bb2-28c26f46ec71` | resolves | `1` | ✅ |
| demo partner `8fa94af0-7390-4f7a-988a-3965f7da04de` active member | the only dev member | `1` | ✅ |
| `audit_events` rows | ≥ 10 | `10` | ✅ |

## 2. Create flow (the client's exact call)

Role-impersonated as the demo partner, `create_matter` with all five
`p_*` parameters (the `SupabaseMatterWriteApiImpl` shape): org = the demo
org, title = generic demo wording (never a real client/case name — D-M4),
`practice_area = 'corporate'`, client = null (F2-D5 orphan arm unused),
attorney = the partner.

```
┌──────────────────────────────────────┐
│ create_matter                        │
├──────────────────────────────────────┤
│ 4a8425d4-5d67-4422-b371-359c9696d65a │
└──────────────────────────────────────┘
```

The call **persisted through the audited path**: F2-D1 (active partner)
passed, the INSERT ran inside the definer function under the categorical
`refuse_platform_owner_assignment` trigger, and the §8 audit row was
written in the same implicit transaction.

## 3. §8 audit row — observed via the org-audit read path

`read_org_audit('ef43087b-…')` as the partner (the exact RPC the
`OrgAuditScreen` renders), filtered to the returned id:

```
│ action        │ outcome │ resource_type │ resource_id                          │ redacted_summary │ server_timestamp              │
│ matter:create │ allowed │ matter        │ 4a8425d4-5d67-4422-b371-359c9696d65a │ matter created   │ 2026-08-09 15:08:52.981748+00 │
```

- The **`matter:create` / `allowed` row appears in the org-audit read**
  for the partner — the surfacing the client swap ships as-is (C-D7: no
  new server surface needed).
- **Redaction holds:** `redacted_summary` is the fixed `matter created`,
  never the title (contract §8; the D-M4 discipline). No PII-shaped value
  appears in this evidence; all ids are demo ids.

## 4. RLS read-back (the client's list would show the new matter)

As the partner, the matters read gate (`is_active_member` AND assignment)
returns the new matter among the partner's rows:

```
│ visible_matters │
│ 5               │   ← 4 prior + 4a8425d4-… (assigned attorney = partner)
```

## 5. F2-D2 negative (the client's typed-refusal path)

Owner-as-assignee through the same RPC as the partner; the refusal
message captured:

```
│ platform owner cannot be assigned to a matter │
```

This is the exact fragment `SupabaseMatterWriteApiImpl._kindFor` matches
to `SupabaseMatterWriteFailureKind.ownerForbidden` →
`matter_write_owner_forbidden` (pinned by the api-impl test) — the typed
refusal the client renders as localized copy, confirmed live against the
real server message.

## 6. Verdict + scope notes

- **PASS:** the write-surface D-45.1 gate is executed — create flow →
  §8 row in the org-audit read → RLS read-back → F2-D2 typed refusal,
  all live on the dev project. The F-01 chain is now closed end-to-end:
  invariant pinned (battery 12) → enforced server-side (RPC + trigger,
  applied) → demo data cleansed (F-12) → client surface built + reviewed
  → **live verification executed**.
- **Honest residuals:** (a) no emulator/device UI pass was run (the
  checklist §3/§5 owner-side device steps remain); (b) the created demo
  matter `4a8425d4-…` persists in the dev demo data (demo rows, by
  design — the surface table's "matters 5→6" delta is a dated addendum
  item if the surface note is updated).
- The run touched only the create flow's own demo row + its §8 audit
  row; no policy/RPC/table change, no rollback needed.
