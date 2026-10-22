import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DEFAULT_MODEL = "deepseek-ai/DeepSeek-V4.1-Flash-1017";
const DEFAULT_BASE_URL = "https://api.river.ai/v1";
const MAX_CONTEXT_CHARS = 12_000;
const MAX_FINDINGS = 12;
const PROVIDER_TIMEOUT_MS = 30_000;

type FailureCode =
  | "unauthorized"
  | "forbidden"
  | "invalid_request"
  | "context_too_large"
  | "provider_not_configured"
  | "provider_unavailable"
  | "invalid_response";

type SourceType = "document" | "matter" | "none";

type Finding = {
  headline: string;
  summary: string;
  excerpt: string | null;
  source_type: SourceType;
  source_id: string | null;
};

type MatterRow = {
  id: string;
  title: string;
  practice_area: string;
  status: string;
};

type DocumentRow = {
  id: string;
  matter_id: string;
  title: string;
  document_type: string;
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

function stripCodeFences(text: string): string {
  let value = text.trim();
  if (!value.startsWith("```")) return value;
  value = value.replace(/^```[a-zA-Z0-9_-]*\s*\n?/, "");
  value = value.replace(/\n?```\s*$/, "");
  return value.trim();
}

function parseFindings(
  value: unknown,
  matterId: string | null,
  documentIds: Set<string>,
): Finding[] | null {
  if (!isRecord(value) || !Array.isArray(value.findings)) return null;
  const rawFindings = value.findings;
  if (rawFindings.length < 1 || rawFindings.length > MAX_FINDINGS) return null;

  const findings: Finding[] = [];
  for (const item of rawFindings) {
    if (!isRecord(item)) return null;

    const headline = typeof item.headline === "string" ? item.headline.trim() : "";
    const summary = typeof item.summary === "string" ? item.summary.trim() : "";
    if (headline.length < 2 || headline.length > 200) return null;
    if (summary.length < 2 || summary.length > 4000) return null;

    let excerpt: string | null = null;
    if (item.excerpt !== undefined && item.excerpt !== null) {
      if (typeof item.excerpt !== "string" || item.excerpt.length > 2000) return null;
      excerpt = item.excerpt;
    }

    const rawSourceType = item.source_type;
    if (rawSourceType !== undefined && rawSourceType !== null && typeof rawSourceType !== "string") {
      return null;
    }
    const sourceType = rawSourceType === undefined || rawSourceType === null || rawSourceType === ""
      ? "none"
      : rawSourceType;
    if (sourceType !== "document" && sourceType !== "matter" && sourceType !== "none") return null;

    const rawSourceId = item.source_id;
    if (rawSourceId !== undefined && rawSourceId !== null
        && (typeof rawSourceId !== "string" || !UUID_RE.test(rawSourceId))) {
      return null;
    }
    const sourceId = rawSourceId === undefined || rawSourceId === null
      ? null
      : rawSourceId.toLowerCase();

    if (sourceType === "none" && sourceId !== null) return null;
    if (sourceType === "document" && (sourceId === null || !documentIds.has(sourceId))) return null;
    if (sourceType === "matter" && (sourceId === null || sourceId !== matterId)) return null;

    findings.push({
      headline,
      summary,
      excerpt,
      source_type: sourceType,
      source_id: sourceId,
    });
  }
  return findings;
}

function buildPrompt(context: string, question: string): string {
  return `Analyze the question using only the supplied context.

Question:
${question}

Context:
${context}

Return strict JSON only, with this shape:
{"findings":[{"headline":"string (2-200 chars)","summary":"string (2-4000 chars)","excerpt":"string or null","source_type":"document|matter|none","source_id":"uuid or null"}]}

Rules:
- Produce between 1 and ${MAX_FINDINGS} findings.
- Do not invent facts, citations, or identifiers.
- Every finding must cite a supplied document id, the supplied matter id, or "none".
- "none" requires source_id null. "document"/"matter" require the matching supplied id.
- The analysis is AI-generated and is not legal advice or attorney verification.`;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (request.method !== "POST") return fail(405, "invalid_request");

  const authorization = request.headers.get("Authorization");
  if (!authorization || !/^bearer\s+\S+$/i.test(authorization)) {
    return fail(401, "unauthorized");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    console.error("research-analyze supabase environment is incomplete");
    return fail(500, "provider_unavailable");
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const recordFailure = async (runId: string, code: FailureCode): Promise<void> => {
    const { error } = await serviceClient.rpc("complete_research_run", {
      p_run_id: runId,
      p_status: "failed",
      p_model: null,
      p_error_code: code,
      p_findings: null,
    });
    if (error) {
      console.error("research-analyze could not record run failure", error.code ?? "unknown");
    }
  };

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) return fail(401, "unauthorized");

  let body: Record<string, unknown>;
  try {
    const parsed: unknown = await request.json();
    if (!isRecord(parsed)) return fail(400, "invalid_request");
    body = parsed;
  } catch {
    return fail(400, "invalid_request");
  }

  const organizationId = body.organization_id;
  const rawMatterId = body.matter_id;
  const rawDocumentIds = body.document_ids;
  const rawQuestion = body.question;

  if (typeof organizationId !== "string" || !UUID_RE.test(organizationId)) {
    return fail(400, "invalid_request");
  }
  if (rawMatterId !== null && rawMatterId !== undefined
      && (typeof rawMatterId !== "string" || !UUID_RE.test(rawMatterId))) {
    return fail(400, "invalid_request");
  }
  if (!Array.isArray(rawDocumentIds)
      || rawDocumentIds.some((id) => typeof id !== "string" || !UUID_RE.test(id))) {
    return fail(400, "invalid_request");
  }
  if (typeof rawQuestion !== "string") return fail(400, "invalid_request");
  const question = rawQuestion.trim();
  if (question.length < 2 || question.length > 500) {
    return fail(400, "invalid_request");
  }

  const matterId = typeof rawMatterId === "string" ? rawMatterId.toLowerCase() : null;
  const documentIds = [...new Set(rawDocumentIds.map((id) => (id as string).toLowerCase()))];
  const documentIdSet = new Set(documentIds);

  const { data: runId, error: startError } = await userClient.rpc("start_research_run", {
    p_organization_id: organizationId,
    p_matter_id: matterId,
    p_prompt_summary: question,
  });

  if (startError || typeof runId !== "string" || !UUID_RE.test(runId)) {
    console.error("research-analyze start rpc failed", startError?.code ?? "unknown");
    if (startError && /permission denied|not authorized|forbidden/i.test(startError.message)) {
      return fail(403, "forbidden");
    }
    if (startError && /invalid|must be|violat/i.test(startError.message)) {
      return fail(400, "invalid_request");
    }
    return fail(500, "invalid_response");
  }

  let matter: MatterRow | null = null;
  if (matterId !== null) {
    const { data, error } = await userClient
      .from("matters")
      .select("id,title,practice_area,status")
      .eq("id", matterId)
      .maybeSingle();
    if (error) {
      console.error("research-analyze matter read failed", error.code ?? "unknown");
      await recordFailure(runId, "invalid_response");
      return fail(500, "invalid_response");
    }
    if (!data) {
      await recordFailure(runId, "forbidden");
      return fail(403, "forbidden");
    }
    matter = data as MatterRow;
  }

  let documents: DocumentRow[] = [];
  if (documentIds.length > 0) {
    const { data, error } = await userClient
      .from("documents")
      .select("id,matter_id,title,document_type")
      .eq("organization_id", organizationId)
      .in("id", documentIds);
    if (error) {
      console.error("research-analyze document read failed", error.code ?? "unknown");
      await recordFailure(runId, "invalid_response");
      return fail(500, "invalid_response");
    }
    documents = (data ?? []) as DocumentRow[];
    if (documents.length !== documentIds.length) {
      await recordFailure(runId, "forbidden");
      return fail(403, "forbidden");
    }
  }

  const contextParts: string[] = [];
  contextParts.push(matter
    ? [
      `Matter id: ${matter.id}`,
      `Title: ${matter.title}`,
      `Practice area: ${matter.practice_area}`,
      `Status: ${matter.status}`,
    ].join("\n")
    : "Matter: none supplied.");
  contextParts.push(documents.length === 0
    ? "Documents: none supplied."
    : documents.map((document) =>
      `Document id: ${document.id}\nType: ${document.document_type}\nTitle: ${document.title}`
    ).join("\n\n"));
  const context = contextParts.join("\n\n");

  if (context.length > MAX_CONTEXT_CHARS) {
    await recordFailure(runId, "context_too_large");
    return fail(422, "context_too_large");
  }

  const apiKey = Deno.env.get("RIVER_API_KEY")?.trim();
  if (!apiKey) {
    await recordFailure(runId, "provider_not_configured");
    return fail(409, "provider_not_configured");
  }

  const baseUrl = (Deno.env.get("RIVER_BASE_URL")?.trim() || DEFAULT_BASE_URL)
    .replace(/\/+$/, "");
  const model = (Deno.env.get("RIVER_MODEL")?.trim() || DEFAULT_MODEL);

  let upstream: Response;
  try {
    upstream = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        temperature: 0.2,
        messages: [
          {
            role: "system",
            content:
              "You are a legal research assistant. Use only the supplied context. Return strict JSON only; never invent facts or identifiers. The output is AI-generated and is not legal advice.",
          },
          { role: "user", content: buildPrompt(context, question) },
        ],
      }),
      signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
    });
  } catch (error) {
    console.error(
      "research-analyze provider request failed",
      error instanceof Error ? error.name : "unknown",
    );
    await recordFailure(runId, "provider_unavailable");
    return fail(502, "provider_unavailable");
  }

  if (!upstream.ok) {
    console.error("research-analyze provider status", upstream.status);
    await recordFailure(runId, "provider_unavailable");
    return fail(502, "provider_unavailable");
  }

  let payload: unknown;
  try {
    payload = JSON.parse(await upstream.text());
  } catch {
    await recordFailure(runId, "invalid_response");
    return fail(500, "invalid_response");
  }

  const choices = isRecord(payload) ? payload.choices : undefined;
  const content = Array.isArray(choices) && choices.length > 0 && isRecord(choices[0])
    ? choices[0].message
    : undefined;
  const text = isRecord(content) && typeof content.content === "string"
    ? content.content
    : null;

  if (text === null || text.trim() === "") {
    await recordFailure(runId, "invalid_response");
    return fail(500, "invalid_response");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(stripCodeFences(text));
  } catch {
    await recordFailure(runId, "invalid_response");
    return fail(500, "invalid_response");
  }

  const findings = parseFindings(parsed, matterId, documentIdSet);
  if (!findings) {
    await recordFailure(runId, "invalid_response");
    return fail(500, "invalid_response");
  }

  const { error: completeError } = await serviceClient.rpc("complete_research_run", {
    p_run_id: runId,
    p_status: "completed",
    p_model: model,
    p_error_code: null,
    p_findings: findings,
  });

  if (completeError) {
    console.error("research-analyze completion rpc failed", completeError.code ?? "unknown");
    await recordFailure(runId, "invalid_response");
    return fail(500, "invalid_response");
  }

  return json(200, {
    run_id: runId,
    status: "completed",
    model,
    findings,
  });
});
