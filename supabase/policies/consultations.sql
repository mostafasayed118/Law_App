-- policies/consultations.sql — own-consultation read policy.
-- Source of truth: the ratified booking design for this wave.
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: a consultation row is readable only by its own client
-- (client_user_id = auth.uid()). Other authenticated users — including
-- org partners and the platform owner — see zero rows; anon holds no
-- SELECT grant at all (the migration's revoke-all baseline).
-- No INSERT/UPDATE/DELETE policy: writes are RPC-only (book_consultation),
-- which is audited and returns a non-PII projection.

create policy consultations_select_own on public.consultations
  for select
  using (
    client_user_id = auth.uid()
  );
