//
//  ModelMarketPlaceView.swift
//  beacon
//
//  Created by Armond Schneider on 6/14/26.
//

import SwiftUI

struct ModelMarketPlaceView: View {
	let models: [BeaconModel]
	var onClose: () -> Void = { }
	var onDownload: (BeaconModel) -> Void = { _ in }
	var onSelect: (BeaconModel) -> Void = { _ in }

	@AppStorage("selectedModelID") private var selectedModelID = ""
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@StateObject private var safariViewModel = SafariViewModel()
	@State private var deletingModelID: String?
	@State private var deleteErrorMessage: String?
	@State private var selectedDeleteWarningModelName: String?
	@State private var switchedModelName: String?
	@State private var modelSwitchToastTask: Task<Void, Never>?
	@State private var selectedCompany = ModelCompanyFilter.all
	@State private var availableStorageGB: Double?
	@State private var hasMeasuredAvailableStorage = false
	private var catalogModels: [BeaconModel] {
		models
	}

	private var companyFilters: [String] {
		[ModelCompanyFilter.all] + Array(Set(catalogModels.map(\.company))).sorted()
	}

	private var filteredModels: [BeaconModel] {
		guard selectedCompany != ModelCompanyFilter.all else { return catalogModels }
		return catalogModels.filter { $0.company == selectedCompany }
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 28) {
					Text("Download, delete and learn more about the local models you use.")
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)

					if let deleteErrorMessage {
						Text(deleteErrorMessage)
							.font(.system(size: 14, weight: .regular))
							.foregroundStyle(.red)
							.padding(16)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
					}

					ModelCompanyFilterTabs(
						companies: companyFilters,
						selection: $selectedCompany
					) {
						ModelMarketPlaceList(
							models: filteredModels,
							selectedModelID: selectedModelID,
							deletingModelID: deletingModelID,
							isDownloaded: isDownloaded,
							downloadAvailability: downloadAvailability,
							onDownload: onDownload,
							onSelect: { model in
								selectedModelID = model.id
								onSelect(model)
								showModelSwitchToast(for: model.name)
							},
							onDelete: delete,
							onOpenLink: { model in
								safariViewModel.open(model.huggingFaceURL)
							}
						)
					}
				}
				.padding(.horizontal, 20)
				.padding(.bottom, 96)
			}
			.scrollEdgeEffectStyle(.soft, for: .top)
			.navigationTitle("Model Marketplace")
			#if !os(macOS)
			.navigationBarTitleDisplayMode(.large)
			.toolbarVisibility(.visible, for: .navigationBar)
			#endif
			.toolbar {
				#if os(macOS)
				ToolbarItem(placement: .automatic) {
					closeButton
				}
				#else
				ToolbarItem(placement: .topBarTrailing) {
					closeButton
				}
				#endif
			}
		}
		.background(Color(uiColor: .systemBackground))
		.overlay(alignment: .bottom) {
			if let switchedModelName {
				ModelSwitchToast(modelName: switchedModelName)
					.padding(.bottom, 34)
					.transition(.opacity.combined(with: .scale(scale: 0.96)))
			}
		}
		.sheet(item: $safariViewModel.page) { page in
			SafariView(url: page.url)
				.ignoresSafeArea()
		}
		.alert("Switch models first", isPresented: selectedDeleteWarningBinding) {
			Button("OK") { }
		} message: {
			Text("\(selectedDeleteWarningModelName ?? "This model") is currently active. Choose another downloaded model before deleting it.")
		}
		.task {
			await measureAvailableStorage()
		}
		.onDisappear {
			modelSwitchToastTask?.cancel()
		}
	}

	private var selectedDeleteWarningBinding: Binding<Bool> {
		Binding(
			get: { selectedDeleteWarningModelName != nil },
			set: { isPresented in
				if !isPresented {
					selectedDeleteWarningModelName = nil
				}
			}
		)
	}

	private var closeButton: some View {
		Button(action: onClose) {
			Image(systemName: "xmark")
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(.black)
				.frame(width: 34, height: 34)
		}
		.buttonStyle(.plain)
	}

	private var downloadedIDs: Set<String> {
		Set(downloadedModelIDs.split(separator: ",").map(String.init))
	}

	private func isDownloaded(_ model: BeaconModel) -> Bool {
		if model.isBuiltIn { return true }
		return downloadedIDs.contains(model.id)
	}

	/// Advisory per-row availability. Until the storage measurement lands, rows
	/// present as downloadable — `ContentView.prepare(_:)` re-checks availability
	/// synchronously when the user actually taps Download.
	private func downloadAvailability(for model: BeaconModel) -> ModelStorageLimit.DownloadAvailability {
		guard hasMeasuredAvailableStorage else { return .available }
		return ModelStorageLimit.downloadAvailability(
			for: model,
			downloadedModelIDs: downloadedModelIDs,
			in: catalogModels,
			availableGB: availableStorageGB
		)
	}

	/// Measures free device storage off the main actor. Querying
	/// `volumeAvailableCapacityForImportantUsageKey` can be slow, so it must not
	/// run inside `body` — let alone once per row.
	@MainActor
	private func measureAvailableStorage() async {
		let measured = await Task.detached(priority: .userInitiated) {
			ModelStorageLimit.availableDeviceStorageGB()
		}.value
		availableStorageGB = measured
		hasMeasuredAvailableStorage = true
	}

	private func delete(_ model: BeaconModel) {
		guard !model.isBuiltIn else { return }
		guard selectedModelID != model.id else {
			selectedDeleteWarningModelName = model.name
			return
		}

		deleteErrorMessage = nil
		deletingModelID = model.id

		defer { deletingModelID = nil }

		do {
			let fileManager = FileManager.default
			let cacheURL = cacheDirectory(for: model)
			let metadataURL = metadataDirectory(for: model)
			let lockURL = lockDirectory(for: model)

			if fileManager.fileExists(atPath: cacheURL.path) {
				try fileManager.removeItem(at: cacheURL)
			}

			if fileManager.fileExists(atPath: metadataURL.path) {
				try fileManager.removeItem(at: metadataURL)
			}

			if fileManager.fileExists(atPath: lockURL.path) {
				try fileManager.removeItem(at: lockURL)
			}

			var ids = downloadedIDs
			ids.remove(model.id)
			downloadedModelIDs = ids.sorted().joined(separator: ",")

			if selectedModelID == model.id {
				selectedModelID = ""
			}

			// Deleting freed space — refresh the cached measurement so rows
			// don't keep showing stale "Not Enough Space" states.
			Task { await measureAvailableStorage() }
		} catch {
			deleteErrorMessage = "Could not delete \(model.name): \(error.localizedDescription)"
		}
	}

	private func showModelSwitchToast(for modelName: String) {
		modelSwitchToastTask?.cancel()
		withAnimation(.smooth(duration: 0.2)) {
			switchedModelName = modelName
		}

		modelSwitchToastTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(1.8))
			withAnimation(.smooth(duration: 0.2)) {
				switchedModelName = nil
			}
		}
	}

	private func cacheDirectory(for model: BeaconModel) -> URL {
		huggingFaceHubCacheDirectory.appendingPathComponent(cacheDirectoryName(for: model))
	}

	private func metadataDirectory(for model: BeaconModel) -> URL {
		huggingFaceHubCacheDirectory
			.appendingPathComponent(".metadata")
			.appendingPathComponent(cacheDirectoryName(for: model))
	}

	private func lockDirectory(for model: BeaconModel) -> URL {
		huggingFaceHubCacheDirectory
			.appendingPathComponent(".locks")
			.appendingPathComponent(cacheDirectoryName(for: model))
	}

	private func cacheDirectoryName(for model: BeaconModel) -> String {
		"models--\(model.repositoryID.replacingOccurrences(of: "/", with: "--"))"
	}

	private var huggingFaceHubCacheDirectory: URL {
		FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("huggingface")
			.appendingPathComponent("hub")
	}
}

private enum ModelCompanyFilter {
	static let all = "All"
}

private struct ModelCompanyFilterTabs<Content: View>: View {
	let companies: [String]
	@Binding var selection: String
	@ViewBuilder var content: () -> Content

	var body: some View {
		Tabs(options: companies, selection: $selection, size: .small, horizontalScrollOverflow: 20) { _ in
			content()
		}
	}
}

private struct ModelMarketPlaceList: View {
	let models: [BeaconModel]
	let selectedModelID: String
	let deletingModelID: String?
	var isDownloaded: (BeaconModel) -> Bool
	var downloadAvailability: (BeaconModel) -> ModelStorageLimit.DownloadAvailability
	var onDownload: (BeaconModel) -> Void
	var onSelect: (BeaconModel) -> Void
	var onDelete: (BeaconModel) -> Void
	var onOpenLink: (BeaconModel) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
				ModelMarketPlaceRow(
					model: model,
					isDownloaded: isDownloaded(model),
					isSelected: selectedModelID == model.id,
					isDeleting: deletingModelID == model.id,
					downloadAvailability: downloadAvailability(model),
					onDownload: {
						onDownload(model)
					},
					onSelect: {
						onSelect(model)
					},
					onDelete: {
						onDelete(model)
					},
					onOpenLink: {
						onOpenLink(model)
					}
				)

				if index < models.count - 1 {
					Divider()
						.padding(.vertical, 20)
				}
			}
		}
	}
}

private extension BeaconModel {
	var company: String {
		let searchableText = "\(name) \(repositoryID)".lowercased()

		if searchableText.contains("deepseek") { return "DeepSeek" }
		if searchableText.contains("apple") { return "Apple" }
		if searchableText.contains("openelm") { return "Apple" }
		if searchableText.contains("qwen") { return "Alibaba" }
		if searchableText.contains("lfm") || searchableText.contains("liquid") { return "Liquid AI" }
		if searchableText.contains("llama") { return "Meta" }
		if searchableText.contains("gemma") { return "Google" }
		if searchableText.contains("phi") { return "Microsoft" }
		if searchableText.contains("mistral") || searchableText.contains("ministral") { return "Mistral AI" }
		if searchableText.contains("granite") { return "IBM" }
		if searchableText.contains("stablelm") { return "Stability AI" }
		if searchableText.contains("smollm") { return "Hugging Face" }
		if searchableText.contains("olmo") { return "Allen Institute" }
		if searchableText.contains("yi-") { return "01.AI" }
		if searchableText.contains("glm") { return "Zhipu" }
		if searchableText.contains("minicpm") { return "OpenBMB" }

		return repositoryID.split(separator: "/").first.map(String.init) ?? "Other"
	}
}

private struct ModelMarketPlaceRow: View {
	let model: BeaconModel
	let isDownloaded: Bool
	let isSelected: Bool
	let isDeleting: Bool
	let downloadAvailability: ModelStorageLimit.DownloadAvailability
	var showsDownloadInProgress = false
	var onDownload: () -> Void
	var onSelect: () -> Void
	var onDelete: () -> Void
	var onOpenLink: () -> Void

	@State private var isDownloading: Bool

	init(
		model: BeaconModel,
		isDownloaded: Bool,
		isSelected: Bool,
		isDeleting: Bool,
		downloadAvailability: ModelStorageLimit.DownloadAvailability = .available,
		showsDownloadInProgress: Bool = false,
		onDownload: @escaping () -> Void,
		onSelect: @escaping () -> Void = { },
		onDelete: @escaping () -> Void,
		onOpenLink: @escaping () -> Void = { }
	) {
		self.model = model
		self.isDownloaded = isDownloaded
		self.isSelected = isSelected
		self.isDeleting = isDeleting
		self.downloadAvailability = downloadAvailability
		self.showsDownloadInProgress = showsDownloadInProgress
		self.onDownload = onDownload
		self.onSelect = onSelect
		self.onDelete = onDelete
		self.onOpenLink = onOpenLink
		self._isDownloading = State(initialValue: showsDownloadInProgress)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			VStack(alignment: .leading, spacing: 12) {
				Text(model.name)
					.font(.system(size: 18, weight: .medium))
					.foregroundStyle(.primary)

				Text(descriptionText)
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(.secondary)
					.lineSpacing(3)
			}

			HStack(spacing: 12) {
				Tag(title: model.formattedSize, color: .indigo)

				if model.type == .reasoning {
					Tag(title: "reasoning", color: .orange)
				} else {
					Tag(title: "chat", color: .gray)
				}

				if model.supportsImages {
					Tag(title: "vision", color: .indigo)
				}

				if deviceCompatibility.showsTag {
					Tag(title: deviceCompatibility.tagTitle, color: deviceCompatibility.tint)
				}
			}

			if let compatibilityMessage = deviceCompatibility.message {
				Label(compatibilityMessage, systemImage: deviceCompatibility.systemImage)
					.font(.system(size: 13, weight: .regular))
					.foregroundStyle(deviceCompatibility.tint)
			}

			VStack(alignment: .leading, spacing: 14) {
				HStack(spacing: 10) {
					if isDownloaded {
						if model.isBuiltIn {
							DownloadedModelButton(title: "Built in")
						} else {
							BeaconButton(isDeleting ? "Deleting" : "Delete", variant: .destructive, size: .small, trailingAssetIcon: "trash.icon", isLoading: isDeleting) {
								onDelete()
							}
						}
					} else {
						BeaconButton(downloadButtonTitle, variant: .secondary, size: .small, trailingAssetIcon: "download.icon", isDisabled: !downloadAvailability.canDownload, isLoading: isDownloading) {
							isDownloading = true
							onDownload()
						}
					}

					if !model.isBuiltIn {
						BeaconButton("View on Hugging Face", variant: .subtle, size: .small, trailingIcon: "arrow.up.right") {
							onOpenLink()
						}
					}
				}

				if isDownloaded {
					VStack(alignment: .leading, spacing: 10) {
						HStack(spacing: 10) {
							if !isSelected {
								BeaconButton("Use", variant: .secondary, size: .small) {
									onSelect()
								}
							}
						}

					}
				}

				if !isDownloaded, let unavailableMessage = downloadUnavailableMessage {
					Text(unavailableMessage)
						.font(.system(size: 14, weight: .regular))
						.foregroundStyle(.secondary)
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var descriptionText: String {
		let trimmedDescription = model.description.trimmingCharacters(in: .whitespacesAndNewlines)
		let recommendation = "Recommended for \(model.recommendedDevice)."

		if trimmedDescription.hasSuffix(".") {
			return "\(trimmedDescription) \(recommendation)"
		}

		return "\(trimmedDescription). \(recommendation)"
	}

	private var downloadButtonTitle: String {
		switch downloadAvailability {
		case .available:
			"Download"
		case .appStorageFull:
			"Storage Full"
		case .deviceStorageLow:
			"Not Enough Space"
		}
	}

	private var downloadUnavailableMessage: String? {
		switch downloadAvailability {
		case .available:
			nil
		case .appStorageFull:
			"Delete a downloaded model to free up Beacon's 10 GB model storage limit."
		case let .deviceStorageLow(requiredGB, availableGB):
			"Requires about \(ModelStorageLimit.formattedGB(requiredGB)) free. You have \(ModelStorageLimit.formattedGB(availableGB)) available."
		}
	}

	private var deviceCompatibility: ModelDeviceCompatibility {
		ModelDeviceCompatibility(recommendedDevice: model.recommendedDevice)
	}
}

private struct ModelDeviceCompatibility {
	let recommendedDevice: String

	var showsTag: Bool {
		status != .compatible
	}

	var tagTitle: String {
		switch status {
		case .compatible:
			"compatible"
		case .belowRecommended:
			"may run slowly"
		case .likelyIncompatible:
			"high-end"
		}
	}

	var message: String? {
		switch status {
		case .compatible:
			nil
		case .belowRecommended:
			"Optimized for \(recommendedDevice) - may run slowly on this device."
		case .likelyIncompatible:
			"Requires \(recommendedDevice) for best results."
		}
	}

	var tint: Color {
		switch status {
		case .compatible:
			.green
		case .belowRecommended:
			.orange
		case .likelyIncompatible:
			.gray
		}
	}

	var systemImage: String {
		switch status {
		case .compatible:
			"checkmark.circle.fill"
		case .belowRecommended:
			"exclamationmark.triangle.fill"
		case .likelyIncompatible:
			"iphone.slash"
		}
	}

	private var status: Status {
		let recommendedTier = DeviceTier(recommendedDevice: recommendedDevice)
		let currentTier = DeviceTier.current
		if currentTier.rawValue >= recommendedTier.rawValue { return .compatible }
		if recommendedTier.rawValue - currentTier.rawValue <= 1 { return .belowRecommended }
		return .likelyIncompatible
	}

	private enum Status {
		case compatible
		case belowRecommended
		case likelyIncompatible
	}
}

private enum DeviceTier: Int {
	case appleIntelligence = 0
	case iPhone13 = 1
	case iPhone14 = 2
	case iPhone14Pro = 3
	case iPhone15Pro = 4
	case iPhone16Pro = 5

	init(recommendedDevice: String) {
		if recommendedDevice.contains("16 Pro") {
			self = .iPhone16Pro
		} else if recommendedDevice.contains("15 Pro") || recommendedDevice.contains("15 Pro Max") {
			self = .iPhone15Pro
		} else if recommendedDevice.contains("14 Pro") {
			self = .iPhone14Pro
		} else if recommendedDevice.contains("14") {
			self = .iPhone14
		} else if recommendedDevice.contains("13") {
			self = .iPhone13
		} else {
			self = .appleIntelligence
		}
	}

	static let current: DeviceTier = {
		#if targetEnvironment(simulator)
		return .iPhone16Pro
		#else
		#if canImport(UIKit)
		let identifier = currentDeviceIdentifier
		if identifier.hasPrefix("iPhone17,") { return .iPhone16Pro }
		if identifier == "iPhone16,1" || identifier == "iPhone16,2" { return .iPhone15Pro }
		if identifier == "iPhone15,2" || identifier == "iPhone15,3" { return .iPhone14Pro }
		if identifier.hasPrefix("iPhone15,") { return .iPhone14 }
		if identifier.hasPrefix("iPhone14,") { return .iPhone13 }
		#endif
		return .iPhone13
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

private struct DownloadedModelButton: View {
	var title = "Downloaded"

	var body: some View {
		HStack(spacing: 8) {
			Text(title)
				.font(.system(size: 14, weight: .semibold))

			Image(systemName: "checkmark")
				.font(.system(size: 14, weight: .bold))
		}
		.foregroundStyle(Color(uiColor: .systemGreen))
		.padding(.horizontal, 14)
		.frame(minHeight: 34)
		.background(Color(uiColor: .systemGreen).opacity(0.14), in: Capsule())
	}
}

private extension BeaconModel {
	var huggingFaceURL: URL {
		URL(string: "https://huggingface.co/\(repositoryID)")!
	}
}

#Preview("Marketplace") {
	ModelMarketPlaceView(models: ModelCatalog.availableModels)
}

#Preview("Available Model") {
	ModelMarketPlaceRow(
		model: ModelCatalog.availableModels[0],
		isDownloaded: false,
		isSelected: false,
		isDeleting: false,
		onDownload: { },
		onDelete: { }
	)
	.padding(20)
	.background(Color(uiColor: .systemBackground))
}

#Preview("Downloaded Model") {
	ModelMarketPlaceRow(
		model: ModelCatalog.availableModels[0],
		isDownloaded: true,
		isSelected: false,
		isDeleting: false,
		onDownload: { },
		onDelete: { }
	)
	.padding(20)
	.background(Color(uiColor: .systemBackground))
}

#Preview("Deleting Model") {
	ModelMarketPlaceRow(
		model: ModelCatalog.availableModels[0],
		isDownloaded: true,
		isSelected: false,
		isDeleting: true,
		onDownload: { },
		onDelete: { }
	)
	.padding(20)
	.background(Color(uiColor: .systemBackground))
}

#Preview("Active Downloaded Model") {
	ModelMarketPlaceRow(
		model: ModelCatalog.availableModels[0],
		isDownloaded: true,
		isSelected: true,
		isDeleting: false,
		onDownload: { },
		onDelete: { }
	)
	.padding(20)
	.background(Color(uiColor: .systemBackground))
}
