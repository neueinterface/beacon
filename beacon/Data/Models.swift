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

	enum OnboardingRole: String, Decodable {
		case chatLight
		case chatCore
		case vision
		case thinker

		var title: String {
			switch self {
			case .chatLight: "Chat Light"
			case .chatCore: "Chat Core"
			case .vision: "Vision"
			case .thinker: "Thinker"
			}
		}

		var systemImage: String {
			switch self {
			case .chatLight: "bolt.fill"
			case .chatCore: "bubble.left.and.bubble.right.fill"
			case .vision: "eye.fill"
			case .thinker: "sparkles"
			}
		}

		var isOptional: Bool {
			self == .thinker
		}
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
	let bestFor: String?
	let onboardingRole: OnboardingRole?

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
		updatedAt: String? = nil,
		bestFor: String? = nil,
		onboardingRole: OnboardingRole? = nil
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
		self.bestFor = bestFor
		self.onboardingRole = onboardingRole
	}

	var onboardingName: String {
		onboardingRole?.title ?? name
	}

	/// Presentation only: repository IDs and persisted model IDs stay unchanged.
	var assistantName: String {
		switch id {
		case "qwen3-0.6b", "qwen3-1.7b", "qwen3-4b-instruct-2507": "Beacon Chat"
		case "deepseek-r1-distill-qwen-1.5b": "Beacon Think"
		case "smolvlm2-500m", "qwen2-vl-2b": "Beacon Vision"
		default: name
		}
	}

	var assistantDescription: String {
		switch assistantName {
		case "Beacon Chat": "Your everyday assistant for questions, writing, summaries, and planning."
		case "Beacon Think": "Take more time with math, logic, and multi-step problems."
		case "Beacon Vision": "Ask questions about photos, describe scenes, and read visible text."
		default: description
		}
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
			"This model may run slowly or exceed available memory. You can still download it; try a smaller model if it cannot run."
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

		return localModel(model, physicalMemoryGB: DeviceMemory.physicalMemoryGB)
	}

	/// Estimates are advisory, not a guarantee of runtime memory availability.
	/// Reserve half of physical RAM for iOS, Beacon, and other processes. Include
	/// overhead for activations/KV cache and the image encoder, not just weights.
	static func localModel(_ model: BeaconModel, physicalMemoryGB: Double) -> ModelDeviceCompatibility {
		let weightsGB = NSDecimalNumber(decimal: model.sizeInGB).doubleValue
		let estimatedWorkingMemoryGB = weightsGB * 1.5 + (model.supportsImages ? 1.25 : 0.5)
		return estimatedWorkingMemoryGB <= physicalMemoryGB * 0.5 ? .goodFit : .mayBeSlow
	}
}

enum DeviceMemory {
	static let physicalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
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

	static func coreOnboardingModels(
		in models: [BeaconModel],
		compatibility: (BeaconModel) -> ModelDeviceCompatibility = { ModelDeviceCompatibility.current(for: $0) }
	) -> [BeaconModel] {
		func bestFit(_ ids: [String]) -> BeaconModel? {
			ids.compactMap { id in models.first { $0.id == id } }
				.first { compatibility($0) == .goodFit }
		}
		let light = bestFit(["qwen3-0.6b"])
		let chat = bestFit(["qwen3-4b-instruct-2507", "qwen3-1.7b", "qwen3-0.6b"])
		let vision = bestFit(["qwen2-vl-2b", "smolvlm2-500m"])
		var seen = Set<String>()
		return [light, chat, vision].compactMap { $0 }.filter { seen.insert($0.id).inserted }
	}

	static func optionalOnboardingModels(in models: [BeaconModel]) -> [BeaconModel] {
		onboardingModels(in: models).filter { $0.onboardingRole?.isOptional == true }
	}

	/// Keep every supported model browsable, even when it isn't recommended.
	static func marketplaceModels(
		in models: [BeaconModel],
		compatibility: (BeaconModel) -> ModelDeviceCompatibility = { ModelDeviceCompatibility.current(for: $0) }
	) -> [BeaconModel] {
		return models.enumerated().sorted { lhs, rhs in
			let left = compatibility(lhs.element).sortPriority
			let right = compatibility(rhs.element).sortPriority
			return left == right ? lhs.offset < rhs.offset : left < right
		}
		.map(\.element)
	}

	static func defaultModel(in models: [BeaconModel]) -> BeaconModel {
		primaryChatModel(in: coreOnboardingModels(in: models))
			?? coreOnboardingModels(in: models).first
			?? onboardingModels(in: models).first
			?? models.first
			?? availableModels[0]
	}

	static func primaryChatModel(in models: [BeaconModel]) -> BeaconModel? {
		["qwen3-4b-instruct-2507", "qwen3-1.7b", "qwen3-0.6b"]
			.compactMap { id in models.first { $0.id == id } }.first
			?? models.first { !$0.supportsImages && $0.type == .regular && !$0.isBuiltIn }
	}

	static func model(id: String, in models: [BeaconModel]) -> BeaconModel? {
		models.first { $0.id == id }
	}
}

enum ModelMarketplaceCategory: Hashable {
	case chatCore
	case recommended
	case company(String)

	var title: String {
		switch self {
		case .chatCore: "Chat Core"
		case .recommended: "Recommended models"
		case let .company(name): name
		}
	}

	static func options(in models: [BeaconModel]) -> [Self] {
		[.chatCore, .recommended] + Set(models.map(\.company)).sorted().map { .company($0) }
	}

	func models(
		in catalog: [BeaconModel],
		compatibility: (BeaconModel) -> ModelDeviceCompatibility = { ModelDeviceCompatibility.current(for: $0) }
	) -> [BeaconModel] {
		switch self {
		case .chatCore:
			ModelCatalog.coreOnboardingModels(in: catalog, compatibility: compatibility)
		case .recommended:
			ModelCatalog.marketplaceModels(in: catalog, compatibility: compatibility)
				.filter { compatibility($0) == .goodFit }
		case let .company(name):
			ModelCatalog.marketplaceModels(in: catalog, compatibility: compatibility)
				.filter { $0.company == name }
		}
	}
}

enum BeaconModelRouter {
	private static let reasoningSignals = [
		"step by step", "think through", "reason", "logic", "proof", "prove", "calculate",
		"equation", "math", "solve", "compare", "analyze", "analysis", "tradeoff", "trade-off"
	]
	private static let lightSignals = [
		"quick", "brief", "short answer", "in one sentence", "summarize", "summary", "rewrite", "fix the grammar"
	]
	private static let coreSignals = [
		"write", "draft", "plan", "explain", "why", "compare", "analyze", "analysis", "code", "debug",
		"detailed", "thorough", "deep", "complex", "multi-step", "research"
	]

	static func route(
		text: String,
		hasImages: Bool,
		in models: [BeaconModel],
		downloadedIDs: Set<String>,
		preferredModelID: String? = nil,
		compatibility: (BeaconModel) -> ModelDeviceCompatibility = { ModelDeviceCompatibility.current(for: $0) }
	) -> BeaconModel {
		let available = models.filter { model in
			(model.isBuiltIn || downloadedIDs.contains(model.id)) && compatibility(model).canUse
		}

		// Manual mode pins the answering model. Text-only models can still use
		// the existing vision bridge without changing the user's selection.
		if let preferredModelID, let selected = available.first(where: { $0.id == preferredModelID }) {
			return selected
		}

		if hasImages, let vision = available.first(where: \.supportsImages) {
			return vision
		}

		let request = text.localizedLowercase
		if containsAny(reasoningSignals, in: request),
			let thinker = available.first(where: { $0.onboardingRole == .thinker || $0.assistantName == "Beacon Think" }) {
			return thinker
		}

		if shouldPreferLight(request),
			let light = available.first(where: { $0.onboardingRole == .chatLight }) {
			return light
		}

		return preferredChatModel(in: available)
			?? available.first
			?? preferredChatModel(in: models)
			?? models.first
			?? ModelCatalog.defaultModel
	}

	private static func preferredChatModel(in models: [BeaconModel]) -> BeaconModel? {
		let preferredIDs = ["qwen3-4b-instruct-2507", "qwen3-1.7b", "qwen3-0.6b"]
		return preferredIDs.compactMap { id in models.first(where: { $0.id == id }) }.first
			?? models.first(where: { $0.onboardingRole == .chatCore || $0.assistantName == "Beacon Chat" })
	}

	private static func containsAny(_ signals: [String], in text: String) -> Bool {
		signals.contains { text.contains($0) }
	}

	private static func shouldPreferLight(_ text: String) -> Bool {
		if containsAny(lightSignals, in: text) { return true }
		let wordCount = text.split { !$0.isLetter && !$0.isNumber }.count
		return wordCount <= 30 && !containsAny(coreSignals, in: text)
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

	nonisolated static func availableDeviceStorageGB() -> Double? {
		guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
			let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
			let bytes = values.volumeAvailableCapacityForImportantUsage else {
			return nil
		}

		return Double(bytes) / 1_000_000_000
	}
}

enum DownloadedModelStorage {
	static var defaultHubDirectory: URL {
		FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("huggingface")
			.appendingPathComponent("hub")
	}

	static func cacheURLs(for model: BeaconModel, hubDirectory: URL = defaultHubDirectory) -> [URL] {
		let name = "models--\(model.repositoryID.replacingOccurrences(of: "/", with: "--"))"
		return [
			hubDirectory.appendingPathComponent(name),
			hubDirectory.appendingPathComponent(".metadata").appendingPathComponent(name),
			hubDirectory.appendingPathComponent(".locks").appendingPathComponent(name)
		]
	}

	static func delete(_ models: [BeaconModel], fileManager: FileManager = .default, hubDirectory: URL = defaultHubDirectory) throws {
		for model in models {
			for url in cacheURLs(for: model, hubDirectory: hubDirectory) where fileManager.fileExists(atPath: url.path) {
				try fileManager.removeItem(at: url)
			}
		}
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
