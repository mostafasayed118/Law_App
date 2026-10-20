# Live apply — 2026-10-21 (task, booking, file-write, payment slices)

Owner-authorized live window on the `law_project` Supabase project.

## Target

| | |
|---|---|
| Project | `law_project` — ref `eutmvevpskerzpqmwplv` (eu-west-2) |
| State before | `INACTIVE` (paused); restored to `ACTIVE_HEALTHY` in this window |
| Method | Supabase Management API `POST /v1/projects/{ref}/database/query` for DDL/RPC/policies; `supabase functions deploy --use-api` for Edge Functions |
| Not used | `supabase db push` (the project has no `supabase_migrations.schema_migrations` history) |

## Applied (forward-only, in order)

1. `migrations/17_tasks.sql` + `policies/tasks.sql` + the four task RPCs
   (`create_task`, `assign_task`, `advance_task_status`, `acknowledge_task`).
2. `migrations/18_booking.sql` + `policies/consultation_slots.sql` +
   `policies/consultations.sql` + `rpc/book_consultation.sql`.
3. `migrations/19_storage_write.sql` (25 MiB + seven-MIME bucket envelope)
   + the new `files_storage_insert` / `files_storage_delete` policies +
   `rpc/register_matter_file.sql` + `rpc/delete_matter_file.sql`.
4. `migrations/20_payments.sql` + the six payment RPCs
   (`initiate_invoice_payment`, `get_invoice_payment_status`,
   `attach_paymob_order`, `apply_paymob_transaction`,
   `record_payment_callback_rejected`, `list_stale_pending_payments`).
5. `rpc/list_matter_assignable_members.sql`.
6. `storage.objects` `files_storage_select` was replaced with the current
   safe-cast definition from `policies/storage_objects.sql` (the live policy
   predated the 2026-10-20 safe-cast hardening; same gate, no widening).

Edge Functions deployed (`--use-api`, no Docker):

| Function | verify_jwt |
|---|---|
| `paymob-initiate` | `true` |
| `paymob-webhook` | `false` |
| `paymob-reconcile` | `false` |

## Verification (live)

- 17 public tables, all with RLS; `tasks`, `consultation_slots`,
  `consultations`, `payments` present.
- 15 public policies + 3 storage policies (`select`/`insert`/`delete`, no
  `update`); `payments` has **no** policy and **no** direct grant.
- 14 new functions present with the expected signatures.
- Grants: `book_consultation`/`initiate_invoice_payment` executable by
  `authenticated`, denied to `anon`; `apply_paymob_transaction` and the other
  service-only RPCs denied to `authenticated`; `authenticated` has **no**
  `SELECT` on `payments`; `tasks` SELECT present.
- `matter-files` bucket: `file_size_limit = 26214400` and the seven allowed
  MIME types.
- `files_storage_select.qual` now contains the safe-cast `CASE`.

## Device E2E (Infinix X6882, Android 14; `development` flavor)

- Booking: real slot read (`Thu, Oct 22 · 1:00 PM`), confirm returned
  `LH-E7B401A0`; `consultations` row + `consultation:book` audit; slot
  `booked_at` stamped.
- Tasks: created `QA live task` on the QA matter; assigned to the QA user;
  acknowledged; advanced to `in_progress`; `task:create` / `task:assign` /
  `task:acknowledge` audit rows present.
- Files: uploaded `qa-upload.txt` (59 B, `text/plain`) through the system
  picker; `public.files` row + `storage.objects` object + `file:create` audit;
  the Files section rendered the row.
- Billing: the invoice read initially failed on-device because
  `SupabaseBillingGateway` expected `issued_at`/`due_at` as `DateTime` while
  PostgREST returns ISO-8601 strings. Fixed in `2bf5b4b`; after rebuild the
  invoice `QA-2026-001` rendered and the demo Pay sheet completed
  `Simulate success`.
- Payments DB path (no Paymob secrets): `initiate_invoice_payment` →
  pending; `attach_paymob_order` → order attached;
  `apply_paymob_transaction(succeeded)` → payment `succeeded`, invoice `paid`,
  `payment:initiate` + `payment:succeeded` audit rows.

CI for the fix: run **39510514279** (`2bf5b4b`) — both jobs **success**
(format/analyze/test + release AAB + debug APK ABI).

## Cleanup

The temporary QA account and its fixture were removed after the pass
(organization → matters/invoices/files/tasks/payments/memberships cascade,
consultation + slot, auth user, storage object). Post-cleanup counts for the
QA ids are zero. The redacted audit rows remain on purpose (append-only); the
actor reference is nulled by the existing `ON DELETE SET NULL` FK.

## Caveats / open items

- **No migration history.** `supabase_migrations.schema_migrations` does not
  exist on this project; the schema was applied directly. `supabase db push`
  would try to replay migrations `01…20` and is **not safe** here. Keep using
  the dated apply records.
- **Policy batteries 18–21 were not run live.** They are designed for an
  ephemeral rehearsal project and their fixtures delete `auth.users`/
  `platform_config`; running them against the dev project would be
  destructive. The static `--check` is green; a fresh-stack rehearsal is
  still the right proof for the SQL itself.
- **Live payments remain disabled.** `PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`,
  `PAYMOB_INTEGRATION_ID`, `PAYMOB_IFRAME_ID`, `PAYMOB_BASE_URL`, and
  `PAYMOB_RECONCILE_SECRET` are not set on the project. The deployed
  functions return `server_misconfigured` until those secrets are set and the
  Paymob dashboard callback URL is configured. `PAYMENTS_MODE` defaults to
  `disabled` in the app.
- **Rollback is targeted, not `rpc/_down.sql` wholesale** (that file drops
  every function). Use the per-slice down files (`18_booking.down.sql`,
  `19_storage_write.down.sql`, `20_payments.down.sql`), the task drop block
  in `rpc/_down.sql`, and drop the two new storage policies explicitly.
- **Booking topic is persisted** (PII) and still needs a retention/residency
  decision; `attorney_ref` remains an opaque demo reference.
- The Management API token and the service-role key were used in-memory only;
  neither is stored in the repo or in any committed file.
