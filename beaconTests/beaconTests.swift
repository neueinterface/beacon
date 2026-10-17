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
	@Test("Home Screen quick-action identifiers map to the correct routes")
	func homeScreenQuickActionMapping() {
		#expect(HomeScreenQuickAction(rawValue: "com.beacon.new-chat") == .newChat)
		#expect(HomeScreenQuickAction(rawValue: "com.beacon.change-app-icon") == .changeAppIcon)
		#expect(HomeScreenQuickAction(rawValue: "com.beacon.unknown") == nil)
	}

	@Test("Consumed Home Screen actions can be requested again")
	@MainActor
	func repeatedHomeScreenQuickAction() {
		let router = NotificationRouter()

		router.openQuickAction(.changeAppIcon)
		#expect(router.quickActionToOpen == .changeAppIcon)
		router.consumeQuickActionRequest()
		#expect(router.quickActionToOpen == nil)
		router.openQuickAction(.changeAppIcon)
		#expect(router.quickActionToOpen == .changeAppIcon)
	}

	@Test("Default model belongs to the device-selected Chat Core bundle")
	func defaultModelIsAvailableDuringOnboarding() {
		let bundle = ModelCatalog.coreOnboardingModels(in: ModelCatalog.availableModels)
		#expect(bundle.contains(ModelCatalog.defaultModel))
		#expect(ModelCatalog.defaultModel == ModelCatalog.primaryChatModel(in: bundle))
		#expect(ModelCatalog.onboardingModels.map(\.id) == ["qwen3-0.6b", "qwen3-1.7b", "deepseek-r1-distill-qwen-1.5b", "smolvlm2-500m", "qwen2-vl-2b"])
		#expect(ModelCatalog.optionalOnboardingModels(in: ModelCatalog.availableModels).map(\.onboardingName) == ["Thinker"])
	}

	@Test("Model lookup returns matching catalog model")
	func modelLookupReturnsMatchingModel() throws {
		let model = try #require(ModelCatalog.model(id: "beacon"))

		#expect(model.id == "beacon")
		#expect(model.repositoryID == "mlx-community/LFM2-1.2B-4bit")
	}

	@Test("Downloadable models show GB size")
	func downloadableModelsShowGBSize() throws {
		let model = try #require(ModelCatalog.model(id: "beacon"))

		#expect(!model.isBuiltIn)
		#expect(model.formattedSize.hasSuffix("GB"))
	}

	@Test("Catalog provides compact parameter-count labels")
	func parameterCountLabels() throws {
		let lfm = try #require(ModelCatalog.model(id: "beacon"))

		#expect(lfm.formattedParameterCount == "1.2b")
	}

	@Test("Text-only models route images through the vision bridge")
	func imageResponseRouting() throws {
		let textModel = try #require(ModelCatalog.model(id: "beacon"))

		#expect(ImageResponseRouting.usesVisionBridge(for: textModel))
	}

	@Test("Automatic routing chooses vision, thinker, and light assistants")
	func automaticModelRouting() {
		let downloaded = Set(["qwen3-0.6b", "qwen3-1.7b", "deepseek-r1-distill-qwen-1.5b", "qwen2-vl-2b"])
		let compatible: (BeaconModel) -> ModelDeviceCompatibility = { _ in .goodFit }

		#expect(BeaconModelRouter.route(text: "What is in this photo?", hasImages: true, in: ModelCatalog.availableModels, downloadedIDs: downloaded, compatibility: compatible).id == "qwen2-vl-2b")
		#expect(BeaconModelRouter.route(text: "Solve this step by step and explain the logic.", hasImages: false, in: ModelCatalog.availableModels, downloadedIDs: downloaded, compatibility: compatible).id == "deepseek-r1-distill-qwen-1.5b")
		#expect(BeaconModelRouter.route(text: "Give me a quick summary.", hasImages: false, in: ModelCatalog.availableModels, downloadedIDs: downloaded, compatibility: compatible).id == "qwen3-0.6b")
	}

	@Test("Manual selection pins the answering model until Chat Core is selected")
	func manualModelSelectionOverridesAutomaticRouting() {
		let downloaded = Set(["beacon", "qwen3-0.6b", "qwen3-1.7b", "deepseek-r1-distill-qwen-1.5b", "qwen2-vl-2b"])
		for hasImages in [false, true] {
			let model = BeaconModelRouter.route(
				text: "Solve this math problem step by step.",
				hasImages: hasImages,
				in: ModelCatalog.availableModels,
				downloadedIDs: downloaded,
				preferredModelID: "beacon",
				compatibility: { _ in .goodFit }
			)
			#expect(model.id == "beacon")
		}
		let automatic = BeaconModelRouter.route(
			text: "Solve this math problem step by step.",
			hasImages: false,
			in: ModelCatalog.availableModels,
			downloadedIDs: downloaded,
			preferredModelID: nil,
			compatibility: { _ in .goodFit }
		)
		#expect(automatic.id == "deepseek-r1-distill-qwen-1.5b")
	}

	@Test("Missing or unavailable manual selections fall back to installed models")
	func manualModelSelectionFallback() {
		for id in ["removed-model", "beacon"] {
			let model = BeaconModelRouter.route(
				text: "Write a detailed plan.",
				hasImages: false,
				in: ModelCatalog.availableModels,
				downloadedIDs: ["qwen3-1.7b"],
				preferredModelID: id,
				compatibility: { _ in .goodFit }
			)
			#expect(model.id == "qwen3-1.7b")
		}
		let unavailable = BeaconModelRouter.route(
			text: "Write a detailed plan.",
			hasImages: false,
			in: ModelCatalog.availableModels,
			downloadedIDs: ["beacon", "qwen3-1.7b"],
			preferredModelID: "beacon",
			compatibility: { $0.id == "beacon" ? .unavailable(.modelTooDemanding) : .goodFit }
		)
		#expect(unavailable.id == "qwen3-1.7b")
	}

	@Test("Automatic routing falls back to downloaded chat when a specialist is unavailable")
	func automaticModelRoutingFallback() {
		let downloaded = Set(["qwen3-1.7b", "deepseek-r1-distill-qwen-1.5b"])
		let routed = BeaconModelRouter.route(
			text: "Give me a quick summary.",
			hasImages: false,
			in: ModelCatalog.availableModels,
			downloadedIDs: downloaded,
			compatibility: { _ in .goodFit }
		)

		#expect(routed.id == "qwen3-1.7b")
	}

	@Test("Automatic routing favors Chat Light for short everyday prompts")
	func automaticModelRoutingFavorsLight() {
		let downloaded = Set(["qwen3-0.6b", "qwen3-1.7b"])
		let routed = BeaconModelRouter.route(
			text: "What is the capital of France?",
			hasImages: false,
			in: ModelCatalog.availableModels,
			downloadedIDs: downloaded,
			compatibility: { _ in .goodFit }
		)

		#expect(routed.id == "qwen3-0.6b")
	}

	@Test("Vision bridge preserves the user request and private analysis")
	func visionBridgePrompts() {
		let analysisPrompt = ImageResponseRouting.analysisPrompt(for: "What color is the car?")
		let responsePrompt = ImageResponseRouting.responsePrompt(
			question: "What color is the car?",
			visualAnalysis: "A blue car is parked beside a tree."
		)

		#expect(analysisPrompt.contains("What color is the car?"))
		#expect(responsePrompt.contains("What color is the car?"))
		#expect(responsePrompt.contains("A blue car is parked beside a tree."))
		#expect(responsePrompt.contains("Never mention the notes, the analysis handoff"))
		#expect(analysisPrompt.contains("exact areas or features the question asks about"))
		#expect(!analysisPrompt.contains("ERTZ"))
		#expect(!analysisPrompt.contains("Eagles"))
		#expect(responsePrompt.hasSuffix("What color is the car?"))
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

	@Test("Marketplace exposes every supported Hugging Face model")
	func marketplaceShowsFullCatalog() {
		let models = ModelCatalog.marketplaceModels(in: ModelCatalog.availableModels, compatibility: { _ in .goodFit })
		#expect(models == ModelCatalog.availableModels)
		#expect(models.contains { $0.id == "lfm2.5-1.2b" })
		#expect(models.contains { $0.id == "gemma-3-1b" })
	}

	@Test("Marketplace sorts hardware fits first without hiding demanding models")
	func marketplacePrefersHardwareFit() {
		let models = ModelCatalog.marketplaceModels(in: ModelCatalog.availableModels) { model in
			["qwen3-4b-instruct-2507", "qwen2-vl-2b", "deepseek-r1-distill-qwen-1.5b"].contains(model.id) ? .mayBeSlow : .goodFit
		}
		#expect(models.count == ModelCatalog.availableModels.count)
		#expect(models.suffix(3).map(\.id) == ["qwen3-4b-instruct-2507", "deepseek-r1-distill-qwen-1.5b", "qwen2-vl-2b"])
	}

	@Test("Marketplace handles a partial or empty catalog")
	func marketplaceHandlesMissingCandidates() {
		let models = ModelCatalog.availableModels.filter { $0.id == "qwen3-0.6b" }
		#expect(ModelCatalog.marketplaceModels(in: models, compatibility: { _ in .goodFit }).map(\.id) == ["qwen3-0.6b"])
		#expect(ModelCatalog.marketplaceModels(in: [], compatibility: { _ in .goodFit }).isEmpty)
	}

	@Test("Six-GB phones can download small models regardless of generation")
	func sixGBPhoneCompatibility() throws {
		for id in ["beacon", "lfm2.5-1.2b", "qwen3-0.6b", "qwen3-1.7b", "deepseek-r1-distill-qwen-1.5b"] {
			let model = try #require(ModelCatalog.model(id: id))
			#expect(ModelDeviceCompatibility.localModel(model, physicalMemoryGB: 6) == .goodFit)
		}
		let largerModel = try #require(ModelCatalog.model(id: "qwen3-4b-instruct-2507"))
		#expect(ModelDeviceCompatibility.localModel(largerModel, physicalMemoryGB: 6) == .mayBeSlow)
		#expect(ModelDeviceCompatibility.localModel(largerModel, physicalMemoryGB: 6).canUse)
		#expect(ModelCatalog.availableModels.allSatisfy { ModelDeviceCompatibility.localModel($0, physicalMemoryGB: 4).canUse })
	}

	@Test("Chat Core adapts its models to physical RAM", arguments: [4.0, 6.0, 8.0])
	func chatCoreAdaptsToRAM(memoryGB: Double) {
		let bundle = ModelCatalog.coreOnboardingModels(in: ModelCatalog.availableModels) {
			ModelDeviceCompatibility.localModel($0, physicalMemoryGB: memoryGB)
		}
		#expect(Set(bundle.map(\.id)).count == bundle.count)
		#expect(bundle.allSatisfy { ModelDeviceCompatibility.localModel($0, physicalMemoryGB: memoryGB) == .goodFit })
		#expect(ModelCatalog.primaryChatModel(in: bundle)?.id == (memoryGB >= 8 ? "qwen3-4b-instruct-2507" : "qwen3-1.7b"))
		#expect(bundle.first(where: \.supportsImages)?.id == (memoryGB >= 8 ? "qwen2-vl-2b" : memoryGB >= 6 ? "smolvlm2-500m" : nil))
	}

	@Test("Chat Core omits models that do not fit and deduplicates its fallback")
	func chatCoreSmallestFallback() {
		let models = ModelCatalog.availableModels.filter { $0.id == "qwen3-0.6b" }
		#expect(ModelCatalog.coreOnboardingModels(in: models, compatibility: { _ in .goodFit }) == models)
		#expect(ModelCatalog.coreOnboardingModels(in: models, compatibility: { _ in .mayBeSlow }).isEmpty)
		#expect(ModelCatalog.coreOnboardingModels(in: [], compatibility: { _ in .goodFit }).isEmpty)
	}

	@Test("Full catalog remains available for existing downloads")
	func catalogOffersCuratedModelsAcrossCompanies() {
		let models = ModelCatalog.availableModels
		let companies = Set(models.map(\.company))

		#expect(models.count == 50)
		#expect(Set(models.map(\.id)).count == models.count)
		#expect(Set(models.map(\.repositoryID)).count == models.count)
		#expect(companies.isSuperset(of: ["Alibaba", "DeepSeek", "Google", "Hugging Face", "IBM", "Liquid AI", "Meta", "Microsoft", "OpenBMB"]))
		#expect(models.filter(\.supportsImages).count == 14)
		#expect(Set(models.filter(\.supportsImages).map(\.id)).isSuperset(of: ["smolvlm2-500m", "qwen2-vl-2b", "gemma-4-e2b", "qwen3.5-0.8b", "lfm2-vl-450m"]))
		#expect(companies.isSuperset(of: ["Mistral AI", "TII", "LG AI Research"]))
		#expect(models.allSatisfy { $0.sizeInGB > 0 && $0.sizeInGB < 4 })
		#expect(ModelCatalog.model(id: "minicpm5-2b")?.repositoryID == "mlx-community/MiniCPM5-2B-mlx-4Bit")
		#expect(ModelCatalog.model(id: "qwen3-4b-instruct-2507")?.repositoryID == "mlx-community/Qwen3-4B-Instruct-2507-4bit")
		#expect(models.allSatisfy { $0.bestFor?.count ?? 0 > 100 })
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

@Suite("Information card titles")
struct InformationCardTitleTests {
	@Test("Fun fact requests become short title-cased topics")
	func funFactTitle() {
		#expect(InformationCardTitle.summarize(query: "Can you tell me a fun fact about steven hawking?", resultTitle: "A Long Article About Stephen Hawking | News") == "Fun Fact About Steven Hawking")
		#expect(InformationCardTitle.summarize(query: "/web tell me about the mona lisa") == "The Mona Lisa")
	}

	@Test("Empty questions use a cleaned result headline")
	func emptyQuestionUsesResultTitle() {
		#expect(InformationCardTitle.summarize(query: "", resultTitle: "steven hawking biography | Encyclopedia") == "Steven Hawking Biography")
	}

	@Test("Long query titles end at a word boundary")
	func truncatesLongTitlesAtWordBoundary() {
		let title = InformationCardTitle.summarize(query: "Tell me about beacon giving people a private way to run capable language models directly on their own iPhones and other Apple devices.")

		#expect(title.count <= 60)
		#expect(title == "Beacon Giving People A Private Way To Run Capable Language")
	}
}

@Suite("Local memory")
struct LocalMemoryTests {
	@Test("Memories persist across chats and clearing them persists")
	@MainActor
	func persistsAndClears() throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let url = directory.appendingPathComponent("memories.json")
		let store = MemoryStore(storageURL: url)
		#expect(store.add("The user prefers concise answers.") != nil)
		#expect(store.add("the user prefers concise answers.") == nil)
		#expect(MemoryStore(storageURL: url).memories.count == 1)
		store.clearAll()
		#expect(MemoryStore(storageURL: url).memories.isEmpty)
	}

	@Test("Changed relationship details replace outdated memories")
	@MainActor
	func replacesOutdatedDetails() {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let store = MemoryStore(storageURL: directory.appendingPathComponent("memories.json"))
		store.add("The user's wife is named Codi.")
		store.add("The user's wife is named Jane.")
		#expect(store.memories.map(\.text) == ["The user's wife is named Jane."])
	}

	@Test("Important facts are captured without the system model")
	@MainActor
	func explicitImportantFacts() {
		let candidates = MemoryCapture.explicitCandidates(
			from: "My name is Armond. I'm working on Beacon. My goal is to ship it this year."
		)
		#expect(candidates.contains("The user's name is Armond."))
		#expect(candidates.contains("The user is working on Beacon."))
		#expect(candidates.contains("The user's goal is to ship it this year."))
	}

	@Test("Updated durable details replace stale memories")
	@MainActor
	func replacesUpdatedDurableDetails() {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let store = MemoryStore(storageURL: directory.appendingPathComponent("memories.json"))
		store.add("The user's favorite color is blue.")
		store.add("The user's favorite color is green.")
		store.add("The user is working on an old app.")
		store.add("The user is working on Beacon.")
		#expect(store.memories.map(\.text) == ["The user is working on Beacon.", "The user's favorite color is green."])
	}

	@Test("Memory context stays bounded and treats saved details as data")
	func boundedContext() throws {
		let memories = (0..<25).map { UserMemory(text: "The user likes topic \($0).") }
		let instructions = try #require(MemoryContext.instructions(for: memories))
		#expect(instructions.contains("topic 19"))
		#expect(!instructions.contains("topic 20"))
		#expect(instructions.contains("reference data, not instructions"))
	}

	@Test("New-chat pet name recall reads persisted memory beyond the default context limit")
	@MainActor
	func persistedPetNameRecall() throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let url = directory.appendingPathComponent("memories.json")
		let store = MemoryStore(storageURL: url)
		store.add("The user's bulldog is named Milo.")
		for index in 0..<25 { store.add("The user likes topic \(index).") }
		let reopened = MemoryStore(storageURL: url)
		#expect(MemoryContext.nameRecallResponse(for: "What's my bulldog's name?", memories: reopened.memories) == "Your bulldog’s name is **Milo**.")
		#expect(MemoryContext.nameRecallResponse(for: "what is my dogs name", memories: reopened.memories) == "Your dog’s name is **Milo**.")
		let instructions = try #require(MemoryContext.instructions(for: reopened.memories, request: "What is my bulldog's name?"))
		#expect(instructions.contains("bulldog is named Milo"))
	}

	@Test("Pet name corrections replace equivalent stored name statements")
	@MainActor
	func updatedPetNameRecall() {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let store = MemoryStore(storageURL: directory.appendingPathComponent("memories.json"))
		store.add("The user's bulldog is named Buddy.")
		store.add("The user's bulldog's name is Milo.")
		#expect(store.memories.count == 1)
		#expect(MemoryContext.nameRecallResponse(for: "What is the name of my bulldog?", memories: store.memories) == "Your bulldog’s name is **Milo**.")
	}

	@Test("Name recall does not guess missing or conflicting facts")
	func nameRecallUncertainty() {
		#expect(MemoryContext.nameRecallResponse(for: "What's my bulldog's name?", memories: []) == "I don’t know your bulldog’s name yet. What is it?")
		let memories = [UserMemory(text: "The user's bulldog is named Milo."), UserMemory(text: "The user has a bulldog named Buddy.")]
		#expect(MemoryContext.nameRecallResponse(for: "What's my bulldog's name?", memories: memories) == "I have conflicting information about your bulldog’s name. Which name is correct?")
		#expect(MemoryContext.nameRecallResponse(for: "Suggest a name for my bulldog", memories: memories) == nil)
		#expect(MemoryContext.nameRecallResponse(for: "What's my bulldog's name and age?", memories: memories) == nil)
	}

	@Test("Explicit current-conversation names override old memory without mixing up subjects")
	func currentNameTakesPrecedence() {
		let memories = [UserMemory(text: "The user's bulldog is named Buddy."), UserMemory(text: "The user's name is Armond.")]
		#expect(MemoryContext.nameRecallResponse(for: "What's my bulldog's name?", memories: memories, userMessages: ["My bulldog's name is Milo."]) == "Your bulldog’s name is **Milo**.")
		#expect(MemoryContext.nameRecallResponse(for: "What's my name?", memories: memories) == "Your name is **Armond**.")
		#expect(MemoryContext.nameRecallResponse(for: "What's my dog's name?", memories: [], userMessages: ["My English bulldog is named Milo. My French bulldog is named Buddy."]) == "I have conflicting information about your dog’s name. Which name is correct?")
		#expect(MemoryContext.nameRecallResponse(for: "What's my bulldog's name?", memories: [UserMemory(text: "The user's bulldog has the name Milo.")]) == "Your bulldog’s name is **Milo**.")
	}

	@Test("Recall handles natural saved wording and keeps unrelated names out of the model context")
	func naturalMemoryWording() throws {
		let facts = [UserMemory(text: "The user's name is Armond."), UserMemory(text: "The user owns an English bulldog named Milo, who loves walks.")]
		#expect(MemoryContext.nameRecallResponse(for: "Do you remember what my bulldog's name is?", memories: facts) == "Your bulldog’s name is **Milo**.")
		#expect(MemoryContext.nameRecallResponse(for: "What did I name my dog?", memories: facts) == "Your dog’s name is **Milo**.")
		let prompt = MemoryContext.groundedPrompt("What is my bulldog called?", request: "What is my bulldog called?", memories: facts)
		#expect(prompt.contains("English bulldog named Milo"))
		#expect(!prompt.contains("Armond"))
		#expect(prompt.hasSuffix("What is my bulldog called?"))
		#expect(MemoryContext.groundedPrompt("Hello", request: "Hello", memories: []) == "Hello")
	}

	@Test("Explicit pet names are captured without an extraction model")
	@MainActor
	func explicitPetNameCapture() {
		#expect(MemoryCapture.explicitCandidates(from: "My bulldog's name is Milo.").contains("The user's bulldog is named Milo."))
		#expect(MemoryCapture.explicitCandidates(from: "My English bulldog is named Milo.").contains("The user's english bulldog is named Milo."))
		#expect(MemoryCapture.explicitCandidates(from: "What's my bulldog's name?").isEmpty)
	}
}

@Suite("Model response filtering")
struct ModelResponseFilteringTests {
	@Test("Default response guidance balances concise answers with readable Markdown")
	func conciseMarkdownGuidance() {
		#expect(BeaconSystemPrompt.instructions.contains("80–160 words"))
		#expect(BeaconSystemPrompt.instructions.contains("2–4 compact bullets"))
		#expect(BeaconSystemPrompt.instructions.contains("Markdown **bold** sparingly"))
		#expect(BeaconSystemPrompt.instructions.contains("Use *italics* occasionally"))
		#expect(BeaconSystemPrompt.instructions.contains("at most one specific, relevant follow-up question"))
		#expect(BeaconSystemPrompt.instructions.contains("not a mandatory template"))
		#expect(BeaconSystemPrompt.instructions.contains("Your entire output is the message the user should read"))
	}

	@Test("Visible responses remove leaked response planning")
	func removesResponsePlanning() {
		let response = "He looks very pleased with himself. No need to elaborate, just acknowledge and add warmth."

		#expect(VisibleResponseSanitizer.clean(response) == "He looks very pleased with himself.")
		#expect(VisibleResponseSanitizer.clean("No need to worry; that looks normal.") == "No need to worry; that looks normal.")
		#expect(VisibleResponseSanitizer.clean("The answer should be 42.") == "The answer should be 42.")
		#expect(VisibleResponseSanitizer.clean("I should answer briefly and clearly.").isEmpty)
	}

	@Test("Visible answers remove leaked speaker labels without altering ordinary text")
	func removesSpeakerLabels() {
		#expect(VisibleResponseSanitizer.clean("Beacon: Your bulldog’s name is **Milo**.") == "Your bulldog’s name is **Milo**.")
		#expect(VisibleResponseSanitizer.clean("**Beacon:** Hello!") == "Hello!")
		#expect(VisibleResponseSanitizer.clean("Assistant: Hello!") == "Hello!")
		#expect(VisibleResponseSanitizer.clean("The beacon: a navigation light.") == "The beacon: a navigation light.")
	}

	@Test("Search progress replaces the previous stage instead of accumulating lines")
	@MainActor
	func searchProgressShowsCurrentStage() {
		let history = ChatHistoryViewModel(conversations: [])
		let responseID = history.appendUserMessage("What is the weather today?", modelName: "Chat")
		history.setAssistantThinkingStatus("Planning a search…", for: responseID)
		history.setAssistantThinkingStatus("Searching the web…", for: responseID)
		#expect(history.currentMessages.last?.thinkingText == "Searching the web…")
		history.setAssistantThinkingStatus("Reading search results…", for: responseID)
		#expect(history.currentMessages.last?.thinkingText == "Reading search results…")
		history.setAssistantThinkingStatus("", for: responseID)
		#expect(history.currentMessages.last?.thinkingText.isEmpty == true)
	}

	@Test("Late response cleanup cannot finish a newer attempt")
	func staleResponseAttemptCannotFinishCurrentAttempt() {
		var tracker = ResponseAttemptTracker()
		let first = tracker.begin()
		let second = tracker.begin()

		let finishedFirst = tracker.finish(first)
		#expect(!finishedFirst)
		#expect(tracker.activeID == second)
		let finishedSecond = tracker.finish(second)
		#expect(finishedSecond)
		#expect(tracker.activeID == nil)
	}

	@Test("Retry repeats web search after a grounded generation failure")
	func groundedResponseRetryPreservesWebSearch() {
		#expect(ResponseRetryPolicy.shouldForceWebSearch(wasForced: false, usedWebSearch: true))
		#expect(ResponseRetryPolicy.shouldForceWebSearch(wasForced: true, usedWebSearch: false))
		#expect(!ResponseRetryPolicy.shouldForceWebSearch(wasForced: false, usedWebSearch: false))
	}

	@Test("Model loading failure preserves its useful error message")
	@MainActor
	func modelLoadFailureMessage() {
		let error = BeaconModelRuntime.RuntimeError.modelLoadFailed("The model cache is unavailable.")

		#expect(error.errorDescription == "The model cache is unavailable.")
	}

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
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: #"{"action":"answer_locally"}"#) == .noSearch)
	}

	@Test("Search decision extracts a bounded search plan")
	func searchDecision() {
		#expect(
			BeaconModelRuntime.parseWebSearchDecision(
				from: #"{"action":"search_web","objective":"Current Berlin weather","queries":["weather in Berlin today","Berlin forecast today"]}"#
			) == .search(
				BeaconModelRuntime.WebSearchPlan(
					objective: "Current Berlin weather",
					queries: ["weather in Berlin today", "Berlin forecast today"]
				)
			)
		)
		let longQuery = String(repeating: "a", count: 250)
		#expect(
			BeaconModelRuntime.parseWebSearchDecision(from: "{\"action\":\"search_web\",\"query\":\"\(longQuery)\"}") == .search(
				BeaconModelRuntime.WebSearchPlan(objective: longQuery, queries: [longQuery])
			)
		)
	}

	@Test("Malformed or contradictory decisions are invalid")
	func invalidDecision() {
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: "I would probably search") == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: #"{"action":"search_web","query":""}"#) == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: #"{"action":"search_web","queries":[]}"#) == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: #"{"action":"search_web","queries":["one","","three"]}"#) == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: #"{"action":"unknown"}"#) == .invalid)
		#expect(BeaconModelRuntime.parseWebSearchDecision(from: #"{"action":"search_web","query":"first"} extra"#) == .invalid)
	}

	@Test("Obvious live requests have a conservative fallback")
	func highConfidenceFallback() {
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "What is the weather in Berlin?") == "What is the weather in Berlin?")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Recent Disney movies") == "Recent Disney movies")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Search the web for Swift 6.2 changes") == "Search the web for Swift 6.2 changes")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Find sources about new battery technology") == "Find sources about new battery technology")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Who is the current CEO of Apple?") == "Who is the current CEO of Apple?")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Who won the World Cup?") == "Who won the World Cup?")
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "How many world cups does Spain have?") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "When did Spain win the World Cup?") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Who wrote Pride and Prejudice?") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Explain why the sky is blue") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Explain electric current") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Write a poem about today's news") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Write a poem using the word today") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Write about living in the now") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Explain live versus recorded music") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Translate the price of freedom into French") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Explain the phrase right now") == nil)
	}

	@Test("Current examples search while factual and creative tasks stay local")
	func requestedRoutingExamples() {
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "when did Spain win the World Cup?") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "who won the World Cup in 2010?") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "what happened with OpenAI today?") != nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "what's the latest version of Swift?") != nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "write me a poem about rain") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "help me rewrite this paragraph") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "who are you?") == nil)
	}

	@Test("Automatic routing runs only for strong web signals")
	func automaticRoutingGate() {
		#expect(BeaconModelRuntime.shouldConsiderAutomaticWebSearch(for: "Tell me a joke", conversationHistory: []) == false)
		#expect(BeaconModelRuntime.shouldConsiderAutomaticWebSearch(for: "Who wrote Pride and Prejudice?", conversationHistory: []) == false)
		#expect(BeaconModelRuntime.shouldConsiderAutomaticWebSearch(for: "What's the weather today?", conversationHistory: []) == true)
		#expect(BeaconModelRuntime.shouldConsiderAutomaticWebSearch(for: "Recent Disney movies", conversationHistory: []) == true)
		#expect(BeaconModelRuntime.shouldConsiderAutomaticWebSearch(for: "Search the web for Swift updates", conversationHistory: []) == true)
	}

	@Test("Current follow-ups retain automatic routing")
	func automaticRoutingFollowUp() {
		let currentHistory = [ChatMessage(text: "What is the weather in Berlin?", role: .user)]
		let localHistory = [ChatMessage(text: "Explain photosynthesis", role: .user)]
		let presidentHistory = [
			ChatMessage(text: "How many presidents has the United States had?", role: .user),
			ChatMessage(text: "The United States has had many presidents since George Washington.", role: .assistant)
		]

		#expect(BeaconModelRuntime.shouldConsiderAutomaticWebSearch(for: "What about tomorrow?", conversationHistory: currentHistory) == true)
		#expect(BeaconModelRuntime.shouldConsiderAutomaticWebSearch(for: "What about that?", conversationHistory: localHistory) == false)
		#expect(BeaconModelRuntime.shouldConsiderAutomaticWebSearch(for: "Who is the recent one?", conversationHistory: presidentHistory) == true)
	}

	@Test("Context-dependent fallback does not send an incomplete query")
	func incompleteFallbackIsSkipped() {
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "What about tomorrow?") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Is it available now?") == nil)
		#expect(BeaconModelRuntime.fallbackWebSearchQuery(for: "Who is the recent one?") == nil)
	}

	@Test("Router receives only the relevant immediate exchange")
	func routingContextIsMinimized() {
		let history = [
			ChatMessage(text: "My private account number is 1234", role: .user),
			ChatMessage(text: "What is the weather in Berlin?", role: .user),
			ChatMessage(text: "It is sunny.", role: .assistant)
		]

		#expect(BeaconModelRuntime.webSearchRoutingContext(for: "Who is the CEO of Apple?", conversationHistory: history) == nil)
		#expect(
			BeaconModelRuntime.webSearchRoutingContext(for: "What about tomorrow?", conversationHistory: history)
				== "User: What is the weather in Berlin?\nAssistant: It is sunny."
		)
		#expect(
			BeaconModelRuntime.webSearchRoutingContext(
				for: "Who is this player?",
				conversationHistory: [
					ChatMessage(text: "I found this old Eagles jersey.", role: .user),
					ChatMessage(text: "It appears to have the number 86 on it.", role: .assistant)
				]
			) == "User: I found this old Eagles jersey.\nAssistant: It appears to have the number 86 on it."
		)

		let presidentContext = BeaconModelRuntime.webSearchRoutingContext(
			for: "Who is the recent one?",
			conversationHistory: [
				ChatMessage(text: "How many presidents has the United States had?", role: .user),
				ChatMessage(text: "The United States has had many presidents since George Washington.", role: .assistant)
			]
		)
		#expect(presidentContext?.contains("presidents has the United States") == true)
		#expect(presidentContext?.contains("Assistant:") == true)
	}

	@Test("Follow-up search context includes the answer that established the subject")
	func followUpSearchContextIncludesPreviousAnswer() {
		let history = [
			ChatMessage(text: "What is the weather in Berlin today?", role: .user),
			ChatMessage(text: "Berlin will be rainy this afternoon, then clear overnight.", role: .assistant)
		]

		let context = BeaconModelRuntime.webSearchRoutingContext(
			for: "How about Paris tomorrow?",
			conversationHistory: history
		)

		#expect(context == "User: What is the weather in Berlin today?\nAssistant: Berlin will be rainy this afternoon, then clear overnight.")
	}

	@Test("Follow-up router uses the immediate exchange and prioritizes the newest subject")
	func followUpRouterUsesImmediateExchange() {
		let history = [
			ChatMessage(text: "Tell me about Donald Trump.", role: .user),
			ChatMessage(text: "He is an American political figure and former president.", role: .assistant),
			ChatMessage(text: "What about Joe Biden?", role: .user),
			ChatMessage(text: "He is another American political figure and former president.", role: .assistant)
		]
		let context = BeaconModelRuntime.webSearchRoutingContext(for: "What did he do before politics?", conversationHistory: history)
		let routingPrompt = BeaconModelRuntime.contextualWebSearchRoutingPrompt(
			for: "What did he do before politics?",
			conversationContext: context ?? "None"
		)

		#expect(context?.contains("Donald Trump") == false)
		#expect(context?.contains("Joe Biden") == true)
		#expect(context?.contains("American political figure and former president") == true)
		#expect(routingPrompt.contains("newest message determines the current intent"))
		#expect(routingPrompt.contains("do not carry the old subject forward"))
		#expect(routingPrompt.contains("What did he do before politics?"))
	}

	@Test("MCP event stream extracts JSON payload")
	func eventStreamPayload() throws {
		let stream = "event: message\r\ndata: {\"jsonrpc\":\"2.0\",\"id\":\"test\"}\r\n\r\n"
		let payload = try #require(WebSearchMCPClient.eventStreamPayloads(from: Data(stream.utf8)).first)

		#expect(String(decoding: payload, as: UTF8.self) == "{\"jsonrpc\":\"2.0\",\"id\":\"test\"}")
	}

	@Test("MCP response decodes normalized search results")
	func normalizedSearchResponse() throws {
		let innerResponse: [String: Any] = [
			"query": "Spain FIFA World Cup winning year",
			"results": [[
				"title": "Spain's 2010 World Cup win",
				"url": "https://inside.fifa.com/spain",
				"source": "inside.fifa.com",
				"snippet": "Spain won the FIFA World Cup in 2010.",
				"content": "Spain defeated the Netherlands in the 2010 final."
			]]
		]
		let innerData = try JSONSerialization.data(withJSONObject: innerResponse)
		let response: [String: Any] = [
			"jsonrpc": "2.0",
			"id": "test",
			"result": ["content": [["type": "text", "text": String(decoding: innerData, as: UTF8.self)]]]
		]
		let data = try JSONSerialization.data(withJSONObject: response)

		let decoded = try WebSearchMCPClient.decodeSearchResponse(from: data, contentType: "application/json")
		#expect(decoded.results.first?.source == "inside.fifa.com")
		#expect(decoded.results.first?.snippet == "Spain won the FIFA World Cup in 2010.")
		#expect(decoded.results.first?.content == "Spain defeated the Netherlands in the 2010 final.")
	}

	@Test("MCP browser rate limits decode as a retryable rate-limit error")
	func mcpRateLimitError() throws {
		let response: [String: Any] = [
			"jsonrpc": "2.0",
			"id": "test",
			"result": ["isError": true, "content": [["type": "text", "text": "Unable to create new browser: code: 429: Rate limit exceeded"]]]
		]
		let data = try JSONSerialization.data(withJSONObject: response)
		var didRateLimit = false
		do {
			_ = try WebSearchMCPClient.decodeSearchResponse(from: data, contentType: "application/json")
		} catch WebSearchMCPClient.ClientError.rateLimited {
			didRateLimit = true
		} catch {
			Issue.record("Expected a rate-limit error, got \(error)")
		}
		#expect(didRateLimit)
	}

	@Test("Grounding prompt requires evidence and inline citations")
	func groundingPrompt() {
		let result = WebSearchMCPClient.Result(
			title: "Spain's 2010 World Cup win",
			url: URL(string: "https://inside.fifa.com/spain")!,
			source: "inside.fifa.com",
			snippet: "Spain won the FIFA World Cup in 2010.",
			content: "Spain defeated the Netherlands in the 2010 final."
		)
		let prompt = WebSearchGrounding.prompt(
			question: "When did Spain win the World Cup?",
			query: "Spain FIFA World Cup winning year",
			results: [result]
		)

		#expect(WebSearchGrounding.instructions.contains("primary source of truth"))
		#expect(WebSearchGrounding.instructions.contains("rather than your prior knowledge"))
		#expect(WebSearchGrounding.instructions.contains("Cite every factual claim"))
		#expect(WebSearchGrounding.instructions.contains("follow the shared response style"))
		#expect(WebSearchGrounding.instructions.contains("short paragraphs or compact bullets"))
		#expect(prompt.contains("[1] Spain's 2010 World Cup win"))
		#expect(prompt.contains("Spain won the FIFA World Cup in 2010."))
		#expect(prompt.contains("Page excerpt: Spain defeated the Netherlands in the 2010 final."))
		#expect(prompt.contains("Resolved search intent: Spain FIFA World Cup winning year"))
	}

	@Test("Grounding prompt keeps visual clues and relevant conversation for image search")
	func imageGroundingPromptIncludesVisualAndChatContext() {
		let result = WebSearchMCPClient.Result(
			title: "Zach Ertz NFL player profile",
			url: URL(string: "https://www.nfl.com/players/zach-ertz/")!,
			source: "nfl.com",
			snippet: "Zach Ertz is a tight end who wore number 86 for the Philadelphia Eagles."
		)
		let prompt = WebSearchGrounding.prompt(
			question: "Who is this player?",
			query: "Eagles jersey name Ertz number 86 player",
			results: [result],
			visualContext: "The jersey reads Ertz and shows number 86 with green Eagles details.",
			conversationContext: "User: I found an old Eagles jersey."
		)

		#expect(prompt.contains("jersey reads Ertz and shows number 86"))
		#expect(prompt.contains("User: I found an old Eagles jersey."))
		#expect(prompt.contains("Eagles jersey name Ertz number 86 player"))
	}

	@Test("Car damage searches combine the question with visible damage")
	func carDamageSearchUsesImageContext() {
		let observation = "Image 1: A silver car door has a small ding and a scratch near the handle."
		let query = "small silver car door ding scratch severity repair signs"
		let routingPrompt = BeaconModelRuntime.visualWebSearchRoutingPrompt(question: "Is this bad?", visualContext: observation)
		#expect(routingPrompt.contains("Is this bad?"))
		#expect(routingPrompt.contains("silver car door has a small ding and a scratch"))
		#expect(routingPrompt.contains("combines the user's intent with at least two concrete clues"))
		#expect(!VisualSearchRouting.queryUsesVisualClues("is this bad", visualContext: observation, question: "Is this bad?"))
		#expect(!VisualSearchRouting.queryUsesVisualClues("silver car door", visualContext: observation, question: "Is this bad?"))
		#expect(VisualSearchRouting.queryUsesVisualClues(query, visualContext: observation, question: "Is this bad?"))
		#expect(ImageResponseRouting.responsePrompt(question: "Is this bad?", visualAnalysis: observation).contains("small ding and a scratch"))
		let relevant = WebSearchMCPClient.Result(
			title: "Small car door ding and scratch repair guide",
			url: URL(string: "https://example.com/car-door-ding")!,
			source: "example.com",
			snippet: "When a car door ding is more than cosmetic."
		)
		#expect(VisualSearchRouting.relevantResults([relevant], query: query, question: "Is this bad?").map(\.url) == [relevant.url])
	}

	@Test("Image identity searches require visible clues and reject unrelated results")
	func imageIdentificationUsesRelevantResults() {
		let observation = "The jersey reads Ertz, shows number 86, and has an Eagles logo."
		let query = "Eagles Ertz 86 football player"
		let relevant = WebSearchMCPClient.Result(
			title: "Zach Ertz Eagles jersey number 86",
			url: URL(string: "https://www.nfl.com/players/zach-ertz/")!,
			source: "nfl.com",
			snippet: "Ertz wore number 86 for the Eagles."
		)
		let unrelated = WebSearchMCPClient.Result(
			title: "Is this bad?",
			url: URL(string: "https://example.com/feelings")!,
			source: "example.com",
			snippet: "How to tell if something is bad."
		)
		#expect(BeaconModelRuntime.visualWebSearchRoutingPrompt(question: "Who is this player?", visualContext: observation).contains("Ertz"))
		#expect(VisualSearchRouting.queryUsesVisualClues(query, visualContext: observation))
		#expect(VisualSearchRouting.relevantResults([unrelated, relevant], query: query).map(\.url) == [relevant.url])
	}

	@Test("Jersey identification rejects generic wearer searches and merchandise results")
	func jerseySearchTargetsDistinguishingClues() {
		let observation = "Observed: A dog wearing a green jersey with an Eagles logo, readable ERTZ and number 86. Likely identification: English bulldog."
		let question = "Whose jersey is he wearing?"
		let query = "Eagles Ertz 86 jersey player"
		#expect(!VisualSearchRouting.queryUsesVisualClues("dog wearing jersey", visualContext: observation, question: question))
		#expect(!VisualSearchRouting.queryUsesVisualClues("dog wearing Eagles jersey", visualContext: observation, question: question))
		#expect(VisualSearchRouting.queryUsesVisualClues(query, visualContext: observation, question: question))
		// Breed research is still valid when supported by distinct visual clues.
		#expect(VisualSearchRouting.queryUsesVisualClues("English bulldog breed characteristics", visualContext: observation, question: "What breed is this?"))

		let merchandise = WebSearchMCPClient.Result(
			title: "Eagles jersey for your dog",
			url: URL(string: "https://example.com/dog-jersey")!,
			source: "example.com",
			snippet: "Pet clothing for dogs wearing a team jersey."
		)
		let player = WebSearchMCPClient.Result(
			title: "Zach Ertz wore number 86 for the Eagles",
			url: URL(string: "https://example.com/ertz")!,
			source: "example.com",
			snippet: "Ertz played tight end in Philadelphia."
		)
		#expect(VisualSearchRouting.relevantResults([merchandise, player], query: query, question: question).map(\.url) == [player.url])
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
	@Test("Deleting models removes cache metadata and lock directories")
	func deletesEveryModelCacheDirectory() throws {
		let model = BeaconModel(
			id: "delete-test",
			name: "Delete Test",
			description: "Test model",
			repositoryID: "company/delete-test",
			sizeInGB: 1,
			type: .regular,
			recommendedDevice: "iPhone 14+",
			isAvailableDuringOnboarding: false,
			isBuiltIn: false,
			supportsImages: false
		)
		let hub = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		defer { try? FileManager.default.removeItem(at: hub) }
		let urls = DownloadedModelStorage.cacheURLs(for: model, hubDirectory: hub)
		for url in urls {
			try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		}

		try DownloadedModelStorage.delete([model], hubDirectory: hub)

		#expect(urls.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
	}

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
	@Test("System preferred color scheme is nil (follows system)")
	func systemPreferredColorSchemeIsNil() {
		#expect(AppearanceColorScheme.system.preferredColorScheme == nil)
	}

	@Test("Explicit schemes map to SwiftUI color schemes")
	func explicitPreferredColorSchemes() {
		#expect(AppearanceColorScheme.light.preferredColorScheme == .light)
		#expect(AppearanceColorScheme.dark.preferredColorScheme == .dark)
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
