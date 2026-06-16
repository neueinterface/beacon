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
			description: "A small, balanced model for private on-device conversations.",
			repositoryID: "mlx-community/Llama-3.2-1B-Instruct-4bit",
			sizeInGB: 0.7,
			type: .regular
		),
		BeaconModel(
			id: "beacon-plus",
			name: "Llama 3.2 3B Instruct 4-bit",
			description: "A stronger local model for richer answers on newer devices.",
			repositoryID: "mlx-community/Llama-3.2-3B-Instruct-4bit",
			sizeInGB: 1.8,
			type: .regular
		),
		BeaconModel(
			id: "beacon-reasoning",
			name: "Qwen3 1.7B 4-bit",
			description: "A newer compact chat model with stronger reasoning than tiny local models.",
			repositoryID: "mlx-community/Qwen3-1.7B-4bit",
			sizeInGB: 0.97,
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
