import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TOKEN_TTL_SECONDS = 2 * 60 * 60;
const TOKEN_NOT_BEFORE_SECONDS = 10;

type FailureCode =
  | "unauthorized"
  | "forbidden"
  | "session_not_found"
  | "session_ended"
  | "provider_not_configured"
  | "internal_error";

type VideoSessionRow = {
  id: string;
  room_name: string;
  status: string;
};

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

function fail(status: number, error: FailureCode): Response {
  return json(status, { error });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function mintLiveKitToken(
  apiKey: string,
  apiSecret: string,
  userId: string,
  room: string,
  nowSeconds: number,
): Promise<string> {
  const encoder = new TextEncoder();
  const header = base64Url(encoder.encode(JSON.stringify({ alg: "HS256", typ: "JWT" })));
  const payload = base64Url(encoder.encode(JSON.stringify({
    iss: apiKey,
    sub: userId,
    exp: nowSeconds + TOKEN_TTL_SECONDS,
    nbf: nowSeconds - TOKEN_NOT_BEFORE_SECONDS,
    video: {
      roomJoin: true,
      room,
      canPublish: true,
      canSubscribe: true,
    },
  })));
  const signingInput = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(apiSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(signingInput));
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (request.method !== "POST") return fail(405, "forbidden");

  const authorization = request.headers.get("Authorization");
  if (!authorization || !/^bearer\s+\S+$/i.test(authorization)) {
    return fail(401, "unauthorized");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  if (!supabaseUrl || !anonKey) {
    console.error("video-token supabase environment is incomplete");
    return fail(500, "internal_error");
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) return fail(401, "unauthorized");

  let body: Record<string, unknown>;
  try {
    const parsed: unknown = await request.json();
    if (!isRecord(parsed)) return fail(400, "session_not_found");
    body = parsed;
  } catch {
    return fail(400, "session_not_found");
  }

  const rawSessionId = body.session_id;
  if (typeof rawSessionId !== "string" || !UUID_RE.test(rawSessionId)) {
    return fail(400, "session_not_found");
  }
  const sessionId = rawSessionId.toLowerCase();

  // RLS is the authorization boundary: video_sessions_select_org calls
  // public.can_access_video_session(id), so only a partner, the creator, a
  // linked-matter reader, or the linked booking's client sees the row;
  // everyone else gets no row (and therefore a 404). A policy-evaluation
  // error is surfaced as 403 below.
  const { data, error } = await userClient
    .from("video_sessions")
    .select("id,room_name,status")
    .eq("id", sessionId)
    .maybeSingle();

  if (error) {
    console.error("video-token session read failed", error.code ?? "unknown");
    if (error.code === "42501"
        || /permission denied|row-level security/i.test(error.message ?? "")) {
      return fail(403, "forbidden");
    }
    return fail(500, "internal_error");
  }
  if (!data) return fail(404, "session_not_found");

  const session = data as VideoSessionRow;
  if (session.status === "ended" || session.status === "cancelled") {
    return fail(409, "session_ended");
  }

  const livekitUrl = Deno.env.get("LIVEKIT_URL")?.trim().replace(/\/+$/, "");
  const apiKey = Deno.env.get("LIVEKIT_API_KEY")?.trim();
  const apiSecret = Deno.env.get("LIVEKIT_API_SECRET")?.trim();
  if (!livekitUrl || !apiKey || !apiSecret) {
    console.error("video-token livekit environment is incomplete");
    return fail(409, "provider_not_configured");
  }

  let token: string;
  try {
    token = await mintLiveKitToken(
      apiKey,
      apiSecret,
      userData.user.id,
      session.room_name,
      Math.floor(Date.now() / 1000),
    );
  } catch (error) {
    console.error("video-token mint failed", error instanceof Error ? error.name : "unknown");
    return fail(500, "internal_error");
  }

  return json(200, { url: livekitUrl, token, room: session.room_name });
});
