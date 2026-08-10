# LegalHub — Verification Plan: F-04 / F-06 / F-10 (2026-08-10)

> **Record type:** dated verification plan for the three **OPEN** findings in
> `docs/p4_findings_register_2026-08-09.md` (F-04, F-06, F-10). **Plan only —
> authorizes nothing.** Each step keeps its own gate (INSTRUCTIONS.md §2/§3):
> any dev-project contact requires a dated owner go-ahead; any dev-project
> **write** (the F-04 demo send) requires an explicit dated approval, mirroring
> the D-45.1 create-flow run (2026-08-09). The demo/portfolio posture
> (D-02/D-03) is unchanged; nothing here touches real data.
>
> **Owner:** Project Owner (github.com/mostafasayed118) executes the
> dev-project steps; engineering drafts probes and ships the client slices.
>
> **Why this plan exists:** all three findings are LOW-severity
> **verification/documentation gaps, not demonstrated defects**. Each has a
> concrete remediation path in the register; this plan turns those paths into
> owner-executable steps with pass criteria and evidence artifacts, and
> records which parts are owner-gated.

---

## 0. Register refs (verbatim anchors)

| Finding | Register row | Threat-model ref | Severity | Current status |
|---|---|---|---|---|
| F-04 — Realtime delivery verified by RLS proxy, not a live websocket round-trip | summary row 39; detail §2 | §4.4 / §6 residual 3 | Low (verification gap) | **OPEN** |
| F-06 — Accept-invite one-time token rides in a deep-link URL | summary row; detail §2 | §4.1 | Low | **OPEN** |
| F-10 — Provider/hosting posture assumed, not verified | summary row; detail §2 | §4.5 / §6 residual 6 | Low | **OPEN** |

---

## 1. F-04 — Realtime live websocket round-trip

### Already pinned (do NOT re-do)
- The delivery **gate** (Realtime RLS): battery `supabase/tests/09_realtime_push.sql` 09.11/09.12 — assigned reader sees the row, suspended/cross-org/owner see 0.
- The publication pin (harness §1f): exactly `public.messages`, nothing else.
- The audited send path (`send_message` RPC, D-SM3; §8 audit by construction).

### The remaining delta
A **live websocket round-trip observed from an actual Realtime client** — the
one thing the widget suite cannot do. The 2026-08-09 D-45.1 execution covered
the **matter-write** chain, not this path (see `docs/f01_client_swap_verification_evidence_2026-08-09.md`).

### Steps

| # | Step | Owner | Gate | Dev-project contact |
|---|---|---|---|---|
| V-F04-1 | **Configured-build interactive pass** — the D-45.1 checklist §3 runbook: partner sign-in on the configured build, open a thread, live send → immediate delivery observed in the UI; denied-role 0 events. | Owner (device + demo password) | Interactive pass is **reserved for the owner** (checklist §5 sign-off — `docs/configured_build_e2e_checklist_2026-08-08.md`) | reads + demo send |
| V-F04-2 | **Scripted Realtime-subscription probe (no device)** — subscribe to `postgres_changes` on `messages` as the demo partner (session from the demo account, anon-key client), then trigger delivery via the audited `send_message` RPC (one owner-approved demo send, mirroring the D-45.1 create run); assert the delivered payload matches the RLS gate and a non-assigned/owner subscription receives 0. | Owner + engineering (probe drafted in repo, run by owner) | **dated owner go-ahead** for the demo send (a dev-project write) | read subscription + 1 audited demo send |
| V-F04-3 | **D-LV4 reconnect/backfill polish** — small client slice (subscription reconnect + backfill via `fetchMessages`). | engineering | standard slice gate | none (client-only) |

### Pass criteria
- V-F04-1/V-F04-2: the delivered event is observed by the assigned reader; **0 events** for the non-assigned/owner subscription; publication unchanged (exactly `messages`).
- V-F04-3: reconnect/backfill behavior pinned by widget/unit tests.

### Boundary
- No publication widening, no new server surface, no new RPC.
- No claim of provider-side delivery guarantees beyond what was observed.
- F-04 closes only when the executed evidence is recorded (checklist §5 sign-off or the dated probe record) and the register row is updated.

---

## 2. F-06 — Accept-invite token in a deep-link URL

### Mitigations already in place (evidence)
Single-use token, sha-256 at rest, in-memory `PendingAcceptInviteStore`
(consumed-and-cleared), no auto-submit, generic denial —
`lib/app/deep_link/app_link_parser.dart` + `pending_accept_invite_store.dart`
(unit-tested).

### Steps

| # | Step | Owner | Gate | Effect |
|---|---|---|---|---|
| V-F06-1 | **Dated exposure note (do now)** — append to `docs/p4_41_deeplink_recovery_scope_2026-08-03.md`: the exposure (OS logs / launcher dumps / other-app intent interception), the in-place mitigations, and the residual (short exposure window; one-time token). | engineering | docs-only | none |
| V-F06-2 | **App Links verification at Android release-config time** — host `assetlinks.json`; add the verification step (scheme `com.legalhub.app` cannot be claimed by another app) to the release checklist. Currently **inert**: the dashboard Redirect URL and assetlinks are owner actions (roadmap 4.1 R1). | Owner | release-config time | dashboard (owner) |
| V-F06-3 | **Stronger fix (future slice, recorded)** — short-lived server-issued code instead of the raw token in the URL. Needs an edge function + mechanism review; **not scheduled**. | engineering | future slice gate + review | none until approved |

### Tests today / optional pin
The parser + store are unit-tested. Optional with this plan: one regression
pin asserting the accept token is **never persisted or logged** by the client
(ADR-0003 redaction discipline).

### Pass criteria
- V-F06-1: dated exposure note present with mitigations + residual stated.
- V-F06-2: assetlinks verified; intent filter resolves only to this app.
- F-06 closes only after V-F06-1 is recorded and V-F06-2 is either executed
  or explicitly deferred with a dated note.

---

## 3. F-10 — Provider/hosting posture probes (all read-only)

### Register refs
Harness WATCH-ITEM (`scripts/verify_policy_tests.sh` §1g); platform default
SELECT grants on `storage.objects`; GoTrue JWT-`email`-claim precondition for
`accept_invitation` (README refinement #8).

### Steps — execution mechanism: the `--linked` Management API SQL runner used
for the D-45.1 probes (no DB password touched; nothing credential-shaped
recorded verbatim).

| # | Probe | Pass criterion | Evidence |
|---|---|---|---|
| V-F10-1 | **Storage-policy baseline** — enumerate `storage.objects` policies on the dev project; compare with the rehearsal-host baseline (harness WATCH-ITEM). | Policy set matches the recorded expectation, or a dated delta is recorded | dated probe record |
| V-F10-2 | **Default grants on `storage.objects`** — the platform default SELECT posture the batteries compensate for. | Posture recorded; if broader than the battery assumption, note it (the pins compensate) | dated probe record |
| V-F10-3 | **GoTrue JWT `email` claim** — decode a demo-account access token (redact the token; record only claim presence). | `email` claim present (the `accept_invitation` precondition) | dated probe record |
| V-F10-4 | **Auth rate-limit settings** — read the dev project's Auth config for rate-limit defaults (closes the F-07 accepted-posture reference with an observed value). | Values recorded | dated probe record |

### Boundary
- Read-only; no config change; no credentials recorded; no demo-data change.
- F-10 closes when the dated probe record exists and the register row is
  updated to verified.

---

## 4. Sequencing & gate summary

| Step | Owner | Gate | Dev-project contact |
|---|---|---|---|
| F-04 V-F04-1 | Owner (device) | interactive-pass reservation (checklist §5) | reads + demo send |
| F-04 V-F04-2 | Owner + engineering | **dated go-ahead** for the demo send | read subscription + 1 audited demo send |
| F-04 V-F04-3 | engineering | standard slice gate | none |
| F-06 V-F06-1 | engineering | docs-only | none |
| F-06 V-F06-2 | Owner | release-config time | dashboard (owner) |
| F-06 V-F06-3 | engineering | future slice + mechanism review | none until approved |
| F-10 V-F10-1..4 | Owner | **dated go-ahead** (read-only probes) | read-only |

Suggested execution order: **F-10 (cheapest, read-only) → F-06 V-F06-1
(docs) → F-04 V-F04-2 (scripted probe) → F-04 V-F04-1 (interactive pass) →
F-06 V-F06-2 (release-config)**.

---

## 5. Non-goals

- No code changes from this plan itself (except the optional F-06 pin and the
  D-LV4 slice, both normally gated).
- No publication widening, no new RPC/edge function, no matrix addendum, no
  demo-data changes beyond the owner-approved demo send.
- No production/real-data contact; the demo posture (D-02/D-03) is unchanged.
- This plan does **not** close the findings — each step's evidence updates the
  register row (OPEN → verified/closed) after execution, per the repo's
  dated-evidence discipline.

---

## 6. Evidence index (filled at execution)

| Finding | Artifact expected |
|---|---|
| F-04 | `configured_build_e2e_checklist_2026-08-08.md` §5 dated sign-off, or a dated realtime-probe record (`docs/…realtime_roundtrip_evidence_2026-08-10.md`) |
| F-06 | dated exposure note appended to `p4_41_deeplink_recovery_scope_2026-08-03.md` + release-checklist verification row |
| F-10 | dated probe record (`docs/f10_provider_posture_probes_2026-08-10.md`) |
