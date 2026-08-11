-- 15_notification_producer.sql — audit-mirror notification producer (DRAFT — T2 artifacts, NOT applied)
-- Source of truth: docs/notification_feed_producer_slice_plan_2026-08-11.md (D-P1..D-P6, RATIFIED cdd7ab4)
--                + docs/notification_feed_producer_gate_review_2026-08-11.md (Q1-Q6, REVIEWED 0f95125).
-- Rollback: 15_notification_producer.down.sql (drop trigger + function).
--
-- D-P1 — the producer is an AUDIT-MIRROR TRIGGER, not an RPC edit (review
-- Q1): an AFTER INSERT trigger on audit_events maps the audited write
-- actions into notifications, so the feed is a filtered projection of the
-- audit log ("the feed says what the audit says"). Zero modification to
-- the shipped RPCs — create_matter (F-01) and send_message (the audited
-- send slice) stay byte-identical; batteries 13/10 pass unchanged.
--
-- D-P2 — the v1 event map is EXACTLY {matter:create, message:create} with
-- outcome='allowed' (review Q2, verified against the RPC sources:
-- create_matter audits 'matter:create'/'allowed' carrying the org param;
-- send_message audits 'message:create'/'allowed' carrying the org resolved
-- thread->matter). Invoice/approval/appointment/system have no server
-- write source (D-11 no-payment, fake-domain queues, no scheduler) — per
-- D-N7 they are NOT invented; appointment/system stay fixture/fake-only.
--
-- D-P3 — fixed redacted summaries (review Q2): never the matter title or
-- message body (structural redaction, the D-N3 mirror). category is always
-- 'activity'; types come from the D-N3 example set.
--
-- D-P4/D-P5 — trigger-only, EXECUTE revoked (the write_audit precedent):
-- the function is invoked by the trigger, never client-callable; RPC-
-- EXECUTE stays 20. The trigger is a DATA-LAYER mechanism, not a policy —
-- applied counts stay 13 tables / 13 RLS / 12 public policies and the
-- matrix row stays read-only member SHIP.
--
-- D-P6 — transactional by construction (review Q3): the mirror insert runs
-- in the SAME transaction as the audit row, so a rolled-back event's feed
-- row vanishes with it (the battery-15 atomicity pin).

begin;

create or replace function public.mirror_audit_to_notifications()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- D-P2 map: only the audited write actions with outcome='allowed'.
  -- organization_id is read FROM THE AUDIT ROW (review Q3 — no re-
  -- derivation); NULL-org identity-level events are SKIPPED, never
  -- synthesized (the is not null guard also protects the NOT NULL org
  -- FK — a NULL-org mirror attempt must filter, not crash).
  if new.organization_id is not null
     and new.action = 'matter:create' and new.outcome = 'allowed' then
    insert into public.notifications (
      organization_id, category, type, summary, server_timestamp
    ) values (
      new.organization_id, 'activity', 'matter_updated',
      'Demo notification — matter created', new.server_timestamp
    );
  elsif new.organization_id is not null
        and new.action = 'message:create' and new.outcome = 'allowed' then
    insert into public.notifications (
      organization_id, category, type, summary, server_timestamp
    ) values (
      new.organization_id, 'activity', 'message_received',
      'new message in thread', new.server_timestamp
    );
  end if;
  return new;
end;
$$;

-- Trigger-invoked only; never client-callable (the 02 helper + 11 trigger
-- pattern): the write_audit precedent (D-P4).
revoke execute on function public.mirror_audit_to_notifications() from public, anon, authenticated;

drop trigger if exists audit_events_mirror_notifications on public.audit_events;
create trigger audit_events_mirror_notifications
  after insert on public.audit_events
  for each row execute function public.mirror_audit_to_notifications();

commit;
