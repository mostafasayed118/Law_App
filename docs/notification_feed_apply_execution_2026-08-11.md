# LegalHub — Notification-Feed Read Slice: Apply Execution Evidence (2026-08-11)

> **Record type:** execution evidence for the notification-feed read slice
> (`supabase/migrations/14_notifications.sql` +
> `supabase/policies/notifications.sql`), per
> `docs/notification_feed_apply_approval_2026-08-11.md` §3/§4. Mirrors the
> matter-write apply-execution record
> (`docs/matter_write_apply_execution_2026-08-09.md`) — the immediate
> precedent.
>
> **Status: APPLIED 2026-08-11 — up sequence complete and verified on the
> shared dev project** (`eutmvevpskerzpqmwplv`, `eu-central-1`): baseline
> probe → `14_notifications.sql` → `policies/notifications.sql` →
> post-apply structural + live smoke all verified. Rollback pairing
> standing by (`14_notifications.down.sql` — drop policy + table, the
> review Q6 contract verbatim — plus the git-revert policy pairing),
> **unexercised** (no trigger condition fired; never fix-forward). The
> owner's dated approval is recorded in
> `docs/notification_feed_apply_approval_2026-08-11.md` §6 (**APPLY
> APPROVED 2026-08-11**, signed in-session when the owner directed the
> apply execution). Nothing beyond the approval §3 scope was touched; the
> approval §5 exclusions hold.
>
> **No findings.** Unlike the matter-write apply (which surfaced the
> pre-existing F-01 owner-assignment demo-data issue), this apply surfaced
> nothing: the new table is empty by design (D-N7 — a producer slice seeds
> rows later), it carries no user-identity column (redaction structural),
> and no pre-existing state was touched.

---

## 0. Runbook (executed 2026-08-11 with these commands)

```bash
# 1. Baseline probe (read-only) — §1
supabase db query --linked "<probe SQL>"   # via the Management API, login role
# 2. Apply the table migration (approval §3.1)
supabase db query --linked --file supabase/migrations/14_notifications.sql
# 3. Apply the policy (approval §3.2)
supabase db query --linked --file supabase/policies/notifications.sql
# 4. Post-apply smoke + negative probes (approval §4.5)
```

Note: the local `supabase` CLI link had to be refreshed first
(`supabase link --project-ref eutmvevpskerzpqmwplv` → "Finished supabase
link.") — the link state did not survive the host restart; no schema
effect, purely the CLI connection metadata.

Rollback pairing standing by: `14_notifications.down.sql` (drop policy +
table) + `git revert` of the artifact commit — **never fix-forward**.

## 1. Baseline probe (read-only, before the up sequence)

| Check | Expected | Observed | Verdict |
|---|---|---|---|
| `notifications` table present? | **absent** | `0` | ✅ |
| tables with RLS | **12** | `12` | ✅ |
| `pg_policies` (public) count | **11** (unchanged by this apply) | `11` | ✅ |
| `pg_policies` (storage) count | **1** | `1` | ✅ |
| publication (`supabase_realtime`) | exactly `messages` | `1` | ✅ |
| `matter-files` bucket | present | `1` | ✅ |
| `platform_config` rows (D-P0C3) | exactly 1 | `1` | ✅ |
| active memberships on dev | resolve | `2` (the demo partner `8fa94af0-…`, active in both dev orgs) | ✅ |

All trigger conditions clean at the baseline; no STOP condition fired.

## 2. Up sequence (each step applied + verified)

### 2.1 `supabase/migrations/14_notifications.sql` — the table

`supabase db query --linked --file …/14_notifications.sql` → exit 0.
Verified immediately after:

```
│ table_present │ rls_on │ indexes │
│ 1             │ 1      │ 2       │      <- table exists, RLS on, PK + composite org_ts index
```

### 2.2 `supabase/policies/notifications.sql` — the org-gate SELECT policy

`supabase db query --linked --file …/policies/notifications.sql` → exit 0.
Verified immediately after:

```
│ notif_policies │ public_policies_total │ auth_select │ anon_select │ auth_insert │ auth_update │ auth_delete │
│ 1              │ 12                    │ true        │ false       │ false       │ false       │ false       │
```

Exactly the Q6 re-scope: 11 → **12** public policies (the one
`notifications_select_org`), SELECT granted to authenticated, **anon
denied, and NO write grant of any kind** (D-N2/D-N6 — the read-only
posture is enforced at the privilege layer).

## 3. Post-apply smoke (dev project)

### 3.1 Structural subset (the Q6 re-scope, live)

```
│ public_tables │ rls_tables │ public_policies │ messages_in_pub │ pub_total │ bucket │
│ 13            │ 13         │ 12              │ 1               │ 1         │ 1      │
```

**13 tables / 13 RLS / 12 public policies** — and the publication is
**unchanged** (exactly `public.messages`, count 1; nothing new exposed via
realtime), storage bucket intact. Matches the r1-rehearsed pins exactly.

### 3.2 Live positive — an active member reads the org feed

Impersonating the dev project's own active member (`8fa94af0-…`, partner,
active in both dev orgs) via `set role authenticated` +
`request.jwt.claims` (the battery's impersonation pattern, live):

```
│ member_read_count │
│ 0                 │      <- the grant + organizations-gate resolve; feed empty (no producer slice yet, D-N7)
```

### 3.3 Live negative — anon read denied

`set role anon; select count(*) from public.notifications;` →

```
ERROR: 42501: permission denied for table notifications
HINT:  Grant the required privileges to the current role with:
GRANT SELECT ON public.notifications TO anon;
```

Denied at the privilege layer (no grant), double-denied by the policy's
`auth.uid()` footing — the battery's 14.07 check, live.

## 4. Verification summary

| Approval §4 condition | Result |
|---|---|
| 1. Pre-up baseline probe | ✅ 0 table / 12 RLS / 11 public + 1 storage / publication exactly messages / bucket / D-P0C3 — all clean |
| 2. Dev-project-own rows in the smoke | ✅ the smoke uses `8fa94af0-…` (dev partner) + `ef43087b-…` (dev org) — no rehearsal synthetic ids |
| 3. Rollback pairing standing by | ✅ `14_notifications.down.sql` + git-revert pairing ready; **unexercised** (no trigger condition fired) |
| 4. Per-step verification | ✅ observed output captured after each step (§2.1/§2.2) |
| 5. Post-apply smoke | ✅ 13/13/12 + publication unchanged + live positive (member reads 0) + live negative (anon denied) |
| 6. No scope beyond the slice | ✅ only the two §3 files applied; no other table/RPC/policy/publication/storage change |

## 5. Findings

**None.** The apply surfaced no pre-existing issue (contrast with the
matter-write apply's §5 finding): the notifications table is new and empty,
carries no user-identity/content column, and no prior state was modified.
No rollback invoked.

## 6. Next steps (per the slice plan gate sequence)

- **T7:** dated `docs/permission_matrix.md` §4 addendum (the "View
  notifications (metadata)" row — member SHIP / non-member deny /
  `platform_owner_admin` deny-always, no write cells) + the applied-surface
  §6 addendum (13 tables / 13 RLS / 12 policies / RPC 20 → 20 unchanged —
  no new RPC, Q5).
- **T8:** the env-gated `NotificationGateway` swap + feed screen + home
  entry + tests, behind `env.isConfigured` (fake for demo runs).
- The battery remains ephemeral-only by design; the dev project's applied
  posture now matches the r1-rehearsed state (13/13/12+1).
