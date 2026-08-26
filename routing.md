# Beacon Web Search Routing

Beacon answers locally by default. When a message needs current information, the already-loaded local model decides whether to call Beacon's Cloudflare-hosted MCP search tool. Search results return to the phone and the selected local model writes the final answer.

## Request Flow

```text
User message
    |
    v
Selected model loaded on the iPhone
    |
    v
Local routing pass: NO_SEARCH or SEARCH: <query>
    |                              |
    | NO_SEARCH                    | SEARCH
    v                              v
Local answer                 HTTPS POST /mcp
                                   |
                                   v
                         Cloudflare Worker rate limit
                                   |
                                   v
                         Bing search, DuckDuckGo fallback
                                   |
                                   v
                         Bounded page-text extraction
                                   |
                                   v
                         MCP result over JSON/SSE
                                   |
                                   v
                         Untrusted search context added locally
                                   |
                                   v
                         Selected local model writes answer
                                   |
                                   v
                         Sources saved and shown in chat
```

## 1. Local Routing

`BeaconModelRuntime.webSearchQuery` first checks deterministic recency phrases such as `recent`, `latest`, `today`, `weather`, `score`, and `who won`. These obvious cases go directly to search with the current year added when no year was supplied. This prevents a small model from incorrectly suppressing an obviously time-sensitive tool call.

For less obvious messages, Beacon runs a separate deterministic generation using the model that is already loaded for chat. Beacon does not download or keep a second routing model in memory.

The router receives:

- The latest user message.
- Up to four recent conversation messages, truncated to 500 characters each.
- Instructions to return exactly `NO_SEARCH` or `SEARCH: <standalone query>`.
- A maximum of 64 output tokens and temperature `0` for MLX models.

Search is intended for current events, weather, prices, schedules, recent releases, requested sources, and other facts likely to change. Casual conversation, creative work, rewriting, and timeless knowledge stay local.

Two explicit overrides are available:

- `/web <query>` always searches.
- `/noweb <message>` always skips search.

Image requests currently skip web routing and use the vision-model path.

## 2. MCP Request

`WebSearchMCPClient` reads the production endpoint from the Git-ignored `beacon/Resources/LocalConfiguration.plist` file and sends a stateless JSON-RPC `tools/call` request to:

```text
https://<worker>.<account>.workers.dev/mcp
```

A fresh clone does not contain the local configuration, so web search is disabled until the developer supplies an endpoint. The endpoint remains discoverable in a distributed app bundle or through network inspection; this keeps account-specific infrastructure out of Git but is not an authentication control.

The request calls only `search_web` and asks for:

- At most three results.
- At most 2,500 characters of extracted text per result.
- A query no longer than 200 characters.
- A 35-second client timeout.

The MCP endpoint can respond with JSON or Server-Sent Events. Beacon accepts both and extracts the JSON-RPC result from the SSE envelope when necessary.

## 3. Worker Search

The Worker lives in `server/web-search-mcp/` and uses Cloudflare Browser Run.

For each accepted call it:

1. Applies a Durable Object rate limit keyed by a SHA-256 hash of Cloudflare's connecting IP.
2. Searches Google and falls back to Bing, then DuckDuckGo, if a provider has no usable results.
3. Unwraps search-engine redirect links before returning sources.
4. Checks whether result titles and summaries overlap the meaningful query terms.
5. Retries once with a date-aware, disambiguated query when results are clearly off-topic.
6. Optionally visits each result and extracts bounded visible page text.
7. Returns titles, direct HTTPS URLs, descriptions, and extracted text through MCP.

Browser requests are guarded against local, private, IP-literal, non-HTTPS, and redirect-based SSRF destinations. Request size, result count, query length, extraction length, and navigation time are bounded.

## 4. Local Answer Generation

The phone treats all returned page text as untrusted data. The final prompt tells the local model to ignore instructions found in search results and use them only as reference material.

The selected local model writes the answer on-device. Sources are stored separately on the assistant message, so the model is instructed not to generate its own source section. The chat UI displays expandable source links and opens them in Safari.

## Failure Behavior

- If automatic routing says `NO_SEARCH`, Beacon answers locally.
- If automatic search fails, Beacon falls back to a normal local answer.
- If a forced `/web` search fails, Beacon shows the error instead of silently ignoring the command.
- HTTP `429` means the rolling per-IP search limit was reached.
- Cancelling generation cancels routing, search, or local generation in progress.

## Privacy Boundary

Local-only messages and normal model generation do not go through the Worker.

When search is selected:

- The generated standalone search query is sent to the Cloudflare Worker.
- The full conversation transcript is not sent to the Worker.
- The Worker sends the query to a public search engine and visits result pages.
- Cloudflare can observe normal request metadata such as IP address, timing, and user agent.
- The Durable Object is addressed by a hash of the connecting IP; Beacon does not intentionally store raw chat messages or raw IP addresses in Worker storage.
- Search results return to the phone, where final answer generation remains local.

## Is The Worker Public?

Yes. `workers_dev` is enabled, so the configured `workers.dev` hostname is reachable from the public internet. The hostname contains the account's public Worker subdomain, but it does not expose Cloudflare credentials or API tokens. The production hostname is intentionally kept in a Git-ignored local configuration file rather than tracked source.

Public routes are intentionally narrow:

- `GET /health` returns service health.
- `POST /mcp` accepts MCP requests.
- Other paths return `404` and other methods on `/mcp` return `405`.

The endpoint is rate-limited, but it is not authenticated. The current limit is 20 searches per connecting IP per rolling 24 hours. That slows individual callers but does not prove that a request came from Beacon, and callers using many IP addresses could still consume the account's free Browser Run allowance or cause a denial of service.

Before treating this as an unrestricted production service, add Apple App Attest verification or another server-verifiable client attestation mechanism. Do not put a static secret in the public iPhone app because it can be extracted and reused.

## Free-Tier Boundaries

- The Worker has no search-provider API key.
- Per-IP search calls are capped by the Durable Object.
- Cloudflare account-level Worker and Browser Run free-plan limits still apply.
- Exhausted Cloudflare capacity should fail requests rather than move model inference off-device.

## Using Your Own Web Search MCP

A fresh clone intentionally has no production endpoint. Contributors can deploy the included Worker to their own Cloudflare account or provide another compatible MCP server.

### Deploy The Included Worker

From the repository root:

```sh
cd server/web-search-mcp
npm install
npx wrangler login
npm run check
npx wrangler deploy --dry-run
npm run deploy
```

Wrangler prints a public Worker URL after deployment. The Beacon endpoint is that HTTPS URL with `/mcp` appended.

If the Worker name is already taken in the contributor's account, change `name` in `server/web-search-mcp/wrangler.jsonc` before deploying. The configuration automatically provisions the Browser Run binding and the SQLite-backed `SearchRateLimiter` Durable Object migration.

### Configure The Local App

Create `beacon/Resources/LocalConfiguration.plist` with the contributor's endpoint:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>WebSearchMCPURL</key>
    <string>https://YOUR-WORKER.YOUR-SUBDOMAIN.workers.dev/mcp</string>
</dict>
</plist>
```

`LocalConfiguration.plist` is ignored by Git and bundled into that developer's local app build. Without it, automatic search is disabled and `/web` reports that web search is not configured.

### Debug and App Store builds

The shared `beacon` scheme runs and tests with the Debug configuration, while Archive uses Release:

- Debug installs as `Beacon Dev` with bundle identifier `me.armond.semera-ios.dev`, uses the yellow development icon, and reads the ignored `LocalConfiguration.plist`.
- Release installs as `Beacon` with bundle identifier `me.armond.semera-ios`, uses the production icon, and reads the ignored `ReleaseConfiguration.plist`.

Create `beacon/Resources/ReleaseConfiguration.plist` locally before creating an App Store archive. It has the same shape as `LocalConfiguration.plist`, but contains the production endpoint. Both files are ignored by Git, and each build excludes the configuration belonging to the other channel.

Then archive normally:

```sh
xcodebuild archive \
  -project beacon.xcodeproj \
  -scheme beacon \
  -configuration Release \
  -archivePath build/Beacon.xcarchive
```

For CI, generate `ReleaseConfiguration.plist` from a protected environment variable in a pre-build step. The endpoint is configuration rather than a secret: users can still recover it from a distributed app or observe it in network traffic. Ignoring the file only keeps deployment-specific configuration out of the repository.

Do not put Cloudflare API tokens, Wrangler OAuth credentials, or search-provider secrets in this file. Beacon only needs the public MCP endpoint. Wrangler credentials remain in the developer's user-level Wrangler configuration.

### Use Another MCP Server

Beacon does not currently discover arbitrary tools. A replacement server must implement the specific stateless contract expected by `WebSearchMCPClient`:

- HTTPS Streamable HTTP MCP endpoint.
- MCP protocol version `2025-06-18`.
- JSON-RPC method `tools/call`.
- Tool name `search_web`.
- Arguments `query`, `limit`, `includeContent`, and `maxContentLength`.
- A JSON or Server-Sent Events response containing an MCP text content item.

The text content must itself contain JSON in this shape:

```json
{
  "query": "standalone search query",
  "results": [
    {
      "title": "Result title",
      "url": "https://example.com/page",
      "description": "Short search-result summary",
      "content": "Optional bounded page text"
    }
  ]
}
```

Result URLs must use HTTPS. Beacon requests at most three results and currently includes up to 2,500 characters of page text per result in the local answer prompt.

For compatible quota errors, return HTTP `429` with an optional ISO-8601 `resetsAt` value:

```json
{
  "error": "Search limit reached",
  "resetsAt": "2026-08-26T12:00:00.000Z"
}
```

Test the replacement endpoint with `/web <query>` before relying on automatic routing. The endpoint is still discoverable from a built app, so server-side authentication must not rely on a static secret embedded in the plist.

## Relevant Files

- `beacon/Services/BeaconModelRuntime.swift`: local routing decision.
- `beacon/Services/WebSearchMCPClient.swift`: MCP request and JSON/SSE decoding.
- `beacon/Views/Chat/ChatView.swift`: orchestration, fallback, context injection, and source persistence.
- `beacon/Views/Chat/MessageBubble.swift`: search status and source presentation.
- `server/web-search-mcp/src/index.ts`: MCP endpoint, request validation, and rate-limit entry point.
- `server/web-search-mcp/src/search.ts`: browser search and bounded extraction.
- `server/web-search-mcp/src/url-safety.ts`: URL validation and redirect cleanup.
- `server/web-search-mcp/src/rate-limiter.ts`: rolling per-IP quota.
- `server/web-search-mcp/wrangler.jsonc`: production bindings and public `workers.dev` configuration.

## Operations

From `server/web-search-mcp/`:

```sh
npm run check
npx wrangler deploy --dry-run
npm run deploy
npx wrangler tail
```

Health check:

```sh
curl https://<worker>.<account>.workers.dev/health
```
