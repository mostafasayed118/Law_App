-- policies/legal_reading_history.sql — per-user reading-history read policy
-- Backout: git revert of this policy commit; the table drop in
-- migrations/33_library_user_data.down.sql removes it with the table.
--
-- SELECT: own rows only. Reading history is behavioural data — arguably the most
-- sensitive table in this schema — so the policy is the narrowest one here.
--
-- No write policy and no write grant: record_legal_reading and
-- clear_my_legal_history are the only paths, both SECURITY DEFINER.

create policy legal_reading_history_select_own on public.legal_reading_history
  for select
  to authenticated
  using (user_id = auth.uid());
