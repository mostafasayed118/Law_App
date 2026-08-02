-- 03_platform_config_seed.sql — P2 reviewed migration (REVIEWED & APPLIED — dev project, 2026-08-01)
-- Q1: platform_config.owner_user_id seeded by migration with the VERIFIED
-- owner auth.users id — no first-run RPC (keeps the client surface minimal).
-- Source of truth: docs/p2_schema_rls_design.md §8 Q1 (gate-approved).
-- Rollback: 03_platform_config_seed.down.sql (same directory).
--
-- APPLY-TIME REQUIREMENT: the owner_user_id below is a substitution token,
-- NOT a real value. Before applying, fill it with the actual auth.users id of
-- the owner's account (verified via a read-only query on the dev project,
-- e.g. select id, email from auth.users where email = '<owner email>').
-- Never guess or fabricate the id; the review record (Q1) requires a
-- verified id. This file is reviewed and committed with the token in place.

begin;

insert into public.platform_config (owner_user_id)
values ('<OWNER_USER_ID: fill from verified auth.users.id at apply time>');

commit;
