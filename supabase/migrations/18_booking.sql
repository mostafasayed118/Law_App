-- 18_booking.sql — real consultation booking (user-scoped read + audited RPC)
-- Source of truth: the ratified booking design for this wave (consultation
-- slots are a public, user-scoped catalogue; bookings are own-row reads).
--
-- Two tables:
--   consultation_slots — an availability catalogue: a start time, a
--     duration, an active flag, and the atomic claim stamp (booked_at).
--     No org/matter column: slots are organization-agnostic in this slice.
--   consultations — a client's booking of exactly one slot. The slot keeps
--     the authoritative claim (booked_at), the consultation keeps the
--     client-facing record (category, optional topic/attorney_ref, status,
--     server-generated reference_id).
--
-- Write posture: SELECT-only direct grants on both tables (the 17_tasks
-- pattern). Every mutation goes through the audited book_consultation RPC
-- (supabase/rpc/book_consultation.sql) — no INSERT/UPDATE/DELETE grant, no
-- write policy. The RPC returns a non-PII projection only (never topic or
-- client_user_id).
-- Rollback: 18_booking.down.sql (same directory).

begin;

-- 18.1 consultation_slots — the availability catalogue.
create table public.consultation_slots (
  id                uuid primary key default gen_random_uuid(),
  starts_at         timestamptz not null,
  duration_minutes  int not null
    check (duration_minutes between 15 and 240),  -- 15m..4h — the booking contract
  is_active         boolean not null default true,
  booked_at         timestamptz,                  -- NULL = available; set atomically by the RPC
  created_at        timestamptz not null default now()
);

-- 18.2 consultations — the client's booking, own-row readable.
create table public.consultations (
  id              uuid primary key default gen_random_uuid(),
  client_user_id  uuid not null references auth.users (id) on delete cascade,
  slot_id         uuid not null references public.consultation_slots (id) on delete restrict,
  category        text not null
    check (category in ('general', 'follow_up', 'urgent')),
  topic           text
    check (topic is null or char_length(topic) <= 2000),
  attorney_ref    text
    check (attorney_ref is null or char_length(attorney_ref) <= 100),
  status          text not null default 'booked'
    check (status in ('booked', 'cancelled', 'completed')),
  reference_id    text not null unique
    check (reference_id <> ''),                  -- server-generated; never client-supplied
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  cancelled_at    timestamptz
);

-- The availability read shape + the slot-claim lookup.
create index consultation_slots_available
  on public.consultation_slots (starts_at)
  where is_active and booked_at is null;

-- The own-bookings list read.
create index consultations_client_created
  on public.consultations (client_user_id, created_at desc);

-- One active booking per slot. The RPC's FOR UPDATE claim is the primary
-- race guard; this index is the data-layer backstop for any other path.
create unique index consultations_slot_booked_once
  on public.consultations (slot_id)
  where status = 'booked';

-- RLS on (default deny: with no policy, all access is denied).
alter table public.consultation_slots enable row level security;
alter table public.consultations enable row level security;

-- Default-deny baseline: strip the hosting default grants (the 01 pattern).
revoke all on public.consultation_slots from anon, authenticated;
revoke all on public.consultations from anon, authenticated;

-- Narrow direct SELECT grants only; mutations are RPC-only from day one.
grant select on public.consultation_slots to authenticated;
grant select on public.consultations to authenticated;

commit;
