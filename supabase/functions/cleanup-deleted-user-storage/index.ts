import "jsr:@supabase/functions-js@^2/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

// Only bucket discovered in the repo: supabase/migrations/07_storage.sql:40-42
// and lib/data/supabase_wire.dart:15-17. Never invent another bucket.
export const BUCKETS = ["matter-files"] as const;

/** SECURITY DEFINER RPC from migration 36; public schema, service_role only. */
export const STORAGE_PATHS_RPC = "deleted_user_storage_paths" as const;

export type OwnedObject = {
  bucket_id: string;
  name: string;
  metadata?: Record<string, unknown> | null;
};

export type CleanupDeps = {
  /** Admin API: true when a user with this id still exists. */
  userExists(userId: string): Promise<boolean>;
  /** Storage metadata rows owned by this user (service-role read). */
  listOwnedObjects(userId: string): Promise<OwnedObject[]>;
  /** Storage API delete; returns the deleted entries or their count. */
  removeObject(bucket: string, name: string): Promise<Array<{ name: string }> | number>;
};

export type CleanupResult = {
  user_id: string;
  deleted: number;
  failed: string[];
  bytes: number;
};

export function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** Constant-time comparison of the Bearer token with the service-role key. */
export async function constantTimeEqual(left: string, right: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  if (a.length !== b.length) {
    // Still hash both inputs so length mismatches do not short-circuit.
    await crypto.subtle.digest("SHA-256", a);
    await crypto.subtle.digest("SHA-256", b);
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

/**
 * Caller credential is a dedicated custom token, never a Supabase API key.
 * Supabase's legacy SUPABASE_SERVICE_ROLE_KEY is deprecated and its injected
 * value can differ from the key returned by the Management API, so callers are
 * authenticated against an explicit secret instead. The internal client below
 * still uses the platform-injected service key for Admin/Storage API calls.
 */
export function configuredAuthToken(
  getEnv: (key: string) => string | undefined = (key) => Deno.env.get(key),
): string | undefined {
  return getEnv("CLEANUP_AUTH_TOKEN");
}

/** The caller must present the configured custom token; no anonymous deletion. */
export async function authorize(
  request: Request,
  expectedServiceKey: string | undefined,
): Promise<boolean> {
  if (!expectedServiceKey) return false;
  const provided = request.headers.get("authorization")?.replace(/^bearer\s+/i, "") ?? "";
  if (!provided) return false;
  return await constantTimeEqual(provided, expectedServiceKey);
}

function objectBytes(object: OwnedObject): number {
  const metadata = object.metadata;
  if (!metadata || typeof metadata !== "object") return 0;
  const raw = metadata.size ?? metadata["content-length"];
  return typeof raw === "number" && Number.isFinite(raw) && raw > 0 ? raw : 0;
}

/**
 * The core behavior, dependency-injected so tests never touch a live project.
 * Idempotent: a second run sees no owned objects and reports deleted: 0.
 */
export async function cleanup(
  userId: string | null | undefined,
  deps: CleanupDeps,
): Promise<{ status: number; body: Record<string, unknown> }> {
  if (typeof userId !== "string" || userId.trim() === "") {
    return { status: 400, body: { error: "user_id_required" } };
  }
  const id = userId.trim();

  // Never delete bytes while the identity still exists.
  if (await deps.userExists(id)) {
    return { status: 409, body: { error: "user_still_exists", user_id: id } };
  }

  const objects = await deps.listOwnedObjects(id);
  const failed: string[] = [];
  let deleted = 0;
  let bytes = 0;

  for (const object of objects) {
    if (!BUCKETS.includes(object.bucket_id as (typeof BUCKETS)[number])) {
      continue; // never act on an undiscovered bucket
    }
    try {
      const result = await deps.removeObject(object.bucket_id, object.name);
      const count = typeof result === "number" ? result : result.length;
      if (count > 0) {
        deleted += count;
        bytes += objectBytes(object);
      }
    } catch {
      failed.push(object.name); // partial failure never crashes the sweep
    }
  }

  const body: CleanupResult = { user_id: id, deleted, failed, bytes };
  return { status: 200, body: body as unknown as Record<string, unknown> };
}

/** Only a genuine 404 / "not found" means the identity is gone. */
function isNotFound(error: { status?: number; message?: string } | null): boolean {
  if (!error) return false;
  if (error.status === 404) return true;
  const message = (error.message ?? "").toLowerCase();
  return message.includes("user not found") || message.includes("not found");
}

export function realDeps(client: SupabaseClient): CleanupDeps {
  return {
    userExists: async (userId) => {
      const { data, error } = await client.auth.admin.getUserById(userId);
      if (error) {
        if (isNotFound(error)) return false;
        throw error; // fail closed: an outage must never authorize a delete
      }
      return Boolean(data?.user);
    },
    listOwnedObjects: async (userId) => {
      // Supabase's /rest/v1 only exposes public + graphql_public (PGRST106),
      // never the storage schema. The SECURITY DEFINER RPC in migration 36
      // reads storage.objects inside the database and returns exactly the
      // rows owned by userId, so no direct storage-schema HTTP access exists.
      const { data, error } = await client.rpc(STORAGE_PATHS_RPC, { p_user_id: userId });
      if (error) throw error;
      return (data ?? []) as OwnedObject[];
    },
    removeObject: async (bucket, name) => {
      const { data, error } = await client.storage.from(bucket).remove([name]);
      if (error) throw error;
      return (data ?? []) as Array<{ name: string }>;
    },
  };
}

export async function handler(request: Request): Promise<Response> {
  if (!(await authorize(
    request,
    configuredAuthToken(),
  ))) {
    return json(401, { error: "unauthorized" });
  }
  const url = new URL(request.url);
  let userId: string | null = url.searchParams.get("user_id");
  if (request.method === "POST") {
    try {
      const body = await request.json() as { user_id?: unknown };
      if (typeof body.user_id === "string") userId = body.user_id;
    } catch {
      return json(400, { error: "invalid_json" });
    }
  }

  const serviceUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SECRET_KEY");
  if (!serviceUrl || !serviceKey) return json(500, { error: "server_misconfigured" });

  const client = createClient(serviceUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let result;
  try {
    result = await cleanup(userId, realDeps(client));
  } catch {
    // A failed identity check (or list read) must never delete bytes.
    return json(500, { error: "user_check_failed" });
  }
  return json(result.status, result.body);
}

if (import.meta.main) Deno.serve(handler);
