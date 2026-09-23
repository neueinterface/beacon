# Beacon Web Search MCP

This Cloudflare Worker exposes one bounded, stateless MCP tool at `/mcp`:

- `search_web`: searches Bing with a DuckDuckGo fallback and optionally extracts limited text from up to five results.
- `GET /model-downloads`: returns aggregate Beacon model download counts.
- `POST /model-downloads`: records one completed model download per anonymous app installation with `{ "modelID": "chat-pro", "installationID": "..." }`.

The service uses Cloudflare Browser Run and is designed to fail closed at the Workers Free plan limits. It does not use a search-provider API key.

## Security

- No credentials, account identifiers, or API tokens belong in this repository.
- Wrangler authentication stays in the developer's local Cloudflare configuration.
- Browser access uses a Cloudflare binding, not an API token.
- A per-IP Durable Object allows 20 search calls per rolling 24 hours.
- Only HTTPS destinations are followed; local, private, and IP-literal targets are rejected.
- MCP request size, query size, result count, extracted content, and navigation time are bounded.
- Only the `search_web` tool can trigger a browser session.

The public endpoint is rate-limited, not user-authenticated. Add App Attest verification before treating it as an unrestricted production service.

## Development

```sh
npm install
npm run types
npm run check
npm run dev
```

Browser Run can be exercised locally through Wrangler's browser binding. Cloudflare account login is required for remote binding or deployment, but no credential is written to the project.

## Deployment

```sh
npx wrangler login
npm run deploy
```

After deployment, use `https://<worker>.<account>.workers.dev/mcp` as Beacon's MCP endpoint. Free plan exhaustion returns an error rather than creating a bill.

The same Worker exposes `https://<worker>.<account>.workers.dev/model-downloads` for optional aggregate model download counts. Configure that URL separately in Beacon as `ModelDownloadsURL`.

Put the deployed endpoint in Beacon's Git-ignored `beacon/Resources/LocalConfiguration.plist` under the `WebSearchMCPURL` key. A fresh clone intentionally has no production endpoint and leaves web search disabled.
