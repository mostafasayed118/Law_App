import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  ConfigError,
  mapTransactionOutcome,
  paymobConfig,
  verifyTransactionHmac,
} from "../_shared/paymob.ts";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });

  let body: Record<string, unknown>;
  try {
    const parsed = await request.json();
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json(400, { error: "malformed_payload" });
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json(400, { error: "malformed_payload" });
  }

  const queryHmac = new URL(request.url).searchParams.get("hmac");
  const bodyHmac = typeof body.hmac === "string" ? body.hmac : null;
  const providedHmac = queryHmac ?? bodyHmac;
  if (!providedHmac) return json(401, { error: "invalid_signature" });

  const transaction = body.obj;
  if (transaction === null || typeof transaction !== "object" || Array.isArray(transaction)) {
    return json(400, { error: "malformed_payload" });
  }

  let hmacSecret: string;
  let integrationId: string;
  try {
    const config = paymobConfig();
    hmacSecret = config.hmacSecret;
    integrationId = config.integrationId;
  } catch (error) {
    if (error instanceof ConfigError) {
      console.error("paymob-webhook config error", error.message);
      return json(500, { error: "server_misconfigured" });
    }
    throw error;
  }

  const txn = transaction as Record<string, unknown>;
  const validSignature = await verifyTransactionHmac(txn, providedHmac, hmacSecret);
  if (!validSignature) return json(401, { error: "invalid_signature" });

  if (body.type !== "TRANSACTION") return json(200, { status: "ignored" });

  const order = txn.order;
  const orderRecord = order !== null && typeof order === "object" ? order as Record<string, unknown> : null;
  const providerOrderId = orderRecord?.id === undefined || orderRecord?.id === null
    ? ""
    : String(orderRecord.id);
  const merchantOrderId = orderRecord?.merchant_order_id;
  const amountCents = Number(txn.amount_cents);
  const currency = typeof txn.currency === "string" ? txn.currency.toUpperCase() : "";

  if (
    !providerOrderId ||
    typeof merchantOrderId !== "string" ||
    !UUID_RE.test(merchantOrderId) ||
    !Number.isInteger(amountCents) ||
    amountCents <= 0 ||
    currency !== "EGP" ||
    String(txn.integration_id ?? "") !== integrationId
  ) {
    return json(400, { error: "malformed_payload" });
  }

  const outcome = mapTransactionOutcome(txn);
  const transactionId = txn.id === undefined || txn.id === null ? "" : String(txn.id);
  if (!transactionId) return json(400, { error: "malformed_payload" });

  // The settlement RPC only accepts terminal outcomes. A pending callback is
  // a valid state, not a transient failure, so acknowledge it without
  // settling and without triggering Paymob's retry loop.
  if (outcome === "pending") return json(200, { status: "pending" });

  const data = txn.data;
  const failureCode = data !== null && typeof data === "object"
    ? (data as Record<string, unknown>).txn_response_code
    : null;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseUrl || !serviceKey) return json(500, { error: "server_misconfigured" });

  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error } = await serviceClient.rpc("apply_paymob_transaction", {
    p_provider_order_id: providerOrderId,
    p_provider_transaction_id: transactionId,
    p_outcome: outcome,
    p_amount_cents: amountCents,
    p_currency: currency,
    p_failure_code: failureCode === null || failureCode === undefined ? null : String(failureCode),
  });

  if (error) {
    console.error("paymob-webhook apply failed", error.code ?? "unknown");
    return json(503, { error: "transient_failure" });
  }

  return json(200, { status: "processed" });
});
