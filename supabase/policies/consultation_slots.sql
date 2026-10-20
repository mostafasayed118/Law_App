-- policies/consultation_slots.sql — available-slot read policy.
-- Source of truth: the ratified booking design for this wave.
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: a slot is readable iff the caller is authenticated AND the slot is
-- still available (is_active and unclaimed). Booked/inactive slots disappear
-- from the catalogue by construction; the owning booking remains readable
-- through consultations_select_own.
-- No INSERT/UPDATE/DELETE policy: the only mutation path is the audited
-- book_consultation RPC (atomic FOR UPDATE claim + section 8 audit).

create policy consultation_slots_select_available on public.consultation_slots
  for select
  using (
    auth.uid() is not null
    and is_active
    and booked_at is null
  );
