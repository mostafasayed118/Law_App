# LegalHub — Configured-Build E2E Checklist (D-45.1, 2026-08-08)

> **Purpose:** the owner-side verification that the **real client surfaces**
> (env-gated behind `env.isConfigured`) round-trip the applied dev-project
> surface end-to-end. This is the one verification the suite cannot do: the
> unit/widget suite pins the fakes + gateways, and the apply smokes
> role-impersonated SQL on the dev project — but **no `.env` build has
> driven the app against the live surface yet** (D-45.1, recorded since
> P2/P3). Ground truth for every expectation: `docs/current_applied_surface_2026-08-08.md`
> (12 tables / 11 public + 1 storage policy / 19 RPCs / publication exactly
> `messages` / `matter-files` bucket / demo rows) + the ten execution records.
>
> **Nothing here is a security control** — it verifies the client reads what
> the RLS/RPC surface already proved server-side (INSTRUCTIONS.md §1.2).

## 0. Prerequisites (owner-side, git-ignored)

- [ ] `.env` at the repo root with the dev-project **URL + anon key** only
      (`eutmvevpskerzpqmwplv` / `eu-central-1`); never a service-role key.
- [ ] `flutter run` (or a release build) on a device/emulator; sign in as each
      demo account below (credentials are the owner-held demo accounts; the
      P2 provider loop — signup/email — stays deferred per D-45.1, so use
      **existing** demo accounts, never a fresh signup).
- [ ] The app shows the **real** org/matter/document/message/storage/billing
      rows (fake data absent) — the flip is `env.isConfigured` in
      `lib/app/service_locator.dart` for all six gateway families.

## 1. Demo accounts + expected surface (per applied policy gate)

**Gate contract (every assigned-client/attorney policy):** `is_active_member(org)`
**AND** assignment on the matter. **Only the partner holds a dev membership row** —
every assigned **client** is deliberately denied (membership guard, recorded as
designed in every smoke). Org `ef43087b-adf4-4480-9bb2-28c26f46ec71`.

| Account (id prefix) | Role on demo data | Org membership | Expected to read |
|---|---|---|---|
| **Partner** `8fa94af0-7390-…` (al3tar66) | assigned **attorney** on matters 1–3 (acquisition `a6715e17-…` · lease `d155dc92-…` · procedural `4f4a935f-…`); **not** assigned on matter 4 (family `575391b6-…`, client-only) | **YES** — active, 2 orgs | matters **3** · documents **3** · threads **3** · messages **6** (1+2+3) · files **3** · invoices **3** (`INV-2026-0001..0003`, family `0004` absent) · orgs **2** · memberships **2** |
| Client `9acfd3b4-96c6-…` (al3tar) | assigned client, matter 1 (acquisition) | **NO** | **0** everywhere — membership guard denies even its own matter (battery 04/05/06/07/10/11 deny rows) |
| Client `187fc8d6-e6df-…` (al3tar1) | assigned client, matter 2 (lease) | **NO** | **0** everywhere |
| Client `0c54d251-1cdd-…` (al3tar4545) | assigned client, matter 4 (family, client-only) | **NO** | **0** everywhere (the family positive waits for a future membership + assignment) |
| Anon / not signed in | — | — | app gates to sign-in; direct API probes denied (no grant) |

## 2. Client surface → exercised path (what a `.env` build proves)

| Gateway (env flip in `service_locator.dart`) | Reads on the live surface | Denied / negative to also confirm |
|---|---|---|
| `SupabaseOrganizationGateway` + admin | orgs (active-member SELECT), memberships (own-row + org roster), invites (partner) | non-member org absent; owner-only RPCs deny |
| `SupabaseMatterGateway` | `matters` via `matters_select_assigned` | org-role-alone / cross-org / suspended denies |
| `SupabaseDocumentGateway` | `documents` via `documents_select_assigned` | same denies (battery 05) |
| `SupabaseMessageGateway` | `message_threads` + `messages` via `message_threads_select_assigned` / `messages_select_assigned`; `sendMessage` → `send_message` RPC (audited, D-SM3 — no direct INSERT) | family thread absent for partner; clients 0; send on unassigned thread denied; audit row written |
| `SupabaseStorageGateway` | `files` metadata + `storage.objects` bytes via the two-layer policies | guessed-path / cross-org / suspended denies (battery 07); no download affordance (D-STR9) |
| `SupabaseBillingGateway` | `billing_invoices` via `invoices_select_assigned` (metadata only, D-11) | family invoice absent for partner; clients 0; no pay surface |
| `SupabasePlatformAdminApi` | `read_platform_audit` / `read_org_audit` + owner-only RPCs | **no demo owner account** — confirm the owner-only rows deny for all demo accounts (client renders denied, never empty-success; audit surfacing contract) |

## 3. Ordered runbook (recommended)

1. **Partner sign-in** → orgs **2**; select org `ef43087b-…`; matter list **3**
   (family absent); open acquisition → documents **1**, thread count **1**,
   messages **1**, file **1**, invoice `INV-2026-0001`.
2. **Message detail + send** → open the acquisition thread; send one demo
   message → appears immediately (realtime push, publication = `messages`);
   confirm no direct-INSERT affordance outside the composer (D-SM3).
3. **Lease + procedural** → repeat the spot-check (documents/thread/files/
   invoice counts **1** each; thread counts 2 / 3; messages 2 / 3).
4. **Family matter** → confirm it never appears for the partner (client-only
   `assigned_client_id`, `assigned_attorney_id = NULL`).
5. **Client sign-in ×3** → org list empty (no membership) → the app shows the
   honest empty/denied state (never fabricated rows); each assigned client
   sees 0 on their own matter.
6. **Owner-only audit rows** (partner session) → platform-admin audit section
   renders **denied**, never empty-success (audit surfacing contract).
7. **Anon** → app requires sign-in; no surface renders.

## 4. Expected vs. honest-empty (never defects)

- The **clients' 0-everything** reads are the membership guard firing — the
  matrix contract ("an org role alone never grants; assignment alone is also
  insufficient"). Record as **expected**, never "fix" by removing the guard.
- A fuller client-side demo = a **deliberate, separate data action**: add
  membership rows for the demo clients (owner-approved) — nothing in this
  checklist changes any policy/RPC/table.

## 5. Owner sign-off (dated)

- [ ] Section 0 prerequisites in place (`.env` = URL + anon key only).
- [ ] Partner pass (steps 1–4) matches the §1 table exactly.
- [ ] Client passes (step 5) show the honest empty/denied states.
- [ ] Owner-only audit renders denied (step 6); anon gates (step 7).
- [ ] Dated signature: **______ (2026-08-__)** — record the result here or in
      a follow-up evidence note (`docs/configured_build_e2e_evidence_2026-08-___.md`).
