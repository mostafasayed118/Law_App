-- 14_notifications.down.sql — backout for 14_notifications.sql (DRAFT — rollback standby; not run on dev)
-- Clean inverse per the review contract (docs/notification_feed_gate_review_2026-08-11.md
-- Q6: "drop policy + table"): drop the notifications_select_org policy
-- FIRST, then the table. The inline category CHECK dies with the table —
-- like 04/05/06/10, there is no type object to drop. Any demo rows go
-- with the table (FK-free, org-cascade), plus the apply-time cleanup step
-- (T5); the policy-side git revert pairing (rollback_plan.md design §7)
-- remains belt-and-braces on top of this explicit drop.

begin;

drop policy if exists notifications_select_org on public.notifications;
drop table if exists public.notifications;

commit;
