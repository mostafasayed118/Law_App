# ADR-0009 — Legal Library scope, global data and sample-only seed

- **Status:** Accepted
- **Date:** 2026-11-16
- **Supersedes:** nothing
- **Related:** ADR-0001 (brand), `docs/auth_tenant_authorization_contract.md`

## Context

LegalHub began as a practice-management platform: matters, documents, messaging,
invoicing, approvals, bookings, video consults. Its name, however, promises
something it did not have — legal *content*. A reader who opens "LegalHub"
expecting statutes, search and bookmarks finds a firm back-office.

The owner resolved the identity question as **hybrid**: the practice-management
platform stays the product, and a **Legal Library** is added as a distinct module
on top of it. Egypt is the assumed jurisdiction, Arabic-first.

Two constraints shaped the first slice:

1. **Legal accuracy is not negotiable.** Text written from a model's memory is
   plausibly-worded and possibly wrong. In a legal product that is worse than no
   text at all.
2. **The corpus does not exist yet.** Official text has to come from an
   authoritative source, which is the owner's task, not the agent's.

## Decision

### 1. The library is global reference data, not tenant data

`legal_sources`, `legal_documents` and `legal_articles` carry no
`organization_id`. They are the first tables in the schema whose rows no tenant
owns, and their RLS reflects that: **any authenticated user reads, anon reads
nothing, only the platform owner writes.**

This is deliberately different from every other table. Matters and documents are
scoped through `memberships`; a statute is not. Two attorneys at competing firms
read the same article 5. Gating the library on `canViewDocuments` would have
hidden statutes from clients, which is why the home entry's gate is simply "has
a session" (the shell already enforces that for every route).

### 2. Sample data only, and visibly so

The repository ships **three invented documents / eighteen articles**, every row
marked `is_sample = true`, and no quotation of any real law. Three mechanisms
keep that honest:

- the DB flag (`is_sample`);
- a **visible badge** on every surface that renders a sample row (index tile,
  document header, article header, search hit) — a truthfulness control, not
  decoration;
- a separate, always-present reader disclaimer ("Informational only. Not legal
  advice."), which says something different: the *app* is not an adviser.

Real text arrives through `tool/import_legal_library.dart`, which writes
`is_sample = false` rows. The seed file says, in its own header, not to extend it
with real text.

### 3. Search strategy, and what it cannot do

Postgres has no built-in Arabic text-search configuration. The slice therefore:

- normalises Arabic with `legal_normalize_ar()` — strips tashkeel and tatweel,
  folds alef variants (`أ إ آ ٱ` → `ا`), alef maqsura (`ى` → `ي`) and ta marbuta
  (`ة` → `ه`), lowercases Latin, collapses whitespace;
- indexes with the **`simple`** configuration over that normalised text, because
  `simple` at least tokenises instead of stemming the wrong language;
- appends an **article-stripped copy** of the text to `search_text`, so a query
  for `ايجار` reaches `الايجار` without a stemmer;
- ORs in a **normalised substring arm**, because Postgres classifies Arabic
  letters as word characters only when the database locale says they are
  alphabetic. On a `C`-locale database the tsvector arm tokenises to nothing, and
  a library that returns no results looks broken rather than empty.

**Known limitations, stated plainly:**

| Limitation | Consequence |
|---|---|
| No stemming / root extraction | `مؤجر` and `ايجار` do not match each other; they are different tokens. |
| Article-strip is a heuristic | Stripping `ال` from every word creates false positives on words whose first two letters are `ال` for another reason (`مال` is safe because the article must start a word; `الوان` is not). |
| Substring arm is unindexed | Acceptable for a reference corpus of this size; the first thing to revisit when it grows. |
| No ranking model | `ts_rank_cd` plus a fixed substring bonus. There is no relevance tuning against real queries yet. |
| No diacritic restoration | Normalisation deletes tashkeel; it never adds it, so a query will not match on a diacritic distinction. |
| `pg_trgm` not used | The extension allowlist could not be verified without applying live, and none of the acceptance cases need fuzzy matching. Falling back to tsvector-only was the documented alternative. |

### 4. Article identity is stable, so the next slice needs no migration

`legal_articles.id` is a uuid primary key; `article_number` is TEXT (citations
include `5 مكرر`); `ordinal` carries reading order. A future
bookmarks/history/highlights slice references `legal_articles(id)` with
per-user rows and user-scoped policies. Nothing in this slice changes when that
lands — which is why those tables were **not** created now.

### 5. Navigation: a home entry, not a third tab

The library is reachable from the home dashboard, not the bottom bar. A third
tab would have required editing an existing route test that pins two
`NavigationDestination`s; the entry card keeps every pre-existing test
untouched. The cost is discoverability — the library is one tap deeper than
matters — and it is recorded here rather than treated as settled.

## Consequences

**Good**

- The name now matches a real capability, without inventing legal content.
- Search works across the three Arabic spellings a reader actually types.
- The write boundary is already in place for the importer, and tested.
- The next slice (bookmarks/history/highlights) is additive.

**Bad / accepted**

- The demo build shows invented law under a real-looking title. The badge and
  the disclaimer are the mitigations; they are load-bearing and must not be
  removed for aesthetics.
- The library is Arabic-first. English titles are optional metadata; there is no
  English body rendering in this slice.
- One extra tap to reach the library.
- The substring search arm will not scale to a very large corpus without a
  trigram index or a proper Arabic FTS extension.

## Rejected alternatives

- **Write plausible statutory text to make the demo look real.** Rejected: a
  wrong law under a confident title is the single worst failure mode this product
  can have.
- **Ship the library empty until real text arrives.** Rejected: an empty module
  cannot be reviewed, tested or shown; the sample corpus is what makes the slice
  demonstrable.
- **Org-scoped library tables.** Rejected: reference data shared by every tenant
  should not be duplicated per tenant or hidden behind membership.
- **A `pg_trgm` index.** Rejected for now: an unverifiable extension dependency
  for a benefit the acceptance cases do not need.
- **Human-written INSERTs for the owner's import.** Rejected: the silent partial
  import is a real risk, and a validator that rejects the whole file removes it.
