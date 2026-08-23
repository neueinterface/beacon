# Beacon

Beacon is a private, local-first AI assistant for Apple devices. It makes it easy to discover and chat with on-device language models while keeping conversations and inference on your device.

The project explores what a polished, approachable interface for local AI can look like. Beacon supports different model families and capabilities so people can choose the model that best fits their device and task.

![Beacon app screenshot](info.png)

## What Beacon Offers

- Private on-device chat with local MLX models
- Apple Foundation Model support when available
- Curated model marketplace and local model downloads
- Persisted chat history
- Markdown assistant responses
- Streaming responses with a stop button
- Support for regular, reasoning, and vision models
- Attach and analyze images with the downloadable Qwen2-VL vision model
- Shortcuts/App Intents support for asking the selected model

## Architecture

- `BeaconModelRuntime` loads and streams local models
- `Resources/models.json` defines the bundled Hugging Face MLX model catalog
- `RequestLLMIntent` exposes a Shortcuts action for asking the selected model

## Requirements

- iOS Simulator or device supported by the project
- Xcode

## Development

Open `beacon.xcodeproj` in Xcode, select your signing team and bundle identifier, then build the `beacon` scheme.

Add or update compatible models by editing `beacon/Resources/models.json`. Downloadable entries must use a Hugging Face repository supported by MLX Swift LM.

### Run On Your iPhone

1. Clone the repository:

   ```sh
   git clone https://github.com/armondschneider/beacon.git
   cd beacon
   ```

2. Open `beacon.xcodeproj` in Xcode and wait for Swift Package dependencies to resolve.
3. In the target's **Signing & Capabilities** settings, select your Apple Developer team and choose a unique bundle identifier.
4. Connect and unlock your iPhone, select it as the run destination, then press Run.
5. Download a text model from the marketplace. To attach images, download and select **Qwen2-VL 2B 4-bit (Image)**.

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
