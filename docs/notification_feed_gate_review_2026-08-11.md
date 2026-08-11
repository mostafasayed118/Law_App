# LegalHub — Notification-Feed RLS-Gate / Mechanism Review (2026-08-11)

> **Record type:** RLS-gate design review (the T1 gate) for the
> **notification-feed read slice** — the first slice of the 2026-08-11
> planning program, following the `docs/p2_schema_rls_design.md` §8 Q1–Q6
> pattern and the nine read-slice precedents (matters → billing
> invoices, all SHIPPED 2026-08-07/08 — applied + client-swapped).
> **Docs + rehearsal-ready artifacts only — NOT applied:** nothing here
> touches the dev project until the owner's dated apply-approval
> (INSTRUCTIONS.md §2.1/§5 hard gates).
>
> **Status: REVIEWED 2026-08-11 (decision-level).** Scope:
> `docs/notification_feed_scope_2026-08-11.md` (**DECIDED 2026-08-11** —
> D-N1…D-N7 ratified; new surface authorized). Plan:
> `docs/notification_feed_slice_plan_2026-08-11.md` (step 0 MET). The
> artifacts (`14_notifications.sql` + `.down` + `policies/notifications.sql`)
> are **the next pipeline step (T3)** — this review gates their shape.
> **Owner:** Project Owner (github.com/mostafasayed118). **Governed by:**
> the ratified scope note (D-N1…D-N7) · `docs/permission_matrix.md` §4/§7
> (the addendum discipline; notifications are org metadata, the
> organizations-gate pattern) · `docs/features_roadmap_2026-08-03.md`
> line 484 (no delivery in v1) · `docs/rollback_plan.md` ·
> `docs/p0_closure_scope_2026-08-05.md` (D-P0C1(a) deny-row discipline) ·
> `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Precondition (scope note → this slice) | Status |
|---|---|
| Scope ratified (the NEW-surface gate, D-N1) | ✅ **DECIDED 2026-08-11** — `docs/notification_feed_scope_2026-08-11.md` (D-N1…D-N7); the slice plan's step 0 MET |
| No-provider precondition (read-only v1) | ✅ D-N2 — no push/FCM/device delivery; no provider decision needed (roadmap line 484) |
| Nine shipped precedents (the discipline chain ran green nine times) | ✅ **SHIPPED 2026-08-07/08** — matters / documents / messages / storage / audit / realtime read / realtime push / audited send / billing invoices — all applied + battery r1 PASSED + matrix addenda + client swaps |
| Signed matrix governs the grant (positive + negative) | ✅ `docs/permission_matrix.md` §4 org-metadata rows (the organizations-gate cell split) + §7 addendum discipline |
| Harness baseline (the pins this slice re-scopes) | ✅ 12 tables / 12 RLS / 11 public + 1 storage policies / publication exactly `public.messages` / 19–20 EXECUTE RPCs / batteries 01–13 (current applied surface, verified 2026-08-11) |
| RLS-gate review (this record) | ✅ Answered 2026-08-11 (§3 Q1–Q6) |
| Rehearsal-ready artifacts (T3) | ⏳ Next step — the review's shape (§3) is the artifact contract |
| Rollback pairing | ⏳ `supabase/migrations/14_notifications.down.sql` + git-revert policy pairing (drafted with T3) |
| Dated matrix addendum **before** the client surface ships | ⏳ T6 of the plan (after apply, before T7) |
| Dated apply-approval | ⏳ T5 — owner-gated; nothing applied until then |

**Conclusion:** the decision-level preconditions are satisfied (scope
DECIDED, no-provider gate MET, nine shipped precedents, the harness
baseline pinned). The schema shape below is the **artifact contract**;
no execution claim is made — the first SQL execution is the
battery/rehearsal (T3/T4) on a Postgres-capable environment (the
established owner's-host precedent).

## 2. Scope

**In scope (read-only feed):** a `public.notifications` metadata table
(D-N3 row shape), a single org-scoped SELECT policy (D-N2 read-only),
and the client read surface behind the env-gated `NotificationGateway`
seam. **Explicitly out:** push/delivery (D-N2), prefs filtering (D-N5),
read-flag writes (D-N6), any user-identity/content column (D-N3
redaction), any INSERT/UPDATE/DELETE path in this slice.

## 3. Q1–Q6 (the p2_schema_rls_design §8 pattern)

### Q1 — Is the redaction posture structural? (D-N3)

**Yes.** The table has **no user-identity column, no content column, no
raw-text column** — only `category`, `type`, `summary` (synthetic demo
copy, never PII), `server_timestamp`, `is_read` (default `false`), and
the org FK. The redaction constraint is **made structural**: the table
*cannot* hold message bodies, document names, or PII field names —
mirroring how D-BI1 made the D-11 PCI constraint structural for
invoices. `summary` is CHECK-free text but its producers (the demo seed,
the fake) are synthetic-only by contract (D-N7).

### Q2 — Is the org gate the right grant? (the feed is org-scoped, not matter-scoped)

**Yes.** Notifications are **org metadata**, not matter content — every
active member of the org reads the org's feed. The gate is the proven
**organizations-gate** (`is_active_member(organization_id)`), the same
predicate the org-audit / member surfaces use — **not** the
matter-assignment exists-subquery (which would wrongly hide org-wide
system notifications from members not assigned to the triggering
matter). Cross-org and non-member reads are denied by the predicate;
anon is denied by the same `auth.uid() IS NOT NULL` footing as every
shipped policy.

### Q3 — Matrix row + cell split (T6 addendum contract)

"View notifications (metadata)" — **member SHIP** behind
`notifications_select_org`; non-member deny; `platform_owner_admin`
**deny-always posture** (D-P0C1(a)); partner role reads the same as any
active member (the organizations-gate posture — no role hierarchy in the
feed). No write cells in v1 (D-N2/D-N6).

### Q4 — No write path, no delivery — is the slice's read-only posture clean?

**Yes.** The slice adds **one SELECT policy only**: no INSERT/UPDATE/
DELETE, no read-flag RPC, no publication change, no triggers. `is_read`
is **display metadata only in v1** (seeded `false`, never mutated) —
a future read-flag slice adds its own policy + RPC under the same
discipline. Delivery (push) stays out entirely (D-N2, roadmap line 484)
— nothing in this slice can reach a device.

### Q5 — Read path: RPC or direct PostgREST?

**Direct PostgREST read** (no new RPC) — the matters/documents read
posture: the policy gates the table directly, newest-first ordering is a
query concern, and the matrix row is the SELECT cell. A read RPC adds a
surface with no new capability; it is avoided per the "smallest safe
change" rule. (If a future slice needs event-filtering or pagination
semantics the read RPC is a separate, reviewed addition.)

### Q6 — Harness re-scope + rollback (T3/T4/T5 contract)

- Table/RLS: 12 → **13**; public policies 11 → **12**; storage
  unchanged; publication **unchanged** (exactly `public.messages`);
  batteries 01–13 → **01–14** (`14_notification_rls.sql` — member
  positive / non-member denied / cross-org denied / anon denied /
  category-CHECK violation / org-cascade).
- Rollback: `14_notifications.down.sql` (drop policy + table) + the
  git-revert policy pairing; the harness `--check` must return to
  12/12/11+1/batteries-01–13 exactly.

## 4. Verdict

**REVIEWED 2026-08-11 — the shape is approved at the decision level.**
The org-scoped, redaction-structural, read-only design satisfies D-N2…
D-N7 with the smallest safe surface (one table, one policy, no RPC, no
writes). The T3 artifacts must match this contract: `14_notifications.sql`
+ `.down` + `policies/notifications.sql`, battery `14_notification_rls.sql`,
harness re-scope 13/13/12+1/batteries-01–14. No execution claim — the
next gate is the artifact draft (T3) and the static `--check`.
