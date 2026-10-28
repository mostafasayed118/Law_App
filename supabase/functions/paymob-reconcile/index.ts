import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  ConfigError,
  constantTimeEqual,
  mapTransactionOutcome,
  paymobAuthToken,
  paymobConfig,
  PaymobRequestError,
  type PaymobConfig,
  type PaymobOutcome,
} from "../_shared/paymob.ts";

// The payment-key TTL is 60 minutes (supabase/functions/_shared/paymob.ts).
// The sweep must never outlive it, or a user who completes 3DS after the
// sweep has their payment expired while the provider still collects the
// money (audit H1). Keep a 5-minute margin above the key TTL.
const STALE_AFTER = "65 minutes";
const STALE_LIMIT = 50;

type StalePayment = {
  payment_id?: string;
  provider_order_id?: string | null;
  paymob_order_id?: string | null;
  amount_cents?: number;
  currency?: string;
};

type InquiryResult =
  | { kind: "transaction"; transaction: Record<string, unknown> }
  | { kind: "no_transaction" }
  | { kind: "unknown" };

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function isTrue(value: unknown): boolean {
  return value === true || value === "true";
}

function asTransaction(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  return record.id === undefined && record.success === undefined ? null : record;
}

/**
 * TODO: confirm the exact Paymob inquiry endpoint and response shape against the
 * merchant docs before enabling in production. Assumed here: GET
 * /api/ecommerce/orders/{order_id}?auth_token=..., returning order.transactions[].
 */
async function inquireOrder(
  config: PaymobConfig,
  authToken: string,
  providerOrderId: string,
): Promise<InquiryResult> {
  // `?auth_token=` is Paymob's documented inquiry API contract; the token is
  // never logged (the error type carries only stage + status).
  const url = `${config.baseUrl}/api/ecommerce/orders/${encodeURIComponent(providerOrderId)}` +
    `?auth_token=${encodeURIComponent(authToken)}`;
  const response = await fetch(url, { method: "GET" });
  if (response.status === 404) return { kind: "no_transaction" };
  if (!response.ok) throw new PaymobRequestError("inquiry", response.status);

  const data = await response.json();
  if (data === null || typeof data !== "object") return { kind: "unknown" };

  const record = data as Record<string, unknown>;
  if (Array.isArray(record.transactions)) {
    const transactions = record.transactions
      .map((entry) => asTransaction(entry))
      .filter((entry): entry is Record<string, unknown> => entry !== null);
    if (transactions.length === 0) return { kind: "no_transaction" };
    const successful = transactions.find((entry) => mapTransactionOutcome(entry) === "success");
    return { kind: "transaction", transaction: successful ?? transactions[transactions.length - 1] };
  }

  const single = asTransaction(record);
  return single ? { kind: "transaction", transaction: single } : { kind: "unknown" };
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });

  let config: PaymobConfig;
  let reconcileSecret: string;
  try {
    config = paymobConfig();
    const envSecret = Deno.env.get("PAYMOB_RECONCILE_SECRET")?.trim();
    if (!envSecret) throw new ConfigError("missing env: PAYMOB_RECONCILE_SECRET");
    reconcileSecret = envSecret;
  } catch (error) {
    if (error instanceof ConfigError) {
      console.error("paymob-reconcile config error", error.message);
      return json(500, { error: "server_misconfigured" });
    }
    throw error;
  }

  const providedSecret = request.headers.get("x-reconcile-secret") ??
    request.headers.get("authorization")?.replace(/^bearer\s+/i, "") ??
    "";
  if (!await constantTimeEqual(providedSecret, reconcileSecret)) {
    return json(401, { error: "unauthorized" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseUrl || !serviceKey) return json(500, { error: "server_misconfigured" });

  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await serviceClient.rpc("list_stale_pending_payments", {
    p_older_than: STALE_AFTER,
    p_limit: STALE_LIMIT,
  });
  if (error) {
    console.error("paymob-reconcile list failed", error.code ?? "unknown");
    return json(503, { error: "transient_failure" });
  }

  const stale = Array.isArray(data) ? data as StalePayment[] : [];
  const counts = { scanned: stale.length, applied: 0, expired: 0, skipped: 0, failed: 0 };
  if (stale.length === 0) return json(200, counts);

  let authToken: string;
  try {
    authToken = await paymobAuthToken(config);
  } catch (error) {
    if (error instanceof PaymobRequestError) {
      console.error("paymob-reconcile auth failed", error.status);
      return json(503, { error: "payment_provider_unavailable" });
    }
    throw error;
  }

  for (const payment of stale) {
    const providerOrderId = payment.provider_order_id ?? payment.paymob_order_id ?? null;
    if (!providerOrderId) {
      counts.skipped += 1;
      continue;
    }

    let inquiry: InquiryResult;
    try {
      inquiry = await inquireOrder(config, authToken, String(providerOrderId));
    } catch (error) {
      if (error instanceof PaymobRequestError) {
        console.error("paymob-reconcile inquiry failed", error.status);
        counts.failed += 1;
        continue;
      }
      throw error;
    }

    if (inquiry.kind === "unknown") {
      counts.skipped += 1;
      continue;
    }

    const transaction = inquiry.kind === "transaction" ? inquiry.transaction : null;
    const isExpiry = transaction === null;
    const outcome: PaymobOutcome = transaction ? mapTransactionOutcome(transaction) : "expired";
    const transactionId = transaction
      ? String(transaction.id)
      : `reconcile-expired-${providerOrderId}`;
    const amountCents = transaction
      ? Number(transaction.amount_cents ?? payment.amount_cents ?? 0)
      : Number(payment.amount_cents ?? 0);
    const rawCurrency = transaction && typeof transaction.currency === "string"
      ? transaction.currency
      : payment.currency;
    const currency = rawCurrency?.toUpperCase() ?? "EGP";
    const failureCode = transaction
      ? (transaction.data as Record<string, unknown> | undefined)?.txn_response_code
      : "reconcile_expired";

    if (!Number.isInteger(amountCents) || amountCents <= 0 || !transactionId || transactionId === "undefined") {
      counts.skipped += 1;
      continue;
    }

    // A stale order with no transaction is closed through the terminal
    // `expired` outcome; the failure code records the reconciliation path.
    const { error: applyError } = await serviceClient.rpc("apply_paymob_transaction", {
      p_provider_order_id: String(providerOrderId),
      p_provider_transaction_id: transactionId,
      p_outcome: outcome,
      p_amount_cents: amountCents,
      p_currency: currency,
      p_failure_code: failureCode === null || failureCode === undefined ? null : String(failureCode),
    });

    if (applyError) {
      console.error("paymob-reconcile apply failed", applyError.code ?? "unknown");
      counts.failed += 1;
      continue;
    }

    if (isExpiry) counts.expired += 1;
    else counts.applied += 1;
  }

  return json(200, counts);
});
