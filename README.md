# Beacon

Beacon is a private, local-first AI assistant for Apple devices. It downloads and runs MLX language models on-device, so everyday chats and inference stay on your device.

The project explores what a polished, approachable interface for local AI can look like. Beacon supports different model families and capabilities so people can choose the model that best fits their device and task.

![Beacon app screenshot](info.png)

## Features

- Private on-device chat with local MLX models
- A curated marketplace of iPhone-suitable Hugging Face MLX models
- Persisted conversations with history selection and swipe-to-delete
- Streaming Markdown responses, including code blocks and inline formatting, with a stop button
- Shortcuts/App Intents support for asking the selected model

## Included Models

The bundled catalog contains 4-bit text models supported by the pinned MLX Swift LM runtime. Download sizes are approximate and exclude runtime memory required during generation.

| Model | Hugging Face repository | Download | Recommended device |
| --- | --- | ---: | --- |
| LFM2 1.2B | [`mlx-community/LFM2-1.2B-4bit`](https://huggingface.co/mlx-community/LFM2-1.2B-4bit) | 0.66 GB | iPhone 14+ |
| Qwen3 0.6B | [`mlx-community/Qwen3-0.6B-4bit`](https://huggingface.co/mlx-community/Qwen3-0.6B-4bit) | 0.68 GB | iPhone 14+ |
| Qwen3 1.7B | [`mlx-community/Qwen3-1.7B-4bit`](https://huggingface.co/mlx-community/Qwen3-1.7B-4bit) | 0.98 GB | iPhone 14+ |
| Llama 3.2 1B Instruct | [`mlx-community/Llama-3.2-1B-Instruct-4bit`](https://huggingface.co/mlx-community/Llama-3.2-1B-Instruct-4bit) | 1.41 GB | iPhone 14+ |
| SmolLM3 3B | [`mlx-community/SmolLM3-3B-4bit`](https://huggingface.co/mlx-community/SmolLM3-3B-4bit) | 1.75 GB | iPhone 15 Pro+ |

Models are downloaded from Hugging Face and stored in the app cache. The marketplace prevents downloads when a model is unsuitable for the current device or would exceed Beacon's 10 GB model-storage limit.

## Architecture

- `BeaconModelRuntime` loads MLX models from a Hugging Face repository and streams responses
- `Resources/models.json` defines the bundled marketplace catalog
- `WebSearchMCPClient` implements the optional MCP-compatible web-search integration
- `RequestLLMIntent` exposes a Shortcuts action for asking the selected model

## Requirements

- Xcode with the iOS SDK
- An iPhone supported by the selected model for on-device inference

## Development

Open `beacon.xcodeproj` in Xcode, select your signing team and bundle identifier, then build the `beacon` scheme.

Add or update compatible models by editing `beacon/Resources/models.json`. Each downloadable entry must be a 4-bit Hugging Face MLX repository whose `model_type` is supported by the pinned `MLX Swift LM` package. Model cards should use accurate repository IDs, download sizes, and device guidance.

### Run On Your iPhone

1. Clone the repository:

   ```sh
   git clone https://github.com/armondschneider/beacon.git
   cd beacon
   ```

2. Open `beacon.xcodeproj` in Xcode and wait for Swift Package dependencies to resolve.
3. In the target's **Signing & Capabilities** settings, select your Apple Developer team and choose a unique bundle identifier.
4. Connect and unlock your iPhone, select it as the run destination, then press Run.
5. Download a model from the marketplace, then select it before starting a chat.

### Optional Backend Setup

Beacon does not require a backend for local chat. The anonymous model-download counter is an optional service that each developer can host for their own build.

The repository also includes a grounded web-search integration, but it is currently disabled in `ChatView` for this release. Before enabling it in a build, deploy the service below and provide its endpoint. Beacon sends only the resolved search query; returned sources are rendered as numbered citations and tappable inline source cards.

The repository includes a Cloudflare Worker in `server/web-search-mcp` that provides both the web search MCP endpoint and model download analytics. To run your own instance:

1. Create a Cloudflare account and install Node.js.
2. From `server/web-search-mcp`, run `npm install` and `npx wrangler login`.
3. Deploy with `npm run deploy`.
4. Add the deployed URL to your local `beacon/Resources/LocalConfiguration.plist`:

   ```xml
   <key>WebSearchMCPURL</key>
   <string>https://your-worker.workers.dev/mcp</string>
   <key>ModelDownloadsURL</key>
   <string>https://your-worker.workers.dev/model-downloads</string>
   ```

These local configuration files are intentionally ignored by Git. A fresh clone keeps web search and analytics disabled until you provide your own endpoints. The model download counter records at most one download per anonymous app installation and does not collect names, accounts, or device identifiers.

## Contributing

Contributions are welcome. If you find a bug, have a feature request, or want to propose a larger change, open a GitHub issue so it can be discussed and tracked.

To submit a pull request:

1. Fork the repository and create a focused branch.
2. Make the smallest change that fully addresses the issue.
3. Build the app and run the relevant tests.
4. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.
5. Open a pull request that explains the problem, the solution, and how it was tested.

Common commit prefixes include:

```text
feat: add a model selector to the chat composer
fix: prevent duplicate chat submissions
docs: clarify local development setup
test: cover reasoning output filtering
chore: update project dependencies
```

Keep pull requests focused on one concern. Link the relevant issue when one exists, and include screenshots or recordings for visible UI changes.

## Security

Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## License

Beacon is available under the [MIT License](LICENSE).
