# Hardcoded Values Inventory — 2026-10-24

Task 2 ledger for the LegalHub hardcoded-values remediation. Generated in the
isolated worktree `C:\flutter_projects\law_app_hardcoded` from `lib/**/*.dart`
(446 files), excluding the generated `lib/l10n/app_localizations*.dart`.

## How to read this ledger

The primary table is the exact output of
`dart run tool/hardcoded_inventory.dart`, with three review columns appended.
One row is one rule match on one source line. The generator records the **first**
match of each rule per line, so a line matched by two rules (the seven
`Duration(seconds: 15)` lines) produces two rows.

| Column | Meaning |
|---|---|
| `rule` | Census rule from the Task 2 brief. |
| `file:line` | Repository-relative source path and 1-based line. |
| `literal` | Matched source text. |
| `verdict` | `extract` = move to the canonical constant/token; `component-local` = name it in the owning file/widget; `leave` = semantic or canonical value, no change. |
| `wave` | Owning remediation task: `T3` motion, `T4` component-local, `T6` tables, `T7` RPC/edge, `T8` request timeout, `T11` server limits, `T15` TTL/poll, `T16–23` failure copy; `—` = no change. |
| `status` | `done` = landed in its wave; `deferred` = carried as a review minor; `n/a` = verdict `leave`. Reconciled by Task 28. |

The brief names three review columns; this ledger adds exactly those:
`verdict`, `wave`, and `status`.

## Census anchor cross-check

Anchor values are from the 2026-10-24 five-agent census (spec §10). "Primary"
is the tool output; "semantic" is a direct scan used only to diagnose gaps.

| Anchor | Census | Primary ledger | Semantic scan | Result |
|---|---|---|---|---|
| raw color matches | 53 | 0 `raw-color` + 1 `material-color` | 52 `Color(0x…)` + 1 `Colors.transparent` | **MATCH via exemption.** All 52 raw colors are in `lib/app/legalhub_theme.dart`, which the rule exempts as the token source. The one `Colors.transparent` is recorded as `material-color` and left. |
| `Duration(` | 24 | 24 Duration-rule rows on 17 unique lines | 24 occurrences; 7 unseen by the rules | **PARTIAL.** The 7 `timeout-15s` rows and 7 `duration-seconds` rows are the same seven 15-second lines (double-counted by design). The 7 uncovered occurrences are listed in the supplement. |
| table names | 10 names / 19 sites | 1 row / 1 name | 10 names / 19 wire sites | **DEVIATION.** The briefed `from('literal')` regex sees only the one direct `.from`; the parked seam refactor passes names to `_table`, `_matterTable`, `_searchCaller`, and `table:`. The 18 missing sites are in the supplement (primary + supplement = 19). |
| RPC names | 48 names / 51 sites | 5 rows / 2 names | 48 names / 54 literal occurrences = 51 call sites + 3 error-map literals | **DEVIATION.** The briefed regex matches only `.rpc('name')`; the seam refactor uses `_rpc`, `_rpcCaller`, `_runVoidRpc`, `_callRpc`, and `_rowsFrom`. The 49 missing occurrences are in the supplement. |
| edge functions | 3 | 1 row / 1 name | 3 names / 3 sites | **DEVIATION.** The other two are listed in the supplement. |
| failure-copy occurrences | 175 | 105 rows (same-line single-quoted) | 161 literal occurrences / 127 distinct literals in 27 files (Task 16 regex, which crosses lines) | **DEVIATION.** The 56 multiline occurrences are in the supplement (105 + 56 = 161). The briefed rule cannot cross lines. The census 175 is not reproducible with the specified five field names; Task 16 must re-census. |
| expected row count | "at least 700" | 154 primary rows | 286 rows including the supplement | **DEVIATION.** The census anchors total at most ~325 rows (53 + 24 + 19 + 51 + 3 + 175), so 700 is not attainable with these rules on this tree. |

## Triage decisions (rows that do not take the default verdict)

- `lib/features/auth/presentation/forgot_password/otp_field_row.dart:98`
  (`maxLength: 1`) → `component-local`, T4: a single-digit OTP field width,
  not a server-mirrored content cap.
- The nine `fontSize` rows in `lib/app/legalhub_text_theme.dart` → `leave`:
  the text theme is the canonical typography scale; wrapping the scale values
  in more constants only adds indirection. The two other `fontSize` rows are
  component-local (T4).
- `Duration(seconds: 60)` in `lib/features/storage/data/fake_storage_gateway.dart:122`
  → `extract`, T15: it is one of the three 60-second signed-URL TTLs that Task 15
  replaces, not a fixture delay.
- `Duration(seconds: 30)` in `ClipboardAutoClear`
  (`lib/features/orgs/presentation/invite_member_sheet.dart:27`) →
  `component-local`, T4: a component-only security delay, not network/poll/TTL;
  the plan has no dedicated task for it.
- `Duration(days: 1)` / `Duration(days: 365)` in `video_create_sheet.dart` →
  `component-local`, T4: UI scheduling defaults, not fixtures or network timers.
- `Duration(hours: 8)`, `Duration(milliseconds: 5)`, `Duration(hours: n)`,
  `Duration(hours: 1)` in fake gateways → `leave`: fixture data.
- `Duration(minutes: 2)` (`payment_cubit.dart:24`) → `extract`, T15: the payment
  poll timeout; Task 15 names it `kPaymentPollTimeout`.
- The seven 15-second lines are matched by both `timeout-15s` and
  `duration-seconds`; remediation counts them once (T8).
- Failure-copy dedupe and ARB keys stay in Task 16 as briefed; this ledger only
  records occurrences.
- `lib/data/list_query_guards.dart:19` (`kSupabaseListReadTimeout`) is now in
  Task 8’s modify list; its definition becomes
  `const Duration kSupabaseListReadTimeout = kSupabaseRequestTimeout;`
  (one source of truth). The row stays `extract` / T8.

## Tool deviations required to compile and pass the analyzer

- `const List<Rule>` → `final List<Rule>`: `RegExp` is not a const constructor,
  so the briefed code does not compile as written.
- `print(...)` → `stdout.writeln(...)`: the repo enables `avoid_print`.
- The four double-quoted patterns use `\x27` for the apostrophe so the
  `prefer_single_quotes` lint stays clean. Patterns and matching semantics are
  unchanged.

## Primary ledger (tool output)

| rule | file:line | literal | verdict | wave | status |
|---|---|---|---|---|---|
| raw-font-size | lib/app/legalhub_text_theme.dart:18 | `fontSize: 48` | leave | — | n/a |
| raw-font-size | lib/app/legalhub_text_theme.dart:25 | `fontSize: 30` | leave | — | n/a |
| raw-font-size | lib/app/legalhub_text_theme.dart:32 | `fontSize: 26` | leave | — | n/a |
| raw-font-size | lib/app/legalhub_text_theme.dart:39 | `fontSize: 22` | leave | — | n/a |
| raw-font-size | lib/app/legalhub_text_theme.dart:46 | `fontSize: 18` | leave | — | n/a |
| raw-font-size | lib/app/legalhub_text_theme.dart:52 | `fontSize: 16` | leave | — | n/a |
| raw-font-size | lib/app/legalhub_text_theme.dart:58 | `fontSize: 14` | leave | — | n/a |
| raw-font-size | lib/app/legalhub_text_theme.dart:64 | `fontSize: 12` | leave | — | n/a |
| raw-font-size | lib/app/legalhub_text_theme.dart:72 | `fontSize: 12` | leave | — | n/a |
| rpc-call | lib/data/admin/supabase_platform_admin_api_impl.dart:108 | `rpc('read_platform_audit'` | extract | T7 | done |
| rpc-call | lib/data/admin/supabase_platform_admin_api_impl.dart:151 | `rpc('read_org_audit'` | extract | T7 | done |
| rpc-call | lib/data/admin/supabase_platform_admin_api_impl.dart:158 | `rpc('read_org_audit'` | extract | T7 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:29 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:46 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:47 | `validationMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:50 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:80 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:101 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:106 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:115 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:116 | `validationMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:119 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:258 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/approvals/supabase_approval_gateway.dart:284 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/billing/supabase_billing_gateway.dart:45 | `userMessage: '` | extract | T16–23 | done |
| edge-invoke | lib/data/billing/supabase_payment_api_impl.dart:41 | `invoke('paymob-initiate'` | extract | T7 | done |
| failure-copy | lib/data/billing/supabase_payment_gateway.dart:37 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/billing/supabase_payment_gateway.dart:60 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/booking/supabase_booking_gateway.dart:45 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/booking/supabase_booking_gateway.dart:61 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/booking/supabase_booking_gateway.dart:82 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/booking/supabase_booking_gateway.dart:158 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/booking/supabase_booking_gateway.dart:175 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/booking/supabase_booking_gateway.dart:190 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/booking/supabase_booking_gateway.dart:195 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/booking/supabase_booking_gateway.dart:207 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/booking/supabase_booking_gateway.dart:213 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:31 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:55 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:87 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:102 | `validationMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:105 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:114 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:115 | `validationMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:118 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:269 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/compliance/supabase_compliance_gateway.dart:295 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/discovery/supabase_attorney_gateway.dart:223 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/discovery/supabase_attorney_gateway.dart:228 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/discovery/supabase_attorney_gateway.dart:233 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/discovery/supabase_attorney_gateway.dart:239 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/discovery/supabase_attorney_gateway.dart:249 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/documents/supabase_document_gateway.dart:57 | `userMessage: '` | extract | T16–23 | done |
| timeout-15s | lib/data/list_query_guards.dart:19 | `Duration(seconds: 15)` | extract | T8 | done |
| duration-seconds | lib/data/list_query_guards.dart:19 | `Duration(seconds: 15)` | extract | T8 | done |
| failure-copy | lib/data/matters/supabase_matter_gateway.dart:74 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/messaging/supabase_message_gateway.dart:66 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/messaging/supabase_message_gateway_messages.dart:31 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/messaging/supabase_message_gateway_messages.dart:75 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/messaging/supabase_message_gateway_messages.dart:78 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/messaging/supabase_message_gateway_messages.dart:112 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/messaging/supabase_message_gateway_messages.dart:160 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/messaging/supabase_message_gateway_messages.dart:173 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/messaging/supabase_message_gateway_messages.dart:176 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/notifications/supabase_notification_gateway.dart:48 | `userMessage: '` | extract | T16–23 | done |
| rpc-call | lib/data/orgs/supabase_org_api_impl.dart:320 | `rpc('read_org_audit'` | extract | T7 | done |
| rpc-call | lib/data/orgs/supabase_org_api_impl.dart:327 | `rpc('read_org_audit'` | extract | T7 | done |
| failure-copy | lib/data/research/supabase_research_gateway.dart:81 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/research/supabase_research_gateway.dart:107 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/research/supabase_research_gateway.dart:340 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/research/supabase_research_gateway.dart:345 | `userMessage: '` | extract | T16–23 | done |
| table-from | lib/data/storage/supabase_storage_api_impl.dart:49 | `from('matters')` | extract | T6 | done |
| timeout-15s | lib/data/storage/supabase_storage_api_impl.dart:53 | `Duration(seconds: 15)` | extract | T8 | done |
| duration-seconds | lib/data/storage/supabase_storage_api_impl.dart:53 | `Duration(seconds: 15)` | extract | T8 | done |
| timeout-15s | lib/data/storage/supabase_storage_api_impl.dart:87 | `Duration(seconds: 15)` | extract | T8 | done |
| duration-seconds | lib/data/storage/supabase_storage_api_impl.dart:87 | `Duration(seconds: 15)` | extract | T8 | done |
| timeout-15s | lib/data/storage/supabase_storage_api_impl.dart:94 | `Duration(seconds: 15)` | extract | T8 | done |
| duration-seconds | lib/data/storage/supabase_storage_api_impl.dart:94 | `Duration(seconds: 15)` | extract | T8 | done |
| timeout-15s | lib/data/storage/supabase_storage_api_impl.dart:101 | `Duration(seconds: 15)` | extract | T8 | done |
| duration-seconds | lib/data/storage/supabase_storage_api_impl.dart:101 | `Duration(seconds: 15)` | extract | T8 | done |
| failure-copy | lib/data/storage/supabase_storage_gateway.dart:39 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/storage/supabase_storage_gateway.dart:74 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/storage/supabase_storage_gateway.dart:83 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/storage/supabase_storage_gateway.dart:133 | `userMessage: '` | extract | T16–23 | done |
| duration-seconds | lib/data/storage/supabase_storage_gateway.dart:143 | `Duration(seconds: 60)` | extract | T15 | done |
| failure-copy | lib/data/storage/supabase_storage_gateway.dart:244 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/storage/supabase_storage_gateway.dart:253 | `userMessage: '` | extract | T16–23 | done |
| timeout-15s | lib/data/supabase_seam.dart:41 | `Duration(seconds: 15)` | extract | T8 | done |
| duration-seconds | lib/data/supabase_seam.dart:41 | `Duration(seconds: 15)` | extract | T8 | done |
| timeout-15s | lib/data/supabase_seam.dart:53 | `Duration(seconds: 15)` | extract | T8 | done |
| duration-seconds | lib/data/supabase_seam.dart:53 | `Duration(seconds: 15)` | extract | T8 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:34 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:35 | `validationMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:38 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:47 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:78 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:85 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:97 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:102 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:111 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:116 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:125 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:126 | `validationMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/tasks/supabase_task_gateway.dart:129 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:32 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:74 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:113 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:131 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:144 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:145 | `validationMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:148 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:157 | `deniedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:158 | `validationMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:161 | `failedMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:279 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:291 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:296 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/data/video/supabase_video_gateway.dart:329 | `userMessage: '` | extract | T16–23 | done |
| max-length | lib/features/admin/presentation/attorney_admin_form.dart:113 | `maxLength: 160` | extract | T11 | done |
| max-length | lib/features/admin/presentation/attorney_admin_form.dart:121 | `maxLength: 120` | extract | T11 | done |
| max-length | lib/features/admin/presentation/attorney_admin_form.dart:175 | `maxLength: 2000` | extract | T11 | done |
| failure-copy | lib/features/approvals/data/fake_approvals_gateway.dart:177 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/approvals/data/fake_approvals_gateway.dart:182 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/approvals/data/fake_approvals_gateway.dart:187 | `userMessage: '` | extract | T16–23 | done |
| max-length | lib/features/approvals/presentation/approval_detail_sheet.dart:211 | `maxLength: 2000` | extract | T11 | done |
| failure-copy | lib/features/auth/presentation/auth_cubit_hydration.dart:141 | `userMessage: '` | extract | T16–23 | done |
| max-length | lib/features/auth/presentation/forgot_password/otp_field_row.dart:98 | `maxLength: 1` | component-local | T4 | done |
| duration-seconds | lib/features/billing/presentation/payment_cubit.dart:23 | `Duration(seconds: 5)` | extract | T15 | done |
| failure-copy | lib/features/compliance/data/fake_compliance_gateway.dart:172 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/compliance/data/fake_compliance_gateway.dart:177 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/compliance/data/fake_compliance_gateway.dart:182 | `userMessage: '` | extract | T16–23 | done |
| max-length | lib/features/compliance/presentation/compliance_alert_detail_sheet.dart:191 | `maxLength: 2000` | extract | T11 | done |
| failure-copy | lib/features/discovery/data/fake_attorney_admin_gateway.dart:22 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/discovery/data/fake_attorney_gateway.dart:85 | `userMessage: '` | extract | T16–23 | done |
| raw-font-size | lib/features/discovery/presentation/attorney_profile_surface.dart:82 | `fontSize: 28` | component-local | T4 | done |
| motion-200-300ms | lib/features/discovery/presentation/discovery_cubit.dart:27 | `Duration(milliseconds: 300)` | extract | T3 | done |
| material-color | lib/features/home/presentation/home_screen.dart:116 | `Colors.transparent` | leave | — | n/a |
| motion-200-300ms | lib/features/onboarding/presentation/onboarding_screen.dart:128 | `Duration(milliseconds: 300)` | extract | T3 | done |
| motion-200-300ms | lib/features/onboarding/presentation/onboarding_screen.dart:132 | `Duration(milliseconds: 200)` | extract | T3 | done |
| motion-200-300ms | lib/features/onboarding/presentation/onboarding_screen.dart:178 | `Duration(milliseconds: 300)` | extract | T3 | done |
| duration-seconds | lib/features/orgs/presentation/invite_member_sheet.dart:27 | `Duration(seconds: 30)` | component-local | T4 | done |
| motion-200-300ms | lib/features/search/presentation/search_surface.dart:44 | `Duration(milliseconds: 300)` | extract | T3 | done |
| duration-seconds | lib/features/storage/data/fake_storage_gateway.dart:122 | `Duration(seconds: 60)` | extract | T15 | done |
| duration-seconds | lib/features/storage/domain/storage_gateway.dart:54 | `Duration(seconds: 60)` | extract | T15 | done |
| failure-copy | lib/features/storage/presentation/file_transfer_cubit.dart:47 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/storage/presentation/file_transfer_cubit.dart:59 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/storage/presentation/file_transfer_cubit.dart:134 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/storage/presentation/file_transfer_cubit.dart:139 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/tasks/data/fake_task_gateway.dart:131 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/tasks/data/fake_task_gateway.dart:181 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/tasks/data/fake_task_gateway.dart:211 | `userMessage: '` | extract | T16–23 | done |
| failure-copy | lib/features/video/data/fake_video_gateway.dart:143 | `userMessage: '` | extract | T16–23 | done |
| raw-font-size | lib/features/video/presentation/video_create_sheet.dart:227 | `fontSize: 12` | component-local | T4 | done |
| failure-copy | lib/shared/state/write_gate.dart:18 | `userMessage: '` | extract | T16–23 | done |

## Supplement — census rows the briefed regexes miss

These rows are **not** tool output. They are the semantic-scan results recorded
so the ledger is complete for later tasks; every row carries the same
verdict/wave/status contract. They are the evidence for the deviations above.
Every path is repository-relative. Multiline literals are joined with a single
space and truncated at 120 chars; `file:line` points at the field name, not the
first string line.

### Uncovered `Duration(` occurrences (7)

| rule | file:line | literal | verdict | wave | status |
|---|---|---|---|---|---|
| duration-other (supplement) | lib/data/auth/fake_auth_gateway.dart:99 | `Duration(hours: 8)` | leave | — | n/a |
| duration-other (supplement) | lib/features/auth/data/fake_sign_up_gateway.dart:13 | `Duration(milliseconds: 5)` | leave | — | n/a |
| duration-other (supplement) | lib/features/billing/presentation/payment_cubit.dart:24 | `Duration(minutes: 2)` | extract | T15 | done |
| duration-other (supplement) | lib/features/messaging/data/fake_message_gateway.dart:101 | `Duration(hours: n)` | leave | — | n/a |
| duration-other (supplement) | lib/features/video/data/fake_video_gateway.dart:86 | `Duration(hours: 1)` | leave | — | n/a |
| duration-other (supplement) | lib/features/video/presentation/video_create_sheet.dart:89 | `Duration(days: 1)` | component-local | T4 | done |
| duration-other (supplement) | lib/features/video/presentation/video_create_sheet.dart:94 | `Duration(days: 365)` | component-local | T4 | done |

### Table wire sites (18; the 19th is the primary `from('matters')` row)

| rule | file:line | literal | verdict | wave | status |
|---|---|---|---|---|---|
| table-from (supplement) | lib/data/billing/supabase_billing_api_impl.dart:65 | `'billing_invoices'` | extract | T6 | done |
| table-from (supplement) | lib/data/billing/supabase_billing_api_impl.dart:66 | `'billing_invoices'` | extract | T6 | done |
| table-from (supplement) | lib/data/booking/supabase_booking_api_impl.dart:66 | `'consultation_slots'` | extract | T6 | done |
| table-from (supplement) | lib/data/documents/supabase_document_api_impl.dart:83 | `'documents'` | extract | T6 | done |
| table-from (supplement) | lib/data/documents/supabase_document_api_impl.dart:84 | `'documents'` | extract | T6 | done |
| table-from (supplement) | lib/data/documents/supabase_document_api_impl.dart:122 | `'documents'` | extract | T6 | done |
| table-from (supplement) | lib/data/matters/supabase_matter_api_impl.dart:59 | `'matters'` | extract | T6 | done |
| table-from (supplement) | lib/data/matters/supabase_matter_api_impl.dart:99 | `'matters'` | extract | T6 | done |
| table-from (supplement) | lib/data/messaging/supabase_message_api_impl.dart:120 | `'message_threads'` | extract | T6 | done |
| table-from (supplement) | lib/data/messaging/supabase_message_api_impl.dart:121 | `'message_threads'` | extract | T6 | done |
| table-from (supplement) | lib/data/messaging/supabase_message_api_impl.dart:147 | `'message_threads'` | extract | T6 | done |
| table-from (supplement) | lib/data/messaging/supabase_message_api_impl.dart:173 | `'messages'` | extract | T6 | done |
| table-from (supplement) | lib/data/messaging/supabase_message_realtime_api_impl.dart:123 | `'messages'` | extract | T6 | done |
| table-from (supplement) | lib/data/notifications/supabase_notification_api_impl.dart:52 | `'notifications'` | extract | T6 | done |
| table-from (supplement) | lib/data/orgs/supabase_org_api_impl.dart:142 | `'memberships'` | extract | T6 | done |
| table-from (supplement) | lib/data/storage/supabase_storage_api_impl.dart:130 | `'files'` | extract | T6 | done |
| table-from (supplement) | lib/data/storage/supabase_storage_api_impl.dart:131 | `'files'` | extract | T6 | done |
| table-from (supplement) | lib/data/tasks/supabase_task_api_impl.dart:75 | `'tasks'` | extract | T6 | done |

### RPC name literals (49; the 5 primary rows cover the other 5 occurrences)

| rule | file:line | literal | verdict | wave | status |
|---|---|---|---|---|---|
| rpc-call (supplement) | lib/data/admin/supabase_platform_admin_api_impl.dart:44 | `'list_organizations_metadata'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/admin/supabase_platform_admin_api_impl.dart:64 | `'list_members_metadata'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/admin/supabase_platform_admin_api_impl.dart:84 | `'suspend_membership_platform'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/admin/supabase_platform_admin_api_impl.dart:93 | `'reactivate_membership_platform'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/admin/supabase_platform_admin_api_impl.dart:100 | `'delete_demo_account'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/approvals/supabase_approval_api_impl.dart:44 | `'list_approval_requests'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/approvals/supabase_approval_api_impl.dart:84 | `'create_approval_request'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/approvals/supabase_approval_api_impl.dart:109 | `'decide_approval_request'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/approvals/supabase_approval_api_impl.dart:120 | `'cancel_approval_request'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/billing/supabase_payment_api_impl.dart:64 | `'get_invoice_payment_status'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/booking/supabase_booking_api_impl.dart:92 | `'book_consultation'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/compliance/supabase_compliance_api_impl.dart:45 | `'list_compliance_alerts'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/compliance/supabase_compliance_api_impl.dart:86 | `'create_compliance_alert'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/compliance/supabase_compliance_api_impl.dart:109 | `'acknowledge_compliance_alert'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/compliance/supabase_compliance_api_impl.dart:118 | `'resolve_compliance_alert'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/discovery/supabase_attorney_api_impl.dart:46 | `'list_attorney_profiles'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/discovery/supabase_attorney_api_impl.dart:81 | `'get_attorney_profile'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/discovery/supabase_attorney_api_impl.dart:108 | `'create_attorney_profile'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/discovery/supabase_attorney_api_impl.dart:144 | `'update_attorney_profile'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/discovery/supabase_attorney_api_impl.dart:163 | `'deactivate_attorney_profile'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/matters/supabase_matter_write_api_impl.dart:60 | `'create_matter'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/messaging/supabase_message_api_impl.dart:203 | `'send_message'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/notifications/supabase_notification_api_impl.dart:90 | `'mark_notifications_read'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:67 | `'create_organization'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:92 | `'list_org_members_metadata'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:114 | `'list_matter_assignable_members'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:164 | `'invite_member'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:193 | `'change_member_role'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:205 | `'suspend_membership'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:216 | `'reactivate_membership'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:227 | `'remove_membership'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:237 | `'resend_invitation'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:258 | `'revoke_invitation'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:265 | `'delete_my_account'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/orgs/supabase_org_api_impl.dart:272 | `'accept_invitation'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/research/supabase_research_api_impl.dart:111 | `'list_research_runs'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/research/supabase_research_api_impl.dart:116 | `'list_research_runs'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/research/supabase_research_api_impl.dart:127 | `'list_research_findings'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/research/supabase_research_api_impl.dart:130 | `'list_research_findings'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/storage/supabase_storage_api_impl.dart:235 | `'register_matter_file'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/tasks/supabase_task_api_impl.dart:99 | `'create_task'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/tasks/supabase_task_api_impl.dart:111 | `'advance_task_status'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/tasks/supabase_task_api_impl.dart:119 | `'assign_task'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/tasks/supabase_task_api_impl.dart:127 | `'acknowledge_task'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/video/supabase_video_api_impl.dart:61 | `'list_video_sessions'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/video/supabase_video_api_impl.dart:64 | `'list_video_sessions'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/video/supabase_video_api_impl.dart:77 | `'create_video_session'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/video/supabase_video_api_impl.dart:137 | `'mark_video_session_live'` | extract | T7 | done |
| rpc-call (supplement) | lib/data/video/supabase_video_api_impl.dart:146 | `'end_video_session'` | extract | T7 | done |

### Edge-function literals (2; the third is the primary `paymob-initiate` row)

| rule | file:line | literal | verdict | wave | status |
|---|---|---|---|---|---|
| edge-invoke (supplement) | lib/data/research/supabase_research_api_impl.dart:65 | `'research-analyze'` | extract | T7 | done |
| edge-invoke (supplement) | lib/data/video/supabase_video_api_impl.dart:98 | `'video-token'` | extract | T7 | done |

### Multiline failure copy (56; the 105 primary rows cover the same-line occurrences)

| rule | file:line | literal | verdict | wave | status |
|---|---|---|---|---|---|
| failure-copy (supplement) | lib/data/approvals/supabase_approval_gateway.dart:48 | `unavailableMessage: 'Approvals are temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/approvals/supabase_approval_gateway.dart:74 | `deniedMessage: 'You do not have permission to create approval requests.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/approvals/supabase_approval_gateway.dart:76 | `validationMessage: 'The request could not be created. Check the details and try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/approvals/supabase_approval_gateway.dart:78 | `unavailableMessage: 'Creating the request is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/approvals/supabase_approval_gateway.dart:102 | `validationMessage: 'The request could not be decided. It may no longer be pending, or the note is missing.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/approvals/supabase_approval_gateway.dart:104 | `unavailableMessage: 'Deciding the request is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/approvals/supabase_approval_gateway.dart:117 | `unavailableMessage: 'Cancelling the request is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/booking/supabase_booking_gateway.dart:164 | `userMessage: 'Available times are temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/booking/supabase_booking_gateway.dart:201 | `userMessage: 'The booking details are invalid. Check them and try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/compliance/supabase_compliance_gateway.dart:49 | `deniedMessage: 'You do not have permission to view compliance alerts.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/compliance/supabase_compliance_gateway.dart:51 | `validationMessage: 'Unable to load compliance alerts. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/compliance/supabase_compliance_gateway.dart:53 | `unavailableMessage: 'Compliance alerts are temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/compliance/supabase_compliance_gateway.dart:81 | `deniedMessage: 'Only a partner or compliance officer can create alerts.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/compliance/supabase_compliance_gateway.dart:83 | `validationMessage: 'The alert could not be created. Check the details and try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/compliance/supabase_compliance_gateway.dart:85 | `unavailableMessage: 'Creating the alert is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/compliance/supabase_compliance_gateway.dart:100 | `deniedMessage: 'Only an active organization member can acknowledge alerts.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/compliance/supabase_compliance_gateway.dart:103 | `unavailableMessage: 'Acknowledging the alert is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/compliance/supabase_compliance_gateway.dart:116 | `unavailableMessage: 'Resolving the alert is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/messaging/supabase_message_gateway_messages.dart:76 | `unavailableMessage: 'Threads are temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/messaging/supabase_message_gateway_messages.dart:156 | `deniedMessage: 'You do not have permission to send messages on this thread.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/messaging/supabase_message_gateway_messages.dart:158 | `unavailableMessage: 'Sending is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/messaging/supabase_message_gateway_messages.dart:174 | `unavailableMessage: 'Messages are temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/notifications/supabase_notification_gateway.dart:163 | `userMessage: 'Notifications are temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/research/supabase_research_gateway.dart:51 | `userMessage: 'Enter a question between 2 and 500 characters and select an organization.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/research/supabase_research_gateway.dart:313 | `userMessage: 'The selected context is too large. Remove documents and try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/research/supabase_research_gateway.dart:319 | `userMessage: 'AI research is not configured for this deployment. No analysis was run.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/research/supabase_research_gateway.dart:334 | `userMessage: 'The AI provider returned an unexpected response. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/tasks/supabase_task_gateway.dart:36 | `unavailableMessage: 'Tasks are temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/tasks/supabase_task_gateway.dart:72 | `deniedMessage: 'You do not have permission to create tasks on this matter.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/tasks/supabase_task_gateway.dart:74 | `validationMessage: 'The task could not be created. Check the title and try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/tasks/supabase_task_gateway.dart:76 | `unavailableMessage: 'Creating the task is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/tasks/supabase_task_gateway.dart:98 | `validationMessage: 'The task cannot move to that status. It may already be done.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/tasks/supabase_task_gateway.dart:100 | `unavailableMessage: 'Updating the task is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/tasks/supabase_task_gateway.dart:112 | `validationMessage: 'That person cannot be assigned this task. Choose an active member of the organization.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/tasks/supabase_task_gateway.dart:114 | `unavailableMessage: 'Re-assigning the task is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/tasks/supabase_task_gateway.dart:127 | `unavailableMessage: 'Acknowledging the task is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:48 | `deniedMessage: 'You do not have permission to view video consultations.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:50 | `validationMessage: 'Unable to load video consultations. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:52 | `unavailableMessage: 'Video consultations are temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:54 | `failedMessage: 'Unable to load video consultations. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:91 | `deniedMessage: 'Only a partner or attorney can schedule a video consultation.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:93 | `validationMessage: 'The consultation could not be scheduled. Check the details and try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:95 | `unavailableMessage: 'Scheduling a consultation is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:97 | `failedMessage: 'Unable to schedule the consultation. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:125 | `deniedMessage: 'You do not have permission to join this consultation.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:127 | `validationMessage: 'The consultation is not available to join right now.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:129 | `unavailableMessage: 'Video calls are temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:146 | `unavailableMessage: 'Starting the consultation is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:159 | `unavailableMessage: 'Ending the consultation is temporarily unavailable. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/data/video/supabase_video_gateway.dart:301 | `userMessage: 'Video calls are not configured for this deployment. No call was started.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/features/auth/data/supabase_password_recovery_gateway.dart:57 | `userMessage: 'We couldn\'t complete that request. Please try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/features/messaging/presentation/message_thread_detail_cubit.dart:198 | `userMessage: 'Message is too long (max $maxMessageLength characters).'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/features/research/presentation/ai_research_cubit.dart:73 | `userMessage: 'Enter a question between 2 and 500 characters and select an organization.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/features/tasks/data/fake_task_gateway.dart:103 | `userMessage: 'The task could not be created. Check the title and try again.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/features/tasks/data/fake_task_gateway.dart:141 | `userMessage: 'The task cannot move to that status. It may already be done.'` | extract | T16–23 | done |
| failure-copy (supplement) | lib/features/video/data/fake_video_gateway.dart:99 | `userMessage: 'Video calls are not configured for this deployment. No call was started.'` | extract | T16–23 | done |

**Row count:** 154 primary + 132 supplement = **286** rows.

## Task 28 close-out (2026-10-24)

Reconciled after Tasks 1–27. The per-row `status` column now reflects the
landed work: `extract` rows are `done`, `component-local` rows are `done`, and
the triaged `leave` rows remain `n/a`.

| Final status | Rows | Composition |
|---|---:|---|
| `done` | 272 | 266 `extract` + 6 `component-local` |
| `deferred` | 0 | No value row was deferred |
| `leave` | 14 | 9 text-theme font sizes, 4 fixture durations, 1 material color |
| **Total** | **286** | 154 primary + 132 supplement |

Every `extract` row has landed in its owning wave: motion/theme (T3–T5), wire
names (T6–T7), request timeout (T8), deep links/config (T9–T10), server limits
(T11), pagination (T12), approval/research/audit wire codes (T13–T14),
TTL/poll/MIME/locale (T15), and app-owned failure copy (T16–T23). The six
`component-local` rows are the OTP width, two font sizes, the clipboard delay,
and the two video-schedule durations named in their component files.

### Deferred review minors (not un-remediated value rows)

38 review minors are carried in `progress.md`; 34 are itemized there:

- Task 6 (2): wire test asserts table-list length, not exact values; SHA-256
  baseline note vs CRLF-normalized realtime file.
- Task 7 (2): wire test pins RPC count, not the 48 exact values; edge-site
  lines are baseline coordinates.
- Task 9 (3): scheme resolved from three sources; recovery producer doc names
  the production URI; missing negative dev-parse test.
- Task 11 (1): attorney city 120 uses `kAttorneyNameMaxLength`.
- Task 12 (1): stale "mirrored 30-row" doc comments.
- Task 14a (3): unused-constant list inaccurate; formatting reflows
  undercounted; tests still pin raw SQLSTATE wire strings (intentional).
- Task 14b (4): generic-copy leg relies on an existing screen test; wire-code
  prose remains in doc comments; report cites pre-edit line numbers; test fake
  retains `limit=20` / raw wire strings.
- Task 15 (1): TTL value duplicated in test doubles/doc comment.
- Task 17 (5): ordinary `task_read_failed` remains unkeyed and its keyed branch
  untested; `messageArgs` unused/absent from props; non-pilot keys fell back to
  `stateError` until Task 23; profile restore-failure test pins English producer
  copy; progress ledger carried the old pilot ruling.
- Batch 18 (2): mapper doc says only the pilot is mapped; ledger Task 17 pilot
  note stale.
- Batch 19 (1): EN uses an ICU placeholder form for `maxMessageLength`
  (behavior identical).
- Batch 20 (3): report calls diagnostic-only literals user-facing; org/admin
  seam docs say "user-facing" when unread; two discovery keys are not surfaced.
- Batch 21 (2): file-too-large copy lost the 25 MB detail (TSV literal); mapper
  header says only the pilot is mapped.
- Batch 22 (4): mapper header stale; recovery copy uses the new draft; one
  interpolated key is placeholderized (EN renders equal); Batch 22 pre-empted
  the Task 23 exhaustive test.

Task 23 (2), Task 24 (1), and Task 25 (1) are counted in `progress.md` without
itemized text there; their itemization lives in
`docs/hardcoded_values_closeout_2026-10-24.md` §6. These are
review/documentation notes; no ledger value row depends on them.
