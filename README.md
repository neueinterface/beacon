# Beacon

Beacon is a local-first iOS assistant for chatting with private on-device AI models.

It lets you choose curated local models, download and manage them, and keep private chat history.

![Beacon app screenshot](info.png)

## Features

- Private on-device chat with local MLX models
- Apple Foundation Model support when available
- Curated model marketplace and local model downloads
- Persisted chat history
- Markdown assistant responses
- Streaming responses with a stop button
- Reasoning/thinking stream shown separately from the final answer
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

Open `semera-ios.xcodeproj` in Xcode, select your signing team and bundle identifier, then build the `semera-ios` scheme.

Add or update compatible models by editing `semera-ios/Resources/models.json`. Downloadable entries must use a Hugging Face repository supported by MLX Swift LM.

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

Beacon is available under the [MIT License](LICENSE).
