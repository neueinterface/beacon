//
//  BeaconModelRuntime.swift
//  beacon
//
//  Created by Armond Schneider on 6/13/26.
//

import Combine
import Foundation
import FoundationModels
import CoreImage
import MLX
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import MLXVLM
import Tokenizers

@MainActor
final class BeaconModelRuntime: ModelDownloadRuntime {
	enum WebSearchRoutingDecision: Equatable {
		case noSearch
		case search(String)
		case invalid
	}

	enum RuntimeError: LocalizedError {
		case modelNotLoaded
		case modelLoadFailed(String)
		case alreadyGenerating
		case imageModelRequired
		case invalidImage
		case foundationModelUnavailable(SystemLanguageModel.Availability.UnavailableReason)

		var errorDescription: String? {
			switch self {
			case .modelNotLoaded:
				"Model is not loaded yet."
			case let .modelLoadFailed(message):
				message
			case .alreadyGenerating:
				"Beacon is already generating a response."
			case .imageModelRequired:
				"Select a downloaded vision model before sending an image."
			case .invalidImage:
				"This image could not be prepared for the selected model."
			case let .foundationModelUnavailable(reason):
				switch reason {
				case .deviceNotEligible:
					"Apple Foundation Model is not available on this device."
				case .appleIntelligenceNotEnabled:
					"Turn on Apple Intelligence to use Apple Foundation Model."
				case .modelNotReady:
					"Apple Foundation Model is not ready yet. Try again after Apple Intelligence finishes setup."
				@unknown default:
					"Apple Foundation Model is not available right now."
				}
			}
		}
	}

	@Published private(set) var progress = 0.0
	@Published private(set) var completedUnitCount: Int64?
	@Published private(set) var totalUnitCount: Int64?
	@Published private(set) var isLoading = false
	@Published private(set) var isGenerating = false
	@Published var errorMessage: String?

	private var loadedModelID: String?
	private var loadedModelRepositoryID: String?
	private var loadedModelType: BeaconModel.ModelType = .regular
	private var loadedModelSupportsImages = false
	private var modelContainer: ModelContainer?
	private var session: ChatSession?
	private var foundationSession: LanguageModelSession?
	private var progressObservations: [NSKeyValueObservation] = []
	private var observedProgresses: [Progress] = []
	private var loadWaiters: [CheckedContinuation<Void, Never>] = []

	func isReady(for model: BeaconModel) -> Bool {
		if model.isBuiltIn {
			return loadedModelID == model.id && foundationSession != nil
		}

		return loadedModelID == model.id && modelContainer != nil
	}

	func load(_ model: BeaconModel) async {
		guard !Task.isCancelled else { return }
		while isLoading {
			await withCheckedContinuation { continuation in
				loadWaiters.append(continuation)
			}
			guard !Task.isCancelled else { return }
		}
		guard !isReady(for: model) else { return }

		isLoading = true
		defer { finishLoading() }
		errorMessage = nil
		progress = 0.02
		completedUnitCount = nil
		totalUnitCount = nil
		progressObservations.removeAll()
		observedProgresses.removeAll()

		if loadedModelID != nil && loadedModelID != model.id {
			releaseLoadedModel()
		}

		do {
			if model.isBuiltIn {
				try loadFoundationModel(model)
				return
			}

			Memory.cacheLimit = 20 * 1024 * 1024
			let configuration = configuration(for: model)
			print("BeaconModelRuntime: loading \(model.repositoryID)")
			let container = try await #huggingFaceLoadModelContainer(configuration: configuration) { progress in
				Task { @MainActor in
					self.observe(progress)
				}
			}
			try Task.checkCancellation()

			modelContainer = container
			session = ChatSession(
				container,
				instructions: BeaconSystemPrompt.instructions,
				generateParameters: GenerateParameters(maxTokens: 4096, temperature: 0.5)
			)
			loadedModelID = model.id
			loadedModelRepositoryID = model.repositoryID
			loadedModelType = model.type
			loadedModelSupportsImages = model.supportsImages
			foundationSession = nil
			progress = 1
			print("BeaconModelRuntime: loaded \(model.repositoryID)")
		} catch is CancellationError {
			progress = 0
			completedUnitCount = nil
			totalUnitCount = nil
			errorMessage = nil
			print("BeaconModelRuntime: cancelled loading \(model.repositoryID)")
		} catch {
			let message = "\(type(of: error)): \(error.localizedDescription)"
			print("BeaconModelRuntime: failed to load \(model.repositoryID): \(message)")
			errorMessage = message
		}

		progressObservations.removeAll()
		observedProgresses.removeAll()
	}

	private func finishLoading() {
		isLoading = false
		let waiters = loadWaiters
		loadWaiters.removeAll()
		waiters.forEach { $0.resume() }
	}

	@discardableResult
	func unloadIfIdle() -> Bool {
		guard !isLoading, !isGenerating else { return false }
		guard loadedModelID != nil || session != nil || foundationSession != nil else { return false }

		releaseLoadedModel()
		progress = 0
		completedUnitCount = nil
		totalUnitCount = nil
		errorMessage = nil
		return true
	}

	func streamResponse(
		to prompt: String,
		imageData: Data? = nil,
		conversationHistory: [ChatMessage] = [],
		additionalInstructions: String? = nil,
		onThinking: (@MainActor (String) -> Void)? = nil,
		onChunk: @escaping @MainActor (String) -> Void
	) async throws {
		guard !isGenerating else { throw RuntimeError.alreadyGenerating }
		guard modelContainer != nil || foundationSession != nil else { throw RuntimeError.modelNotLoaded }
		guard imageData == nil || loadedModelSupportsImages else { throw RuntimeError.imageModelRequired }

		isGenerating = true
		defer { isGenerating = false }
		let instructions = additionalInstructions.map { "\(BeaconSystemPrompt.instructions)\n\n\($0)" } ?? BeaconSystemPrompt.instructions

		if foundationSession != nil {
			let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
			foundationSession = session
			try await streamFoundationResponse(to: contextualPrompt(prompt, history: conversationHistory), using: session, onChunk: onChunk)
			return
		}

		guard let modelContainer else { throw RuntimeError.modelNotLoaded }
		let session = ChatSession(
			modelContainer,
			instructions: instructions,
			history: mlxHistory(from: conversationHistory),
			generateParameters: GenerateParameters(maxTokens: 1024, temperature: 0.5)
		)
		self.session = session

		let image = imageData.flatMap(CIImage.init(data:)).map(UserInput.Image.ciImage)
		guard imageData == nil || image != nil else { throw RuntimeError.invalidImage }

		var filter = ThinkingOutputFilter()
		for try await chunk in session.streamResponse(to: prompt, image: image) {
			try Task.checkCancellation()

			let output = filter.append(chunk)
			if !output.thinking.isEmpty {
				onThinking?(output.thinking)
			}

			if !output.visible.isEmpty {
				onChunk(output.visible)
			}
		}
	}

	func webSearchQuery(for prompt: String, conversationHistory: [ChatMessage] = []) async throws -> String? {
		guard !isGenerating else { throw RuntimeError.alreadyGenerating }
		guard modelContainer != nil || foundationSession != nil else { throw RuntimeError.modelNotLoaded }
		guard Self.shouldConsiderAutomaticWebSearch(for: prompt, conversationHistory: conversationHistory) else { return nil }
		let query: String?
		if let directQuery = Self.fallbackWebSearchQuery(for: prompt) {
			query = directQuery
		} else if let contextualQuery = try await contextualWebSearchQuery(for: prompt, conversationHistory: conversationHistory) {
			query = contextualQuery
		} else {
			query = Self.contextualWebSearchQuery(for: prompt, conversationHistory: conversationHistory)
		}
		#if DEBUG
		print("WebSearchPipeline original query: \(prompt)")
		print("WebSearchPipeline router decision: \(query == nil ? "no search" : "search_web (deterministic)")")
		print("WebSearchPipeline generated search query: \(query ?? "none")")
		#endif
		return query
	}

	nonisolated static func parseWebSearchDecision(from output: String) -> WebSearchRoutingDecision {
		struct RoutingOutput: Decodable {
			let action: String
			let query: String?
		}

		var json = output.trimmingCharacters(in: .whitespacesAndNewlines)
		if json.hasPrefix("```"), json.hasSuffix("```") {
			json = json.components(separatedBy: .newlines).dropFirst().dropLast().joined(separator: "\n")
		}
		guard let data = json.data(using: .utf8),
			  let routing = try? JSONDecoder().decode(RoutingOutput.self, from: data) else { return .invalid }
		switch routing.action {
		case "answer_locally":
			return .noSearch
		case "search_web":
			guard let rawQuery = routing.query?.trimmingCharacters(in: .whitespacesAndNewlines), !rawQuery.isEmpty else { return .invalid }
			return .search(String(rawQuery.prefix(200)))
		default:
			return .invalid
		}
	}

	nonisolated static func fallbackWebSearchQuery(for prompt: String) -> String? {
		let normalizedPrompt = normalizedSearchText(prompt)
		guard !normalizedPrompt.isEmpty,
			  !requiresConversationContext(normalizedPrompt),
			  hasHighConfidenceWebSignal(in: normalizedPrompt) else { return nil }
		return String(normalizedPrompt.prefix(200))
	}

	nonisolated private static func contextualWebSearchQuery(for prompt: String, conversationHistory: [ChatMessage]) -> String? {
		let normalizedPrompt = normalizedSearchText(prompt)
		guard requiresConversationContext(normalizedPrompt),
			  let previousUserText = conversationHistory.reversed().first(where: { $0.role == .user })?.text else { return nil }
		let normalizedPrevious = normalizedSearchText(previousUserText)
		guard hasHighConfidenceWebSignal(in: normalizedPrevious) else { return nil }
		return String("\(normalizedPrevious) \(normalizedPrompt)".prefix(200))
	}

	private func contextualWebSearchQuery(for prompt: String, conversationHistory: [ChatMessage]) async throws -> String? {
		guard let context = Self.webSearchRoutingContext(for: prompt, conversationHistory: conversationHistory) else {
			return nil
		}

		let resolverPrompt = """
			Rewrite the user's follow-up as one standalone web search query. Resolve references using the conversation. When the follow-up introduces a new person, place, or item, use that new subject instead of keeping the old one. Keep only terms needed to find the answer.

			Conversation:
			\(context)

			Follow-up:
			\(Self.normalizedSearchText(prompt))

			Return only JSON in this exact shape: {"action":"search_web","query":"standalone search query"}
			"""
		var output = ""
		try await streamResponse(
			to: resolverPrompt,
			conversationHistory: [],
			additionalInstructions: "Return only the requested JSON. Do not answer the user or add Markdown."
		) { chunk in
			output += chunk
		}

		guard case let .search(query) = Self.parseWebSearchDecision(from: output) else {
			return nil
		}
		return query
	}

	nonisolated static func shouldConsiderAutomaticWebSearch(for prompt: String, conversationHistory: [ChatMessage]) -> Bool {
		if fallbackWebSearchQuery(for: prompt) != nil { return true }
		let normalizedPrompt = normalizedSearchText(prompt)
		guard requiresConversationContext(normalizedPrompt) else { return false }
		if hasHighConfidenceWebSignal(in: normalizedPrompt) { return true }
		guard
			  let previousUserText = conversationHistory.reversed().first(where: { $0.role == .user })?.text else {
			return false
		}
		return hasHighConfidenceWebSignal(in: normalizedSearchText(previousUserText))
	}

	nonisolated static func webSearchRoutingContext(for prompt: String, conversationHistory: [ChatMessage]) -> String? {
		guard requiresConversationContext(normalizedSearchText(prompt)),
			  let previousUserIndex = conversationHistory.lastIndex(where: { $0.role == .user }) else {
			return nil
		}

		let context = conversationHistory[previousUserIndex...].compactMap { message -> String? in
			let text = normalizedSearchText(message.text)
			guard !text.isEmpty else { return nil }
			let role = message.role == .user ? "User" : "Assistant"
			return "\(role): \(text.prefix(500))"
		}.joined(separator: "\n")
		return context.isEmpty ? nil : context
	}

	nonisolated private static func hasHighConfidenceWebSignal(in text: String) -> Bool {
		let lowercased = text.lowercased()
		let words = Set(lowercased.split { !$0.isLetter && !$0.isNumber }.map(String.init))
		let explicitRequests = [
			"search the web", "search online", "look up online", "find sources", "find articles",
			"cite sources", "provide sources", "verify online", "fact-check", "check online"
		]
		if explicitRequests.contains(where: lowercased.contains) { return true }
		let offlineTaskPrefixes = ["brainstorm ", "compose ", "explain ", "define ", "help me rewrite", "translate ", "rewrite ", "summarize ", "write "]
		if offlineTaskPrefixes.contains(where: lowercased.hasPrefix) { return false }
		let offlineTaskPhrases = [
			"how are you", "tell me about yourself", "what can you do", "what do you think", "who are you",
			"using the word today", "includes the word today", "include the word today"
		]
		if offlineTaskPhrases.contains(where: lowercased.contains) { return false }
		let learningPrefixes = [
			"tell me about ", "why ", "who was ", "who is ", "what is ", "what are ",
			"how does ", "how do ", "how did ", "could ", "explain "
		]
		let personalTaskPrefixes = ["how do i ", "how can i ", "what should i ", "help me "]
		if personalTaskPrefixes.contains(where: lowercased.hasPrefix) { return false }
		if learningPrefixes.contains(where: lowercased.hasPrefix) { return true }
		let questionPrefixes = ["what ", "what's ", "whats ", "who ", "when ", "where ", "how ", "is ", "are ", "did ", "does ", "can ", "will ", "should "]
		let timeSensitiveWords = ["today", "tonight", "tomorrow", "yesterday", "now", "currently", "latest", "recent", "live", "breaking"]
		let standaloneFreshnessWords = ["currently", "latest", "recent", "breaking"]
		if standaloneFreshnessWords.contains(where: words.contains) {
			return true
		}
		if questionPrefixes.contains(where: lowercased.hasPrefix), timeSensitiveWords.contains(where: words.contains) {
			return true
		}
		let hasHistoricalYear = words.compactMap(Int.init).contains { (1_000..<Calendar.current.component(.year, from: Date.now)).contains($0) }
		if lowercased.contains("who won"), !hasHistoricalYear { return true }

		let timeSensitivePhrases = [
			"right now", "this week", "this month", "this year", "as of", "today's news", "news today",
			"latest news", "recent news", "news about", "in the news", "current headlines", "recent developments", "weather in",
			"forecast for", "price of", "stock price", "share price", "exchange rate",
			"score of", "score for", "schedule for", "release date for", "in stock", "flight status",
			"who is the president", "who is president", "who is the ceo", "who is ceo",
			"current president", "current ceo", "current version", "current price", "current status"
		]
		return timeSensitivePhrases.contains(where: lowercased.contains)
	}

	nonisolated private static func requiresConversationContext(_ text: String) -> Bool {
		let lowercased = text.lowercased()
		let words = Set(lowercased.split { !$0.isLetter && !$0.isNumber }.map(String.init))
		let followUpPhrases = ["what about", "how about", "and tomorrow", "and today", "that one", "the recent one", "the latest one", "most recent one", "which one"]
		let referenceWords = ["it", "they", "their", "them", "there", "that", "those", "these", "he", "she", "his", "her", "one", "ones"]
		return followUpPhrases.contains(where: lowercased.contains) || referenceWords.contains(where: words.contains)
	}

	nonisolated private static func normalizedSearchText(_ text: String) -> String {
		text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
	}

	private func configuration(for model: BeaconModel) -> ModelConfiguration {
		ModelConfiguration(id: model.repositoryID)
	}

	private func releaseLoadedModel() {
		progressObservations.removeAll()
		observedProgresses.removeAll()
		modelContainer = nil
		session = nil
		foundationSession = nil
		loadedModelID = nil
		loadedModelRepositoryID = nil
		loadedModelType = .regular
		loadedModelSupportsImages = false
	}

	private func observe(_ downloadProgress: Progress) {
		updateProgress(from: downloadProgress)

		guard !observedProgresses.contains(where: { $0 === downloadProgress }) else { return }
		observedProgresses.append(downloadProgress)

		let fractionObservation = downloadProgress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
			Task { @MainActor in
				self?.updateProgress(from: progress)
			}
		}
		let completedObservation = downloadProgress.observe(\.completedUnitCount, options: [.new]) { [weak self] progress, _ in
			Task { @MainActor in
				self?.updateProgress(from: progress)
			}
		}
		let totalObservation = downloadProgress.observe(\.totalUnitCount, options: [.new]) { [weak self] progress, _ in
			Task { @MainActor in
				self?.updateProgress(from: progress)
			}
		}
		progressObservations.append(contentsOf: [fractionObservation, completedObservation, totalObservation])
	}

	private func updateProgress(from downloadProgress: Progress) {
		if downloadProgress.completedUnitCount >= 0 {
			completedUnitCount = downloadProgress.completedUnitCount
		}

		if downloadProgress.totalUnitCount > 0 {
			totalUnitCount = downloadProgress.totalUnitCount
		}

		let fractionCompleted: Double
		if downloadProgress.totalUnitCount > 0, downloadProgress.completedUnitCount >= 0 {
			fractionCompleted = Double(downloadProgress.completedUnitCount) / Double(downloadProgress.totalUnitCount)
		} else {
			fractionCompleted = downloadProgress.fractionCompleted
		}

		guard fractionCompleted.isFinite else { return }
		progress = min(max(0.02, fractionCompleted), 1)
	}

	private func mlxHistory(from messages: [ChatMessage]) -> [Chat.Message] {
		messages.compactMap { message in
			let content = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !content.isEmpty else { return nil }

			switch message.role {
			case .user:
				return .user(content)
			case .assistant:
				return .assistant(content)
			}
		}
	}

	private func contextualPrompt(_ prompt: String, history: [ChatMessage]) -> String {
		let transcript = history.compactMap { message -> String? in
			let content = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !content.isEmpty else { return nil }
			let role = message.role == .user ? "User" : "Assistant"
			return "\(role): \(content)"
		}.joined(separator: "\n")

		guard !transcript.isEmpty else { return prompt }
		return """
		Continue this conversation using only the chat transcript below.
		\(transcript)

		User message: \(prompt)
		"""
	}

	private func loadFoundationModel(_ model: BeaconModel) throws {
		let foundationModel = SystemLanguageModel.default

		switch foundationModel.availability {
		case .available:
			foundationSession = LanguageModelSession(model: foundationModel, instructions: BeaconSystemPrompt.instructions)
			session = nil
			loadedModelID = model.id
			loadedModelRepositoryID = model.repositoryID
			loadedModelType = model.type
			loadedModelSupportsImages = false
			progress = 1
			completedUnitCount = nil
			totalUnitCount = nil
			print("BeaconModelRuntime: loaded Apple Foundation Model")
		case let .unavailable(reason):
			throw RuntimeError.foundationModelUnavailable(reason)
		}
	}

	private func streamFoundationResponse(
		to prompt: String,
		using session: LanguageModelSession,
		onChunk: @escaping @MainActor (String) -> Void
	) async throws {
		var previousResponse = ""

		for try await snapshot in session.streamResponse(to: prompt) {
			try Task.checkCancellation()

			let response = snapshot.content
			guard response.count >= previousResponse.count else {
				previousResponse = response
				continue
			}

			let chunk = String(response.dropFirst(previousResponse.count))
			previousResponse = response

			if !chunk.isEmpty {
				onChunk(chunk)
			}
		}
	}
}

struct ThinkingOutputFilter {
	struct Output {
		var visible = ""
		var thinking = ""
	}

	private var buffer = ""
	private var isInsideThinkBlock = false

	mutating func append(_ chunk: String) -> Output {
		buffer += chunk
		var output = Output()

		while !buffer.isEmpty {
			if isInsideThinkBlock {
				guard let endRange = buffer.range(of: "</think>", options: [.caseInsensitive]) else {
					let retainedCount = partialClosingTagLength(in: buffer)
					let emitEnd = buffer.index(buffer.endIndex, offsetBy: -retainedCount)
					output.thinking += buffer[..<emitEnd]
					buffer = String(buffer[emitEnd...])
					break
				}

				output.thinking += buffer[..<endRange.lowerBound]
				buffer.removeSubrange(buffer.startIndex..<endRange.upperBound)
				isInsideThinkBlock = false
				continue
			}

			guard let startRange = buffer.range(of: "<think", options: [.caseInsensitive]) else {
				let retainedCount = partialOpeningTagLength(in: buffer)
				let emitEnd = buffer.index(buffer.endIndex, offsetBy: -retainedCount)
				output.visible += buffer[..<emitEnd]
				buffer = String(buffer[emitEnd...])
				break
			}

			output.visible += buffer[..<startRange.lowerBound]

			guard let tagEnd = buffer[startRange.lowerBound...].firstIndex(of: ">") else {
				buffer = String(buffer[startRange.lowerBound...])
				break
			}

			buffer.removeSubrange(buffer.startIndex...tagEnd)
			isInsideThinkBlock = true
		}

		return output
	}

	private func partialOpeningTagLength(in text: String) -> Int {
		let tag = "<think"
		let lowercasedText = text.lowercased()

		for count in stride(from: min(tag.count - 1, lowercasedText.count), through: 1, by: -1) {
			if lowercasedText.hasSuffix(String(tag.prefix(count))) {
				return count
			}
		}

		return 0
	}

	private func partialClosingTagLength(in text: String) -> Int {
		let tag = "</think>"
		let lowercasedText = text.lowercased()

		for count in stride(from: min(tag.count - 1, lowercasedText.count), through: 1, by: -1) {
			if lowercasedText.hasSuffix(String(tag.prefix(count))) {
				return count
			}
		}

		return 0
	}
}
