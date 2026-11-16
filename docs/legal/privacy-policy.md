> **Draft generated from code review; requires review by qualified counsel before production use.**


# LegalHub Privacy Policy

## Who we are

LegalHub is a legal practice-management app with a Legal Library module. The app is offered for demonstration; it is operated by the owner identified in the in-app contact constant. This draft was generated from a code review and requires review by qualified counsel before production use.

## What we collect

Account email and display name; your role and organization memberships; matters, documents and message metadata; invoices and notifications; Legal Library bookmarks, highlights and reading history; AI research run metadata and video session metadata. The demo build uses synthetic records and no real client data.

## How it is processed

Data is stored in Supabase Postgres with row-level security. Practice data is organization-scoped; Legal Library reference content is global; bookmarks, highlights and history are visible only to you. Mutations go through server-side functions that derive your identity from the session.

## Storage and files

Files are kept in a private storage bucket at 25 MiB maximum per file with a restricted file-type allowlist. Access to a file requires active membership in its organization and assignment to its matter.

## What we do not collect

The app contains no analytics SDK, no advertising and no third-party crash-reporting SDK. Errors are reported through a redacting console reporter. Payment collection, AI research and video calls are provider-gated and disabled unless explicitly configured.

## Your controls

You can edit your display name and change your password in Account settings. You can delete your account from the same screen after reading exactly what is removed. You can clear your reading history in the Library Saved screen.

## Deletion and contact

Account deletion removes your sign-in, profile, memberships, Legal Library rows and your file records with their metadata. Stored file bytes on hosted deployments are removed by the operator's storage cleanup, not by the in-app step. It does not remove records owned by other people or provider-side records. Redacted audit entries are retained with the actor reference cleared. For questions, use the contact address in the in-app legal notice.
