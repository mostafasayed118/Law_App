-- policies/invoices.sql — billing invoices read policy (REHEARSAL-READY — NOT applied, 2026-08-08)
-- Source of truth: docs/billing_invoices_real_data_plan_2026-08-08.md (D-BI2)
--                + docs/billing_invoices_gate_review_2026-08-08.md (§4 deny-rows).
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: an invoice METADATA row is readable iff the reader is an ACTIVE
-- MEMBER of the invoice's organization AND is assigned (client or
-- attorney) on the invoice's MATTER. This enforces the matrix §4 contract
-- exactly (invoices are matter content — the documents row's "restricted
-- matter or its documents/messages" reading, extended to invoices):
--   - "org role alone (no matter assignment)" -> deny, every role (the
--     exists subquery finds no assignment match);
--   - cross-org denied (is_active_member tests the invoice's org, and the
--     exists requires the matter's org to MATCH the invoice's org);
--   - suspended/removed memberships never authorize (is_active_member is
--     the status = 'active' rule, 02_rls_functions);
--   - platform_owner_admin denied, always (owner accounts are never
--     assigned; no carve-out exists, Q4).
-- The matter gate is a plain exists subquery on the APPLIED matters table
-- (D-BI2, the documents D-DR2 pattern verbatim): the assignment columns
-- live on the matters row itself, so the exists yields the matter gate
-- regardless of whether matters RLS re-applies inside the policy
-- (defense-in-depth either way). The m.organization_id =
-- billing_invoices.organization_id clause is load-bearing: the org gate
-- comes from the matter's AUTHORITATIVE org, never the invoice's
-- denormalized column, so an invoice is never readable when its matter is
-- not (the org-mismatch battery row pins it, non-vacuously). No new
-- function surface — is_active_member is already EXECUTE-granted to
-- authenticated (R-4 grants in 02_rls_functions.sql).
-- No INSERT/UPDATE/DELETE policy: this slice is read-only (Q5); no
-- card/payment columns exist at all (D-BI1 — the D-11 PCI constraint is
-- structural).

create policy invoices_select_assigned on public.billing_invoices
  for select
  using (
    public.is_active_member(organization_id)
    and exists (
      select 1
      from public.matters m
      where m.id = billing_invoices.matter_id
        and m.organization_id = billing_invoices.organization_id
        and (
          m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid()
        )
    )
  );
