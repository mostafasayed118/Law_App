import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export const PAYMOB_CANONICAL_FIELDS = [
  "amount_cents",
  "created_at",
  "currency",
  "error_occured",
  "has_parent_transaction",
  "id",
  "integration_id",
  "is_3d_secure",
  "is_auth",
  "is_capture",
  "is_refunded",
  "is_standalone_payment",
  "is_voided",
  "order.id",
  "owner",
  "pending",
  "source_data.pan",
  "source_data.sub_type",
  "source_data.type",
  "success",
] as const;

export type PaymobOutcome = "success" | "pending" | "voided" | "refunded" | "failed" | "expired";

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConfigError";
  }
}

export class PaymobRequestError extends Error {
  constructor(readonly stage: string, readonly status: number) {
    super(`paymob ${stage} failed with status ${status}`);
    this.name = "PaymobRequestError";
  }
}

export type PaymobConfig = {
  apiKey: string;
  hmacSecret: string;
  integrationId: string;
  iframeId: string;
  baseUrl: string;
};

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new ConfigError(`missing env: ${name}`);
  return value;
}

export function paymobConfig(): PaymobConfig {
  return {
    apiKey: requireEnv("PAYMOB_API_KEY"),
    hmacSecret: requireEnv("PAYMOB_HMAC_SECRET"),
    integrationId: requireEnv("PAYMOB_INTEGRATION_ID"),
    iframeId: requireEnv("PAYMOB_IFRAME_ID"),
    baseUrl: (Deno.env.get("PAYMOB_BASE_URL")?.trim() || "https://accept.paymob.com").replace(/\/+$/, ""),
  };
}

function readPath(source: Record<string, unknown>, path: string): unknown {
  return path.split(".").reduce<unknown>((value, key) => {
    if (value !== null && typeof value === "object") {
      return (value as Record<string, unknown>)[key];
    }
    return undefined;
  }, source);
}

function canonicalValue(value: unknown): string {
  if (value === null || value === undefined) return "";
  return String(value);
}

export function buildHmacCanonicalString(transaction: Record<string, unknown>): string {
  return PAYMOB_CANONICAL_FIELDS.map((field) => canonicalValue(readPath(transaction, field))).join("");
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function hmacSha512Hex(message: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return toHex(new Uint8Array(signature));
}

/** Length-independent comparison: both inputs are hashed before the XOR loop. */
export async function constantTimeEqual(left: string, right: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left.toLowerCase());
  const rightBytes = encoder.encode(right.toLowerCase());
  const [leftHash, rightHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", leftBytes),
    crypto.subtle.digest("SHA-256", rightBytes),
  ]);
  const leftView = new Uint8Array(leftHash);
  const rightView = new Uint8Array(rightHash);
  let diff = leftBytes.length ^ rightBytes.length;
  for (let index = 0; index < leftView.length; index += 1) {
    diff |= leftView[index] ^ rightView[index];
  }
  return diff === 0;
}

export async function verifyTransactionHmac(
  transaction: Record<string, unknown>,
  providedHmac: string | null,
  secret: string,
): Promise<boolean> {
  if (!providedHmac) return false;
  const expected = await hmacSha512Hex(buildHmacCanonicalString(transaction), secret);
  return constantTimeEqual(expected, providedHmac);
}

function isTrue(value: unknown): boolean {
  return value === true || value === "true";
}

export function mapTransactionOutcome(transaction: Record<string, unknown>): PaymobOutcome {
  if (isTrue(transaction.is_voided)) return "voided";
  if (isTrue(transaction.is_refunded)) return "refunded";
  if (isTrue(transaction.pending)) return "pending";
  if (isTrue(transaction.success) && !isTrue(transaction.error_occured)) return "success";
  return "failed";
}

async function paymobPost(config: PaymobConfig, path: string, body: Record<string, unknown>): Promise<Record<string, unknown>> {
  const response = await fetch(`${config.baseUrl}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new PaymobRequestError(path, response.status);
  const data = await response.json();
  if (data === null || typeof data !== "object") throw new PaymobRequestError(path, response.status);
  return data as Record<string, unknown>;
}

export async function paymobAuthToken(config: PaymobConfig): Promise<string> {
  const data = await paymobPost(config, "/api/auth/tokens", { api_key: config.apiKey });
  if (typeof data.token !== "string" || !data.token) throw new PaymobRequestError("auth", 502);
  return data.token;
}

export async function createPaymobOrder(
  config: PaymobConfig,
  authToken: string,
  amountCents: number,
  merchantOrderId: string,
): Promise<string> {
  const data = await paymobPost(config, "/api/ecommerce/orders", {
    auth_token: authToken,
    delivery_needed: false,
    amount_cents: amountCents,
    currency: "EGP",
    merchant_order_id: merchantOrderId,
  });
  if (data.id === null || data.id === undefined) throw new PaymobRequestError("order", 502);
  return String(data.id);
}

export async function createPaymobPaymentKey(
  config: PaymobConfig,
  authToken: string,
  providerOrderId: string,
  amountCents: number,
): Promise<string> {
  const data = await paymobPost(config, "/api/acceptance/payment_keys", {
    auth_token: authToken,
    amount_cents: amountCents,
    expiration: 3600,
    order_id: Number(providerOrderId),
    currency: "EGP",
    integration_id: Number(config.integrationId),
    billing_data: {
      first_name: "NA",
      last_name: "NA",
      email: "na@example.com",
      phone_number: "NA",
      street: "NA",
      building: "NA",
      floor: "NA",
      apartment: "NA",
      city: "NA",
      state: "NA",
      country: "EGY",
      postal_code: "NA",
    },
  });
  if (typeof data.token !== "string" || !data.token) throw new PaymobRequestError("payment_key", 502);
  return data.token;
}

export function buildCheckoutUrl(config: PaymobConfig, paymentToken: string): string {
  return `${config.baseUrl}/api/acceptance/iframes/${config.iframeId}?payment_token=${encodeURIComponent(paymentToken)}`;
}
