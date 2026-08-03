# LegalHub — Phase 2 Scope Note: Org Lifecycle Wiring (2026-08-03)

> **Record type:** Spec-lite scope note required by the Phase 2 gate
> (`docs/features_roadmap_2026-08-03.md` §4): scope, assumptions, non-goals,
> RPC mapping, acceptance criteria, and the risks recorded — then approval,
> then one slice per `INSTRUCTIONS.md` §2.1 with the B2 gate stack. **No
> server changes** in this phase: every RPC below is already committed,
> rehearsed, and applied (`3704a1d`).
> **Planning owner:** `docs/features_roadmap_2026-08-03.md` §4.
> **Status: APPROVED (2026-08-03, Project Owner — session instruction "approve,
> go to next phase" after Phase 1 shipped `03862ce`, suite 408, ledger PASS 115).
> Implementing slices 2.1–2.4.**

---

## 1. Scope

Client-only wiring of the remaining applied org RPCs, plus the UX surfaces
that close the org lifecycle gaps from Phase 1:

1. **2.1 Resend / revoke invite** — wire `resend_invitation(p_invitation_id)`
   and `revoke_invitation(p_invitation_id)` into `SupabaseOrgApi` +
   `OrganizationGateway` + fake; invited roster rows gain Resend / Revoke
   actions (partner-only; both RPCs enforce the partner guard server-side).
2. **2.2 Delete own account** — wire `delete_my_account()` (D-05, the only
   removal path; no direct DELETE policy exists); profile-screen action with
   a redaction-safe confirm; the fake mirrors the cascade.
3. **2.3 Active-org switcher** — selector UI over `Session.memberships`
   (client-side context only; **never transmitted** — the server re-derives
   membership per D-08; "switch active organization" is a UX hint, matrix
   §3).
4. **2.4 Invitation acceptance (R3)** — **UX decision recorded: paste-screen
   in Phase 2** (deep-link variant moves to Phase 4 with the platform
   intent-filter work). Wire `accept_invitation(token)` — already
   failure-mapped (`invalidInvitation`) — behind a token-entry screen.

## 2. RPC mapping

| Operation | RPC | Client surface |
|---|---|---|
| Resend invite | `resend_invitation(p_invitation_id)` → new token | `OrganizationGateway.resendInvitation` |
| Revoke invite | `revoke_invitation(p_invitation_id)` | `OrganizationGateway.revokeInvitation` |
| Delete own account | `delete_my_account()` | `OrganizationGateway.deleteMyAccount` |
| Accept invite | `accept_invitation(p_token)` → membership id | `OrganizationGateway.acceptInvitation` |
| Active-org context | (none — client projection of `Session.memberships`) | hub selector |

Failure kinds: `permission denied` → `denied`; `invitation not found` /
`only pending invitations can be (re)sent|revoked` → `invalidInvitation`
(undifferentiated, non-enumerating — matches the existing generic mapping);
existing `invalidInvitation`/`denied` localized messages are reused.

## 3. Assumptions & non-goals

- **No server changes, no new RPCs, no matrix addendum** (nothing widens the
  approved client surface; every RPC here is already applied).
- Invited rows carry a client-visible **invitation id** so Resend/Revoke can
  target the row. The current roster read (`list_members_metadata`) is
  platform-owner-only and exposes no invitation id — recorded as an **R1
  extension** (Phase 3 member-facing roster RPC must union `invitations` and
  expose the id). Until then the Resend/Revoke menus are real through the
  dev fake, exactly like the Phase 1 roster itself.
- `Session.memberships` is empty with a real provider today (the dev project
  has zero tables); the 2.3 switcher is therefore fake-real only, and the
  selector is a local UI context, never an authority.
- 2.2's confirm dialog and success/failure copy are redaction-safe
  (ADR-0003); no raw provider messages.
- Non-goals: invite emails (R2), deep-link acceptance (Phase 4), member
  metadata RPC (R1, Phase 3), any server amendment.

## 4. Acceptance criteria

1. Partner can Resend an invite → a fresh one-time token is shown once with
   copy; Revoke removes the pending invited row; non-pending/unknown
   invitation ids surface the localized `invalidInvitation` message.
2. Account deletion is a guarded profile action (redaction-safe confirm);
   success signs the session out; the fake removes the demo identity's
   memberships.
3. The org hub offers an active-org selector over `Session.memberships`; the
   selection is local-only (never sent) and defaults to the server-derived
   active membership.
4. Accepting an invitation: paste a token → typed `invalidInvitation` on bad
   tokens; success states the org and the fake records the membership.
5. Every server error surfaces localized and non-sensitive; provider types
   stay below the seams.

## 5. Risks (recorded, not assumed)

- **R1 extension** — invitation ids and invited rows are not readable through
  any member-facing RPC today; 2.1 surfaces are fake-real until the Phase 3
  member-facing roster RPC ships (tracked in the Phase 3 gate, not here).
- **R2/R3 carry-over** — no email integration; acceptance is paste-based by
  decision above.
- **Session staleness** — accepted memberships and the switcher depend on
  `Session.memberships`, which production populates with `[]` today; the
  demo fake remains the behavioral reference.

## 6. Exit

`bash scripts/verify_ledger.sh` + `dart format --output=none
--set-exit-if-changed .` + `flutter analyze` + `flutter test` all green,
README coverage count updated, no push without owner approval.
