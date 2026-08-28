//
//  beaconTests.swift
//  beaconTests
//
//  Created by Armond Schneider on 3/7/26.
//

import Testing
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import beacon

@Suite("Beacon app data")
struct BeaconAppDataTests {
	@Test("Default model is available during onboarding")
	func defaultModelIsAvailableDuringOnboarding() {
		#expect(ModelCatalog.onboardingModels.contains(ModelCatalog.defaultModel))
	}

	@Test("Model lookup returns matching catalog model")
	func modelLookupReturnsMatchingModel() throws {
		let model = try #require(ModelCatalog.model(id: "qwen3-0.6b-4bit"))

		#expect(model.id == "qwen3-0.6b-4bit")
		#expect(model.repositoryID == "mlx-community/Qwen3-0.6B-4bit")
	}

	@Test("Built-in model formats size clearly")
	func builtInModelFormatsSizeClearly() throws {
		let model = try #require(ModelCatalog.model(id: "apple-foundation"))

		#expect(model.isBuiltIn)
		#expect(model.formattedSize == "Built in")
	}

	@Test("Downloadable models show GB size")
	func downloadableModelsShowGBSize() throws {
		let model = try #require(ModelCatalog.model(id: "lfm2-1.2b-4bit"))

		#expect(!model.isBuiltIn)
		#expect(model.formattedSize.hasSuffix("GB"))
	}

	@Test("Catalog provides compact parameter-count labels")
	func parameterCountLabels() throws {
		let qwen = try #require(ModelCatalog.model(id: "qwen3-0.6b-4bit"))
		let phi = try #require(ModelCatalog.model(id: "phi-3.5-mini-instruct-4bit"))
		let apple = try #require(ModelCatalog.model(id: "apple-foundation"))

		#expect(qwen.formattedParameterCount == "0.6b")
		#expect(phi.formattedParameterCount == "3.8b")
		#expect(apple.formattedParameterCount == nil)
	}

	@Test("Vision model accepts image attachments")
	func visionModelSupportsImages() throws {
		let model = try #require(ModelCatalog.model(id: "qwen2-vl-2b-instruct-4bit"))

		#expect(model.supportsImages)
		#expect(!model.isBuiltIn)
	}

	@Test("Model capability tags are additive")
	func modelCapabilityTagsAreAdditive() {
		let model = BeaconModel(
			id: "multimodal-coder",
			name: "Multimodal Coder",
			description: "Test model",
			repositoryID: "example/multimodal-coder",
			sizeInGB: 1,
			type: .reasoning,
			recommendedDevice: "iPhone 15 Pro",
			isAvailableDuringOnboarding: false,
			isBuiltIn: false,
			supportsImages: true
		)

		#expect(model.capabilityTags == ["chat", "vision", "thinking", "coding"])
	}

	@Test("Bundled catalog offers varied model families")
	func catalogOffersVariedModelFamilies() {
		let repositories = ModelCatalog.availableModels.map(\.repositoryID)

		#expect(ModelCatalog.availableModels.count >= 15)
		#expect(repositories.contains { $0.localizedCaseInsensitiveContains("gemma") })
		#expect(repositories.contains { $0.localizedCaseInsensitiveContains("granite") })
		#expect(repositories.contains { $0.localizedCaseInsensitiveContains("phi") })
		#expect(repositories.contains { $0.localizedCaseInsensitiveContains("deepseek") })
		#expect(ModelCatalog.availableModels.contains { $0.type == .reasoning })
	}

	@Test("Hugging Face README front matter is removed")
	func huggingFaceReadmeFrontMatterIsRemoved() {
		let readme = """
		---
		license: apache-2.0
		tags:
		- mlx
		---

		# Model card
		Model details.
		"""

		let result = HuggingFaceModelMetadataService.removingFrontMatter(from: readme)

		#expect(result.trimmingCharacters(in: .whitespacesAndNewlines) == "# Model card\nModel details.")
	}
}

@Suite("Model response filtering")
struct ModelResponseFilteringTests {
	@Test("Reasoning that repeats the user message is not emitted as the answer")
	func reasoningIsSeparatedFromAnswer() {
		var filter = ThinkingOutputFilter()
		let reasoning = filter.append("<think>The user said hey, what's up")
		let answer = filter.append(".</think>Hey! Not much. How are you?")

		#expect(reasoning.visible.isEmpty)
		#expect(reasoning.thinking == "The user said hey, what's up")
		#expect(answer.thinking == ".")
		#expect(answer.visible == "Hey! Not much. How are you?")
	}
}

@Suite("Web search routing")
struct WebSearchRoutingTests {
	@Test("No-search decision does not produce a query")
	func noSearchDecision() {
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "NO_SEARCH") == .noSearch)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "NO_SEARCH: explanation") == .noSearch)
	}

	@Test("Search decision extracts one bounded query")
	func searchDecision() {
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "SEARCH: weather in Berlin today") == .search("weather in Berlin today"))
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "SEARCH: Swift 6.2 release notes\nExtra text") == .search("Swift 6.2 release notes"))
		let longQuery = String(repeating: "a", count: 250)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "SEARCH: \(longQuery)") == .search(String(longQuery.prefix(200))))
	}

	@Test("Malformed or contradictory decisions are invalid")
	func invalidDecision() {
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "I would probably search") == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "SEARCH:   ") == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "NO_SEARCH\nSEARCH: ignored") == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "SEARCH: first\nSEARCH: second") == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "Do not SEARCH: private text") == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "SEARCH: query NO_SEARCH") == .invalid)
	}

	@Test("Obvious live requests have a conservative fallback")
	func highConfidenceFallback() {
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "What is the weather in Berlin?") == "What is the weather in Berlin?")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Search the web for Swift 6.2 changes") == "Search the web for Swift 6.2 changes")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Find sources about new battery technology") == "Find sources about new battery technology")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Who is the current CEO of Apple?") == "Who is the current CEO of Apple?")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Who won the World Cup?") == "Who won the World Cup?")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "How many world cups do Spaing have?") == "How many world cups do Spaing have?")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Explain why the sky is blue") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Explain electric current") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Write a poem about today's news") == "Write a poem about today's news")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Write a poem using the word today") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Write about living in the now") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Explain live versus recorded music") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Translate the price of freedom into French") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Explain the phrase right now") == nil)
	}

	@Test("Context-dependent fallback does not send an incomplete query")
	func incompleteFallbackIsSkipped() {
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "What about tomorrow?") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Is it available now?") == nil)
	}

	@Test("Router receives only relevant immediate user context")
	func routingContextIsMinimized() {
		let history = [
			ChatMessage(text: "My private account number is 1234", role: .user),
			ChatMessage(text: "What is the weather in Berlin?", role: .user),
			ChatMessage(text: "It is sunny.", role: .assistant)
		]

		#expect(BeaconModelRuntime.webSearchRoutingContext(for: "Who is the CEO of Apple?", conversationHistory: history) == nil)
		#expect(
			BeaconModelRuntime.webSearchRoutingContext(for: "What about tomorrow?", conversationHistory: history)
				== "User: What is the weather in Berlin?"
		)
	}

	@Test("MCP event stream extracts JSON payload")
	func eventStreamPayload() throws {
		let stream = "event: message\r\ndata: {\"jsonrpc\":\"2.0\",\"id\":\"test\"}\r\n\r\n"
		let payload = try #require(WebSearchMCPClient.eventStreamPayloads(from: Data(stream.utf8)).first)

		#expect(String(decoding: payload, as: UTF8.self) == "{\"jsonrpc\":\"2.0\",\"id\":\"test\"}")
	}

}

@Suite("Settings rows")
struct SettingsRowTests {
	@Test("Settings toggle row stores subtitle text")
	func settingsToggleRowStoresSubtitle() {
		var isOn = false
		let binding = Binding<Bool>(get: { isOn }, set: { isOn = $0 })
		let row = SettingsToggleRow(
			title: "Notifications",
			icon: "bell.icon",
			subtitle: "Optional alerts",
			isOn: binding
		)

		#expect(row.title == "Notifications")
		#expect(row.subtitle == "Optional alerts")
	}

	@Test("Settings toggle row subtitle defaults to nil")
	func settingsToggleRowSubtitleDefaultsToNil() {
		var isOn = false
		let binding = Binding<Bool>(get: { isOn }, set: { isOn = $0 })
		let row = SettingsToggleRow(
			title: "Notifications",
			icon: "bell.icon",
			isOn: binding
		)

		#expect(row.subtitle == nil)
	}
}

@Suite("Model storage limits")
struct ModelStorageLimitTests {
	private func makeModel(id: String, sizeInGB: Decimal, isBuiltIn: Bool = false) -> BeaconModel {
		BeaconModel(
			id: id,
			name: id,
			description: "Test model",
			repositoryID: "test/\(id)",
			sizeInGB: sizeInGB,
			type: .regular,
			recommendedDevice: "iPhone 15 Pro+",
			isAvailableDuringOnboarding: false,
			isBuiltIn: isBuiltIn
		)
	}

	@Test("Built-in model is downloadable regardless of device storage")
	func builtInModelSkipsStorageCheck() {
		let model = makeModel(id: "built-in", sizeInGB: 0, isBuiltIn: true)

		#expect(ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: "", in: [model], availableGB: 0) == .available)
	}

	@Test("Already downloaded model is available regardless of device storage")
	func downloadedModelSkipsStorageCheck() {
		let model = makeModel(id: "downloaded", sizeInGB: 4)

		#expect(ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: "downloaded", in: [model], availableGB: 0.01) == .available)
	}

	@Test("Download exceeding the 10 GB app storage limit is blocked")
	func appStorageFullBlocksDownload() {
		let big = makeModel(id: "big", sizeInGB: 8)
		let small = makeModel(id: "small", sizeInGB: 2.5)

		#expect(ModelStorageLimit.downloadAvailability(for: small, downloadedModelIDs: "big", in: [big, small], availableGB: 100) == .appStorageFull)
	}

	@Test("Download within the 10 GB app storage limit is allowed")
	func appStorageWithinLimitAllowsDownload() {
		let first = makeModel(id: "first", sizeInGB: 4)
		let second = makeModel(id: "second", sizeInGB: 5)

		#expect(ModelStorageLimit.downloadAvailability(for: second, downloadedModelIDs: "first", in: [first, second], availableGB: 100) == .available)
	}

	@Test("Downloaded size only counts downloaded, non-built-in models")
	func downloadedSizeAccounting() {
		let downloaded = makeModel(id: "downloaded", sizeInGB: 2)
		let alsoDownloaded = makeModel(id: "also-downloaded", sizeInGB: 3)
		let builtIn = makeModel(id: "built-in", sizeInGB: 0, isBuiltIn: true)
		let notDownloaded = makeModel(id: "not-downloaded", sizeInGB: 9)

		let size = ModelStorageLimit.downloadedSizeGB(
			downloadedModelIDs: "downloaded,also-downloaded,built-in",
			in: [downloaded, alsoDownloaded, builtIn, notDownloaded]
		)

		#expect(size == 5)
	}

	@Test("Device storage below the required 110% of model size is blocked")
	func deviceStorageLowBlocksDownload() {
		let model = makeModel(id: "model", sizeInGB: 1) // requires 1.1 GB

		#expect(ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: "", in: [model], availableGB: 1.0) == .deviceStorageLow(requiredGB: 1.1, availableGB: 1.0))
	}

	@Test("Device storage exactly at the required threshold is allowed")
	func deviceStorageAtThresholdAllowsDownload() {
		let model = makeModel(id: "model", sizeInGB: 1) // requires 1.1 GB

		#expect(ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: "", in: [model], availableGB: 1.1) == .available)
	}

	@Test("Failed storage measurement is treated as low storage")
	func failedStorageMeasurementIsConservative() {
		let model = makeModel(id: "model", sizeInGB: 1)

		#expect(ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: "", in: [model], availableGB: nil) == .deviceStorageLow(requiredGB: 1.1, availableGB: 0))
	}
}

@Suite("Appearance color scheme")
struct AppearanceColorSchemeTests {
	@Test("System maps to unspecified user interface style")
	func systemMapsToUnspecified() {
		#if canImport(UIKit)
		#expect(AppearanceColorScheme.system.userInterfaceStyle == .unspecified)
		#endif
	}

	@Test("Light maps to light user interface style")
	func lightMapsToLight() {
		#if canImport(UIKit)
		#expect(AppearanceColorScheme.light.userInterfaceStyle == .light)
		#endif
	}

	@Test("Dark maps to dark user interface style")
	func darkMapsToDark() {
		#if canImport(UIKit)
		#expect(AppearanceColorScheme.dark.userInterfaceStyle == .dark)
		#endif
	}

	@Test("System preferred color scheme is nil (follows system)")
	func systemPreferredColorSchemeIsNil() {
		#expect(AppearanceColorScheme.system.preferredColorScheme == nil)
	}

	@Test("Dark then system produces different user interface styles")
	func darkThenSystemProducesDifferentStyles() {
		#if canImport(UIKit)
		let darkStyle = AppearanceColorScheme.dark.userInterfaceStyle
		let systemStyle = AppearanceColorScheme.system.userInterfaceStyle
		#expect(darkStyle != systemStyle)
		#expect(darkStyle == .dark)
		#expect(systemStyle == .unspecified)
		#endif
	}

	@Test("Appearance setting defaults to system")
	func appearanceSettingDefaultsToSystem() {
		let key = "appearanceColorScheme"
		let defaults = UserDefaults.standard
		let hadPreviousValue = defaults.object(forKey: key) != nil
		let previousValue = defaults.string(forKey: key)

		defaults.removeObject(forKey: key)
		let raw = defaults.string(forKey: key) ?? AppearanceColorScheme.system.rawValue
		let scheme = AppearanceColorScheme(rawValue: raw) ?? .system
		#expect(scheme == .system)

		if hadPreviousValue, let previousValue {
			defaults.set(previousValue, forKey: key)
		} else {
			defaults.removeObject(forKey: key)
		}
	}
}
