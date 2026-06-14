//
//  Models.swift
//  beacon-ios
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
	let subtitle: String
	let description: String
	let repositoryID: String
	let sizeInGB: Decimal
	let type: ModelType

	var formattedSize: String {
		"\(sizeInGB) GB"
	}
}

enum ModelCatalog {
	static let availableModels: [BeaconModel] = [
		BeaconModel(
			id: "beacon-lite",
			name: "Llama 3.2 1B Instruct 4-bit",
			subtitle: "Fast everyday chat",
			description: "A small, balanced model for private on-device conversations.",
			repositoryID: "mlx-community/Llama-3.2-1B-Instruct-4bit",
			sizeInGB: 0.7,
			type: .regular
		),
		BeaconModel(
			id: "beacon-plus",
			name: "Llama 3.2 3B Instruct 4-bit",
			subtitle: "Better quality, larger download",
			description: "A stronger local model for richer answers on newer devices.",
			repositoryID: "mlx-community/Llama-3.2-3B-Instruct-4bit",
			sizeInGB: 1.8,
			type: .regular
		),
		BeaconModel(
			id: "beacon-reasoning",
			name: "DeepSeek R1 Distill Qwen 1.5B 4-bit",
			subtitle: "Step-by-step problem solving",
			description: "A compact reasoning model for more deliberate responses.",
			repositoryID: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit",
			sizeInGB: 1.0,
			type: .reasoning
		)
	]

	static var defaultModel: BeaconModel {
		availableModels[0]
	}

	static func model(id: String) -> BeaconModel? {
		availableModels.first { $0.id == id }
	}
}
