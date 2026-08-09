# LegalHub — Final End-to-End Demo Walkthrough: Evidence (2026-08-09)

> **Record type:** final configured-build demo walkthrough — the partner's
> full read surface (matters, documents, messaging, storage, billing,
> orgs, org audit) plus **transactional write demos** (matter create +
> message send, each rolled back with zero residue) against the live dev
> project. Executed 2026-08-09, owner-requested, after the F-01 chain
> closed (D-45.1, `docs/f01_client_swap_verification_evidence_2026-08-09.md`).
>
> **Status: EXECUTED + PASSED 2026-08-09 on the shared dev project**
> (`eutmvevpskerzpqmwplv`, `eu-central-1`).
>
> **Method:** the same role impersonation the repo's apply smokes use —
> `supabase db query --linked` (Management API SQL runner; no DB password
> touched), `set local role authenticated` + `set local request.jwt.claims`
> with the demo partner `8fa94af0-7390-4f7a-988a-3965f7da04de`, org
> `ef43087b-adf4-4480-9bb2-28c26f46ec71`. RLS applies normally, so every
> count below is the partner's **actual** policy-filtered view, not a
> manual re-derivation.
>
> **Boundary (honest scope):** this is a server-round-trip walkthrough of
> the configured build's surfaces — the exact RPC/gate paths the client
> gateways call. It is **not** a UI-driving pass (no emulator in this
> environment; the checklist's owner-side device pass,
> `docs/configured_build_e2e_checklist_2026-08-08.md` §3/§5, remains
> available). Both write demos ran inside `BEGIN … ROLLBACK`
> transactions — the created matter/message and their audit rows were
> rolled back; the walkthrough left **no content residue** (the sole
> residual is one `audit:read_org` row from the walkthrough's own org-audit
> read — audited reads are by design, §8 contract).

## 0. Runbook (executed 2026-08-09)

```bash
# P1 — baseline counts (postgres role, read-only)
# P2 — identities: platform_config owner id, demo org resolves, partner memberships
# P3 — partner RLS-gated read surface (authenticated impersonation, RLS counts)
# P3b — storage.objects count through the storage policy as the partner
# P4 — matter write demo: create_matter → §8 audit row observed in-txn → ROLLBACK → residue check
# P5 — message send demo: send_message → message RLS-visible in-txn → §8 audit row → ROLLBACK → residue check
# P6 — org-audit view: read_org_audit latest rows (the OrgAuditScreen path)
# P7 — F-01 invariant: platform-owner id in 0 assignment columns (battery-12 mirror)
```

## 1. Baseline (P1, postgres role)

| Surface | Count |
|---|---|
| `matters` | 6 |
| `documents` | 4 |
| `message_threads` | 4 |
| `messages` | 12 |
| `files` | 4 |
| `storage.objects` | 4 |
| `billing_invoices` | 4 |
| `audit_events` | 13 |

Identities (P2): `platform_config.owner_user_id` = `9acfd3b4-96c6-4836-aaa7-defd7864cefb`; demo org `ef43087b-…` resolves (1); partner has **2** active memberships.

## 2. Partner read surface (P3/P3b, RLS counts)

| Surface | Partner view | Note |
|---|---|---|
| `organizations` | 2 | active-member gate |
| `memberships` | 2 | org roster |
| `matters` | **5** | 3 seeded (acquisition/lease/procedural) + `d28f1f05-…` (F-01 apply create) + `4a8425d4-…` (D-45.1 create) — both live creates assigned attorney = partner. Family matter absent (client-only, as designed). |
| `documents` | 3 | matters 1–3 |
| `message_threads` | 3 | matters 1–3 |
| `messages` | 8 | 6 seeded (1+2+3) + the two live sends (`7cbf49e0-…` realtime, `1c031882-…` audited RPC) |
| `files` | 3 | metadata rows |
| `storage.objects` | 3 | bytes via the two-layer storage policy |
| `billing_invoices` | 3 | `INV-2026-0001..0003`; family `0004` absent |

All counts match the checklist's gate contract (the `matters 3→5` and
`messages 6→8` deltas are the two audited live writes since the checklist
was drafted — expected, recorded in `docs/current_applied_surface_2026-08-08.md`
addenda and the F-01 execution records).

## 3. Matter write — transactional demo, rolled back (P4)

As the partner, the exact `create_matter` call the configured build's
`SupabaseMatterWriteApiImpl` makes — observed **inside the transaction**,
then rolled back:

```
┌──────────────────────────────────────┬───────────────┬────────────────┐
│ new_id                               │ audit_action  │ audit_summary  │
├──────────────────────────────────────┼───────────────┼────────────────┤
│ ea82781b-5fc1-46b0-8c89-45d1acd55da8 │ matter:create │ matter created │
└──────────────────────────────────────┴───────────────┴────────────────┘
```

- The §8 `matter:create` / `matter created` row (redacted — never the
  title) is visible to the partner through `read_org_audit` in the same
  transaction.
- `ROLLBACK` → residue check: `matters` back to **6**; no new matter and
  no new audit row persisted.

## 4. Message send — transactional demo, rolled back (P5)

As the partner, `send_message` on the acquisition thread
`5d148bca-d784-4c21-81a1-1646c6754e2a` (matter `a6715e17-…`, assigned
attorney = partner) — before/after in one transaction:

```
┌────────────┬──────────────────────────────────────┬───────────┬───────────────┐
│ before_cnt │ new_id                               │ after_cnt │ visible_after │
├────────────┼──────────────────────────────────────┼───────────┼───────────────┤
│ 8          │ 61b81491-5704-48aa-b75e-f2b7750a42bd │ 9         │ 1             │
└────────────┴──────────────────────────────────────┴───────────┴───────────────┘
```

- The message is **RLS-visible to the partner immediately after the send**
  (8 → 9, the new body found: `visible_after = 1`) and audited
  (`message:create` / `message sent`, redacted — never the body).
- `ROLLBACK` → residue check: `messages` back to **12**; no new message or
  audit row persisted.
- (A first probe read `messages_in_txn = 8` before the send ran — a
  PostgreSQL InitPlan-timing artifact: the non-correlated count subquery
  executes at query start, before the FROM clause's function call. The
  before/after probe above is the corrected measurement.)

## 5. Org-audit view (P6, the OrgAuditScreen path)

`read_org_audit('ef43087b-…')` as the partner, latest 6:

```
│ action                      │ outcome │ resource_type │ resource_id                          │ redacted_summary                                  │
│ audit:read_org              │ allowed │ audit_events  │ NULL                                 │ org audit rows read by partner                    │
│ audit:read_org              │ allowed │ audit_events  │ NULL                                 │ org audit rows read by partner                    │
│ matter:create               │ allowed │ matter        │ 4a8425d4-5d67-4422-b371-359c9696d65a │ matter created                                    │
│ matter:assignee_remediation │ allowed │ matter        │ a6715e17-15a6-4456-96e3-78fc56630cfe │ assigned client corrected (demo data remediation) │
│ matter:create               │ allowed │ matter        │ d28f1f05-f95f-46ea-9b15-767f15778c01 │ matter created                                    │
```

- The full F-01 chain is visible in the org audit: the F-12 remediation
  row (`a6715e17-…`), the apply-session create (`d28f1f05-…`), and the
  D-45.1 create (`4a8425d4-…`).
- **Audited reads confirmed:** the walkthrough's own `read_org_audit`
  calls write `audit:read_org` rows — by design (§8 contract); the
  surfacing the client ships as-is (C-D7).

## 6. F-01 invariant — battery-12 mirror on dev (P7, postgres role)

The platform-owner id (derived from `platform_config`, the same derivation
battery 12 and the F2-D2 gate use) in every content-table position:

```
│ owner_user_id                        │ matters_assignments │ documents_owner_refs │ threads_owner_refs │ files_owner_refs │ messages_owner_refs │ invoices_owner_refs │
│ 9acfd3b4-96c6-4836-aaa7-defd7864cefb │ 0                   │ 0                    │ 0                  │ 0                │ 0                   │ 0                   │
```

The owner id appears in **no** matter assignment column and **no**
content-table uuid column — the F-01 invariant holds live on the dev
project (F-12 remediation intact).

## 7. Verdict + honest residuals

- **PASS:** every configured-build surface round-tripped the live dev
  project — partner read surface exactly as gated (matters/documents/
  threads/messages/files/storage/invoices/orgs), the audited matter-write
  and message-send RPCs work and are RLS-visible, the org-audit view shows
  the full F-01 chain, and the F-01 invariant holds in the live data.
- **Residue:** the two write demos left **zero content residue** (both
  rolled back, counts verified). The only delta vs. baseline is **+1
  `audit:read_org` row** from the walkthrough's own committed org-audit
  read (13 → 14) — an audited read, by design, not a data change.
- **Honest residuals:** (a) no emulator/device UI pass — the checklist's
  owner-side device steps (§3/§5 of
  `docs/configured_build_e2e_checklist_2026-08-08.md`) remain the
  UI-driving complement; (b) the demo matter `4a8425d4-…` and its audit
  row persist (created by the D-45.1 verification — demo rows, by design);
  (c) the client-role positive path stays undemoable (no client membership
  rows — F-09 deliberately skipped per owner decision 2026-08-09).
- **Redaction:** no PII-shaped value appears in this evidence — all ids
  are demo ids; audit summaries are the fixed redacted strings; the demo
  write titles/bodies are generic. No credentials were used or recorded
  (the runner used the CLI's Management API token, not a DB password).
