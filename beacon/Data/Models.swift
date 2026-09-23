//
//  Models.swift
//  beacon
//
//  Created by Armond Schneider on 6/13/26.
//

import Foundation
import FoundationModels

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
	let parameterCountInBillions: Decimal?
	let updatedAt: String?

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
		supportsImages: Bool = false,
		parameterCountInBillions: Decimal? = nil,
		updatedAt: String? = nil
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
		self.parameterCountInBillions = parameterCountInBillions
		self.updatedAt = updatedAt
	}

	var formattedSize: String {
		if isBuiltIn { return "Built in" }
		return String(format: "%.2f GB", NSDecimalNumber(decimal: sizeInGB).doubleValue)
	}

	var formattedParameterCount: String? {
		guard let parameterCountInBillions else { return nil }
		return "\(String(format: "%g", NSDecimalNumber(decimal: parameterCountInBillions).doubleValue))b"
	}

	var capabilityTags: [String] {
		var tags = ["chat"]
		if supportsImages { tags.append("vision") }
		if type == .reasoning { tags.append("thinking") }
		if repositoryID.localizedCaseInsensitiveContains("coder") { tags.append("coding") }
		return tags
	}
}

enum ModelDeviceCompatibility: Equatable {
	case goodFit
	case mayBeSlow
	case unavailable(UnavailableReason)

	enum UnavailableReason: Equatable {
		case appleIntelligenceUnsupported
		case appleIntelligenceDisabled
		case appleIntelligencePreparing
		case appleIntelligenceUnavailable
		case modelTooDemanding
	}

	var canUse: Bool {
		if case .unavailable = self { return false }
		return true
	}

	var sortPriority: Int {
		switch self {
		case .goodFit: 0
		case .mayBeSlow: 1
		case .unavailable: 2
		}
	}

	var tagTitle: String {
		switch self {
		case .goodFit:
			"Works with this iPhone"
		case .mayBeSlow:
			"Reduced performance"
		case let .unavailable(reason):
			switch reason {
			case .appleIntelligenceDisabled:
				"Apple Intelligence off"
			case .appleIntelligencePreparing:
				"Model preparing"
			default:
				"Not supported"
			}
		}
	}

	var message: String? {
		switch self {
		case .goodFit:
			nil
		case .mayBeSlow:
			"This model can run on your iPhone, but responses may be slower."
		case let .unavailable(reason):
			switch reason {
			case .appleIntelligenceUnsupported:
				"Apple's built-in model isn't available on this iPhone. You can still use Beacon with one of the downloadable models below."
			case .appleIntelligenceDisabled:
				"Turn on Apple Intelligence in Settings to use this option, or choose one of the downloadable models below."
			case .appleIntelligencePreparing:
				"Apple Intelligence is still getting ready. Try again later, or choose one of the downloadable models below."
			case .appleIntelligenceUnavailable:
				"Apple's built-in model isn't available right now. Choose one of the downloadable models below."
			case .modelTooDemanding:
				"This model isn't supported on this iPhone. Choose one marked Works with this iPhone instead."
			}
		}
	}

	var systemImage: String {
		switch self {
		case .goodFit:
			"checkmark.circle.fill"
		case .mayBeSlow:
			"exclamationmark.triangle.fill"
		case let .unavailable(reason):
			switch reason {
			case .appleIntelligenceDisabled:
				"gear"
			case .appleIntelligencePreparing:
				"clock.fill"
			default:
				"iphone.slash"
			}
		}
	}

	static func current(for model: BeaconModel) -> ModelDeviceCompatibility {
		if model.isBuiltIn {
			switch SystemLanguageModel.default.availability {
			case .available:
				return .goodFit
			case let .unavailable(reason):
				switch reason {
				case .deviceNotEligible:
					return .unavailable(.appleIntelligenceUnsupported)
				case .appleIntelligenceNotEnabled:
					return .unavailable(.appleIntelligenceDisabled)
				case .modelNotReady:
					return .unavailable(.appleIntelligencePreparing)
				@unknown default:
					return .unavailable(.appleIntelligenceUnavailable)
				}
			}
		}

		let recommendedTier = DeviceTier(recommendedDevice: model.recommendedDevice)
		let currentTier = DeviceTier.current
		if currentTier.rawValue >= recommendedTier.rawValue { return .goodFit }
		if recommendedTier.rawValue - currentTier.rawValue == 1 { return .mayBeSlow }
		return .unavailable(.modelTooDemanding)
	}
}

private enum DeviceTier: Int {
	case unsupported = 0
	case iPhone13 = 1
	case iPhone14 = 2
	case iPhone14Pro = 3
	case iPhone15Pro = 4
	case iPhone16Pro = 5

	init(recommendedDevice: String) {
		if recommendedDevice.contains("16 Pro") {
			self = .iPhone16Pro
		} else if recommendedDevice.contains("15 Pro") {
			self = .iPhone15Pro
		} else if recommendedDevice.contains("14 Pro") {
			self = .iPhone14Pro
		} else if recommendedDevice.contains("14") {
			self = .iPhone14
		} else {
			self = .iPhone13
		}
	}

	static let current: DeviceTier = {
		#if targetEnvironment(simulator)
		return .iPhone16Pro
		#elseif os(iOS)
		let identifier = currentDeviceIdentifier
		guard identifier.hasPrefix("iPhone") else { return .iPhone16Pro }
		if identifier.hasPrefix("iPhone18,") || identifier.hasPrefix("iPhone17,") { return .iPhone16Pro }
		if identifier == "iPhone16,1" || identifier == "iPhone16,2" { return .iPhone15Pro }
		if identifier == "iPhone15,2" || identifier == "iPhone15,3" || identifier == "iPhone16,3" || identifier == "iPhone16,4" { return .iPhone14Pro }
		if identifier == "iPhone14,2" || identifier == "iPhone14,3" || identifier == "iPhone14,7" || identifier == "iPhone14,8" || identifier == "iPhone15,4" || identifier == "iPhone15,5" { return .iPhone14 }
		if identifier.hasPrefix("iPhone14,") { return .iPhone13 }
		return .unsupported
		#else
		return .iPhone16Pro
		#endif
	}()

	private static var currentDeviceIdentifier: String {
		var systemInfo = utsname()
		uname(&systemInfo)
		let mirror = Mirror(reflecting: systemInfo.machine)
		return mirror.children.reduce(into: "") { identifier, element in
			guard let value = element.value as? Int8, value != 0 else { return }
			identifier.append(Character(UnicodeScalar(UInt8(value))))
		}
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

	static func requiredOnboardingModels(in models: [BeaconModel]) -> [BeaconModel] {
		let requiredIDs = ["beacon"]
		return requiredIDs.compactMap { id in models.first { $0.id == id } }
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
	private static let migrationKey = "hasMigratedBeaconModelIDsV3"
	private static let modelIDMigrationMap = [
		"semera-lite": "beacon",
		"semera-plus": "beacon",
		"semera-llama32-1b": "beacon",
		"semera-qwen25-3b-instruct": "beacon",
		"semera-llama32-3b": "beacon",
		"qwen3-0.6b-4bit": "beacon",
		"lfm2-1.2b-4bit": "beacon",
		"qwen2-vl-2b-instruct-4bit": "beacon",
		"llama-3.2-1b-instruct-4bit": "beacon",
		"qwen2.5-3b-instruct-4bit": "beacon",
		"llama-3.2-3b-instruct-4bit": "beacon"
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
