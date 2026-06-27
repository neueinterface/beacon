//
//  Models.swift
//  semera-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import Foundation

struct BeaconModel: Identifiable, Equatable {
	enum ModelType {
		case regular
		case reasoning
	}

	let id: String
	let name: String
	let description: String
	let repositoryID: String
	let sizeInGB: Decimal
	let type: ModelType
	let recommendedDevice: String
	let isAvailableDuringOnboarding: Bool
	let isBuiltIn: Bool

	var formattedSize: String {
		if isBuiltIn { return "Built in" }
		return String(format: "%.2f GB", NSDecimalNumber(decimal: sizeInGB).doubleValue)
	}
}

enum ModelCatalog {
	static let availableModels: [BeaconModel] = [
		BeaconModel(
			id: "apple-foundation",
			name: "Apple Foundation Model",
			description: "Apple's private on-device system model. No download required when Apple Intelligence is available.",
			repositoryID: "apple-foundation-model",
			sizeInGB: 0,
			type: .regular,
			recommendedDevice: "Apple Intelligence device",
			isAvailableDuringOnboarding: true,
			isBuiltIn: true
		),
		BeaconModel(
			id: "qwen3-0.6b-4bit",
			name: "Qwen3 0.6B 4-bit",
			description: "A very small Qwen model for fast private chat on most iPhones.",
			repositoryID: "mlx-community/Qwen3-0.6B-4bit",
			sizeInGB: 0.34,
			type: .regular,
			recommendedDevice: "iPhone 13+",
			isAvailableDuringOnboarding: true,
			isBuiltIn: false
		),
		BeaconModel(
			id: "lfm2-1.2b-4bit",
			name: "LFM2 1.2B 4-bit",
			description: "A compact Liquid AI text model with strong tool/chat formatting support.",
			repositoryID: "mlx-community/LFM2-1.2B-4bit",
			sizeInGB: 0.66,
			type: .regular,
			recommendedDevice: "iPhone 14+",
			isAvailableDuringOnboarding: true,
			isBuiltIn: false
		),
		BeaconModel(
			id: "llama-3.2-1b-instruct-4bit",
			name: "Llama 3.2 1B Instruct 4-bit",
			description: "A small instruct-tuned chat model with clearer everyday responses than reasoning-first models.",
			repositoryID: "mlx-community/Llama-3.2-1B-Instruct-4bit",
			sizeInGB: 0.76,
			type: .regular,
			recommendedDevice: "iPhone 14 Pro+",
			isAvailableDuringOnboarding: true,
			isBuiltIn: false
		),
		BeaconModel(
			id: "qwen2.5-3b-instruct-4bit",
			name: "Qwen2.5 3B Instruct 4-bit",
			description: "A balanced chat model for stronger writing, summaries, and practical Q&A on newer iPhones.",
			repositoryID: "mlx-community/Qwen2.5-3B-Instruct-4bit",
			sizeInGB: 1.90,
			type: .regular,
			recommendedDevice: "iPhone 15 Pro+",
			isAvailableDuringOnboarding: false,
			isBuiltIn: false
		),
		BeaconModel(
			id: "llama-3.2-3b-instruct-4bit",
			name: "Llama 3.2 3B Instruct 4-bit",
			description: "A higher-quality instruct model for conversational answers, rewriting, and longer chats on Pro devices.",
			repositoryID: "mlx-community/Llama-3.2-3B-Instruct-4bit",
			sizeInGB: 2.02,
			type: .regular,
			recommendedDevice: "iPhone 15 Pro+",
			isAvailableDuringOnboarding: false,
			isBuiltIn: false
		)
	]

	static var onboardingModels: [BeaconModel] {
		onboardingModels(in: availableModels)
	}

	static var defaultModel: BeaconModel {
		defaultModel(in: availableModels)
	}

	static func model(id: String) -> BeaconModel? {
		model(id: id, in: availableModels)
	}

	static func onboardingModels(in models: [BeaconModel]) -> [BeaconModel] {
		models.filter(\.isAvailableDuringOnboarding)
	}

	static func defaultModel(in models: [BeaconModel]) -> BeaconModel {
		onboardingModels(in: models).first ?? models.first ?? availableModels[0]
	}

	static func model(id: String, in models: [BeaconModel]) -> BeaconModel? {
		models.first { $0.id == id }
	}
}

enum ModelIDMigration {
	private static let migrationKey = "hasMigratedBackendModelIDs"
	private static let modelIDMigrationMap = [
		"semera-lite": "qwen3-0.6b-4bit",
		"semera-plus": "lfm2-1.2b-4bit",
		"semera-llama32-1b": "llama-3.2-1b-instruct-4bit",
		"semera-qwen25-3b-instruct": "qwen2.5-3b-instruct-4bit",
		"semera-llama32-3b": "llama-3.2-3b-instruct-4bit"
	]

	static func migrate(defaults: UserDefaults = .standard) {
		guard !defaults.bool(forKey: migrationKey) else { return }

		if let selectedModelID = defaults.string(forKey: "selectedModelID"),
		   let migratedModelID = modelIDMigrationMap[selectedModelID] {
			defaults.set(migratedModelID, forKey: "selectedModelID")
		}

		let downloadedModelIDs = defaults.string(forKey: "downloadedModelIDs") ?? ""
		let migratedDownloadedModelIDs = downloadedModelIDs
			.split(separator: ",")
			.map(String.init)
			.map { modelIDMigrationMap[$0] ?? $0 }

		defaults.set(Set(migratedDownloadedModelIDs).sorted().joined(separator: ","), forKey: "downloadedModelIDs")
		defaults.set(true, forKey: migrationKey)
	}
}
