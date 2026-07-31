# Architecture Decision Records

| ADR | Title | Status |
| --- | --- | --- |
| [0001](0001-brand-is-legalhub.md) | Product brand is LegalHub | Accepted |
| [0002](0002-dark-theme-approved-as-is.md) | Dark theme tokens approved as-is | Accepted |
| [0003](0003-signup-request-redaction-contract.md) | SignUpRequest is a pure-domain redaction contract | Accepted |
| [0004](0004-shared-second-use-rule-and-viewstateview.md) | Enforce the shared/ second-use rule; retain ViewStateView | Accepted |
| [0005](0005-canonical-primary-is-0b1d2e.md) | Canonical primary token is Midnight Blue #0b1d2e | Accepted |
| [0006](0006-primarycontainer-tracked-deviation.md) | primaryContainer remains #1A2B3C (tracked deviation from spec #0b1d2e) | Accepted (deviation recorded, not reconciled) |

ADRs record decisions that are expensive to reverse or that deviate from an
approved specification. They do not approve deferred work; they make implicit
decisions reviewable. Known deviations that are **not** architecture decisions
(a deferred render bug, unwired-but-tested domain contracts, a hardcoded
fixture string) live in [`../tracked_deviations.md`](../tracked_deviations.md),
not the ADR log, to keep the ADR log's contract honest.
