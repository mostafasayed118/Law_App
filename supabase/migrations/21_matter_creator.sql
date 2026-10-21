-- 21_matter_creator.sql — matter creator column (NOT APPLIED — rehearsal only)
-- Source of truth: the owner ruling D1 (2026-10-21) on device finding F4
--                (docs/device_e2e_2026-10-21_c835ced.md) — a matter's
--                creator must be able to read the matter they created.
--
-- The matters table carried NO creator column, and the read policy
-- (supabase/policies/matters.sql) grants a row only to the assigned client /
-- assigned attorney. A partner who created a matter WITHOUT assigning
-- someone therefore received a matter they could never read back (device:
-- matter a457cf53… invisible; the same matter with the client assigned was
-- visible).
--
-- D1 (owner ruling, 2026-10-21): the fix is a CREATOR CARVE-OUT in the read
-- policy. A carve-out needs a creator to compare against, so this migration
-- adds exactly one column plus the index the new read path uses. The read
-- side lives in supabase/policies/matters.sql (the creator arm) and the write
-- side in supabase/rpc/create_matter.sql (created_by = auth.uid()).
--
-- The carve-out does NOT widen the gate for anyone else: the policy keeps
-- `is_active_member(organization_id)` as its first conjunct, so the carve-out
-- only ever ADDS the creator (an active org member) to the readers of their
-- own row. A suspended creator, a non-member, and the platform owner stay
-- denied exactly as before (the owner can never be a creator — F2-D1 admits
-- only an active PARTNER of the org, and the owner holds no membership).
--
-- BACKFILL: existing matters have no creator. created_by stays NULL for them,
-- so the carve-out simply does not apply to them and their readers remain the
-- assignees. NOTHING is backfilled from the audit log (the §8 audit rows carry
-- no creator id — the create summary is redacted and the resource id is the
-- matter's).
--
-- Backout (the live project applies this by hand — it has no migration
-- history, so the PM applies the three pieces in this order: column → RPC →
-- policy; the backout is the reverse):
--   drop policy if exists matters_select_assigned on public.matters;
--   -- revert supabase/rpc/create_matter.sql to its pre-21 body (no
--   -- created_by in the insert), then:
--   alter table public.matters drop column created_by;
--   -- (the partial index drops with the column), then re-create the
--   -- pre-21 policy from supabase/policies/matters.sql.
-- (The index drops with the column, so no separate drop statement is needed.)

begin;

-- 21.1 the creator column — the assignment-column convention: a deleted
-- user must not delete the matter row, so the reference nulls out (on delete
-- set null). Nullable: rows that predate the column have no creator, and
-- their readers stay the assignees.
alter table public.matters
  add column created_by uuid references auth.users (id) on delete set null;

-- The new read shape: the creator's own rows — the same partial-index
-- convention as matters_assigned_client / matters_assigned_attorney (04).
create index matters_created_by
  on public.matters (created_by) where created_by is not null;

commit;
