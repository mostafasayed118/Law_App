# Live apply — 2026-10-28 (migrations 22–31, policies, RPCs, functions)

**STATUS: APPLIED** on `law_project` (`eutmvevpskerzpqmwplv`, eu-west-2)
against the repo state at `1c6fa1c` + the wave-2 edits, via the Supabase
Management API (`database/query`). No `supabase db push` was used: the live
project has **no `supabase_migrations.schema_migrations` table**.

## Preflight (read-only, measured)

| Check | Result |
|---|---|
| PostgREST incident `PGRST202` | **RESOLVED** — `/rest/v1/` exposes 41 RPCs; `list_organizations_metadata` and `create_matter` both execute and return function-level `P0001 permission denied` |
| Live baseline | 17 public tables, 15 public policies, 44 public functions; migration 21 present (`matters.created_by`) |
| Row counts | 7 profiles, 5 orgs, 5 memberships, 8 matters, 4 documents, 4 threads, 12 messages, 4 files, 4 invoices, 2 notifications, 0 tasks/slots/consultations/payments |
| API keys | legacy `anon` valid for data API; new publishable/secret keys also active; OpenAPI root requires a secret key |
| Edge functions | only `paymob-initiate`, `paymob-webhook`, `paymob-reconcile` were deployed; no Paymob/River/LiveKit secrets present |
| Snapshot | `%TEMP%\opencode\legalhub_backup_20261028` — all 17 tables as JSON + `policies.json`, `functions.json`, `indexes.json`, `grants.json` |

## Applied, in order

1. **Migrations** `22_attorney_directory` → `31_profile_display_name_and_invite_email`
   (10 files). `29` was applied **without** the `research_runs(requested_by,
   created_at)` index (it cannot serve `list_research_runs`'s org-first query).
2. **Policies** for the new tables: `attorney_profiles`, `approval_requests`,
   `approval_events`, `compliance_alerts`, `compliance_alert_events`,
   `research_runs`, `research_findings`, `video_sessions`.
3. **RPCs** — all 56 `supabase/rpc/*.sql` files (excluding `_down.sql`).
   Four signatures dropped their `default null` parameters before recreation
   (`create_matter`, `create_task`, `book_consultation`,
   `apply_paymob_transaction`); `send_message` was dropped and recreated
   because it now returns `jsonb`.
4. **Edge functions** — `paymob-reconcile`, `research-analyze`, `video-token`
   deployed with `supabase functions deploy --use-api`.
   `research-analyze` and `video-token` return `provider_not_configured`
   until `RIVER_*`, `LIVEKIT_*` and `ALLOWED_ORIGINS` are added to project
   secrets.

## Post-apply verification (measured)

| Check | Result |
|---|---|
| Tables / RLS | **25 tables, 0 without RLS** |
| Policies | **22** public policies (the harness pin); `profiles_update_own` gone |
| Indexes | 6 × migration 29 + 2 × migration 28 present |
| Profiles grants | table UPDATE `false`, column UPDATE `false`, SELECT `true` |
| Member probe (real partner, transactional) | `can_read_matter=true`; created approval, compliance alert, research run, task and matter; approval list saw 1; **rolled back** |
| Cross-tenant probe (partner of another org) | foreign matter `false`; approvals/alerts/research/video/matters = **0**; profiles = **1** (own row); own memberships = 2 |
| Payment late success | `expired` → `succeeded` settles the invoice to `paid`; replay `already_processed=true`; `expired → failed` still `check_violation`; **rolled back** |
| PII backfill | Google profile restored to `Marfat Abo El Wafa`; three email-named profiles now `Member`; trigger maps `full_name`/`name`/fallback `Member`, never email |
| Invite confirmation | unconfirmed user gets `invalid invitation`; confirmed user redeems and the invitation becomes `accepted`; **rolled back** |
| Demo delete guard | real account → `target is not a synthetic demo account`; `@legalhub.test` account deletes; **rolled back** |

## Rollback

- Migrations 22–31 each have a `.down.sql` (31 restores the old trigger; the
  backfill is not reversed because the previous value was the email address).
- The RPC surface rolls back with `supabase/rpc/_down.sql` (drops the whole
  surface) — not recommended while the client expects it.
- Edge functions: redeploy the previous version from the dashboard, or delete
  `research-analyze` / `video-token`.

## Caveats / still owner-gated

- **No full policy battery run.** The committed `supabase/tests/*.sql` battery
  needs a direct Postgres connection; this environment had no DB password.
  The transactional probes above cover the changed contracts, not all 26 files.
- **Provider secrets absent**: live Paymob/River/LiveKit calls fail closed
  until the owner adds `PAYMOB_*`, `RIVER_*`, `LIVEKIT_*`, `ALLOWED_ORIGINS`.
- **Notifications/tasks/booking/payments tables existed already** (migrations
  14–20 had been applied); their policies were left untouched except where 27
  changed helper functions.
- `03_platform_config_seed.sql` was not applied (apply-time owner token); the
  live `platform_config` already has the owner row.

## Related records

- `docs/live_apply_2026-10-24_audit_remediation.md` (27) — applied in this window.
- `docs/live_apply_2026-10-24_list_bounds.md` (28) — applied in this window.
- `docs/live_apply_2026-10-26_audit_followups.md` (29/30) — applied in this window.
- The `PGRST202` incident record: `docs/live_apply_2026-10-21_w4_matter_creator.md` §4.
