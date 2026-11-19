import { authorize, cleanup, configuredAuthToken, realDeps, STORAGE_PATHS_RPC, type CleanupDeps, type OwnedObject } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown, label: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${label}: expected ${e}, got ${a}`);
}

function mockDeps(objects: OwnedObject[], exists = false) {
  const removed: Array<{ bucket: string; name: string }> = [];
  const failing = new Set<string>();
  const deps: CleanupDeps = {
    userExists: async () => { await Promise.resolve(); return exists; },
    listOwnedObjects: async (_userId) => {
      await Promise.resolve();
      return objects.slice();
    },
    removeObject: async (bucket, name) => {
      await Promise.resolve();
      if (failing.has(name)) throw new Error("storage failure");
      removed.push({ bucket, name });
      return [{ name }];
    },
  };
  return { deps, removed, failing };
}

const TARGET = "11111111-1111-4111-8111-111111111111";
const bytes = (n: number) => ({ size: n });

Deno.test("deletes only the target user's objects in the discovered bucket", async () => {
  const { deps, removed } = mockDeps([
    { bucket_id: "matter-files", name: `${TARGET}/matter/a.pdf`, metadata: bytes(100) },
    { bucket_id: "matter-files", name: `${TARGET}/matter/b.pdf`, metadata: bytes(250) },
    { bucket_id: "other-bucket", name: `${TARGET}/x.pdf`, metadata: bytes(999) },
  ]);
  const result = await cleanup(TARGET, deps);
  assertEquals(result.status, 200, "status");
  assertEquals(
    { deleted: result.body.deleted, bytes: result.body.bytes, failed: result.body.failed },
    { deleted: 2, bytes: 350, failed: [] },
    "measured result",
  );
  assertEquals(removed, [
    { bucket: "matter-files", name: `${TARGET}/matter/a.pdf` },
    { bucket: "matter-files", name: `${TARGET}/matter/b.pdf` },
  ], "deleted objects");
});

Deno.test("another user's objects are never listed or removed", async () => {
  const other = "22222222-2222-4222-8222-222222222222";
  const all = [
    { bucket_id: "matter-files", name: `${TARGET}/mine.pdf`, metadata: bytes(10) },
    { bucket_id: "matter-files", name: `${other}/theirs.pdf`, metadata: bytes(20) },
  ];
  const { deps, removed } = mockDeps(all.filter((o) => o.name.startsWith(TARGET)));
  const result = await cleanup(TARGET, deps);
  assertEquals(result.body.deleted, 1, "deleted count");
  assertEquals(removed.length, 1, "remove calls");
  assertEquals(removed[0].name.startsWith(TARGET), true, "scoped to target");
});

Deno.test("refuses when the user still exists and deletes nothing", async () => {
  const { deps, removed } = mockDeps([
    { bucket_id: "matter-files", name: `${TARGET}/a.pdf`, metadata: bytes(10) },
  ], true);
  const result = await cleanup(TARGET, deps);
  assertEquals(result.status, 409, "status");
  assertEquals(result.body.error, "user_still_exists", "error code");
  assertEquals(removed.length, 0, "no deletes");
});

Deno.test("refuses an empty or missing user_id without touching storage", async () => {
  const { deps, removed } = mockDeps([]);
  for (const bad of [null, undefined, "", "   "]) {
    const result = await cleanup(bad, deps);
    assertEquals(result.status, 400, `status for ${JSON.stringify(bad)}`);
    assertEquals(result.body.error, "user_id_required", "error code");
  }
  assertEquals(removed.length, 0, "no deletes");
});

Deno.test("second run is idempotent and reports deleted: 0", async () => {
  let remaining: OwnedObject[] = [
    { bucket_id: "matter-files", name: `${TARGET}/a.pdf`, metadata: bytes(64) },
  ];
  const deps: CleanupDeps = {
    userExists: async () => { await Promise.resolve(); return false; },
    listOwnedObjects: async () => {
      await Promise.resolve();
      return remaining.slice();
    },
    removeObject: async (_bucket, name) => {
      await Promise.resolve();
      remaining = remaining.filter((o) => o.name !== name);
      return [{ name }];
    },
  };
  const first = await cleanup(TARGET, deps);
  const second = await cleanup(TARGET, deps);
  assertEquals(first.body.deleted, 1, "first run");
  assertEquals(second.body.deleted, 0, "second run");
  assertEquals(second.body.bytes, 0, "second run bytes");
  assertEquals(second.status, 200, "not an error");
});

Deno.test("partial failure is reported in failed without crashing", async () => {
  const { deps, failing } = mockDeps([
    { bucket_id: "matter-files", name: `${TARGET}/ok.pdf`, metadata: bytes(10) },
    { bucket_id: "matter-files", name: `${TARGET}/bad.pdf`, metadata: bytes(20) },
    { bucket_id: "matter-files", name: `${TARGET}/ok2.pdf`, metadata: bytes(30) },
  ]);
  failing.add(`${TARGET}/bad.pdf`);
  const result = await cleanup(TARGET, deps);
  assertEquals(result.status, 200, "status");
  assertEquals(result.body.deleted, 2, "successful deletes");
  assertEquals(result.body.bytes, 40, "measured bytes");
  assertEquals(result.body.failed, [`${TARGET}/bad.pdf`], "failed names");
});

Deno.test("a failing Admin API check aborts and deletes nothing", async () => {
  const { deps, removed } = mockDeps([
    { bucket_id: "matter-files", name: `${TARGET}/a.pdf`, metadata: bytes(100) },
  ]);
  deps.userExists = async () => {
    await Promise.resolve();
    throw new Error("admin api 500");
  };
  let threw = false;
  try {
    await cleanup(TARGET, deps);
  } catch {
    threw = true;
  }
  assertEquals(threw, true, "cleanup aborts");
  assertEquals(removed.length, 0, "no deletes after a failed identity check");
});

Deno.test("realDeps reads storage metadata through the RPC, never .schema('storage')", async () => {
  let rpcName = "";
  let rpcArgs: Record<string, unknown> = {};
  const fakeClient = {
    rpc: (name: string, args: Record<string, unknown>) => {
      rpcName = name;
      rpcArgs = args;
      return Promise.resolve({ data: [] as OwnedObject[], error: null });
    },
  } as unknown as Parameters<typeof realDeps>[0];
  const deps = realDeps(fakeClient);
  const rows = await deps.listOwnedObjects(TARGET);
  assertEquals(rpcName, STORAGE_PATHS_RPC, "rpc name");
  assertEquals(rpcArgs, { p_user_id: TARGET }, "rpc args");
  assertEquals(rows, [], "rows");
});

Deno.test("caller authorization reads the dedicated CLEANUP_AUTH_TOKEN", async () => {
  const key = "cln_test_custom_token";
  assertEquals(
    configuredAuthToken((name) => name === "CLEANUP_AUTH_TOKEN" ? key : undefined),
    key,
    "reads CLEANUP_AUTH_TOKEN",
  );
  assertEquals(
    configuredAuthToken((name) => name === "SUPABASE_SERVICE_ROLE_KEY" ? key : undefined),
    undefined,
    "does not fall back to the deprecated service-role key",
  );
  const withKey = new Request("https://example.test/", { headers: { authorization: `Bearer ${key}` } });
  const without = new Request("https://example.test/");
  assertEquals(await authorize(withKey, configuredAuthToken((n) => n === "CLEANUP_AUTH_TOKEN" ? key : undefined)), true, "valid custom token");
  assertEquals(await authorize(without, key), false, "missing token");
  assertEquals(await authorize(withKey, "different"), false, "wrong token");
  assertEquals(await authorize(withKey, undefined), false, "no configured token");
});
