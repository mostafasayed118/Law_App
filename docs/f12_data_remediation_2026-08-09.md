# LegalHub — F-12 Data Remediation: Acquisition Matter Re-Assignment (2026-08-09)

> **Record type:** execution evidence for the **F-12** remediation
> (`docs/p4_findings_register_2026-08-09.md` F-12 — the pre-existing demo
> matter carrying the platform-owner id as its assigned client). The
> owner-directed, owner-approved data slice that restores the F-01
> never-assigned invariant in the dev demo data.
>
> **Status: RESOLVED 2026-08-09 — applied and verified on the shared dev
> project** (`eutmvevpskerzpqmwplv`, `eu-central-1`): the acquisition demo
> matter's `assigned_client_id` was moved **off the platform-owner id** onto
> the real demo-client account, with a machine audit row, in one
> transaction. **Post-state: the platform-owner id appears in NO matter
> assignment column (0 of 5 matters)** — the F-01 invariant now holds in the
> dev demo data. Rollback pairing (restore the owner id + delete the audit
> row) standing by, **unexercised**.
>
> **Owner:** Project Owner (github.com/mostafasayed118) — directed the
> remediation in-session 2026-08-09.

---

## 1. Pre-state (verified before the change, 2026-08-09)

| Fact | Value |
|---|---|
| Target matter | `a6715e17-15a6-4456-96e3-78fc56630cfe` — "Demo matter — acquisition review" |
| `assigned_client_id` | the platform-owner id (`platform_config.owner_user_id`, `9acfd3b4-…`) — the Q4 residual state, seeded 2026-08-07 by the matters apply |
| `assigned_attorney_id` | `8fa94af0-7390-4f7a-988a-3965f7da04de` (the demo partner) |
| `organization_id` | `ef43087b-adf4-4480-9bb2-28c26f46ec71` (the demo org) |
| Target assignee (resolved, verify-don't-guess) | `0c54d251-1cdd-4be6-9ce5-623a5987045f` — `profiles.display_name = 'Demo Client'` (the real demo-client account; the send-message hygiene fix's target) |

## 2. The change (one guarded UPDATE + machine audit row, one transaction)

```sql
begin;
update public.matters
   set assigned_client_id = '0c54d251-1cdd-4be6-9ce5-623a5987045f'
 where id = 'a6715e17-15a6-4456-96e3-78fc56630cfe'
   and assigned_client_id = (select owner_user_id from public.platform_config limit 1);
select public.write_audit(
  'matter:assignee_remediation', 'allowed',
  'ef43087b-adf4-4480-9bb2-28c26f46ec71',
  'matter', 'a6715e17-15a6-4456-96e3-78fc56630cfe',
  null, 'assigned client corrected (demo data remediation)', null);
commit;
```

- The `WHERE` guard (id **AND** current client = the owner id) means the
  UPDATE could only touch the target row — a no-op against anything else.
- The F-01 step 2 trigger (`refuse_platform_owner_assignment`, `BEFORE
  INSERT OR UPDATE`) **passed** — the re-assignment is to a non-owner, the
  narrowness arm (battery 13.15) firing exactly as designed.
- The audit row is a **machine event** (Q6 — `p_actor` NULL), redacted
  summary with no sensitive content, written via the single `write_audit`
  path.

## 3. Post-state (verified immediately after)

| Check | Observed | Verdict |
|---|---|---|
| Platform-owner id in **any** matter assignment column (client or attorney, all 5 matters) | **0** | ✅ **the F-01 invariant now holds in the dev demo data** |
| `a6715e17-…` assigned client | `0c54d251…` (Demo Client) | ✅ |
| `a6715e17-…` assigned attorney | `8fa94af0…` (partner, unchanged) | ✅ |
| `a6715e17-…` org | `ef43087b…` (unchanged) | ✅ |
| Audit row `matter:assignee_remediation` for the matter | **1** | ✅ |
| Platform owner reads matters (impersonated) | **0** (no membership — unchanged posture) | ✅ contained |
| Demo client reads matters (impersonated) | **0** (no membership — the F-09 posture, unchanged, never a defect) | ✅ honest expectation |

## 4. Honest scope notes

- This is a **data change only** — no schema, policy, RPC, or trigger
  change; the F-01 step 2 server guarantee is untouched.
- The demo **client still holds no membership rows**, so it reads the
  matter 0 — the pre-existing demo posture (F-09), unchanged by design; a
  client-side positive demo would require the separate membership-data
  action.
- Rollback pairing (restore the owner id to `a6715e17-…` + delete the
  audit row) stands by, unexercised; nothing was pushed.
