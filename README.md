# Sonara

Sonara is a local-first iOS assistant for chatting with private on-device AI models.

It lets you choose curated local models, download and manage them, keep private chat history, and optionally use a lightweight Cloudflare-powered web search tool for current information.

![Sonara app screenshot](info.png)

## Features

- Private on-device chat with local MLX models
- Apple Foundation Model support when available
- Curated model marketplace and local model downloads
- Persisted chat history
- Markdown assistant responses
- Streaming responses with a stop button
- Reasoning/thinking stream shown separately from the final answer
- Optional web search through a Cloudflare Worker
- Source dropdowns that open links in in-app Safari
- Shortcuts/App Intents support for asking the selected model

## Web Search

Sonara keeps model inference local by default. Web search is only used when a prompt needs current information.

Supported controls:

- `/web your question` forces web search
- `/noweb your question` disables web search for that message
- Prompts with current-information signals such as `latest`, `today`, `news`, `price`, `weather`, or `2026` can trigger web search automatically

The app calls a Cloudflare Worker at `/search`. The Worker owns the Brave Search API key through a Cloudflare secret named `BRAVE_SEARCH_API_KEY`. The Brave key should never be placed in the iOS app.

For development, the app can send an `APP_API_KEY` authorization header to the Worker. That key is basic abuse protection only and should not be treated as a production secret because iOS app binaries can be inspected.

## Architecture

- `BeaconModelRuntime` loads and streams local models
- `WebSearchService` calls the Cloudflare Worker search endpoint
- `SourceTag` renders source dropdowns for web-backed answers
- `SafariView` opens source links inside the app
- `RequestLLMIntent` exposes a Shortcuts action for asking the selected model

## Release Notes

Before App Store release:

- Remove any hardcoded development `APP_API_KEY`
- Keep `BRAVE_SEARCH_API_KEY` only in Cloudflare secrets
- Add Cloudflare rate limits and query length limits
- Consider App Attest, DeviceCheck, or account-based quotas if abuse becomes a concern

## Requirements

- iOS Simulator or device supported by the project
- Xcode
