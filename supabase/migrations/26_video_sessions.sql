-- 26_video_sessions.sql — persisted LiveKit video sessions (NOT APPLIED — rehearsal only)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §6
--                + docs/superpowers/plans/2026-10-22-video.md Tasks 1-3.
--
-- One row per room. The provider is recorded explicitly ('livekit' only, the
-- single supported adapter) and the room name is generated server-side in
-- create_video_session — never client-supplied — so the CHECK below is the
-- shape contract for every minted room.
--
-- Default-deny posture: RLS on, all privileges revoked from anon +
-- authenticated, exactly one narrow SELECT grant. The participant read
-- policy lives in supabase/policies/video_sessions.sql; the five RPCs live
-- in supabase/rpc/*video*.sql.
--
-- Rollback: 26_video_sessions.down.sql (same directory).

begin;

create table public.video_sessions (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  matter_id       uuid references public.matters (id) on delete set null,
  booking_id      uuid references public.consultations (id) on delete set null,
  room_name       text not null unique check (room_name ~ '^room_[a-z0-9]{16,40}$'),
  provider        text not null default 'livekit' check (provider = 'livekit'),
  status          text not null default 'scheduled'
                    check (status in ('scheduled','live','ended','cancelled')),
  scheduled_at    timestamptz,
  started_at      timestamptz,
  ended_at        timestamptz,
  created_by      uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index video_sessions_org_created
  on public.video_sessions (organization_id, created_at desc);
create index video_sessions_matter
  on public.video_sessions (matter_id) where matter_id is not null;

alter table public.video_sessions enable row level security;
revoke all on public.video_sessions from anon, authenticated;
grant select on public.video_sessions to authenticated;

commit;
