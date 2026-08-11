# LegalHub — Current Applied Surface (single source of truth, 2026-08-08)

> **Purpose:** one page describing exactly what is live on the shared dev
> project (`eutmvevpskerzpqmwplv`, `eu-central-1`) as of the **last apply
> (billing, `fc7ed1b`, 2026-08-08 21:31)**. Every number is cross-referenced
> to the ten apply-execution records below — the harness/CI pins
> (`scripts/verify_policy_tests.sh` `--check` **73/0/0** — corrected count,
> register §3b) pin the same set
> on a fresh scratch stack. This note is the reference for configured-build
> E2E (D-45.1) and any future slice.

## 1. Final state (post-billing apply)

| Surface | Count / set | Evidence |
|---|---|---|
| **Tables (public)** | **12 / 12 RLS** | `profiles` · `organizations` · `memberships` · `invitations` · `audit_events` · `platform_config` (P2 base) + `matters` (04) + `documents` (05) + `message_threads` (06) + `files` (07) + `messages` (08) + `billing_invoices` (10). Harness pin "twelve public tables present" + "RLS enabled on all twelve". |
| **Policies** | **11 public + 1 storage** | Public: `profiles_select_own` · `profiles_update_own` · `organizations_select_active_member` · `memberships_select_org_roster` · `invitations_select_partner` (P2) + `matters_select_assigned` (04) + `documents_select_assigned` (05) + `message_threads_select_assigned` (06) + `files_select_assigned` (07) + `messages_select_assigned` (08) + `invoices_select_assigned` (10). Storage: `storage_objects` policy (07). **`messages_insert_assigned` dropped** by the send-message D-SM3 revocation — all writes go through the audited RPC. |
| **RPCs** | **19 EXECUTE** (anon false) | 17 P2 RPCs + `list_org_members_metadata` (Phase 3 R1) + `send_message` (audited, D-SM3; §8 audit by construction). Harness RPC-EXECUTE pin = 19. |
| **Publication** | **exactly `public.messages`** | `supabase_realtime` — nothing else (D-LV2/D-P0C1(b)). |
| **Bucket** | **`matter-files` (1)** | `storage.objects` rows for the 4 demo files; no other bucket. |
| **Demo rows** | 4 matters · 4 documents · 4 threads · **12 messages** · 4 files + 4 objects · 4 invoices | Counts below (§2). |

## 1a. Addendum (2026-08-09 — F-01 step 2 matter-write apply)

| Surface | Before → After | Evidence |
|---|---|---|
| **RPCs** | **19 → 20 EXECUTE** (anon false) | `create_matter(uuid, text, text, uuid, uuid)` added (audited, F2-D1/D2/D4; §8 by construction). Harness RPC-EXECUTE pin 19 → 20 (`docs/matter_write_apply_execution_2026-08-09.md` §2.1). |
| **Trigger (not a policy)** | **new** — `refuse_platform_owner_assignment` `BEFORE INSERT OR UPDATE` on `matters`, EXECUTE-revoked | The categorical F-01 owner-assignment guard (`docs/matter_write_apply_execution_2026-08-09.md` §2.2). **Policies row unchanged** (11 public + 1 storage — the trigger is a data-layer mechanism, no RLS arm, no R-4 probe widening). |
| **Demo matters** | 4 → **5** | The first §8-audited live matter write `d28f1f05-f95f-46ea-9b15-767f15778c01` (via the RPC as the demo partner; §2 below). **F-12 RESOLVED 2026-08-09:** the pre-existing matter `a6715e17-…` carried the platform-owner id as `assigned_client_id` (seeded 2026-08-07, pre-F-01) — re-assigned onto the demo client (`0c54d251-…`) with a machine audit row; **the owner id now appears in no assignment column** (`docs/f12_data_remediation_2026-08-09.md`). |
| **Matter write path** | none → **audited RPC + categorical trigger** | `create_matter` is the ONLY matter-write surface (no INSERT/UPDATE grants to clients); every create §8-audited. |

## 1b. Addendum (2026-08-11 — notification-feed read apply)

| Surface | Before → After | Evidence |
|---|---|---|
| **Tables (public)** | **12 → 13** / RLS 12 → 13 | `notifications` added (`14_notifications.sql`): `id` PK · `organization_id` FK → organizations, cascade · `category` CHECK (`appointment`/`activity`/`system`, D-N4) · `type` · `summary` (synthetic-only by convention, D-N3) · `server_timestamp` (server clock) · `is_read` (display metadata only, D-N6) + composite index `notifications_org_ts`. **Redaction structural (T1 Q1): no user-identity / content / raw-text column** — PII *cannot* be stored (`docs/notification_feed_apply_execution_2026-08-11.md` §2.1). |
| **Policies** | **11 public → 12** (+ 1 storage unchanged) | `notifications_select_org` — the single SELECT policy, organizations-gate (`is_active_member(organization_id)`), **no write policies** (D-N2/D-N6); auth SELECT granted, anon denied (`docs/notification_feed_apply_execution_2026-08-11.md` §2.2/§4). |
| **RPCs** | **20 → 20 EXECUTE** (unchanged) | **No new RPC** — direct PostgREST read (T1 Q5). Harness RPC-EXECUTE pin stays 20. |
| **Publication** | unchanged — exactly `public.messages` | The feed is not realtime; no publication change (T1 Q4/Q5). |
| **Bucket** | unchanged — `matter-files` (1) | Untouched. |
| **Demo rows** | 0 notification rows | No seed on the dev project (D-N7 — feed empty pre-producer; synthetic rows arrive with the T8 client swap's fake gateway or a future producer slice). Live positive = 0 rows; anon denied at the privilege layer. |

## 1c. Addendum (2026-08-11 — notification producer apply)

| Surface | Before → After | Evidence |
|---|---|---|
| **Functions (mechanism, not a policy)** | **new** — `mirror_audit_to_notifications()` `AFTER INSERT` trigger on `audit_events`, **EXECUTE-revoked** | The audit-mirror producer (D-P1): maps `matter:create`/`message:create` + `outcome='allowed'` audit rows into org-scoped `notifications` rows with **fixed D-P3 summaries** (`Demo notification — matter created` / `new message in thread` — never the matter title / message body). `15_notification_producer.sql` (`docs/notification_feed_producer_apply_execution_2026-08-11.md` §2.1). **Tables/policies row unchanged** (13/13/12 — the trigger is a data-layer mechanism, no RLS arm, D-P5; the F-01 11_matter_write precedent). |
| **RPCs** | **20 → 20 EXECUTE** (unchanged) | No new RPC — the producer is trigger-invoked only; `has_function_privilege('authenticated', 'mirror_audit_to_notifications()', 'EXECUTE')` = **false** and anon = **false** (D-P4, the write_audit precedent; verified live §2.1). |
| **Tables (public)** | **13 / 13 RLS — unchanged** | No table change; `notifications` stays read-only for clients (no write grant of any kind). |
| **Policies** | **12 public + 1 storage — unchanged** | The producer is not a policy; `notifications_select_org` remains the sole feed gate. |
| **Publication** | unchanged — exactly `public.messages` | Untouched. |
| **Demo rows** | 0 notification rows (unchanged) | The apply adds no rows; the live smoke ran **in-transaction** (partner `create_matter` → produced org feed row visible via RLS → `ROLLBACK`, **zero residue** — D-P6 atomicity live, execution record §3.2/§3.3). The dev feed fills only with real event traffic after this apply. |

## 1d. Addendum (2026-08-11 — client-side RPC-binding await-contract fix; NO server change)

| Surface | Before → After | Evidence |
|---|---|---|
| **Client bindings** | 4 `*ApiImpl._boundRpc` production bindings corrected | postgrest 2.8.0 resolves `await client.rpc<T>()` to the **raw decoded data** (`T`), not a `PostgrestResponse` — the bindings' `as PostgrestResponse<dynamic>` cast crashed on-device with `type 'String' is not a subtype of type 'PostgrestResponse<dynamic>'` on the create-org flow (scalar-returning RPCs: `create_organization`/`create_matter`/`send_message`, all `returns uuid`). Fixed by wrapping the raw value in the seam's `PostgrestResponse(data:…, count: 0)` shape; `PostgrestException` propagation unchanged (`f1308cd`: org/messaging/matters/admin impls + a 3-test regression-pin suite against a real `SupabaseClient` + mocked HTTP + `http` dev dep + README count 1300→1303). **No server file touched — the applied surface below is unchanged.** |
| **Server surface** | **13/13/12+1 / 20 RPC-EXECUTE — unchanged** | The fix is client-side; the RPCs, policies, and grants were already correct (the server returned the right scalars all along — the org was created server-side even on the crashed attempt). |
| **Live verification** | `docs/rpc_binding_fix_verification_2026-08-11.md` | All three RPC paths exercised live on the dev project (in-transaction, rolled back, **zero residue**): `create_organization` → `8adb8533-…` · `create_matter` → `5974a3de-…` · `send_message` → `52a5cba7-…` — each a raw uuid scalar with its audit row, matching the shape the fixed bindings now consume. |

## 2. Demo rows (org `ef43087b-adf4-4480-9bb2-28c26f46ec71`, generic only — no real PII)

| Kind | Rows | Anchors |
|---|---|---|
| Matters | 4 | `a6715e17-…` acquisition · `d155dc92-…` lease · `4f4a935f-…` procedural · `575391b6-…` family |
| Documents | 4 | on the 4 demo matters (05 seed) |
| Threads | 4 | `5d148bca-…` (acq, count 1) · `a8fd025e-…` (lease, 2) · `d0904762-…` (proc, 3) · `4a8755b1-…` (family, 4) |
| Messages | **12** | 10 seeded (08) + live send `7cbf49e0-…` (realtime-push) + audited RPC send `1c031882-…` (send-message) — tally 12 per the send record |
| Files + objects | 4 + 4 | storage_path == object name, generic names (07 seed) |
| Invoices | 4 | `INV-2026-0001..0004` on the 4 demo matters, org = matter org (10 seed) |

Demo accounts: partner `8fa94af0-7390-4f7a-988a-3965f7da04de` (active member, 2 orgs) + assigned
clients `9acfd3b4-…`, `187fc8d6-…`, `0c54d251-1cdd-…` (**no membership rows** — the membership guard
deliberately denies them; recorded as designed, never a defect).

## 3. Apply chronology (the ten execution records)

| # | Apply (commit) | What went live | Final count after |
|---|---|---|---|
| 1 | matters `7d0fbfe` (08-07) | `04_matters` + policy + 4 matters | 7 tables / 6 policies |
| 2 | documents `f500095` (08-08 00:11) | `05_documents` + policy + 4 docs | 8 tables / 7 policies |
| 3 | messages `a14650d` (08-08 01:19) | `06_message_threads` + policy + 4 threads | 9 tables / 8 policies |
| 4 | realtime-read `35cceb9` (15:19) | `08_messages` + policy + 10 messages | 10 tables / 9 policies |
| 5 | realtime-push `7efb32b` (16:07) | `09_realtime_push` + `messages_insert` + live send | 10 tables / 10 policies |
| 6 | send-message `031ebdc` (18:14) | `send_message` RPC + D-SM3 (drop `messages_insert_assigned`) + audited send | 10 tables / 9 policies |
| 7 | storage `e9a02ac` (18:36) | `07_storage` (bucket + files) + 2 policies + 4 files/objects | **11 tables / 10 public + 1 storage** |
| 8 | billing `fc7ed1b` (21:31) | `10_billing_invoices` + `invoices_select_assigned` + 4 invoices | **12 tables / 11 public + 1 storage** |
| 9 | F-01 step 2 `f2e88cc` (08-09) | `create_matter` RPC + `11_matter_write` trigger + demo create `d28f1f05-…` | **12 tables / 11 public + 1 storage / 20 RPC-EXECUTE** (trigger is not a policy) |
| 10 | notification-feed `e21f9dd` (08-11) | `14_notifications` + `notifications_select_org` (single SELECT, org gate) + harness re-scope 13/13/12 | **13 tables / 12 public + 1 storage / 20 RPC-EXECUTE unchanged** (no new RPC, T1 Q5) |
| 11 | notification producer `8dd23c1` (08-11) | `mirror_audit_to_notifications` function + `audit_events_mirror_notifications` trigger (EXECUTE-revoked; **mechanism only**, no table/policy/RPC change) | **13 tables / 12 public + 1 storage / 20 RPC-EXECUTE unchanged** (D-P5 — trigger is not a policy) |
| 12 | RPC-binding fix `f1308cd` (08-11) | **client-side** postgrest await-contract fix in the 4 `*ApiImpl._boundRpc` bindings (the create-org on-device crash; root cause + verification in §1d) + regression-pin suite + verification `d26aef7` | **Server surface unchanged** — 13 tables / 12 public + 1 storage / 20 RPC-EXECUTE (the fix corrected how the client awaits RPC responses, not what the server exposes) |

> **Baseline-count honesty:** storage's §0 note explicitly records that its
> approval's "8 → 9 policies" baseline was written before the realtime-push
> + send-message applies and gives the true pre-apply state (**10 tables /
> 10 RLS / 9 public / 0 storage**). The send-message + realtime-push
> records originally carried spurious **"11 tables / 11 RLS"** lines in
> their §5 (the true count at 16:07–18:14 was **10 tables** — `files`
> landed at 18:36 with storage); those lines were corrected to 10 in the
> source records, and the billing record's one-segment client-UUID typo
> (`0c54d251-6b23-…` → `0c54d251-1cdd-…`) was corrected — this note's
> chronology is authoritative.

## 4. Cross-references

- Execution records: `docs/matters_apply_execution_2026-08-07.md` ·
  `documents_apply_execution_2026-08-07.md` · `messages_apply_execution_2026-08-07.md` ·
  `realtime_apply_execution_2026-08-08.md` · `realtime_push_apply_execution_2026-08-08.md` ·
  `send_message_apply_execution_2026-08-08.md` · `storage_apply_execution_2026-08-08.md` ·
  `billing_invoices_apply_execution_2026-08-08.md` (+ P2-era: `p2_apply_execution_2026-08-01.md`,
  `p2_hardening_apply_execution_2026-08-03.md`).
- Harness pins: `scripts/verify_policy_tests.sh` §1a (12 tables / 12 RLS), §1d (**20 RPC-EXECUTE** — 19 + `create_matter`, 2026-08-09 addendum),
  §1e (11 public + 1 storage), §1g (publication exactly messages, bucket).
- Rehearsal evidence (the same set, scratch stack): r1 records per slice.
- Not live by design: AI (deferred, D-07/D-08) · storage write/download (D-STR9) · billing
  write/Paymob (D-11) · any `lib/` change needs a configured build (`.env`, git-ignored) to
  exercise this surface end-to-end (D-45.1).

## 5. Owner-side notes

- **Configured-build E2E (D-45.1)** remains the only un-executed verification: the 12-table /
  11-policy / **20-RPC** surface above is battery-proven and smoke-proven via role-impersonated
  SQL, but no `.env` build has round-tripped it from the app (the 2026-08-09 addendum moved the
  RPC count 19 → 20).
- **F-12 RESOLVED (2026-08-09):** the demo matter `a6715e17-…` had carried the platform-owner
  id as `assigned_client_id` (seeded 2026-08-07, pre-F-01); re-assigned onto the demo-client
  account with a machine audit row — **the owner id now appears in no assignment column**
  (`docs/f12_data_remediation_2026-08-09.md`).
- The demo **clients** have no membership rows — add them (a deliberate data action) if a
  client-side demo wants the assigned-client positives live.
