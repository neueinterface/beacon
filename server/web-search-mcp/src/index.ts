import { McpServer } from "@modelcontextprotocol/server";
import { createMcpHandler } from "agents/mcp/server";
import { z } from "zod";
import { SearchRateLimiter } from "./rate-limiter";
import { ModelDownloadCounter } from "./model-downloads";
import { searchWeb } from "./search";

export { SearchRateLimiter, ModelDownloadCounter };

const MAX_REQUEST_BYTES = 16_384;
const PROTOCOL_VERSION = "2025-06-18";

function createServer(env: Env): McpServer {
  const server = new McpServer({
    name: "beacon-web-search",
    version: "0.1.0"
  });

  server.registerTool(
    "search_web",
    {
      description: "Search the current web and optionally extract bounded text from the top results.",
      inputSchema: {
        query: z.string().trim().min(2).max(200),
        limit: z.number().int().min(1).max(5).default(3),
        includeContent: z.boolean().default(true),
        maxContentLength: z.number().int().min(500).max(5_000).default(3_000)
      }
    },
    async ({ query, limit, includeContent, maxContentLength }) => {
      const results = await searchWeb(env.BROWSER, {
        query,
        limit,
        includeContent,
        maxContentLength
      });

      return {
        content: [{
          type: "text",
          text: JSON.stringify({ query, results })
        }]
      };
    }
  );

  return server;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health" && request.method === "GET") {
      return secureJSON({ ok: true, service: "beacon-web-search-mcp" });
    }

    if (url.pathname === "/model-downloads" && request.method === "GET") {
      const counter = env.MODEL_DOWNLOADS.getByName("global");
      return secureJSON({ counts: await counter.counts() });
    }

    if (url.pathname === "/model-downloads" && request.method === "POST") {
      let body: unknown;
      try {
        body = await request.json();
      } catch {
        return secureJSON({ error: "Invalid JSON" }, 400);
      }

      const modelID = getModelID(body);
      const installationID = getInstallationID(body);
      if (!modelID || !installationID) return secureJSON({ error: "modelID and installationID are required" }, 400);

      const counter = env.MODEL_DOWNLOADS.getByName("global");
      await counter.record(modelID, installationID);
      return secureJSON({ ok: true });
    }

    if (url.pathname !== "/mcp") return new Response("Not found", { status: 404 });
    if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });

    const contentLength = Number(request.headers.get("content-length") ?? 0);
    if (contentLength > MAX_REQUEST_BYTES) return secureJSON({ error: "Request too large" }, 413);

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return secureJSON({ error: "Invalid JSON" }, 400);
    }

    if (JSON.stringify(body).length > MAX_REQUEST_BYTES) return secureJSON({ error: "Request too large" }, 413);

    if (isSearchToolCall(body)) {
      const identity = await clientIdentity(request);
      const limiter = env.SEARCH_RATE_LIMITER.getByName(identity);
      const limit = await limiter.consume();
      if (!limit.allowed) {
        return secureJSON({
          error: "Search limit reached",
          resetsAt: new Date(limit.resetsAt).toISOString()
        }, 429, {
          "Retry-After": String(Math.max(1, Math.ceil((limit.resetsAt - Date.now()) / 1_000))),
          "X-RateLimit-Limit": String(limit.limit),
          "X-RateLimit-Remaining": "0"
        });
      }
    }

    const handler = createMcpHandler(() => createServer(env), {
      route: "/mcp",
      corsOptions: false,
      legacy: "stateless",
      responseMode: "json",
      onerror(error) {
        console.error(JSON.stringify({ message: "MCP request failed", error: error.message }));
      }
    });

    const protocolHeaders = new Headers(request.headers);
    protocolHeaders.set("MCP-Protocol-Version", request.headers.get("MCP-Protocol-Version") ?? PROTOCOL_VERSION);
    protocolHeaders.delete("Content-Length");
    const protocolRequest = new Request(request.url, {
      method: "POST",
      headers: protocolHeaders,
      body: JSON.stringify(body)
    });
    const response = await handler.fetch(protocolRequest, { parsedBody: body });
    return withSecurityHeaders(response);
  }
} satisfies ExportedHandler<Env>;

function isSearchToolCall(body: unknown): boolean {
  if (!body || typeof body !== "object") return false;
  const request = body as { method?: unknown; params?: { name?: unknown } };
  return request.method === "tools/call" && request.params?.name === "search_web";
}

function getModelID(body: unknown): string | null {
  if (!body || typeof body !== "object") return null;
  const modelID = (body as { modelID?: unknown }).modelID;
  return typeof modelID === "string" && /^[a-z0-9][a-z0-9-]{0,63}$/.test(modelID)
    ? modelID
    : null;
}

function getInstallationID(body: unknown): string | null {
  if (!body || typeof body !== "object") return null;
  const installationID = (body as { installationID?: unknown }).installationID;
  return typeof installationID === "string" && /^[a-f0-9-]{36}$/.test(installationID)
    ? installationID
    : null;
}

async function clientIdentity(request: Request): Promise<string> {
  const address = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(address));
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
}

function secureJSON(body: unknown, status = 200, extraHeaders: HeadersInit = {}): Response {
  return withSecurityHeaders(Response.json(body, { status, headers: extraHeaders }));
}

function withSecurityHeaders(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set("Cache-Control", "no-store");
  headers.set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'");
  headers.set("Referrer-Policy", "no-referrer");
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("X-Frame-Options", "DENY");
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}
