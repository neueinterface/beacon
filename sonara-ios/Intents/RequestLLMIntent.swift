import AppIntents
import Foundation

@available(iOS 16.0, macOS 13.0, *)
struct RequestLLMIntent: AppIntent {
	static var title: LocalizedStringResource = "New Chat"
	static var description: IntentDescription = "Ask the selected Sonara model a question."
	static var openAppWhenRun = false

	@Parameter(title: "Continuous Chat", default: false)
	var continuous: Bool

	@Parameter(title: "Message", requestValueDialog: IntentDialog("What do you want to ask Sonara?"))
	var prompt: String

	static var parameterSummary: some ParameterSummary {
		Summary("Ask Sonara \(\.$prompt)") {
			\.$continuous
		}
	}

	private var maxCharacters: Int? {
		continuous ? 300 : nil
	}

	@MainActor
	func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
		let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedPrompt.isEmpty else {
			throw $prompt.requestValue("What do you want to ask Sonara?")
		}

		let defaults = UserDefaults.standard
		let selectedModelID = defaults.string(forKey: "selectedModelID") ?? ""
		let selectedModel = ModelCatalog.model(id: selectedModelID) ?? ModelCatalog.defaultModel

		guard selectedModel.isBuiltIn || isDownloaded(selectedModel, defaults: defaults) else {
			let message = "Open Sonara and download \(selectedModel.name) before using it from Shortcuts."
			return .result(value: message, dialog: IntentDialog(stringLiteral: message))
		}

		let runtime = BeaconModelRuntime()
		await runtime.load(selectedModel)

		guard runtime.isReady(for: selectedModel) else {
			let message = runtime.errorMessage ?? "Sonara could not load the selected model. Open the app and choose a model first."
			return .result(value: message, dialog: IntentDialog(stringLiteral: message))
		}

		var output = ""
		let prompt = promptForShortcut(trimmedPrompt, continuous: continuous)
		try await runtime.streamResponse(to: prompt) { chunk in
			output += chunk
		}

		output = trimmed(output, maxCharacters: maxCharacters)

		if continuous {
			throw $prompt.requestValue(IntentDialog(stringLiteral: output))
		}

		return .result(value: output, dialog: IntentDialog(stringLiteral: output))
	}

	private func isDownloaded(_ model: BeaconModel, defaults: UserDefaults) -> Bool {
		let downloadedModelIDs = defaults.string(forKey: "downloadedModelIDs") ?? ""
		return Set(downloadedModelIDs.split(separator: ",").map(String.init)).contains(model.id)
	}

	private func promptForShortcut(_ prompt: String, continuous: Bool) -> String {
		guard continuous else { return prompt }
		return """
		\(prompt)

		Reply in no more than four sentences because this answer is being spoken or shown by Shortcuts.
		"""
	}

	private func trimmed(_ output: String, maxCharacters: Int?) -> String {
		let output = output.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let maxCharacters, output.count > maxCharacters else { return output }
		return String(output.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
	}
}

@available(iOS 16.0, macOS 13.0, *)
struct SonaraShortcuts: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
		AppShortcut(
			intent: RequestLLMIntent(),
			phrases: [
				"Start a new chat with \(.applicationName)",
				"Chat with \(.applicationName)",
				"Ask \(.applicationName) a question"
			],
			shortTitle: "New Chat",
			systemImageName: "bubble"
		)
	}
}
