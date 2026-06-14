//
//  BeaconModelRuntime.swift
//  beacon-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import Combine
import Foundation
import MLX
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

@MainActor
final class BeaconModelRuntime: ObservableObject {
	enum RuntimeError: LocalizedError {
		case modelNotLoaded
		case alreadyGenerating

		var errorDescription: String? {
			switch self {
			case .modelNotLoaded:
				"Model is not loaded yet."
			case .alreadyGenerating:
				"Beacon is already generating a response."
			}
		}
	}

	@Published private(set) var progress = 0.0
	@Published private(set) var isLoading = false
	@Published private(set) var isGenerating = false
	@Published var errorMessage: String?

	private var loadedModelID: String?
	private var session: ChatSession?

	func isReady(for model: BeaconModel) -> Bool {
		loadedModelID == model.id && session != nil
	}

	func load(_ model: BeaconModel) async {
		guard !isReady(for: model), !isLoading else { return }

		isLoading = true
		errorMessage = nil
		progress = 0.02

		do {
			Memory.cacheLimit = 20 * 1024 * 1024
			let configuration = configuration(for: model)
			print("BeaconModelRuntime: loading \(model.repositoryID)")
			let container = try await #huggingFaceLoadModelContainer(configuration: configuration) { progress in
				Task { @MainActor in
					self.progress = max(0.02, progress.fractionCompleted)
				}
			}

			session = ChatSession(
				container,
				instructions: BeaconSystemPrompt.instructions,
				generateParameters: GenerateParameters(maxTokens: 256, temperature: 0.5)
			)
			loadedModelID = model.id
			progress = 1
			print("BeaconModelRuntime: loaded \(model.repositoryID)")
		} catch {
			let message = "\(type(of: error)): \(error.localizedDescription)"
			print("BeaconModelRuntime: failed to load \(model.repositoryID): \(message)")
			errorMessage = message
		}

		isLoading = false
	}

	func streamResponse(to prompt: String, onChunk: @escaping @MainActor (String) -> Void) async throws {
		guard !isGenerating else { throw RuntimeError.alreadyGenerating }
		guard let session else { throw RuntimeError.modelNotLoaded }

		isGenerating = true
		defer { isGenerating = false }

		for try await chunk in session.streamResponse(to: prompt) {
			onChunk(chunk)
		}
	}

	private func configuration(for model: BeaconModel) -> ModelConfiguration {
		switch model.repositoryID {
		case "mlx-community/Llama-3.2-1B-Instruct-4bit":
			LLMRegistry.llama3_2_1B_4bit
		case "mlx-community/Llama-3.2-3B-Instruct-4bit":
			LLMRegistry.llama3_2_3B_4bit
		default:
			ModelConfiguration(id: model.repositoryID)
		}
	}
}
