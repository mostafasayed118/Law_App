# D-11 — Billing & Payments (provider / tax / PCI) — DECIDED 2026-08-08

> **Record type:** Dated owner decision capture (the p0/D-45.1 convention)
> closing the billing un-block gate that `docs/send_message_rpc_plan_2026-08-08.md`
> §A.1 recorded (previously "spec D-09 — OPEN"). **Supersedes the spec's
> D-09 (payment provider / tax / PCI)** — the p0 capture's D-09 (role
> semantics, DECIDED 2026-07-31) is unrelated and stays closed. The
> billing-invoices read slice (roadmap §14) is now **plannable** under the
> same T1–T8 per-feature discipline — still deferred as an implementation
> until its own slice plan + apply gates run.
>
> **Status: DECIDED 2026-08-08** (owner, github.com/mostafasayed118).
> **Owner:** Project Owner. **Blocks:** the §14 billing row — now
> **un-blocked for planning** (a future Paymob integration spec is
> unblocked too; MVP implementation stays out).

---

## 1. Decision (D-11 — payment provider / tax / PCI scope)

| # | Question | Decision |
|---|---|---|
| Provider | Payment provider for any future real integration | **Paymob** (Egyptian gateway: cards, wallets, online payments; sandbox available) |
| MVP | Live payment in the portfolio/demo MVP | **No live payment integration.** Any billing/invoicing surface runs on the **fake-gateway pattern** (synthetic invoices, no real charges) — consistent with p0 "no live payment in MVP" |
| PCI-DSS | Card-data compliance scope | **Paymob-hosted tokenization** (card data goes directly to Paymob via SDK/iframe/redirect); raw PAN/CVV never touches our servers, logs, or audit → PCI scope targets **SAQ-A-like**; **no PCI claim is made for the demo** |
| Tax | Tax/VAT/invoicing rules | **Out of scope for the demo**; no tax/VAT calculation in MVP; real tax rules deferred to a real product and **never hardcoded** (INSTRUCTIONS §1.2/§4.4) |

## 2. Decision (D-04, billing aspect — payment-data residency)

- Supabase dev project stays **West Europe (London)** (D-04 as already
  decided). Paymob processes payment data on its **own (Egyptian)
  infrastructure**.
- For the **synthetic demo**: no real cross-border constraints apply.
- For a **real product**: Egyptian data-protection law **151/2020** +
  cross-border transfer rules apply → **deferred** to a real product.

## 3. Reasoning (one line)

Paymob + hosted tokenization gives a credible Egyptian-market path with
the smallest PCI footprint, while the demo keeps the fake-gateway pattern
("no live payment in MVP") so nothing real is ever charged or stored.

## 4. Effect on the roadmap / plans

- **§14 billing row:** the deferred note's un-block gate ("owner's dated
  closing of spec D-09 + D-04") is **MET** — the row stays §14-deferred
  as an implementation, but a **billing-invoices read-metadata slice**
  (invoice rows + RLS + battery + rehearsal + dated apply + matrix
  addendum + env-gated client swap on the fake-gateway pattern, mirroring
  the seven read slices) is now **plannable** under the same discipline.
- **Phase 5 (booking):** client-only, "no live payment" — unchanged; the
  D-11 decision does not alter the booking slice.
- **Future Paymob integration:** D-11 unblocks a **Paymob integration
  spec** — a separate, owner-approved slice; not MVP.

## 5. Ledger

- DECIDED 2026-08-08 by the Project Owner; recorded
  `docs/d11_billing_payments_decision_2026-08-08.md`; roadmap §14 + the
  reconciliation (`docs/send_message_rpc_plan_2026-08-08.md` §A.1) + the
  send-message/realtime-push T8 evidence §8s updated to cite D-11.
- Committed as docs(billing); ledger PASS 115; nothing pushed.
