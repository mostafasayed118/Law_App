# Legal Library import format

The contract between the owner's real legal text and the Legal Library tables
(ADR-0009). The importer that consumes it is
[`tool/import_legal_library.dart`](../tool/import_legal_library.dart).

**The tool does not touch a database.** It reads a JSON file, validates it, and
prints SQL to stdout. You review the SQL, then run it yourself against the dev
project first.

## Why a validating tool instead of hand-written INSERTs

The dangerous failure is silent: a code imported with six of its forty articles,
or two articles sharing the number "5" because of a copy-paste, looks fine on
the screen and is wrong in the law. The validator rejects the **whole file** on
any such defect, so a partial import cannot happen by accident.

## Running it

```bash
dart run tool/import_legal_library.dart --input my_codes.json > import.sql
```

| Exit | Meaning |
|---|---|
| 0 | Valid. SQL on stdout, a one-line summary on stderr. |
| 1 | Validation failed. Every problem is listed on stderr; **no SQL is printed**. |
| 2 | Bad invocation or missing input file. |

Then, deliberately:

```sql
-- review import.sql first
\i import.sql          -- against the DEV project
```

Apply to the production project only through the normal migration discipline
(see `supabase/README.md`), never straight from this tool.

## Shape

```json
{
  "source": {
    "name_ar": "…",            // required
    "name_en": "…",            // optional
    "kind": "statute",         // required: statute | regulation | court_ruling
    "jurisdiction": "EG",      // optional, default "EG", two uppercase letters
    "is_sample": false
  },
  "documents": [
    {
      "title_ar": "…",         // required, ≤ 400 chars
      "title_en": "…",         // optional
      "official_number": "…",  // optional
      "year": 2020,            // optional, 1800–2200
      "category": "civil",     // required: civil | criminal | labor | commercial |
                               //           family | administrative | constitutional | other
      "status": "in_force",    // optional, default "unknown":
                               //           in_force | amended | repealed | unknown
      "summary_ar": "…",       // optional, ≤ 4000 chars
      "published_at": "2020-01-15", // optional, ISO date
      "is_sample": false,
      "articles": [            // required, non-empty
        {
          "article_number": "5 مكرر", // required, ≤ 40 chars, TEXT on purpose
          "ordinal": 6,               // optional, defaults to array position
          "heading_ar": "…",          // optional, ≤ 400 chars
          "body_ar": "…",             // required, non-empty, ≤ 20000 chars
          "is_sample": false          // optional, inherits the document's flag
        }
      ]
    }
  ]
}
```

## Validation rules

Rejected with exit code 1:

- any required field missing, blank, or of the wrong type;
- an enum value outside the sets above (`kind`, `category`, `status`);
- a `year` outside 1800–2200, or a non-integer;
- a `jurisdiction` that is not two uppercase letters;
- a document with an empty or missing `articles` array;
- **two articles in one document sharing `article_number`**;
- **two articles in one document sharing `ordinal`**;
- an article whose `body_ar` is blank;
- a field over its length cap;
- **the same `title_ar` appearing twice in one file**.

Accepted but worth knowing:

- `ordinal` defaults to the article's position in the array, so a file that
  lists articles in reading order needs no ordinals at all — but a citation
  whose numbering has gaps ("1", "2", "5") should carry explicit ordinals, or
  the reader's previous/next order will not match the printed numbering.

## What the generated SQL does

One `do $$ … $$` block inside a transaction:

1. resolves the source by `(name_ar, jurisdiction)`, creating it only if absent;
2. for each document, resolves it by `(source_id, title_ar)` — if it already
   exists the document is **skipped with a `raise notice`**, never partially
   re-inserted and never duplicated;
3. otherwise inserts the document and all of its articles.

So re-running the same file is safe and reports what it skipped. Editing an
existing document is deliberately **not** supported by this tool: an amendment
is a reviewable SQL change, not a silent upsert.

## Sample data

`tool/fixtures/legal_library_example.json` is a valid file whose every row is
marked `is_sample: true`. It exists to exercise the importer and to show the
shape; it contains no real legal text. The UI renders a visible badge for any
sample row, so a mistaken import of this file is visible rather than silent.

## What is not handled yet

- Amending or repealing an existing article (the tool only inserts new
  documents).
- Attaching an English translation to an existing article.
- Splitting a long code across multiple files.
- Verifying that the text is authoritative. That check is the owner's, not the
  tool's — which is exactly why nothing here invents content.
