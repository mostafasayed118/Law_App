# ADR-0011 — Polish: honest account deletion, in-app legal text, and accessibility gates

- **Status:** Accepted
- **Date:** 2026-11-16
- **Builds on:** ADR-0009 (Legal Library scope), ADR-0010 (per-user library data)
- **Migrations:** `supabase/migrations/34_polish_profile_and_deletion.sql`
- **Batteries:** `supabase/tests/29_polish_profile_deletion.sql`

## Context

The audit found four credibility gaps: the sign-up checkbox linked to policies
that did not exist; the profile was read-only despite there being a deletion
RPC; the Home bell had no unread badge; and accessibility had almost no
automated coverage. The brief also insisted that any new SQL be executed for
real, because structural checks had previously missed three defects in slice 1.

## Decision

### 1. Execute the SQL on a disposable cluster, never on a live project

A throwaway PostgreSQL 16 cluster was created under `%TEMP%` on a spare port
with Supabase-shaped roles and a minimal `storage` schema. All 121 migration,
policy and RPC files applied cleanly. Calling `delete_my_account()` as
`authenticated` with the anon-key client shape **succeeded**: the existing RPC
is `SECURITY DEFINER` and hard-deletes `auth.users`. The feared "anon cannot
delete identity, so this must be anonymize-only" was not the case.

The probe did find three real gaps the old RPC did not cover:

| Finding | Measured before → after |
|---|---|
| `storage.objects` owned by the caller | 1 → 1 (orphaned bytes survived) |
| `public.files` metadata | survived with the object |
| Hosted Supabase storage guard | discovered later: direct DELETE on `storage.objects` raises 42501 |
| Last-active-partner guard | bypassed by the cascade; org left with 0 active partners |
| Platform owner deletion | failed with raw SQLSTATE 23503 from `platform_config` |

Migration 34 removes the caller's file records and their metadata first, refuses
the two governance-invalid cases with stable codes
(`account_deletion_last_partner`, `account_deletion_platform_owner`, both
23514), audits before deletion, then hard-deletes the identity so profiles,
memberships and the ADR-0010 library rows cascade. Anon has no EXECUTE; both
RPCs are definers with a pinned `search_path`. The function bodies are
duplicated byte-identically in the migration and in `supabase/rpc/*.sql`
because the rehearsal harness applies RPCs after migrations — if one changes,
both must.

On a hosted project the storage-table delete is wrapped in an exception handler:
Supabase raises `42501` ("Use the Storage API instead") for direct
`storage.objects` deletes, and that guard must never block identity deletion.
File **records** are removed by the RPC; stored **bytes** remain until the
operator runs a Storage-API cleanup with the service role. The scheduled
service-role cleanup (Edge Function `cleanup-deleted-user-storage` plus
migration `36_storage_bytes_cleanup_wiring.sql`) now exists as **code on a
feature branch**, not deployed: account deletion stays PARTIAL until the owner
deploys the function, sets the secret, applies the migration and verifies with a
disposable test user. See `docs/internal/STORAGE_BYTES_CLEANUP_RUNBOOK.md`.

### 2. The UI tells the truth about what deletion removes

The deletion sheet states both halves explicitly: it removes sign-in, profile,
memberships, library rows and the reader's file records with their metadata;
it does **not** remove stored file bytes on hosted Supabase, other people's
objects, or provider-side records
(LiveKit / Paymob / AI provider), and redacted audit entries are retained with
the actor reference cleared. The cubit sets `done` only after the RPC succeeds,
and the success message names exactly what was removed. It never says a generic
"fully deleted". This is the central decision of the ADR: a stronger claim than
the code can prove would be a false statement in a legal product.

No service-role edge function is required for the identity deletion itself;
the remaining provider-side gap is documented as an owner action, not hidden.

### 3. Separate seams instead of widening AuthGateway

`AuthGateway` has many test implementers and Dart's `implements` requires
overriding every member, so adding a password-change method there would have
forced edits across unrelated fakes for no gain. `PasswordApi`/
`PasswordGateway` and `AccountApi`/`AccountGateway` own the four settings
actions. The fakes mirror every server guard, because the env-less demo build
is the product posture in local runs: a fake more permissive than the RPC would
let the UI ship a flow the server refuses.

### 4. Legal text is bundled JSON, rendered by a small in-repo widget

No markdown dependency was added. The policy and terms are structured per-locale
JSON assets (`assets/legal/legal_{en,ar,tr}.json`) with stable section ids,
rendered by a one-file section renderer. A parity test fails the build if any
locale drops a section or ships an empty paragraph. Every factual claim is
grounded in code; operator name, contact address, last-updated date and
governing law live in one `LegalConfig` constant, and an obvious placeholder
renders an honest "not configured" notice until the owner fills it. The
hostable `docs/legal/*.md` drafts carry a counsel-review notice; the in-app
text deliberately does not.

### 5. Accessibility is a gate, not a prose claim

`test/accessibility/` runs Flutter's `labeledTapTargetGuideline` and
`androidTapTargetGuideline` across 12 surfaces and computes WCAG contrast for
14 theme token pairs at a documented 4.5:1 body-text floor. The matchers found
four real defects (unlabeled password/back controls, an unlabeled checkbox and
two sub-48dp inline targets), all fixed at the shared-widget level. The
statement says exactly what is tested and explicitly does **not** claim full
WCAG conformance or a device TalkBack pass.

### 6. What was deliberately not built

- **Tab promotion** stays reverted per the earlier ADR line; this pass does not
  revisit it.
- **Avatar upload and email change** are out of scope: they need Storage/Auth
  flows unrelated to the deletion contract.
- **A provider-side deletion edge function** is not written here. The identity
  and all repo-owned data are deleted by the RPC; touching Storage bytes
  (hosted Supabase forbids direct table deletes), LiveKit, Paymob or AI
  records requires service-role credentials and a separate owner decision.
- **Golden PNGs** were not hand-edited. The 48dp tap-target fixes may shift
  baselines; regeneration is an owner action via the CI workflow.
