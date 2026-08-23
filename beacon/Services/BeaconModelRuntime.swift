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
	enum RuntimeError: LocalizedError {
		case modelNotLoaded
		case alreadyGenerating
		case imageModelRequired
		case invalidImage
		case foundationModelUnavailable(SystemLanguageModel.Availability.UnavailableReason)

		var errorDescription: String? {
			switch self {
			case .modelNotLoaded:
				"Model is not loaded yet."
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

	func isReady(for model: BeaconModel) -> Bool {
		if model.isBuiltIn {
			return loadedModelID == model.id && foundationSession != nil
		}

		return loadedModelID == model.id && modelContainer != nil
	}

	func load(_ model: BeaconModel) async {
		guard !isReady(for: model), !isLoading else { return }

		isLoading = true
		defer { isLoading = false }
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
		onThinking: (@MainActor (String) -> Void)? = nil,
		onChunk: @escaping @MainActor (String) -> Void
	) async throws {
		guard !isGenerating else { throw RuntimeError.alreadyGenerating }
		guard modelContainer != nil || foundationSession != nil else { throw RuntimeError.modelNotLoaded }
		guard imageData == nil || loadedModelSupportsImages else { throw RuntimeError.imageModelRequired }

		isGenerating = true
		defer { isGenerating = false }

		if foundationSession != nil {
			let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: BeaconSystemPrompt.instructions)
			foundationSession = session
			try await streamFoundationResponse(to: contextualPrompt(prompt, history: conversationHistory), using: session, onChunk: onChunk)
			return
		}

		guard let modelContainer else { throw RuntimeError.modelNotLoaded }
		let session = ChatSession(
			modelContainer,
			instructions: BeaconSystemPrompt.instructions,
			history: mlxHistory(from: conversationHistory),
			generateParameters: GenerateParameters(maxTokens: 4096, temperature: 0.5)
		)
		self.session = session

		let image = imageData.flatMap(CIImage.init(data:)).map(UserInput.Image.ciImage)
		guard imageData == nil || image != nil else { throw RuntimeError.invalidImage }

		var filter = ThinkingOutputFilter()
		let modelPrompt = promptForLoadedModel(prompt)

		for try await chunk in session.streamResponse(to: modelPrompt, image: image) {
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

	private func configuration(for model: BeaconModel) -> ModelConfiguration {
		switch model.repositoryID {
		case "mlx-community/Qwen3-0.6B-4bit":
			LLMRegistry.qwen3_0_6b_4bit
		case "mlx-community/LFM2-1.2B-4bit":
			LLMRegistry.lfm2_1_2b_4bit
		case "mlx-community/Qwen2-VL-2B-Instruct-4bit":
			VLMRegistry.qwen2VL2BInstruct4Bit
		default:
			ModelConfiguration(id: model.repositoryID)
		}
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

	private func promptForLoadedModel(_ prompt: String) -> String {
		guard loadedModelType == .regular, loadedModelRepositoryID?.contains("Qwen3") == true else { return prompt }
		return "\(prompt) /no_think"
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

private struct ThinkingOutputFilter {
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
