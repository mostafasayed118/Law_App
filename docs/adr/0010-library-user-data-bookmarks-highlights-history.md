# ADR-0010 — Per-user library data: bookmarks, highlights, history

- **Status:** Accepted
- **Date:** 2026-11-16
- **Builds on:** ADR-0009 (the Legal Library is global reference data)
- **Migration:** `supabase/migrations/33_library_user_data.sql`

## Context

ADR-0009 shipped a read-only global corpus. Readers can browse, search and read,
but they cannot keep anything: no bookmarks, no marks on the text, no memory of
what they read. For a reference library that is the difference between a
browsable document and a tool someone returns to.

Slice 2 adds the reader's own layer, and it is the first module in the repo whose
data belongs to a *person* rather than an organization. That distinction drives
every decision here.

## Decision

### 1. Per-user means per-user — including for the platform owner

`legal_bookmarks`, `legal_highlights` and `legal_reading_history` carry a
`user_id` referencing `auth.users` with `on delete cascade`. RLS has exactly one
predicate, `user_id = auth.uid()`, and there is **no administrative carve-out**.

A platform owner reading another person's highlights or reading history is a
privacy breach, not administration. There is no reporting need in this product
that would justify it, and adding one later must be an explicit, reviewable
decision rather than a policy that quietly already allowed it. Battery 28.08
pins that the owner sees zero of another user's rows.

### 2. RPC-only writes, SELECT-only grant

The three tables grant `SELECT` to `authenticated` and nothing else. There is no
INSERT/UPDATE/DELETE grant and no write policy, so a direct client write fails at
the **privilege layer**, before any policy is consulted — for the owner too. This
is stricter than a write policy and matches the `attorney_profiles` precedent.

Every mutation is one of nine RPCs. Each derives the caller from `auth.uid()` and
**never accepts a user id parameter**, so "write as someone else" is not a
validation rule to get right; it is unrepresentable.

A cross-user edit is reported as `not_found`, not as `denied`: the server cannot
tell "does not exist" from "not yours", and it should not, because distinguishing
them would leak the existence of other people's rows.

### 3. Highlights: offsets + quote + hash

A highlight stores three things about the text it covers:

| Field | Why |
|---|---|
| `start_offset`, `end_offset` | Where the reader marked, end-exclusive |
| `quote` | A snapshot of the words, so the reader can still be shown what they chose |
| `body_hash` (`md5(body_ar)`) | What the article said when the highlight was made |

On create, the server recomputes the hash from the **current** body and refuses
unless `substring(body from start+1 for span)` equals the quote. An offset that no
longer points at the quoted words therefore cannot be stored at all.

On read, `list_my_legal_highlights` reports `is_stale = (body_hash <> md5(body_ar))`.
A stale highlight is **never drawn at its offsets** — the words underneath have
changed, and painting them would underline a sentence the reader never chose. The
reader shows a notice listing the saved quotes instead, which is the honest
alternative: "this is what you marked; the text has moved on".

### 4. Offsets are RUNES, not UTF-16

`TextSelection` reports UTF-16 code units; Postgres `substring` counts characters.
For Arabic (BMP) the two agree — until an astral character appears (an emoji in a
heading, a rare symbol), at which point a naive hand-off shifts every highlight
after it by one per surrogate pair.

The boundary contract is therefore: **the client converts to rune offsets before
calling the server, and back when rendering.** `highlight_offsets.dart` is the
only place that conversion lives, and it clamps a selection edge that splits a
surrogate pair to the character's start, because a highlight may not begin inside
a character. The helpers are unit-tested with an emoji case, not just Arabic.

### 5. Caps, and why they are a distinct error

| Cap | Value | Rationale |
|---|---|---|
| Bookmarks per user | 500 | A personal library, not an archive |
| Highlights per article | 50 | More than that is not annotation, it is a copy |
| Highlights per user | 2000 | Bounds storage and keeps the saved list usable |
| History rows per user | 100 | Bookkeeping, pruned on every write |

Caps live in one `legal_cap()` function so the RPCs and the tests cannot drift.
They raise `54000` (`program_limit_exceeded`) and map to their own `AppError`,
because "you have reached the limit" is not a bug and must not read like one. The
same applies to `22023` (a rejected selection) and `P0002` (not found): three
different sentences for a reader, not one generic failure.

### 6. A separate gateway

`LibraryUserDataGateway` is deliberately not part of `LibraryGateway`. The corpus
gateway is read-only and identical for every user; this one is mutable and
caller-scoped. Merging them would put `toggleBookmark` next to `listDocuments` in
an interface the browse cubit also implements against — the wrong shape for both,
and it would have made the fake's job ambiguous.

### 7. One read answers "is this bookmarked"

`list_my_legal_bookmarks` takes an optional `p_article_id`. The reader needs to
know whether the open article is saved, and the unrestricted read returns at most
50 rows: paging to find one row would be wrong past the cap and a wasted round
trip. Rather than add a tenth RPC, the read gained a filter, mirroring
`list_my_legal_highlights`, which already had one.

### 8. No tab promotion (attempted, reverted)

Promoting the Library to a third bottom-bar destination was attempted and
reverted. Adding an unconditional destination changed the shell's
capability-degradation behaviour — a role hidden from Home *or* Settings now
still rendered a bar — which broke two semantic shell tests and two end-to-end
navigation flows. That is more than an index shift, so the change was backed out
rather than papering over the tests. The library stays reachable from the Home
entry card (ADR-0009) and the Saved screen from the library index. The
discoverability cost is unchanged and still recorded.

## Consequences

**Good**

- The library is now something a reader keeps, not just visits.
- Ownership is a structural property, not a rule to remember.
- A stale highlight degrades honestly instead of lying about its position.
- The offset contract is written down and tested before it could bite.

**Bad / accepted**

- Nine RPCs is a wide surface for three tables; each is one narrow intent.
- History is behavioural data. It is the most sensitive table in the schema and
  it exists because the feature is expected; the mitigation is that only the
  owner can ever read it, and `clear_my_legal_history` destroys it on request.
- The Saved screen has no pagination beyond the 50-row read cap. Acceptable at
  these caps, wrong if a user could hold thousands of bookmarks — which the
  500-bookmark cap prevents.
- Highlights are anchored to text, so an amended article produces stale rows that
  the reader must reconcile by hand. A future slice could offer "re-anchor".

## Rejected alternatives

- **A single `LibraryGateway`.** Wrong shape for both halves (see 6).
- **A write policy instead of RPC-only.** Weaker: a policy is a rule that must be
  right; a missing grant is a door that is not there.
- **Letting the platform owner read everything.** Rejected outright.
- **Storing UTF-16 offsets.** Works for Arabic today and breaks silently on the
  first astral character.
- **Drawing stale highlights anyway.** Underlines the wrong sentence with full
  confidence — the worst outcome for a legal reader.
- **A tenth RPC for "is bookmarked".** A filter on an existing read is less
  surface for the same answer.
