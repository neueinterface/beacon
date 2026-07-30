# Semera

Semera is a local-first iOS assistant for chatting with private on-device AI models.

It lets you choose curated local models, download and manage them, and keep private chat history.

![Semera app screenshot](info.png)

## Features

- Private on-device chat with local MLX models
- Apple Foundation Model support when available
- Curated model marketplace and local model downloads
- Persisted chat history
- Markdown assistant responses
- Streaming responses with a stop button
- Reasoning/thinking stream shown separately from the final answer
- Attach and analyze images with the downloadable Qwen2-VL vision model
<!-- Web search and source dropdowns are not currently available.
- Optional web search through a Cloudflare Worker
- Source dropdowns that open links in in-app Safari
-->
- Shortcuts/App Intents support for asking the selected model

<!-- Web search is not currently available.
## Web Search

Semera keeps model inference local by default. Web search is only used when a prompt needs current information.

Supported controls:

- `/web your question` forces web search
- `/noweb your question` disables web search for that message
- Prompts with current-information signals such as `latest`, `today`, `news`, `price`, `weather`, or `2026` can trigger web search automatically

The app calls a Cloudflare Worker at `/search`. The Worker owns the search provider API key. Provider keys should never be placed in the iOS app.

For development, the app can send an `APP_API_KEY` authorization header to the Worker. That key is basic abuse protection only and should not be treated as a production secret because iOS app binaries can be inspected.
-->

## Architecture

- `BeaconModelRuntime` loads and streams local models
<!-- `WebSearchService` calls the Cloudflare Worker search endpoint
- `SourceTag` renders source dropdowns for web-backed answers -->
- `SafariView` opens source links inside the app
- `RequestLLMIntent` exposes a Shortcuts action for asking the selected model

## Release Notes

Before App Store release:

<!-- Web search release tasks are not currently applicable.
- Remove any hardcoded development `APP_API_KEY`
- Keep search provider API keys only in Cloudflare secrets
- Add Cloudflare rate limits and query length limits
- Consider App Attest, DeviceCheck, or account-based quotas if abuse becomes a concern
-->

## Requirements

- iOS Simulator or device supported by the project
- Xcode

## Development

Open `semera-ios.xcodeproj` in Xcode, select your signing team and bundle identifier, then build the `semera-ios` scheme.

Semera runs local models by default. A fork can opt into backend integrations by setting the `SEARCH_API_BASE_URL` build setting in Xcode or archive CI. The project passes that value to the generated Info.plist without committing a service URL. Never embed API keys, signing credentials, or provider secrets in the app.

### Run On Your iPhone

1. Clone the repository:

   ```sh
   git clone https://github.com/semeraco/semera-ios-public.git
   cd semera-ios-public
   ```

2. Open `semera-ios.xcodeproj` in Xcode and wait for Swift Package dependencies to resolve.
3. In the target's **Signing & Capabilities** settings, select your Apple Developer team and choose a unique bundle identifier.
4. Connect and unlock your iPhone, select it as the run destination, then press Run.
5. Download a text model from the marketplace. To attach images, download and select **Qwen2-VL 2B 4-bit (Image)**.

## Security

Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## License

Semera is available under the [MIT License](LICENSE).
