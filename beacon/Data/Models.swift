//
//  Models.swift
//  beacon
//
//  Created by Armond Schneider on 6/13/26.
//

import Foundation

struct BeaconModel: Identifiable, Equatable, Decodable {
	enum ModelType: String, Decodable {
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
	let supportsImages: Bool

	init(
		id: String,
		name: String,
		description: String,
		repositoryID: String,
		sizeInGB: Decimal,
		type: ModelType,
		recommendedDevice: String,
		isAvailableDuringOnboarding: Bool,
		isBuiltIn: Bool,
		supportsImages: Bool = false
	) {
		self.id = id
		self.name = name
		self.description = description
		self.repositoryID = repositoryID
		self.sizeInGB = sizeInGB
		self.type = type
		self.recommendedDevice = recommendedDevice
		self.isAvailableDuringOnboarding = isAvailableDuringOnboarding
		self.isBuiltIn = isBuiltIn
		self.supportsImages = supportsImages
	}

	var formattedSize: String {
		if isBuiltIn { return "Built in" }
		return String(format: "%.2f GB", NSDecimalNumber(decimal: sizeInGB).doubleValue)
	}
}

enum ModelCatalog {
	static let availableModels: [BeaconModel] = {
		do {
			guard let url = Bundle.main.url(forResource: "models", withExtension: "json") else {
				throw CocoaError(.fileNoSuchFile)
			}

			return try decode(Data(contentsOf: url))
		} catch {
			fatalError("Could not load the bundled model catalog: \(error)")
		}
	}()

	static func decode(_ data: Data) throws -> [BeaconModel] {
		try JSONDecoder().decode([BeaconModel].self, from: data)
	}

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

enum ModelStorageLimit {
	static let maxGB: Decimal = 10

	enum DownloadAvailability: Equatable {
		case available
		case appStorageFull
		case deviceStorageLow(requiredGB: Double, availableGB: Double)

		var canDownload: Bool {
			self == .available
		}
	}

	static func downloadedSizeGB(downloadedModelIDs: String, in models: [BeaconModel]) -> Decimal {
		let downloadedIDs = Set(downloadedModelIDs.split(separator: ",").map(String.init))
		return models.reduce(Decimal(0)) { total, model in
			guard !model.isBuiltIn, downloadedIDs.contains(model.id) else { return total }
			return total + model.sizeInGB
		}
	}

	static func canDownload(_ model: BeaconModel, downloadedModelIDs: String, in models: [BeaconModel]) -> Bool {
		downloadAvailability(for: model, downloadedModelIDs: downloadedModelIDs, in: models).canDownload
	}

	static func downloadAvailability(for model: BeaconModel, downloadedModelIDs: String, in models: [BeaconModel]) -> DownloadAvailability {
		if let availability = availabilityBeforeStorageCheck(for: model, downloadedModelIDs: downloadedModelIDs, in: models) {
			return availability
		}

		return storageAvailability(for: model, availableGB: availableDeviceStorageGB())
	}

	/// Same as `downloadAvailability(for:downloadedModelIDs:in:)` but uses a prefetched
	/// device storage measurement instead of querying the volume synchronously.
	/// Pass nil for `availableGB` when the measurement failed — this keeps the
	/// conservative "not enough space" behavior.
	static func downloadAvailability(for model: BeaconModel, downloadedModelIDs: String, in models: [BeaconModel], availableGB: Double?) -> DownloadAvailability {
		if let availability = availabilityBeforeStorageCheck(for: model, downloadedModelIDs: downloadedModelIDs, in: models) {
			return availability
		}

		return storageAvailability(for: model, availableGB: availableGB)
	}

	/// Cheap checks that don't require querying the device for free storage.
	/// Returns nil when the decision depends on available device storage.
	private static func availabilityBeforeStorageCheck(for model: BeaconModel, downloadedModelIDs: String, in models: [BeaconModel]) -> DownloadAvailability? {
		guard !model.isBuiltIn else { return .available }
		let downloadedIDs = Set(downloadedModelIDs.split(separator: ",").map(String.init))
		guard !downloadedIDs.contains(model.id) else { return .available }

		guard downloadedSizeGB(downloadedModelIDs: downloadedModelIDs, in: models) + model.sizeInGB <= maxGB else {
			return .appStorageFull
		}

		return nil
	}

	private static func storageAvailability(for model: BeaconModel, availableGB: Double?) -> DownloadAvailability {
		let requiredGB = NSDecimalNumber(decimal: model.sizeInGB).doubleValue * 1.1
		guard let availableGB, availableGB >= requiredGB else {
			return .deviceStorageLow(requiredGB: requiredGB, availableGB: availableGB ?? 0)
		}

		return .available
	}

	static func formattedGB(_ value: Decimal) -> String {
		String(format: "%.1f GB", NSDecimalNumber(decimal: value).doubleValue)
	}

	static func formattedGB(_ value: Double) -> String {
		if value < 1 {
			return String(format: "%.2f GB", value)
		}

		return String(format: "%.1f GB", value)
	}

	static func availableDeviceStorageGB() -> Double? {
		guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
			let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
			let bytes = values.volumeAvailableCapacityForImportantUsage else {
			return nil
		}

		return Double(bytes) / 1_000_000_000
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
