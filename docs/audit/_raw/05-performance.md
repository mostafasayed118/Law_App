# Performance audit — LegalHub (Flutter/Dart + Supabase)

Date: 2026-09-21 · Scope: `lib/`, `supabase/` (static reading + scoped grep; no build, no test, no profiling)
Auditor note: the working tree carries 13 uncommitted modified files plus one untracked file that are an **in-flight performance hardening pass** (lazy `ViewStateList`, bounded table SELECTs, composer `buildWhen`, lazy transcript). Those are treated as in-flight and are **not** reported as findings; they are called out under "What's done well" where relevant. Everything below is a defect in the code as it stands in the working tree, including what the in-flight pass did **not** reach.

---

## HIGH — Platform-admin reads bypass the new bounded-query guard: unbounded RPCs, eager render, O(members × orgs) join

**Location**: `lib/data/admin/supabase_platform_admin_api_impl.dart:47-84` and `:111-151`; `supabase/rpc/list_members_metadata.sql:34-41`; `supabase/rpc/read_platform_audit.sql:36-41`; `supabase/rpc/read_org_audit.sql:34-38`; `lib/features/admin/presentation/platform_admin_lists.dart:29,45,66,100-107`

**Issue**: The in-flight guard `lib/data/list_query_guards.dart` bounds every **table** SELECT in the app (`.order()` + `.limit(200)`), and `grep -rn "\.select(" lib/` confirms the only remaining raw SELECT in `lib/` is inside the guard itself. But the guard is a *table* binding — the platform-admin surface does not use tables, it uses four RPCs, which bypass it entirely:

- `list_members_metadata()` (`supabase/rpc/list_members_metadata.sql:34-41`) returns `memberships m JOIN profiles p` for **every membership in the database**, `order by m.organization_id, m.user_id`, with **no LIMIT**.
- `read_platform_audit()` (`read_platform_audit.sql:36-41`) returns **the entire `audit_events` table** ordered by `server_timestamp desc`, with **no LIMIT** — and it writes an audit row (`write_audit('platform:read_audit', ...)`) *before* reading, so each read appends to the table it just read in full. The payload grows monotonically with use.
- `list_organizations_metadata()` and `read_org_audit()` are likewise unbounded (`read_org_audit` is org-scoped but still grows without limit per org).

The client then renders those unbounded lists in a **non-lazy** `ListView(children: [...])` (`platform_admin_lists.dart:29`) built from `...organizations.map(...)` (`:45`) and `...members.map(...)` (`:66`) — every row constructed on the first frame and on every state change. Worse, the members loop resolves each member's org name with `_orgNameFor(organizations, member.organizationId)` (`:69-72`), a **linear scan of `organizations`** (`:100-107`) executed once per member → **O(members × orgs)** per build, on two collections that are both unbounded.

**Impact**: This is the one query path in the repository that meets the stated CRITICAL definition ("an unbounded query that will grow without limit"): the audit read is unbounded *and* self-amplifying, and its result set is fully materialized and fully rendered. Every visit to `/admin` re-downloads the whole audit trail and eagerly builds a row per entry. It bites as the dev/demo project accumulates audited actions (every audited read/write appends). It is placed at **HIGH rather than CRITICAL** only because the surface is gated to the single `platform_owner_admin` role in a demo-scoped app; if this surface ships to real tenants, it should be raised to CRITICAL. Note that the in-flight bounded-query work explicitly stops at the PostgREST table seam ("cursor/`.range()` paging remains a separate slice"), so this is the known unfinished half of that slice, not a regression.

**Fix**: bound the RPCs the same way the tables are now bounded — add `p_limit`/`p_offset` (or a literal `limit 200`) to all four functions and return a total count if the UI needs it:

```sql
-- list_members_metadata.sql
create or replace function public.list_members_metadata(p_limit int default 200, p_offset int default 0)
...
      from public.memberships m
      join public.profiles p on p.user_id = m.user_id
     order by m.organization_id, m.user_id
     limit p_limit offset p_offset;
```

and hoist the org-name join out of the row loop:

```dart
final Map<String, String> orgNameById = <String, String>{
  for (final OrganizationSummary org in organizations) org.id: org.name,
};
// ...then in the members map:
organizationName: orgNameById[member.organizationId],
```

plus move the success arm to `ListView.builder`.

---

## MEDIUM — N+1 on the hottest read path: one roster RPC per distinct org, awaited serially inside `fetchMatters()`

**Location**: `lib/data/matters/supabase_matter_gateway.dart:79-91` (the loop), called from `:45-49`; consumer at `lib/features/search/presentation/search_cubit.dart:76-81`

**Issue**: `SupabaseMatterGateway.fetchMatters()` fetches the matter rows (1 query), then calls `_displayNamesFor(...)`, which is:

```dart
for (final String organizationId in organizationIds.toSet()) {
  final OrgOutcome<List<OrgMember>> outcome =
      await _orgGateway.listMembers(organizationId: organizationId);   // :79-81
  ...
}
```

A `grep` for `await` inside a `for` across all of `lib/data` and `lib/features` returns exactly this one site — so it is the only N+1 in the app. It dedupes by `.toSet()`, so the loop is O(distinct orgs) rather than O(rows), but the awaits are **serial**, so `fetchMatters()` costs `1 + N` sequential round-trips where `N` is the distinct-org count.

This matters because `fetchMatters()` is not a rare read: it is called by the matter list (`matter_list_screen.dart:64`), the matter details screen, the document vault and message list (both mount a `MatterCubit` purely for the reverse cross-link — `document_list_screen.dart:57-60`, `message_list_screen.dart:60-63`), and **every debounced search** (`search_cubit.dart:77`, alongside three other gateway fetches).

**Impact**: A matter-list open costs 2-4 serialized round-trips instead of 1; on a mobile link at ~150 ms RTT that is 150-450 ms of avoidable added latency before the list settles, and the roster data (which changes rarely) is re-read on every one of those fetches. Scales linearly with the number of orgs a user belongs to. Bounded and small in a single-org demo, which is why this is MEDIUM and not HIGH.

**Fix**: parallelize the loop and stop re-reading the roster per fetch:

```dart
final List<String> orgIds = organizationIds.toSet().toList();
final List<OrgOutcome<List<OrgMember>>> outcomes =
    await Future.wait(orgIds.map((id) => _orgGateway.listMembers(organizationId: id)));
```

A per-org roster cache (invalidated on `hydrate()`) removes the round-trips entirely.

---

## MEDIUM — No caching layer anywhere: every screen mount and every search re-fetches

**Location**: 20 `addPostFrameCallback(load)` sites, e.g. `lib/features/matters/presentation/matter_list_screen.dart:60-65`, `lib/features/documents/presentation/document_list_screen.dart:84-90`, `lib/features/messaging/presentation/message_list_screen.dart:87-93`, `lib/features/notifications/presentation/notification_feed_screen.dart:67`; `lib/features/search/presentation/search_cubit.dart:76-81`

**Issue**: `grep -rn "cache|Cache|_cached|memo" lib/data/` returns only comment prose — there is **no cache layer** in the data or domain layer. Every list cubit is constructed per route entry (`BlocProvider<T>(create: (ctx) => TCubit(serviceLocator<TGateway>()))` in each screen's `build`) and triggers its load from `initState`'s post-frame callback. Navigating away and back therefore re-issues the identical read. The search surface amplifies this: each debounced query re-fetches **all four** lists (`search_cubit.dart:76-81`, `.wait` over matters/documents/threads/attorneys) with no reuse of the lists the standalone screens just loaded.

**Impact**: Redundant network reads on every navigation; on a slow link a re-visited list shows a spinner for data the user saw seconds ago. In a demo over a fast link this is invisible; it is nonetheless the largest remaining data-layer win and the reason a "back to the list" navigation can feel slower than it should.

**Fix**: a short-TTL in-memory cache inside each gateway (the natural seam — the gateways already own row→VO mapping), or keep the list cubits alive at shell level instead of per-route. If a cache is added, remember the two write paths that must invalidate it (`sendMessage` re-reads at `supabase_message_gateway.dart:226-232`; `notification_cubit.markRead` re-loads at `notification_cubit.dart:136`).

---

## MEDIUM — Most list surfaces still build every row eagerly (viewport culling defeated)

**Location**: `matter_list_screen.dart:88,141`; `document_list_screen.dart:123,170`; `message_list_screen.dart:124,171`; `notification_feed_screen.dart:101,106`; `billing_invoices_screen.dart:80,85`; `attorney_search_screen.dart:71,125`; `ai_research_screen.dart:175,180`; `platform_admin_lists.dart:29`

**Issue**: `grep -rn "ListView(" lib/features` returns 22 sites against only 3 `ListView.builder`/`ListView.separated`. In each of the screens above the success arm is a `Column` whose children are `for (final X x in list) ...<Widget>[tile, SizedBox]`, nested inside a `ListView(children: <Widget>[...])` — i.e. the collection is fully expanded before the list ever lays out, so `SliverChildBuilderDelegate`'s culling never applies. Example (`document_list_screen.dart:165-178`):

```dart
builder: (BuildContext context, List<Document> documents) => documents.isEmpty
    ? empty
    : Column(children: <Widget>[
        for (final Document document in documents) ...<Widget>[
          _DocumentTile(document: document, onViewMatter: _matterTap(context, document, matters)),
          const SizedBox(height: LegalHubTheme.spaceSm),
        ],
      ]),
```

The in-flight refactor fixed exactly this shape on four surfaces by introducing the now-lazy `ViewStateList` (`lib/shared/widgets/view_state_list.dart`, `_SuccessListView` is a `ListView.builder`) and converting approvals/compliance/tasks/thread-detail to it — but these screens were not converted; they still call `ViewStateSwitch` directly and hand it an eager `Column`.

**Impact**: A list at the new 200-row cap constructs 200 rows — each an outlined `AppTile` card with a `Wrap`, a chip, and an `Icon` — on the first frame and again on every state change. Concretely: toggling a status filter chip on the matter list (`matter_list_screen.dart:99` → `cubit.setStatus` → new state) rebuilds all rows; marking one notification read (`notification_feed_screen.dart:110-111`) rebuilds the entire feed. Bounded by the 200 cap, so this is jank rather than a hang — which is what keeps it at MEDIUM rather than HIGH.

**Fix**: route these through the lazy `ViewStateList` with its `tileBuilder` (the same mechanical change the in-flight pass already applied to approvals/compliance/tasks), or wrap the row collection in a `ListView.builder`.

---

## MEDIUM — `MatterState.visibleMatters` recomputes the filtered projection twice per build

**Location**: `lib/features/matters/presentation/matter_state.dart:23-34`; `lib/features/matters/presentation/matter_list_screen.dart:137` and `:141`

**Issue**: `visibleMatters` is a getter that runs a `switch` and, on the success arm, allocates a fresh list on **every access**:

```dart
List<Matter> get visibleMatters => switch (matters) {
  ViewSuccess<List<Matter>>(data: final List<Matter> list) => status == null
      ? list
      : list.where((Matter matter) => matter.status == status).toList(growable: false),
  ...
};
```

The screen accesses it twice in the same build — once for the emptiness check (`:137 state.visibleMatters.isEmpty`) and once to drive the loop (`:141 for (final Matter matter in state.visibleMatters)`) — so each build performs two filter passes and two list allocations over the full matter list, on every filter toggle and every load.

**Impact**: 2× the filtering work plus a throwaway allocation per build. Cheap in absolute terms at the 200 cap, but it is pure waste on a user-facing interaction (filter toggling) and the fix is a single local. Rated MEDIUM only because it sits on an interactive path that already rebuilds the whole list.

**Fix**:

```dart
final List<Matter> visible = state.visibleMatters;   // once
...
visible.isEmpty ? empty : Column(children: [for (final Matter m in visible) ...])
```

---

## MEDIUM — Startup blocks the first frame on a network round-trip

**Location**: `lib/main.dart:36-49`; `lib/features/auth/presentation/auth_cubit.dart:89-102` and `:222-231`; `lib/data/orgs/supabase_membership_repository.dart:28-32`; `lib/data/auth/supabase_auth_api_impl.dart:88-89`

**Issue**: `main()` awaits, in order, `SharedPreferences.getInstance()` (`main.dart:36`), `localeCubit.load()` (`:39`), `themeCubit.load()` (`:43`), and `authCubit.restore()` (`:49`) — all **before** `runApp` at `:63`. The docs' claim that restore is awaited is correct. The auth restore itself is cheap (`SupabaseAuthApiImpl.restore()` is just `_toSnapshot(_client.currentSession)` — a synchronous read of the persisted session, no I/O), but the cubit's outcome path is not:

```dart
Future<void> restore() async {
  ...
  final AuthOutcome<Session> outcome = await _gateway.restore();
  await _applySessionOutcome(outcome);     // → _applyAuthenticatedSession
}
Future<void> _applyAuthenticatedSession(Session session) async {
  ...
  final MembershipHydrationResult result =
      await _membershipRepository.loadMemberships(userId: session.userId);  // network SELECT
```

`loadMemberships` issues a PostgREST read (`supabase_membership_repository.dart:32` → `listMyMemberships()`), so with a persisted session the app awaits a **network round-trip with no first frame rendered** — there is no splash and no `runApp`-then-restore ordering, so the user sees nothing until it resolves.

**Impact**: Cold start on a slow or unreachable network shows a blank/black screen until the HTTP client times out, instead of a restoring state. In the env-less/demo path the fake gateway resolves immediately so this does not bite the demo — which is why it is MEDIUM, not HIGH. The DI work itself is not a cost: `service_locator.dart` uses `registerLazySingleton` for every registration (`:144-547`), so nothing is constructed before `main` asks for it.

**Fix**: `runApp` first and let the router render `AuthStatus.restoring` (the status already exists — `auth_cubit.dart:94` — and the router already refreshes on the auth stream, `router.dart:107`), or race the hydration against a short timeout so the shell paints regardless:

```dart
runApp(...);                    // shell renders the restoring state
unawaited(authCubit.restore()); // hydration lands when it lands
```

---

## MEDIUM — Realtime: one channel for the app lifetime, never re-pointed at the open thread

**Location**: `lib/data/messaging/supabase_message_realtime_api_impl.dart:34-40` and `:92-121`; `lib/data/messaging/supabase_message_gateway.dart:271-277`; `lib/features/messaging/presentation/message_thread_detail_cubit.dart:73-88`; registration at `lib/app/service_locator.dart:434-441`

**Issue**: The realtime API is a **lazy singleton** (`registerLazySingleton<MessageGateway>` holding one `SupabaseMessageRealtimeApiImpl`), and it caches the first thread it is ever asked about:

```dart
Stream<SupabaseMessageRealtimeEvent> watchMessages(String threadId) {
  if (_threadId == null) {          // :35 — only ever opens for the FIRST thread
    _threadId = threadId;
    _open(threadId);
  }
  return _events.stream;
}
```

The channel name and filter are derived from that first id (`:97-109`, `filter: thread_id=eq.$threadId`). Opening a second thread therefore returns the **same** stream, still filtered to the first thread: live INSERTs for thread B are never delivered. The cubit's `unsubscribe()` (`:86-88`) cancels only its *stream subscription* and never calls `_realtimeApi.close()`, so the underlying channel is never torn down.

Two things are worth separating here. The **good** part: because the api impl is a shared singleton, there is no per-navigation channel leak — the "one leaked channel per navigation" failure mode does not exist in this codebase, and payload filtering is done server-side (`PostgresChangeFilter` with `thread_id=eq.…`, `:105-109`) rather than pushed to the client and filtered locally. The **bad** part: the single channel is pinned to whichever thread was opened first and is held for the whole app lifetime — a permanent subscription to a thread the user has left, plus broken live delivery for every other thread.

**Impact**: Stale realtime subscription retained for the process lifetime (one topic — bounded, not accumulating), and a functional defect: the second and subsequent threads opened in a session never receive live messages. Rated MEDIUM: it is not an accumulating leak, but it is a real lifecycle defect in the one subsystem the brief flags for leaks.

**Fix**: key the channel on the thread and close the previous one on switch:

```dart
Future<void> watchMessages(String threadId) async {
  if (_threadId == threadId) return;
  await _handle?.close();          // unsubscribe the previous topic
  _handle = null;
  _threadId = threadId;
  _open(threadId);
}
```

and have the cubit call `close()` (or a new `release(threadId)`) on dispose so the channel is not held after leaving messaging.

---

## LOW — O(n²) matter resolution inside the document and thread list builds

**Location**: `lib/features/documents/presentation/document_list_screen.dart:173` → `:195`; `lib/features/messaging/presentation/message_list_screen.dart:200`; `lib/features/matters/domain/matter_title_resolver.dart:15-22`

**Issue**: `resolveMatterByTitle(matters, ref)` is a linear scan (`for (final Matter matter in matters)`), and it is called **once per row, inside the build** — `_DocumentTile(document: document, onViewMatter: _matterTap(context, document, matters))` at `:171-174` where `_matterTap` calls the resolver at `:195`. That is **O(rows × matters)** per rebuild, in a tree that (per the finding above) rebuilds eagerly. At the 200-row cap the worst case is 200 × 200 = 40 000 string comparisons per rebuild.

**Impact**: Sub-millisecond in absolute terms at the capped scale, so this is genuinely LOW — but the complexity class is wrong (it should be O(rows)) and before the in-flight row cap it was O(n²) over an unbounded `n`. `matter_details_screen.dart:120 _findById` is the same linear-scan shape but runs once per build, so it is negligible.

**Fix**: build the index once per build (or in the cubit) instead of scanning per row:

```dart
final Map<String, Matter> byTitle = <String, Matter>{
  for (final Matter m in matters) m.title: m,
};
```

---

## LOW — 34 of 36 `BlocBuilder`s lack `buildWhen`; no high-frequency emitter drives them

**Location**: all 36 `BlocBuilder<` sites; the 2 that have `buildWhen` are `message_thread_detail_screen.dart:305` and `create_organization_screen.dart:110`. Notable unguarded ones: `message_thread_detail_screen.dart:100` (transcript), `document_list_screen.dart:101` and `:103` (nested), `message_list_screen.dart:104` and `:106` (nested), `search_screen.dart:141`

**Issue**: The quantified result is 34 of 36 `BlocBuilder`s without a `buildWhen` predicate (0 `BlocConsumer`, 0 `BlocSelector`, 5 `BlocListener`). The audit question is whether any of them sits on a high-frequency emitter, and the honest answer is **no**: a grep of `onChanged:` across `lib/features` shows no text field wired to a cubit per keystroke (the one search field is 300 ms-debounced at `search_screen.dart:112-119`, and the messaging composer's per-keystroke `setState` was removed by the in-flight pass in favour of a `ValueListenableBuilder` scoped to the send button, `:300-308`). So the unguarded builders rebuild on real state transitions, which is what they are for. Two concrete instances are still worth tightening:

- the transcript builder (`message_thread_detail_screen.dart:100`) has no `buildWhen`, so flipping `sending`/`sendError` rebuilds the whole transcript;
- `search_screen.dart:141` wraps the search `TextField` inside the `BlocBuilder`, so every search state transition rebuilds the field widget alongside the results.

**Impact**: Extra widget construction on state transitions; not user-visible at demo scale. Rated LOW deliberately — the "34 of 36" number reads worse than the actual consequence, because no cubit in this app emits at keystroke frequency.

**Fix**: add `buildWhen` on the transcript (`previous.messages != current.messages`), and hoist the `LegalHubTextField` above the `BlocBuilder` in `search_screen.dart`.

---

## LOW — Three redundant JSON decodes per notification-feed load

**Location**: `lib/features/notifications/presentation/notification_cubit.dart:64-68` and `:93-115`; `lib/features/notifications/data/shared_preferences_notification_prefs_store.dart:23-37`

**Issue**: `load()` builds the muted set with three separate awaits, each of which calls `store.read()` on the same store:

```dart
final Set<NotificationCategory> muted = <NotificationCategory>{
  if (!(await _readAppointmentToggle())) NotificationCategory.appointment,
  if (!(await _readActivityToggle()))    NotificationCategory.activity,
  if (!(await _readSystemToggle()))      NotificationCategory.system,
};
```

Each `_read*Toggle()` does its own `store.read()`, and the SharedPreferences implementation performs `getString` + `jsonDecode` + `NotificationPrefs.fromJson` per call — so the same small JSON payload is decoded three times per feed load. (`muted` being a `Set` for the subsequent `contains` at `:73` is correct — O(1), no finding there.)

**Impact**: Two redundant JSON decodes per feed load. Negligible in absolute cost (a three-boolean payload); LOW.

**Fix**:

```dart
final NotificationPrefs prefs = await _prefsStore?.read() ?? NotificationPrefs.defaults();
final Set<NotificationCategory> muted = <NotificationCategory>{
  if (!prefs.appointmentReminders) NotificationCategory.appointment,
  if (!prefs.activityUpdates) NotificationCategory.activity,
  if (!prefs.systemAlerts) NotificationCategory.system,
};
```

---

## LOW — `DateFormat` constructed per row per build

**Location**: `lib/shared/formatting/date_formatting.dart:14`; call sites `document_list_screen.dart:226`, `notification_feed_screen.dart:150`, plus the other `formatMediumDate` callers

**Issue**: The shared helper builds a new formatter on every call:

```dart
String formatMediumDate(AppLocalizations l10n, DateTime date) =>
    DateFormat.yMMMd(l10n.localeName).format(date);
```

`DateFormat.yMMMd(locale)` performs a locale lookup and parses the skeleton on construction; `intl` caches nothing for direct construction. Because the helper is called from inside per-row tile builds, a 200-row list performs 200 constructions per rebuild.

**Impact**: Roughly 200 formatter constructions per list rebuild — tens of microseconds each, so a few milliseconds at the cap. LOW; the fix is trivial and removes the allocation entirely.

**Fix**: memoize one formatter per locale:

```dart
final Map<String, DateFormat> _mediumDateCache = <String, DateFormat>{};
String formatMediumDate(AppLocalizations l10n, DateTime date) =>
    (_mediumDateCache[l10n.localeName] ??=
        DateFormat.yMMMd(l10n.localeName)).format(date);
```

---

## LOW — 2.3 MB of unused italic font shipped in the asset bundle

**Location**: `pubspec.yaml:39-50`; `assets/fonts/noto_sans/NotoSans-Italic-Variable.ttf`

**Issue**: All three declared families are genuinely used — `legalhub_theme.dart:183,257-260` selects `NotoSans` / `NotoNaskhArabic` by locale and `PlayfairDisplay` for headings — so the family list is not dead. But the **italic face** is: `NotoSans-Italic-Variable.ttf` is declared at `pubspec.yaml:43-44` and `grep -rn "FontStyle.italic" lib/` returns **zero** hits, so nothing in the app can ever select it. The four font files total ~5.0 MB; the unused italic file is 2 322 640 bytes — about **46% of the font payload** — and is bundled into the APK/IPA regardless.

**Impact**: App download/install size only; no runtime frame cost. LOW.

**Fix**: drop the `- asset: assets/fonts/noto_sans/NotoSans-Italic-Variable.ttf` / `style: italic` pair from `pubspec.yaml` (and the file), or add the italic style to the theme if it was intended.

---

## LOW — `Opacity` per roster row forces a per-row layer

**Location**: `lib/features/orgs/presentation/member_roster_screen.dart:373`

**Issue**: `_MemberRow.build` wraps each row in `Opacity(opacity: inactive ? 0.55 : 1, child: ListTile(...))`. A sub-1 opacity makes the engine push a `saveLayer` for that row; the opaque case (`1`) is skipped, so only suspended/removed rows pay. The rows are lazy (`ListView.separated`, `:77`), so only visible ones are affected. This is the only `Opacity`/`ClipRRect`/`BackdropFilter`/`ShaderMask` in `lib/` (a scoped grep finds no others, and there are no `Image.*` widgets at all, hence no missing `cacheWidth`/`cacheHeight`).

**Impact**: A save layer per dimmed visible row. Small and bounded; LOW. Dimming via colour alpha (`TextStyle`/`IconTheme` with a reduced-alpha foreground) achieves the same visual with no layer.

---

## What's done well

1. **Every list read at the table seam is now bounded and deterministically ordered.** `lib/data/list_query_guards.dart` centralises a single `boundedTableSelect` (`.order()` per table + hard `.limit(200)`), and all seven Supabase table api impls route through it (`supabase_matter_api_impl.dart:18-23`, `supabase_document_api_impl.dart`, `supabase_billing_api_impl.dart`, `supabase_notification_api_impl.dart`, `supabase_org_api_impl.dart`, `supabase_storage_api_impl.dart`, `supabase_message_api_impl.dart:31-45`). Verified by `grep -rn "\.select(" lib/` returning only the guard itself. This is the single most valuable perf change in the tree.
2. **A principled lazy-list primitive exists and is being adopted.** `lib/shared/widgets/view_state_list.dart` makes the success arm a `ListView.builder` (`_SuccessListView`, `:118-155`) while preserving the exact tile/gap/note rhythm, and it is generic over the item type so call sites pass only a per-item `tileBuilder`. Four surfaces already use it (`approvals_screen.dart:73-79`, `compliance_alerts_screen.dart:71-75`, `task_board_screen.dart:69-73`) and the messaging transcript is now lazy too (`message_thread_detail_screen.dart:162-180`). The remaining eager screens are a mechanical follow-up, not new design work.
3. **Controller and subscription lifecycle hygiene is complete.** All 20 `TextEditingController`s are disposed, including the generated OTP row (`otp_field_row.dart:44-51`) and the messaging composer's `FocusNode` (`message_thread_detail_screen.dart:267-272`); `search_screen.dart:126-131` cancels its debounce `Timer` *and* disposes its controller; `AuthCubit.close()` cancels its session subscription (`auth_cubit.dart:369-373`); `organization_hub_screen.dart:52-59` pairs `addListener` with `removeListener`. No undisposed `AnimationController`, no un-cancelled `Timer` outside the debounce, and no unpaired listener was found.
4. **`addPostFrameCallback` is used correctly — no repeat-fire.** All 20 call sites are in `initState` (fires once per mount) and are guarded by both a `mounted` check and a state predicate that prevents re-issuing an in-flight or already-loaded read, e.g. `member_roster_screen.dart:37-49` (`state is! OrgRosterLoaded && state is! OrgRosterLoading`) and `platform_admin_screen.dart:116-124`. The workspace sections use the same shape (`matter_documents_section.dart:54`, `matter_files_section.dart:55`, `matter_invoices_section.dart:55`, `matter_messages_section.dart:56`).
5. **DI is entirely lazy, so bootstrap does no speculative construction.** `lib/app/service_locator.dart` uses `registerLazySingleton` for every registration (`:144-547`) — nothing is built until `main` resolves it, and the app-scoped cubits are registered as singletons so the router and root `MaterialApp` observe the same instances (`main.dart:92-97` passes them as `.value`). The pre-`runApp` cost is therefore the three awaited `load()`/`restore()` calls, not DI.
6. **Local persistence is off the hot path.** All nine `lib/data/local/*` stores plus `ActiveOrgStore` read/write only a single scalar string (or one small JSON object), never in `build()`: `ActiveOrgStore` reads once at construction (`active_org_store.dart:41-42, 76-96`) and persists only on `select` (`:156-174`); the locale/theme/org-selection stores are `getString`/`setString` only. No large payload is JSON-encoded on the main isolate. Realtime payload filtering is also done server-side rather than client-side (`supabase_message_realtime_api_impl.dart:105-109`), and `muted` is a `Set` so the feed filter is O(1) per row (`notification_cubit.dart:64-74`).
7. **Generated l10n is correctly wired for tree-shaking.** `main.dart:118-119` passes both `AppLocalizations.localizationsDelegates` and `AppLocalizations.supportedLocales` to `MaterialApp.router`, and `l10n.yaml` sets `output-class`/`nullable-getter` with three ARB files (en/ar/tr). That is the configuration the Flutter build expects, so unused locale bundles are stripped at build time and the ~5,950 generated lines are subject to normal Dart tree-shaking — no dead-locale payload ships.

## Dimension score

**Performance: 6.5 / 10**

The strongest aspect is the data-access seam: every table read in the app is now bounded and deterministically ordered through one audited guard, and the in-flight pass added a reusable lazy-list primitive plus a genuine fix to the one real per-keystroke rebuild (the messaging composer). The weakest aspects are the two places the same discipline was not carried: the platform-admin RPCs still return unbounded result sets that are then rendered eagerly with an O(members × orgs) join, and the majority of list screens still expand their rows into a `Column` inside a non-lazy `ListView`, so viewport culling is defeated everywhere except the four converted surfaces. Startup blocking the first frame on a network round-trip and the complete absence of a caching layer are real but demo-tolerable costs. Nothing here is a user-visible hang or an accumulating leak in the demo path — the unbounded audit read is the one item that would escalate if the admin surface ever shipped to real tenants.
