-- 24_compliance_alerts.down.sql — backout for 24_compliance_alerts.sql
-- (NOT APPLIED — standby)
-- Clean inverse: drop the slice's RPCs first (so no definer function is left
-- pointing at a missing table), then the events table (FK child) and the
-- alerts table. Indexes, inline CHECKs, and read policies die with their
-- tables. The consolidated rpc/_down.sql drop list is maintained separately
-- for the whole RPC surface; the drops here are idempotent, so running both
-- orders is safe.

begin;

drop function if exists public.create_compliance_alert(uuid, uuid, text, text, text, text, timestamptz);
drop function if exists public.acknowledge_compliance_alert(uuid);
drop function if exists public.resolve_compliance_alert(uuid, text);
drop function if exists public.list_compliance_alerts(uuid, text, text);

drop table if exists public.compliance_alert_events;
drop table if exists public.compliance_alerts;

commit;
