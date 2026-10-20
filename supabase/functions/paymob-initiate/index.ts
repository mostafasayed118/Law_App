import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  buildCheckoutUrl,
  ConfigError,
  createPaymobOrder,
  createPaymobPaymentKey,
  paymobAuthToken,
  PaymobRequestError,
  paymobConfig,
} from "../_shared/paymob.ts";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type InitiatedPayment = {
  payment_id: string;
  invoice_id: string;
  invoice_number: string;
  amount_cents: number;
  currency: string;
  status: string;
  provider_order_id?: string | null;
  paymob_order_id?: string | null;
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function rpcStatus(message: string, code?: string): number {
  if (code === "PGRST202") return 500;
  if (/not found|does not exist/i.test(message)) return 404;
  if (/not authorized|forbidden|permission denied/i.test(message)) return 403;
  if (/invalid|must be|cannot|already/i.test(message)) return 400;
  return 502;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });

  const authorization = request.headers.get("Authorization");
  if (!authorization || !/^bearer\s+\S+$/i.test(authorization)) {
    return json(401, { error: "unauthenticated" });
  }

  let body: { invoice_id?: unknown };
  try {
    body = await request.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }
  const invoiceId = body?.invoice_id;
  if (typeof invoiceId !== "string" || !UUID_RE.test(invoiceId)) {
    return json(400, { error: "invalid_invoice_id" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json(500, { error: "server_misconfigured" });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) return json(401, { error: "unauthenticated" });

  const { data: rpcData, error: rpcError } = await userClient.rpc("initiate_invoice_payment", {
    p_invoice_id: invoiceId,
  });
  if (rpcError) {
    return json(rpcStatus(rpcError.message, rpcError.code), { error: "initiate_failed" });
  }
  if (!rpcData || typeof rpcData !== "object") return json(502, { error: "initiate_failed" });

  const payment = rpcData as InitiatedPayment;
  if (
    typeof payment.payment_id !== "string" ||
    typeof payment.amount_cents !== "number" ||
    !Number.isInteger(payment.amount_cents) ||
    payment.amount_cents <= 0 ||
    payment.currency !== "EGP"
  ) {
    return json(502, { error: "initiate_failed" });
  }
  if (payment.status === "paid") return json(409, { error: "invoice_already_paid" });

  const existingOrderId = payment.provider_order_id ?? payment.paymob_order_id ?? null;

  try {
    const config = paymobConfig();
    const authToken = await paymobAuthToken(config);
    const providerOrderId = existingOrderId ??
      await createPaymobOrder(config, authToken, payment.amount_cents, payment.payment_id);

    if (!existingOrderId) {
      const serviceClient = createClient(supabaseUrl, serviceKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { error: attachError } = await serviceClient.rpc("attach_paymob_order", {
        p_payment_id: payment.payment_id,
        p_provider_order_id: providerOrderId,
      });
      if (attachError) return json(502, { error: "attach_failed" });
    }

    const paymentToken = await createPaymobPaymentKey(config, authToken, providerOrderId, payment.amount_cents);
    const checkoutUrl = buildCheckoutUrl(config, paymentToken);

    return json(200, {
      payment_id: payment.payment_id,
      status: payment.status,
      checkout_url: checkoutUrl,
      amount_cents: payment.amount_cents,
      currency: payment.currency,
    });
  } catch (error) {
    if (error instanceof ConfigError) {
      console.error("paymob-initiate config error", error.message);
      return json(500, { error: "server_misconfigured" });
    }
    if (error instanceof PaymobRequestError) {
      console.error("paymob-initiate upstream error", error.stage, error.status);
      return json(502, { error: "payment_provider_unavailable" });
    }
    console.error("paymob-initiate unexpected error");
    return json(500, { error: "internal_error" });
  }
});
