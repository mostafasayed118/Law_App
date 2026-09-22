# Owner-needs — items only you can resolve

> **Generated:** 2026-09-23 (post-extraction-slice commit)
> **Context:** `docs/audit/LegalHub_AUDIT_2026-09-21.md` §12.14 ·
> `docs/open_items_for_owner_2026-09-22.md`
> **How to use:** §1 lists actions only you can take. §2 lists decisions
> that unblock the next slice. §3 collects format / doc-precision items
> where you may want a different call. §4 lists what I deliberately did
> **not** do without an answer.

This file does **not** supersede `docs/open_items_for_owner_2026-09-22.md`;
that document is still authoritative for P1.1, P1.2 iOS, P1.3 SQL, D-T9, and
the rest of the open-roadmap items. The items below are the ones raised by
this session's "fix-all" review.

---

## 1. Actions only you can take

### 1.1 Push the extraction-slice commit — **highest priority**

The slice is committed locally (the slice's first commit was the actual
refactor; a second commit tightened §12.14's wording. `git log --oneline
-2` shows both). Until it is pushed to `origin/main`, it exists in exactly
three places: your working tree, the local git objects, and the sandbox's
`ModifyBackup` store (audit doc §12.12). Per `INSTRUCTIONS.md` §2, pushing
is owner-gated; I have not done it.

*Say the word and I will run `git push` — or push it yourself.*

### 1.2 Identify what deleted `lib/` at 21:50 on 2026-09-21 — still open

The §12.12 finding named WorkBuddyAI's sandbox as the interceptor (it is
benign — that is *why* recovery was possible). It also flagged the sandbox
backup store as a data-exposure surface for any project that ever holds
client work on this machine. Two optional hygiene items you may want to
action:

- Confirm the backup store's retention policy (per-session accumulations
  of ~17k files will grow without bound).
- Confirm the `command-safety` / `file-safety` audit log retention (it is
  the only reason §12.12 was reconstructable).

### 1.3 Do not empty the Recycle Bin (still holds the §12.11 references)

Specifically the entries deleted around 21:50 on 2026-09-21, until 1.1 is
done and you have confirmed the tree.

---

## 2. Decisions that unblock this session's work

### 2.1 Confirm §12.14's `<commit-hash>` placeholder strategy — or pick a different one

§12.14 and the matrix addendum both reference the extraction-slice commit
via `git log` lookups (the slice's first commit was made with a placeholder
form, then the wording was tightened in a follow-up commit; the canonical
hash is `git log --oneline -1` or the two-commit pair from `git log -2`).
Three ways forward; pick one:

| Option | What it does | Trade-off |
|---|---|---|
| **(a) Amend the slice commit** *(recommended)* | `git commit --amend` after filling the placeholders in §12.14 + the matrix addendum with the actual hash. The resulting commit carries its own hash in its own body. | Local-only commits are safe to amend (audit doc's existing pattern); pushed commits must never be amended. The push is still owner-gated, so this is fine here. The amend will produce a third hash; the audit doc and matrix addendum would then point to it consistently. |
| **(b) Follow-up docs commit** *(also recommended; what I would default to without instruction)* | Leave the slice commit + the wording-tightening commit as they are; the canonical lookup is `git log --oneline -2` or `-1` depending on which the reader wants. | Cleanest for git archaeology — two commits, each with its own clean message; no amend needed. The downside is that the audit doc points at the second commit, and a future reader running `git log -1` gets the wording-tightening commit, not the slice proper. |
| **(c) Leave the placeholders** | Ship the slice with the placeholder text and let `git log` be the lookup. | No amend, but the audit doc reads as unfinished in the meantime. |

**What I need:** (a), (b), or (c). If you say nothing, I will leave the
two-commit shape as-is (option b).

### 2.2 Confirm the §12.14 certification block's suite / analyze / test numbers

§12.14 records **+1400 tests pass · `verify_ledger.sh` PASS 115/0/0 ·
README lockstep 1400** for the landing commit, all from this session's
gates. If the verify_ledger.sh self-selftest or the README lockstep
count were to drift before you push (a possibility if the unpushed commits
ahead of this one carry suite deltas), the numbers will be off.

**What I need:** confirm the numbers stand, or correct them. The
`scripts/verify_ledger.sh` PASS row is the authoritative source for the
suite count — if it disagrees with §12.14's claim, the audit doc is wrong.

### 2.3 Whether the matrix addendum should also touch the headline §3 table

I added a dated A1/A2 section at the bottom of
`docs/screen_completeness_matrix_2026-08-09.md` instead of editing the
historical §3 summary block (per the `permission_matrix.md` pattern: a
dated addendum, not a historical edit). If you would rather the §3
summary be edited in place — the document is already 4 months old and
the 33-screen / 1400-test reality is current — say so and I will make
the in-place edit (also in the same commit, no history rewrite).

**What I need:** addendum-only (already done), or also edit §3 in place.

---

## 3. Format / doc-precision items where you may want a different call

### 3.1 Confirm the audit doc's "supersedes §12.13" wording on §12.14

§12.13's first paragraph now reads `> **Superseded by §12.14.** ... Do
not act on §12.13's "the slice wants its gate run and then a commit"
wording — that commit was made.`. This treats §12.13 as a historical
record and points the reader forward. Alternative phrasings if you want
something tighter or more pedantic — say so and I will adjust.

### 3.2 The matrix addendum A1 lists 94 `part` files as "extracted widgets"
The matrix's vocabulary treats `*_screen.dart` as the only screen
artifact. The 94 new `part` files are private sub-widgets, not screens,
so they do not appear in the screen count — but the matrix A1 paragraph
*names* them so a maintainer scanning the tree knows why the file count
jumped. If you would rather the matrix stay silent on the part files
(since they are private widgets, not screen surfaces), say so and I will
remove the naming line from A1.

### 3.3 The audit doc's `flutter test` invocation requires `NO_PROXY` override
Still true on this machine (audit doc §12, `open_items_for_owner_2026-09-22.md`
§1.4). The override survives in the §12.14 certification block. If you
want it permanently fixed in your shell profile (e.g. via `.bashrc` /
`$PROFILE`), I can suggest the exact line; otherwise it stays a per-shell
override that future sessions will need to remember.

---

## 4. What I deliberately did NOT do without an answer

- **Push to `origin/main`.** Always yours. The slice is committed but not
  pushed; the safety net (the push) is yours.
- **Amend the slice commit to fill the `<commit-hash>` placeholders.** Awaits
  §2.1 above.
- **Edit the matrix §3 summary in place** (per §2.3 above).
- **Add the audit-side §12.14 entry to the navigation / TOC** the audit doc
  does not currently have a TOC, so this is N/A, but if you want one I can
  add it in a separate docs-only commit.
- **Re-record the same numbers in `docs/open_items_for_owner_2026-09-22.md`'s
  §0 "Where things stand" block.** That file says "7 commits, working tree
  clean, nothing pushed. 1381 tests pass." — pre-extraction-slice numbers.
  If you want a §0.1 "stale numbers; see today's owner-needs file" callout
  added, I will do it as a docs-only edit in the same commit (no separate
  PR noise).