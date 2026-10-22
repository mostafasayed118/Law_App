# W-A Discovery — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the synthetic attorney directory with a persisted, platform-admin
managed directory, and stop synthetic `atty-*` ids from reaching the real booking RPC.

**Architecture:** One additive migration (`22_attorney_directory.sql`) + one policy
file + five `security definer` RPCs. Flutter gains a Supabase gateway behind the
existing `AttorneyGateway` seam, an admin gateway, a platform-admin screen, and a
booking-side UUID guard. Fake data remains only for env-less builds.

**Tech Stack:** Postgres/Supabase (RLS + RPC), Dart/Flutter (Cubit, go_router, l10n).

**Spec:** `docs/superpowers/specs/2026-10-22-five-features-design.md` §2.

## Global Constraints

- Writes are RPC-only; tables are RLS-enabled with default-deny and a narrow
  `select` grant. No `insert/update/delete` grants to `authenticated`.
- Every RPC: `security definer set search_path = public`, explicit
  `revoke ... from public, anon` + `grant execute ... to authenticated`, a
  permission re-check, and a redacted `write_audit` call.
- No RPC parameter may carry a `default` (the open PostgREST incident).
- Migration must ship `22_attorney_directory.down.sql`; RPC drops go in
  `supabase/rpc/_down.sql`.
- Do **not** apply anything to the live project. Local/ephemeral proof only.
- Do not change `lib/l10n` copy without adding en/ar/tr keys in the same commit.
- No push. Commits with explicit pathspecs only.

---

### Task 1: Migration + down

**Files:**
- Create: `supabase/migrations/22_attorney_directory.sql`
- Create: `supabase/migrations/22_attorney_directory.down.sql`

**Interfaces:**
- Produces table `public.attorney_profiles` used by every later task.

- [ ] **Step 1: Write the migration**

```sql
-- 22_attorney_directory.sql — real attorney directory (NOT APPLIED — rehearsal only)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §2.
--
-- Replaces the synthetic discovery list with a platform-level directory managed
-- by the platform owner. Professional profile data only: no phone, email,
-- address, credential number, or availability. Reads are member-scoped and
-- expose active rows only; every mutation is an owner-only audited RPC.
--
-- Rollback: 22_attorney_directory.down.sql (same directory).

begin;

create table public.attorney_profiles (
  id               uuid primary key default gen_random_uuid(),
  display_name     text not null check (length(trim(display_name)) between 2 and 120),
  headline         text check (headline is null or length(headline) <= 160),
  bio              text check (bio is null or length(bio) <= 2000),
  specialties      text[] not null default '{}',
  languages        text[] not null default '{}',
  city             text check (city is null or length(city) <= 120),
  years_experience integer check (years_experience is null
                                  or years_experience between 0 and 80),
  avatar_url       text,
  status           text not null default 'active'
                     check (status in ('active', 'inactive')),
  created_by       uuid references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index attorney_profiles_active
  on public.attorney_profiles (display_name) where status = 'active';

alter table public.attorney_profiles enable row level security;
revoke all on public.attorney_profiles from anon, authenticated;
grant select on public.attorney_profiles to authenticated;

commit;
```

- [ ] **Step 2: Write the down migration**

```sql
-- 22_attorney_directory.down.sql — backout for 22_attorney_directory.sql
begin;

drop function if exists public.list_attorney_profiles(text, boolean, integer);
drop function if exists public.get_attorney_profile(uuid);
drop function if exists public.create_attorney_profile(text, text, text, text[], text[], text, integer, text);
drop function if exists public.update_attorney_profile(uuid, text, text, text, text[], text[], text, integer, text, text);
drop function if exists public.deactivate_attorney_profile(uuid);

drop table if exists public.attorney_profiles;

commit;
```

---

### Task 2: Read policy

**Files:**
- Create: `supabase/policies/attorney_profiles.sql`

**Interfaces:**
- Produces policy `attorney_profiles_select_active` consumed by the direct select.

- [ ] **Step 1: Write the policy**

```sql
-- attorney_profiles_select_active — active directory rows for active members.
-- Platform-owner listing (including inactive rows) is RPC-only; this policy
-- never exposes an inactive profile and never exposes the table to anon.
create policy attorney_profiles_select_active on public.attorney_profiles
  for select
  using (
    status = 'active'
    and exists (
      select 1 from public.memberships m
       where m.user_id = auth.uid()
         and m.status = 'active'
    )
  );
```

- [ ] **Step 2: Prove the policy count pin**

Run: `rg -n "policy count|pg_policies" scripts/verify_policy_tests.sh supabase/tests | Select-Object -First 10`
Expected: identify the pinned policy count and update it by exactly +1 in the
same commit (record the old and new number in the commit body).

---

### Task 3: RPCs

**Files:**
- Create: `supabase/rpc/list_attorney_profiles.sql`
- Create: `supabase/rpc/get_attorney_profile.sql`
- Create: `supabase/rpc/create_attorney_profile.sql`
- Create: `supabase/rpc/update_attorney_profile.sql`
- Create: `supabase/rpc/deactivate_attorney_profile.sql`
- Modify: `supabase/rpc/_down.sql`

**Interfaces:**
- `create_attorney_profile(text,text,text,text[],text[],text,integer,text) returns uuid`
- `update_attorney_profile(uuid,text,text,text,text[],text[],text,integer,text,text) returns void`
- `deactivate_attorney_profile(uuid) returns void`
- `list_attorney_profiles(text,boolean,integer) returns setof public.attorney_profiles`
- `get_attorney_profile(uuid) returns public.attorney_profiles`

- [ ] **Step 1: Write `create_attorney_profile.sql`**

```sql
-- rpc/create_attorney_profile.sql — owner-only directory write (NOT APPLIED)
create or replace function public.create_attorney_profile(
  p_display_name     text,
  p_headline         text,
  p_bio              text,
  p_specialties      text[],
  p_languages        text[],
  p_city             text,
  p_years_experience integer,
  p_avatar_url       text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;
  if p_display_name is null or length(trim(p_display_name)) < 2 then
    raise exception 'display name is required';
  end if;

  insert into public.attorney_profiles
    (display_name, headline, bio, specialties, languages, city,
     years_experience, avatar_url, status, created_by)
  values
    (trim(p_display_name), nullif(trim(p_headline), ''), nullif(trim(p_bio), ''),
     coalesce(p_specialties, '{}'), coalesce(p_languages, '{}'),
     nullif(trim(p_city), ''), p_years_experience, nullif(trim(p_avatar_url), ''),
     'active', auth.uid())
  returning id into v_id;

  perform public.write_audit(
    'attorney_profile:create', 'allowed',
    p_resource_type    => 'attorney_profile',
    p_resource_id      => v_id,
    p_redacted_summary => 'attorney profile created'
  );
  return v_id;
end;
$$;

revoke execute on function public.create_attorney_profile(text, text, text, text[], text[], text, integer, text) from public, anon;
grant execute on function public.create_attorney_profile(text, text, text, text[], text[], text, integer, text) to authenticated;
```

- [ ] **Step 2: Write `update_attorney_profile.sql`**

Same shape; owner gate; `update public.attorney_profiles set ... , updated_at = now()
where id = p_id`; raise `'attorney profile not found'` when no row; audit
`attorney_profile:update`.

- [ ] **Step 3: Write `deactivate_attorney_profile.sql`**

Owner gate; `update ... set status = 'inactive', updated_at = now() where id =
p_id and status = 'active'`; raise `'attorney profile not found or already
inactive'` when no row; audit `attorney_profile:deactivate`.

- [ ] **Step 4: Write `list_attorney_profiles.sql`**

```sql
create or replace function public.list_attorney_profiles(
  p_query            text,
  p_include_inactive boolean,
  p_limit            integer
) returns setof public.attorney_profiles
language plpgsql security definer set search_path = public as $$
begin
  if p_include_inactive and not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;
  if not exists (
    select 1 from public.memberships m
     where m.user_id = auth.uid() and m.status = 'active'
  ) and not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;

  return query
    select a.*
      from public.attorney_profiles a
     where (p_include_inactive or a.status = 'active')
       and (p_query is null or trim(p_query) = ''
            or a.display_name ilike '%' || trim(p_query) || '%'
            or coalesce(a.headline, '') ilike '%' || trim(p_query) || '%'
            or coalesce(a.city, '') ilike '%' || trim(p_query) || '%'
            or exists (
                 select 1 from unnest(a.specialties) s
                  where s ilike '%' || trim(p_query) || '%'))
     order by a.display_name
     limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

revoke execute on function public.list_attorney_profiles(text, boolean, integer) from public, anon;
grant execute on function public.list_attorney_profiles(text, boolean, integer) to authenticated;
```

- [ ] **Step 5: Write `get_attorney_profile.sql`**

Member gate (active membership or platform owner), returns the row only when
`status = 'active'` or the caller is the platform owner; raise
`'attorney profile not found'` otherwise.

- [ ] **Step 6: Register drops in `supabase/rpc/_down.sql`**

Append the five `drop function if exists` statements in the file's existing
style (after the newest entries).

---

### Task 4: SQL battery + harness registration

**Files:**
- Create: `supabase/tests/22_attorney_directory_rls.sql`
- Modify: `scripts/verify_policy_tests.sh` (four lists + apply order if needed)

**Interfaces:**
- Produces at least 12 `POLICY-BATTERY FAIL` markers and the counts used by the
  final report.

- [ ] **Step 1: Write the battery**

Cover, in separate `do $$` blocks:
1. owner creates a profile → row exists + one audit row.
2. partner/admin (non-owner) create → denied, no audit row.
3. active member selects active profile → visible.
4. suspended / no-membership user selects → zero rows.
5. anon selects → denied (no grant).
6. owner `list_attorney_profiles(..., true, ...)` sees inactive rows.
7. non-owner `p_include_inactive = true` → denied.
8. search by name/city/specialty → matching row only.
9. update by non-owner → denied; row unchanged.
10. deactivate by owner → status inactive; direct select hides it.
11. `get_attorney_profile` on inactive as non-owner → not found.
12. cross-org member still reads the platform directory (by design).

- [ ] **Step 2: Register in all four places**

`BATTERY_FILES`, the UUID scan list, the FAIL-marker loop list, and the
execution loop. If `--apply` builds the schema, add `22_attorney_directory.sql`
to the apply order.

- [ ] **Step 3: Run static check**

Run: `bash scripts/verify_policy_tests.sh --check` (through an LF copy on
Windows).
Expected: PASS, 0 failures.

---

### Task 5: Dart data layer

**Files:**
- Modify: `lib/features/discovery/domain/attorney.dart`
- Modify: `lib/features/discovery/domain/attorney_gateway.dart`
- Create: `lib/features/discovery/domain/attorney_admin_gateway.dart`
- Create: `lib/data/discovery/supabase_attorney_api.dart`
- Create: `lib/data/discovery/supabase_attorney_api_impl.dart`
- Create: `lib/data/discovery/supabase_attorney_gateway.dart`
- Modify: `lib/features/discovery/data/fake_attorney_gateway.dart`
- Modify: `lib/app/service_locator_features.dart`
- Modify: `lib/app/service_locator.dart` (factory threading)

**Interfaces:**
- `Attorney` gains `headline`, `city`, `specialties`, `languages`,
  `yearsExperience`, `isActive`; `id` stays `String` but real rows carry UUIDs.
- `AttorneyGateway.fetchAttorneys({String query = ''})`,
  `AttorneyGateway.fetchAttorney(String id)`.
- `AttorneyAdminGateway.fetchAll()`, `.create(AttorneyDraft)`,
  `.update(String id, AttorneyDraft)`, `.deactivate(String id)`.
- `AttorneyDraft` is a small value object in `attorney_admin_gateway.dart`.

- [ ] **Step 1: Extend the VO** with optional fields and a
  `bool get hasRealId => Uuid.isValid(id)` helper (use the repo's existing UUID
  validation utility if one exists; otherwise a local regex
  `^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`).
- [ ] **Step 2: Extend the gateway interfaces** exactly as above.
- [ ] **Step 3: Implement the API + gateway** by copying the structure of
  `lib/data/matters/supabase_matter_api.dart` + `_impl.dart` +
  `supabase_matter_gateway.dart`. Reads call `rpc('list_attorney_profiles',
  params: {...})` and `rpc('get_attorney_profile', ...)`; admin calls the write
  RPCs. Map `PostgrestException` through the existing failure mapping.
- [ ] **Step 4: Update the fake** to return local data and to generate ids with
  an `atty-` prefix (deliberately not UUIDs), and make `fetchAttorney` return
  the matching fake row.
- [ ] **Step 5: Register the seams** with `_registerSeam<AttorneyGateway>` and
  `_registerSeam<AttorneyAdminGateway>`; thread the new api factory parameters
  through `service_locator.dart` the same way the matter factory is threaded.
- [ ] **Step 6: Unit tests** for the gateway: mapping, query passthrough,
  inactive filtering, error mapping, and fake id shape. Use a fake
  `SupabaseAttorneyApi` as in `test/data/matters/supabase_matter_gateway_test.dart`.

---

### Task 6: Booking guard (the live bug)

**Files:**
- Modify: `lib/features/booking/domain/booking_request.dart`
- Modify: `lib/features/booking/presentation/booking_cubit.dart`
- Modify: `lib/data/booking/supabase_booking_gateway.dart`
- Test: `test/features/booking/booking_cubit_test.dart` (or the existing test file)

**Interfaces:**
- `BookingRequest.attorneyRef` becomes `String?`.
- A non-UUID ref is normalized to `null` before the RPC call.

- [ ] **Step 1: Write the failing test**

```dart
test('a synthetic attorney id is not sent to the real booking RPC', () async {
  final request = BookingRequest(/* ... attorneyRef: 'atty-1' ... */);
  final normalized = normalizeAttorneyRef(request.attorneyRef);
  expect(normalized, isNull);
});

test('a real uuid attorney id is preserved', () {
  const id = '11111111-1111-4111-8111-111111111111';
  expect(normalizeAttorneyRef(id), id);
});
```

- [ ] **Step 2: Run it** → FAIL (function missing).
- [ ] **Step 3: Implement** a top-level `String? normalizeAttorneyRef(String?)`
  in `booking_request.dart` using the same UUID shape; apply it in the cubit
  when building the request and again in the gateway before the RPC.
- [ ] **Step 4: Run the booking tests** → PASS.

---

### Task 7: UI — discovery + admin

**Files:**
- Modify: `lib/features/discovery/presentation/attorney_search_screen.dart`
- Modify: `lib/features/discovery/presentation/attorney_profile_surface.dart`
- Create: `lib/features/admin/presentation/attorney_admin_screen.dart`
- Create: `lib/features/admin/presentation/attorney_admin_form.dart`
- Modify: `lib/app/router.dart` + `lib/app/router_shell_routes.dart`
- Modify: `lib/features/admin/presentation/platform_admin_screen.dart` (entry)

**Interfaces:**
- Route `/platform-admin/attorneys`, guarded by the existing platform-admin
  redirect.
- Create form validates: name length, years 0–80, at least one specialty,
  optional headline/city/bio.

- [ ] **Step 1: Wire the search screen** to `fetchAttorneys(query: ...)` with a
  debounce on the search field; keep the existing `CubitListSurface` pattern.
- [ ] **Step 2: Profile surface** loads by id via `fetchAttorney`, shows the
  new fields, and passes the real UUID to booking (null when fake).
- [ ] **Step 3: Admin screen** lists all profiles with status chips; actions
  create/edit/deactivate; empty and error states; no fake data in configured
  builds.
- [ ] **Step 4: Entry point** from the platform admin screen (a tile with a
  chevron, 48×48 touch target, direction-aware icon).
- [ ] **Step 5: Widget tests**: list renders, search filters, detail renders,
  admin create validation, deactivate confirmation, admin route denies a
  non-owner session.

---

### Task 8: l10n

**Files:**
- Modify: `lib/l10n/app_en.arb`, `app_ar.arb`, `app_tr.arb`
- Generated: `lib/l10n/app_localizations*.dart` via `flutter gen-l10n`

- [ ] **Step 1:** Add keys (en/ar/tr) for: admin title, create/update/deactivate,
  form labels (name, headline, bio, specialties, languages, city, years),
  validation errors, empty/error states, status labels, and the honest
  directory note.
- [ ] **Step 2:** Run `flutter gen-l10n`; do not hand-edit generated files.
- [ ] **Step 3:** Run `bash scripts/verify_arb_parity.sh` → PASS.

---

### Task 9: Docs + gates + commits

**Files:**
- Modify: `supabase/README.md` (layout row, apply order, battery table)
- Modify: `README.md` (feature bullet + both test-count markers)
- Create: `docs/live_apply_<date>_attorney_directory.md` **only when the live
  apply happens** (after PGRST202 clears) — not in this wave.

- [ ] **Step 1: Update `supabase/README.md`** with the migration, down pair,
  RPCs, and battery row.
- [ ] **Step 2: Update `README.md`** wording and the exact test counts.
- [ ] **Step 3: Run the full gates**:

```
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --reporter=compact
bash scripts/verify_ledger.sh
bash scripts/verify_arb_parity.sh
bash scripts/verify_policy_tests.sh --check   # via LF copy on Windows
```

All must exit 0.

- [ ] **Step 4: Commit with explicit pathspecs** (no push):

```
git add -- supabase/migrations/22_attorney_directory.sql supabase/migrations/22_attorney_directory.down.sql supabase/policies/attorney_profiles.sql supabase/rpc/*attorney*.sql supabase/rpc/_down.sql supabase/tests/22_attorney_directory_rls.sql scripts/verify_policy_tests.sh
git commit -m "feat(db): real attorney directory with owner-only writes"

git add -- lib/features/discovery lib/features/admin lib/data/discovery lib/app/service_locator_features.dart lib/app/service_locator.dart lib/features/booking/domain/booking_request.dart lib/features/booking/presentation/booking_cubit.dart lib/data/booking/supabase_booking_gateway.dart test
git commit -m "feat(discovery): real directory and booking attorney-reference guard"

git add -- lib/l10n README.md supabase/README.md
git commit -m "docs(discovery): record the directory surface and test counts"
```

**STOP list.** Stop and report if: the migration needs to change an existing
table or policy; a write RPC cannot satisfy the permission gate without widening
an existing policy; l10n parity needs a duplicate key; the booking guard would
change a frozen test expectation beyond the two tests named above; the live
project would need to be touched.
