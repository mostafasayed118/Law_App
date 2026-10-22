# Five Real Features — Design

**Status:** approved in chat 2026-10-22 (owner said "ابدأ"; all five; River for AI,
LiveKit as the video default).
**Scope:** replace the five always-fake surfaces with persisted, permissioned
features: Discovery, Approvals, Compliance, Research, Video.

## 1. Principles (binding)

1. **RPC-only writes.** Every new table is RLS-enabled, default-deny
   (`revoke all ... from anon, authenticated`), with a narrow direct `select`
   grant only. Mutations go through `security definer` RPCs that re-assert the
   permission gate and write a redacted `write_audit` row in the same
   transaction.
2. **No fake identifier reaches a real backend.** Discovery's synthetic
   `atty-*` ids must never be sent to the Supabase booking RPC.
3. **Provider adapters are disabled by default.** River (research) and LiveKit
   (video) are selected only when their secrets exist. A missing secret yields
   an honest unavailable state, never a synthetic success.
4. **Honest UI.** Copy states what the surface really is; no "AI verified",
   no "compliance certified", no "attorney verified" claims.
5. **Migration pairing.** Every migration `NN_name.sql` ships with
   `NN_name.down.sql`; RPCs are added to `supabase/rpc/_down.sql`.
6. **Live apply is deferred** until the PostgREST `PGRST202` incident clears.
   Migrations are proven on the ephemeral local stack only; the live apply gets
   a dated `docs/live_apply_YYYY-MM-DD_<slice>.md` record when it happens.

## 2. Discovery — real attorney directory

**Data.** `public.attorney_profiles`: id, display_name, headline, bio,
specialties `text[]`, languages `text[]`, city, years_experience, avatar_url,
status (`active|inactive`), created_by, timestamps.

**Reads.** Direct `select` for authenticated users who hold an active
membership; the policy exposes `status = 'active'` rows only. Platform admin
listing (including inactive) goes through an RPC.

**RPCs.** `list_attorney_profiles(p_query text, p_include_inactive boolean,
p_limit integer)` (admin-only when `p_include_inactive`), `get_attorney_profile
(p_id uuid)`, `create_attorney_profile(...)`, `update_attorney_profile(...)`,
`deactivate_attorney_profile(p_id uuid)`. Write RPCs are platform-owner only
and audited.

**Client.** `AttorneyGateway` gains query + detail; new
`AttorneyAdminGateway` (create/update/deactivate/listAll). Supabase gateway
uses the api-interface pattern (`supabase_attorney_api.dart` + `_impl.dart`).
The fake keeps serving synthetic rows only in env-less builds, with ids that
are obviously not UUIDs.

**Bug fix.** `BookingCubit`/`BookingRequest.attorneyRef` become nullable and
validate UUID shape; a non-UUID reference is dropped (and the booking proceeds
without an attorney reference) instead of being sent to `book_consultation`.

**UI.** Discovery list/detail read from the gateway with server-side query.
New platform-admin attorneys screen: list, create, deactivate.

## 3. Approvals — real workflow

**Data.** `approval_requests` (organization_id, matter_id nullable, title,
description, kind, status `pending|approved|rejected|cancelled`, requested_by,
decided_by, decided_at, decision_note, timestamps) + `approval_events`
(append-only status trail).

**RPCs.** `create_approval_request`, `decide_approval_request(p_id uuid,
p_decision text, p_note text)`, `cancel_approval_request(p_id uuid)`,
`list_approval_requests(p_organization_id uuid, p_status text)`.

**Gates.** Reads: active member of the org. Create: active member; a matter id
must belong to the same org and the caller must be able to read it. Decide:
partner/admin of the org, never the requester. Cancel: requester or
partner/admin. Every transition writes an event + audit row.

**UI.** Status filters; detail sheet; approve/reject with note; create form
(matter optional).

## 4. Compliance — real alerts

**Data.** `compliance_alerts` (organization_id, matter_id nullable, kind,
severity `low|medium|high|critical`, title, description, status
`open|acknowledged|resolved`, due_at, acknowledged_by/at, resolved_by/at,
timestamps).

**RPCs.** `create_compliance_alert`, `acknowledge_compliance_alert(p_id uuid)`,
`resolve_compliance_alert(p_id uuid)`, `list_compliance_alerts
(p_organization_id uuid, p_status text, p_severity text)`.

**Gates.** Reads: active org member. Create: partner/admin. Acknowledge:
active member. Resolve: partner/admin. No automated legal verification is
claimed anywhere.

## 5. Research — River LLM

**Provider.** River Inference, OpenAI-compatible: `POST
https://api.river.ai/v1/chat/completions`, model from `RIVER_MODEL`
(default `deepseek-ai/DeepSeek-V4.1-Flash-1017`). Key only in Edge Function
secrets (`RIVER_API_KEY`, `RIVER_BASE_URL`, `RIVER_MODEL`).

**Data.** `research_runs` (organization_id, matter_id nullable, requested_by,
status `running|completed|failed`, model, prompt_summary, error_code,
timestamps) + `research_findings` (run_id, headline, summary, excerpt,
source_type, source_id, sort_order).

**Flow.** Authenticated user triggers `research-analyze` with matter/document
ids. The function reads the cited rows under the caller's JWT (RLS applies),
composes a bounded prompt, calls River, validates the structured JSON, and
writes results through the service-role client scoped to the caller's org.
No background crawling, no training, no cross-org context.

**Guardrails.** Manual trigger only; max ~12k characters of context; 30 s
timeout; output labelled AI-generated; private-data notice on first use;
failure codes surfaced honestly (`provider_not_configured`,
`provider_unavailable`, `context_too_large`).

**UI.** Runs history + generate action + finding detail. The synthetic engine
remains only for env-less demo builds, clearly labelled.

## 6. Video — LiveKit

**Provider.** LiveKit Cloud. Secrets: `LIVEKIT_URL`, `LIVEKIT_API_KEY`,
`LIVEKIT_API_SECRET`. Edge Function `video-token` mints a room-scoped JWT for
an authorized participant.

**Data.** `video_sessions` (organization_id, matter_id nullable, booking_id
nullable, room_name unique, provider, status
`scheduled|live|ended|cancelled`, scheduled_at, started_at, ended_at,
created_by, timestamps).

**Flow.** A partner/admin creates a session for a matter (or a booking
success). `video-token` re-asserts membership and returns
`{ url, token, room }`. The Flutter client uses `livekit_client` to connect,
publishes camera/mic after the OS permission grant, and renders real
participant tiles. Missing secrets → an honest "not configured" state.

**Platform.** Android `CAMERA`/`RECORD_AUDIO` permissions; iOS usage strings;
no call recording in v1.

## 7. Order and gates

`W-A Discovery → W-B Approvals → W-C Compliance → W-D Research → W-E Video`.

Every wave: migration + down + policies + RPCs + battery + Dart gateway + UI +
l10n + tests + docs, then `dart format`, `flutter analyze --no-pub`,
`flutter test`, `verify_ledger.sh`, `verify_arb_parity.sh`, and the policy
battery on the local stack. One commit per logical slice, no push without a
separate owner GO.

## 8. Out of scope (explicit)

- Real attorney credential verification, contact data, or availability.
- Automated legal compliance verification.
- Recording, transcription, or storage of video/audio.
- Background or scheduled AI analysis.
- Push-notification delivery.
- Applying anything to the live project before `PGRST202` clears.

## 9. Implementation status — 2026-10-22

All five waves landed locally (no push): W-A Discovery (`c38f665`, `ddca47d`,
`c672601`), W-B Approvals (`dbddf1d`, `695f752`, `d645ca4`), W-C Compliance
(`1d87795`, `127fc1e`, `807133f`), W-D Research (`f6c84a6`, `4c5246d`,
`a1c5451`), W-E Video (`cc6cc74`, `c7b00b7`, `958adc3`).

Gates on the final tree: format 0 changed, `flutter analyze` clean,
`flutter test` 1883/1883 (concurrency=1 under local memory pressure), ledger
115/0 PASS, ARB 703/703/703 PASS, policy `--check` 120/0 PASS, `deno check`
clean for both new functions, and a development debug APK builds with the
native LiveKit client.

Still required before any of this is live:

1. Resolve the PostgREST `PGRST202` incident (migrations 22-26 cannot be
   exercised through RPCs until then).
2. Apply migrations 22-26 forward-only on `law_project` via the dashboard,
   recording a dated `docs/live_apply_*.md`.
3. Deploy `research-analyze` and `video-token` with `--use-api`.
4. Set `RIVER_*` and `LIVEKIT_*` secrets on the project.
5. Run the new batteries (22-26) on an ephemeral local stack.
6. Device E2E for discovery, approvals, compliance, research, and video.
7. A push window for the unpushed commits, on an explicit owner GO.

