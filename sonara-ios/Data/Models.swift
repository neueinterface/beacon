//
//  Models.swift
//  sonara-ios
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
			id: "sonara-lite",
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
			id: "sonara-plus",
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
			id: "sonara-reasoning",
			name: "Qwen3 1.7B 4-bit",
			description: "A compact reasoning-focused Qwen model with a sub-1 GB download.",
			repositoryID: "mlx-community/Qwen3-1.7B-4bit",
			sizeInGB: 0.97,
			type: .reasoning,
			recommendedDevice: "iPhone 14 Pro+",
			isAvailableDuringOnboarding: true,
			isBuiltIn: false
		),
		BeaconModel(
			id: "sonara-qwen35-medium",
			name: "Qwen3.5 2B 4-bit",
			description: "A newer Qwen model for better answers on newer iPhones.",
			repositoryID: "mlx-community/Qwen3.5-2B-4bit",
			sizeInGB: 1.72,
			type: .reasoning,
			recommendedDevice: "iPhone 15 Pro+",
			isAvailableDuringOnboarding: false,
			isBuiltIn: false
		),
		BeaconModel(
			id: "sonara-qwen-2507",
			name: "Qwen3 4B Instruct 2507 4-bit",
			description: "A newer Qwen3 instruct model for higher-quality local chat on Pro devices.",
			repositoryID: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
			sizeInGB: 2.26,
			type: .reasoning,
			recommendedDevice: "iPhone 15 Pro+",
			isAvailableDuringOnboarding: false,
			isBuiltIn: false
		)
	]

	static var onboardingModels: [BeaconModel] {
		availableModels.filter(\.isAvailableDuringOnboarding)
	}

	static var defaultModel: BeaconModel {
		onboardingModels[0]
	}

	static func model(id: String) -> BeaconModel? {
		availableModels.first { $0.id == id }
	}
}
