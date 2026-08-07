# Plan: Invite-side share-link generation (2026-08-07)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> **produce side** of the accept-invitation deep link — the follow-up
> recorded at the P3 §13 Q2 partial resolution and the Phase 4.1 close
> (`docs/p4_1_completion_evidence_2026-08-07.md` §3/§8). The **consume
> side** (parser → `PendingAcceptInviteStore` → listener → accept screen
> pre-fill) already shipped as Phase 4.1 D-P34.2 (`95c1676`..`58134f6`,
> merged `13543ed`). This slice closes the loop: the inviter can hand the
> invitee a full deep link instead of a bare token.
>
> **Status: PLAN — 2026-08-07, client-only (no schema/RLS change, no new
> dependency, no platform config).** Decisions D-IS1..D-IS5 ratified by
> autonomy; owner ratification may flip any of them before Task 1 starts.
> Owner-side device smoke of the produced link is recorded as a checklist
> item, not claimed as verified (INSTRUCTIONS.md §1.3 #5).

---

## 1. Problem / gap (verified, not assumed)

`invite_member` returns a **one-time token** (server stores only its sha-256
hash). The shipped P3.3 invite sheet (`lib/features/orgs/presentation/
invite_member_sheet.dart` `_buildToken`) shows the token once with a
**Copy token** button (`Clipboard.setData` + `inviteTokenCopied` snackbar) —
the paste surface. The accept side accepts both a pasted token and a deep
link `com.legalhub.app://accept-invite?token=<one-time-token>` (D-P34.2).

**The gap:** nothing *produces* that deep link. `lib/` contains only the
parser/listener/store (consume side); a grep for `accept-invite` in `lib/`
finds no URI builder. So the "share link" delivery promise in P3 §2 /
§13 Q2 is half-consummated — the invitee must copy-paste a bare token
instead of tapping a link.

## 2. Goal

A **copy-share button** on the invite-success sheet that copies the full
deep link `com.legalhub.app://accept-invite?token=<token>` to the clipboard
(with a distinct localized confirmation), built from the **same constants**
the parser uses, so every produced link round-trips through
`AppLinkParser.parse` as `AcceptInviteIntent` with the identical token.

## 3. Design decisions (D-IS1..D-IS5)

| # | Decision | Recommendation | Why / alternative |
|---|---|---|---|
| D-IS1 | **Builder location** | Add `AppLinkParser.acceptInviteUri(String token)` (static) alongside `parse` — the parser already owns `appScheme` + `acceptInviteHost` and documents the URI contract | One source of truth; round-trip pin is trivially expressible. Alternative (separate `AcceptInviteLinkBuilder` class) adds a file + indirection for one URI — rejected |
| D-IS2 | **Share semantics** | **Copy-to-clipboard** of the full link with a new snackbar; **no** `share_plus`/native share sheet | Matches the existing token-copy pattern; zero new deps (flutter/services already imported); the user's "copy-share button" wording. Native share sheet is a later optional enhancement (would need a pubspec + platform review) |
| D-IS3 | **Token exposure** | The link embeds exactly the one-shot token the sheet already displays; built **on-demand in the button handler**, never stored/logged | Same trust model as the existing token copy (contract §8 — transient, never persisted); no new exposure, no auto-generation |
| D-IS4 | **Dependencies** | None added — `Clipboard` from `flutter/services` (already imported); consume side (app_links) unchanged | Confirmed the produced URI needs no platform config: the Android intent filter + iOS `CFBundleURLTypes` for `com.legalhub.app` are already registered (Phase 4.1) |
| D-IS5 | **Empty-token guard** | `acceptInviteUri` trims and throws `ArgumentError` on blank — mirrors the parse-side never-mint guard | The button is only reachable with a real invite token, so this is a defensive invariant (pinned by a unit test), not a user path |

## 4. Layers touched

| Layer | File | Change |
|---|---|---|
| deep-link domain (pure) | `lib/app/deep_link/app_link_parser.dart` | `+acceptInviteUri(String)` static builder (scheme/host reuse, trim + empty guard) |
| presentation (invite sheet) | `lib/features/orgs/presentation/invite_member_sheet.dart` | `+` "Copy invite link" button in `_buildToken` + `_copyShareLink` handler + snackbar |
| l10n | `lib/l10n/app_en.arb`, `app_ar.arb`, `app_tr.arb` + generated l10n | `+2` keys ×3 locales (`inviteShareLink`, `inviteShareLinkCopied`) |
| tests | `test/app/deep_link/app_link_parser_test.dart`, `test/features/orgs/presentation/invite_member_sheet_test.dart` | builder unit pins + widget pins |

**State shape:** none new — the sheet's existing `_invite` (one-shot
`InviteResult`) is the only state the button reads; the link is derived
on-demand, never stored.

## 5. Data flow

```
invite success (_invite set)
  → button tap
  → AppLinkParser.acceptInviteUri(token)          // pure: trim + guard
  → com.legalhub.app://accept-invite?token=<token>
  → Clipboard.setData(text: link)                  // flutter/services
  → snackbar inviteShareLinkCopied
Invitee: pastes link / taps link on device
  → (consume side, already shipped) parser → store → accept screen pre-fill
```

The produced link round-trips: `parse(acceptInviteUri(t)).token == t`
(pinned as a unit test).

## 6. Testing strategy

- **Unit (`app_link_parser_test.dart`, +3–4):** `acceptInviteUri('abc')` →
  `com.legalhub.app://accept-invite?token=abc` (scheme/host from the
  constants, not literals duplicated in the test where avoidable);
  **round-trip** `parse(acceptInviteUri(t))` is `AcceptInviteIntent(t)`
  (identical token); trimmed input is trimmed; blank/empty input throws
  `ArgumentError` (D-IS5).
- **Widget (`invite_member_sheet_test.dart`, +2):** token state renders the
  "Copy invite link" button; tap → the mocked `Clipboard.setData` channel
  (`setMockMethodCallHandler`, the existing copy-token seam at line ~131)
  carries the **full URI** and the `inviteShareLinkCopied` snackbar shows;
  the original "Copy token" button still copies the bare token unchanged
  (regression pin).
- **Gate:** full B2 stack on the committed state — `dart format
  --output=none --set-exit-if-changed lib test`, `flutter analyze`,
  `flutter test`, `scripts/verify_ledger.sh` (README 847 → ~849
  declaration lockstep), plus the gen-l10n regeneration.

## 7. Risks / open questions

- **R1 — device tap of the produced link:** widget tests mock the clipboard
  and the consume side is stub-source verified; a real device tap
  (invite on one device → tap link on another, signed-in and signed-out)
  stays **owner-side** (reuses the Phase 4.1 R3/R4 checklist). Not claimed
  as verified here.
- **R2 — share-sheet expectation:** if the owner later wants a native
  share sheet instead of copy, that is a separate small slice (add
  `share_plus` + platform review) — the builder + l10n keys in this plan
  are reused as-is.
- **R3 — token length in URLs:** one-time invite tokens are short hex
  strings; no URL-encoding edge beyond `Uri(queryParameters:)` handling —
  pinned by the round-trip test (a token with special characters must
  round-trip; the builder uses `Uri` query encoding, not string
  interpolation).

---

# Tasks: Invite-side share-link generation

Sequential, independently committable slices (branch
`feat/invite-share-link` off `main`), each gated before the next.

| # | Slice | Files | Layer / state | Tests | Risks |
|---|---|---|---|---|---|
| 1 | **Builder** — `AppLinkParser.acceptInviteUri(String)` static (trim + `ArgumentError` on blank; scheme/host from the class constants via `Uri` query encoding) | `lib/app/deep_link/app_link_parser.dart` + `test/app/deep_link/app_link_parser_test.dart` | pure domain, no deps | +3–4 unit: exact URI, round-trip identity, trim, blank throws | R3 (encoding) — pinned by round-trip |
| 2 | **l10n** — `inviteShareLink` ("Copy invite link") + `inviteShareLinkCopied` ("Invite link copied to clipboard.") × EN/AR/TR + gen-l10n | 3 `.arb` + generated `app_localizations*.dart` | l10n | resolution smoke via the widget pins in T3 | none |
| 3 | **Button** — "Copy invite link" in `_buildToken` (below the token, beside/under "Copy token") + `_copyShareLink` (builder → `Clipboard.setData` → `inviteShareLinkCopied` snackbar) | `lib/features/orgs/presentation/invite_member_sheet.dart` + `test/features/orgs/presentation/invite_member_sheet_test.dart` | presentation, reads existing `_invite` | +2 widget: clipboard carries full URI + snackbar; bare-token copy regression pin | R1 (device) — owner-side |
| 4 | **Close** — full gate on committed state, README test-count lockstep (847 → ~849), roadmap/P3-plan Q2 note update ("share-link generation SHIPPED"), ledger sweep | `README.md`, `docs/features_roadmap_2026-08-03.md`, `docs/p3_auth_org_ux_plan.md`, new evidence record | docs | format/analyze/test/ledger green | — |

**Exit criteria:** the produced link round-trips through the shipped
consume side (`parse(acceptInviteUri(t))` is `AcceptInviteIntent(t)`);
the sheet offers both bare-token copy and full-link copy; no new
dependency, no platform config, no schema change; ledger green with README
in lockstep.
