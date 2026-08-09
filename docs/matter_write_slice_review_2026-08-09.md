# LegalHub — F-01 Step 2 Matter-Write Slice: Mechanism/RLS-Gate Review (2026-08-09)

> **Record type:** mechanism/RLS-gate review of the F-01 step 2 slice —
> `supabase/rpc/create_matter.sql`, `supabase/migrations/11_matter_write.sql`
> (+ `.down`), `supabase/tests/13_matter_write_rls.sql`, and the harness
> re-scope (§1c/§1d/§1e/§1f pins, apply order), per
> `docs/f01_step2_matter_write_design_2026-08-09.md` (F2-D1…F2-D5).
> **Status: PASS — two coverage findings (R-1, R-2) found and remediated
> within this review; the slice re-rehearsed 82/0/0 ×2 and is ready for the
> dated apply-approval gate.**
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Review basis:** the artifacts as committed to the working tree at HEAD
> `f16586e` + the uncommitted slice; every claim cross-checked against the
> permission matrix (`docs/permission_matrix.md`), the auth/tenant contract
> (`docs/auth_tenant_authorization_contract.md`), the applied surface
> (`docs/current_applied_surface_2026-08-08.md`), and the live rehearsal
> evidence (`docs/matter_write_slice_rehearsal_r1_2026-08-09.md`).

---

## 1. Scope and ground rules

Reviewed: the RPC's in-function gates, the categorical trigger, the battery's
coverage, and the RLS/policy-layer interplay. Ground rules applied:

- **R-4 (no probe-surface widening):** the slice must not add policy arms
  that let clients probe the owner capability. The trigger is a data-layer
  mechanism, **not** an RLS policy — no policy count change, no probe
  widening. (This is why F-01 step 3's explicit policy arm was dropped.)
- **D-08 (re-derive, never trust the arg):** the RPC re-derives membership
  server-side from `memberships`; the org id is a routing hint.
- **F-11 (self-scoped helpers):** the RPC deliberately queries
  `public.memberships` directly instead of `is_active_member()` (which is
  `auth.uid()`-self-scoped) for the *assignee* checks.
- **Contract §9:** every matrix/design row needs ≥1 positive + ≥1 negative.

## 2. Mechanism review (per gate)

| Gate | Mechanism | Verdict | Evidence |
|---|---|---|---|
| F2-D1 creator | `has_org_role(p_org,'partner')` → `active_membership` (filters `status='active'`, `auth.uid()`, SETOF zero-rows-on-no-match) | SOUND — suspended/removed members excluded; cross-org refused; generic `permission denied`, non-enumerating | 13.08 (client denied), 13.11 (cross-org denied), live; helper chain verified in `02_rls_functions.sql` |
| F2-D2 owner refusal | owner id **derived** from `platform_config` (self-updating, not hardcoded — the battery-12 pattern); both assignee columns checked; runs before the member checks | SOUND — constant, non-enumerating message; the Q4 residual state uncreatable through the RPC | 13.02 (owner as client), 13.03 (owner as attorney), live |
| F2-D3 categorical trigger | `BEFORE INSERT OR UPDATE` on `matters`, SECURITY DEFINER, `set search_path = public`; fires for the connection role (postgres bypasses RLS but **not** triggers — the "any path" claim); EXECUTE revoked from client roles | SOUND — narrow (owner-assignment only, demo-seed path viable); both INSERT and UPDATE arms; `.down` pairing verified | 13.04 (INSERT), 13.14 (UPDATE), 13.05/13.15 (narrowness), live; §1c pin `refuse_platform_owner_assignment denied` |
| F2-D4 assignee guard | direct `memberships` query, `status='active'`, both assignee slots | SOUND — dead assignments (non-member / suspended) refused; consistent with the read gate (`is_active_member(org) AND assignment`) | 13.09 (non-member), 13.10 (suspended), live |
| validation | title trimmed non-empty; `practice_area` left to the 04 CHECK (mapping contract) | SOUND — a bad enum raises the schema CHECK and maps to a generic client error | 13.12, live; 04 battery pins the CHECK |
| §8 audit | `write_audit` named args match the 02 signature; same implicit transaction (an audit failure rolls the create back); redacted summary `matter created` — never the title | SOUND — denied creates write nothing; allowed writes exactly one row | 13.06 (neg), 13.07 (pos, summary asserted), live |
| grants | `revoke … from public, anon`; `grant … to authenticated` | SOUND — anon refused at the privilege layer; authenticated EXECUTE pinned | 13.13, live; §1d `create_matter(uuid, text, text, uuid, uuid)` |

## 3. RLS-gate review (policy-layer interplay)

- **No new policies:** the public-policy total stays 11 (verified live in the
  rehearsal — §1e pin). The trigger is a trigger, not a policy: no client
  role can reach it (EXECUTE revoked), and it adds no query surface the
  client can probe.
- **Read-back consistency:** a created matter is readable by its assigned
  attorney under RLS (13.01 — the new row flows through the existing
  `matters_select_assigned` grant); an orphan matter is invisible to every
  role including its creator (13.16 — assignment-based read gate, the
  invoice-orphan 11 semantics). No disclosure path introduced.
- **`platform_config` reads** inside both definer bodies are RPC-only
  (D-P0C4: zero policies, no client grant — live §1b). The owner id never
  leaves the server.
- **Cross-tenant:** org is re-derived from the caller's membership; a
  partner of org-a cannot create in org-b (13.11). Audit rows carry the org
  id and are scoped by `read_org_audit` (partner-gated).

## 4. Battery coverage (contract §9)

16 check blocks map 1:1 onto the design claims — F2-D1 (13.01 pos, 13.08/13.11
neg), F2-D2 (13.02/13.03 neg), F2-D3 (13.04/13.14 neg, 13.05/13.15 pos), F2-D4
(13.09/13.10 neg), F2-D5 (13.16 pos), §8 (13.06 neg, 13.07 pos), validation
(13.12 neg), privilege layer (13.13 neg). Every row has ≥1 positive + ≥1
negative. Non-vacuity anchors: the happy path (13.01) re-reads the created
row through RLS; the trigger blocks run as the connection role so the
"any-path" claim is tested against a role that bypasses RLS.

## 5. Findings (found in this review — remediated in the same review)

- **R-1 (Medium — coverage): the trigger's UPDATE arm was unpinned.** The
  trigger is `BEFORE INSERT OR UPDATE`, but battery 13 pinned only the
  INSERT arm — a re-assignment UPDATE to the owner (the update path to the
  Q4 residual state) had no battery row. **Remediated:** 13.14 (UPDATE → owner
  refused) + 13.15 (UPDATE → non-owner succeeds, narrowness); the slice
  re-rehearsed 82/0/0 ×2 with them live.
- **R-2 (Low — coverage): F2-D5 (assignments nullable at creation) was
  unpinned**, yet the pending matrix §4 addendum will claim it. **Remediated:**
  13.16 (partner creates with null/null → orphan row, invisible to its
  creator under RLS); re-rehearsed with R-1.
- **Observations (no action, recorded):** the owner-refusal message constant
  is duplicated across the RPC and the trigger — acceptable because both
  battery paths assert the exact string, so a drift fails the battery; and
  both definer bodies use `select … limit 1` on `platform_config` — safe
  under the D-P0C3 single-row pin (verified live: exactly one row after
  fixtures).

## 6. Verdict

**PASS.** The mechanism is sound, the RLS interplay is clean (no probe
widening, no new policies, read-back consistent), and the battery now fully
pins the trigger contract and the design decisions. The slice is ready for
the next gate: **dated apply-approval (owner)** — the record is PREPARED
(`docs/matter_write_apply_approval_2026-08-09.md`, pending signature) →
apply to the dev project → dated matrix §4 addendum → env-gated client swap
(the app has no matter-creation surface yet — that swap is a separate
slice).

## 7. Scope notes

This review covers the server-side slice as rehearsed (working tree at HEAD
`f16586e` + uncommitted changes; evidence
`docs/matter_write_slice_rehearsal_r1_2026-08-09.md`, `--apply` 44/44,
battery **82/0/0 ×2**). It does **not** close the P4 gate — the controlled
rollout rehearsal and the dated release approval remain owner-gated — and it
makes no claim about the client side (D-45.1 E2E remains outstanding).
