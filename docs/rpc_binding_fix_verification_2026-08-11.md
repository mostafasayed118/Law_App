# LegalHub — RPC-Binding Fix: Post-Apply Verification Evidence (2026-08-11)

> **Record type:** verification evidence for the on-device crash fix
> `f1308cd` (`fix(data): correct the postgrest rpc await contract in the
> production bindings`) — the `type 'String' is not a subtype of type
> 'PostgrestResponse&lt;dynamic&gt;'` crash on the create-org flow. This
> records the **live server round-trips of the three RPCs the fixed
> bindings call** — `create_organization`, `create_matter`,
> `send_message` — executed against the shared dev project
> (`eutmvevpskerzpqmwplv`, `eu-central-1`) on 2026-08-11, plus the
> response-shape chain that closes the crash class.
>
> **Status: VERIFIED 2026-08-11.** All three RPC paths return raw uuid
> scalars through the partner-impersonated path, each audited and rolled
> back with **zero residue**; the Dart-side await contract is pinned by the
> regression suite (`test/data/orgs/supabase_rpc_await_contract_test.dart`,
> committed in `f1308cd`). The interactive device pass (owner's emulator/
> device) stays owner-reserved per the D-45.1 checklist posture.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. What the fix changed and why this verification matters

The four `*ApiImpl._boundRpc` production bindings previously cast the
awaited `rpc<dynamic>()` value to `PostgrestResponse<dynamic>`. In
postgrest 2.8.0 the awaited value is the **raw decoded data** (`T`), so a
scalar-returning RPC (`returns uuid`) crashes the cast — the exact
on-device failure. The fix wraps the raw value in the seam's
`PostgrestResponse(data:…, count: 0)` shape. This verification proves the
server half produces exactly the shape the fixed binding now consumes: a
PostgREST JSON string scalar (`"uuid"`) for every one of the three RPCs.

## 2. Live RPC round-trips (dev project, in-transaction, rolled back)

Method: `supabase db query --linked` (Management API SQL runner), the
house role-impersonation pattern — `set local role authenticated` +
`request.jwt.claims` with the demo partner
`8fa94af0-7390-4f7a-988a-3965f7da04de`, every call inside
`begin; … rollback;`, audit reads as the privileged role (D-P0C4 — never
a raw client SELECT on `audit_events`).

| Probe | RPC (client binding) | Returned scalar (uuid) | Audited | Residue |
|---|---|---|---|---|
| P1 | `create_organization('rpc-fix-probe-org')` (`SupabaseOrgApiImpl.createOrganization` — **the crash site**) | `8adb8533-3044-499d-a4e1-303038aef09c` | `organization:create` / `allowed` — "org created; creator made partner" | 0 (org not present after rollback) |
| P2 | `create_matter(org, 'rpc-fix-probe matter', 'corporate', null, partner)` (`SupabaseMatterWriteApiImpl.createMatter`) | `5974a3de-c001-4389-b152-fac76341d558` | `matter:create` / `allowed` (in-txn) | 0 (matter not present after rollback) |
| P3 | `send_message(thread 5d148bca-…, 'rpc-fix-probe message — must never leak')` (`SupabaseMessageApiImpl` — the D-SM1 gate: partner is the assigned attorney on the acquisition matter) | `52a5cba7-3c52-457c-92ba-55cc1d50d344` | `message:create` / `allowed` (in-txn) | 0 (message not present after rollback) |

Residue probe (post-rollback, privileged):

```
orgs = 3 · matters = 6 · messages = 12 · notifications = 0
org_probe_residue = 0 · matter_probe_residue = 0 · msg_probe_residue = 0
```

The dev DB returned to its exact pre-probe state — the same counts as the
applied-surface §2 tally (12 messages = 10 seeded + 2 live sends).

## 3. The response-shape chain (why the crash class is closed)

1. PostgREST wraps each `returns uuid` RPC response as a JSON string
   scalar — `"<uuid>"` (verified live: the three probes above each
   returned exactly one uuid value).
2. postgrest 2.8.0's `_parseResponse` returns the raw decoded body as `T`
   when no count is requested → `await client.rpc<dynamic>(...)` yields
   the `String` id (pinned by the regression suite against a real
   `SupabaseClient` + mocked HTTP: scalar → raw String, set → raw List,
   non-2xx → `PostgrestException`).
3. The fixed `_boundRpc` wraps that raw value →
   `PostgrestResponse(data: <uuid>, count: 0)` → the impl methods read
   `.data` == the id exactly as before.

The crash (`String is not a PostgrestResponse`) is impossible on this
path: the awaited value is never cast to a response wrapper anymore.

## 4. Observed concurrent activity (honest note)

During this verification the dev audit tally moved from 16 → 29. The new
rows (ids 32–47, 10:48–10:53 UTC) are **live app usage from the owner's
configured build** — `partner:list_org_members` (roster reads),
`audit:read_org` (org-audit screen), `invitation:create` (an invite
issued), `membership:role_change` (partner → partner) — all audited
through the shipped gates, consistent with the app running post-fix.
**None of these came from these probes** (all three rolled back; probe
residues zero). The prior external `organization:create` ("jxjx",
10:37 UTC — the crash-era attempt that succeeded server-side) is the same
owner-session activity documented in the T8 walkthrough append. The
on-device create-org confirmation is the remaining interactive pass.

## 5. Boundary + ledger

- **Boundary:** this is the server-round-trip half. The client halves
  (screen → cubit → gateway → api impl wiring) are pinned by the suite:
  the org/gateway/cubit tests + the new await-contract suite. The
  interactive device pass stays owner-reserved per the D-45.1 checklist
  posture.
- **Gates at verification time:** format clean · `flutter analyze` **No
  issues found** · `flutter test` **1306 passing** (+3 pin tests) · ledger
  **PASS 115/0/0** · HEAD `f1308cd` (fix) + `e4c83ff` (producer records),
  pushed, origin/main == HEAD.
