//
//  ContentView.swift
//  beacon
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI
import StoreKit

struct ContentView: View {
	@Environment(\.requestReview) private var requestReview
	@AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
	@AppStorage("selectedModelID") private var selectedModelID = ""
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@AppStorage("hasSeenModelRoutingUpdate") private var hasSeenModelRoutingUpdate = false
	@AppStorage("lastSeenWhatsNewRelease") private var lastSeenAttentionID = ""
	@ObservedObject private var modelRuntime: BeaconModelRuntime
	@StateObject private var memoryStore = MemoryStore()
	private let models = ModelCatalog.availableModels
	@State private var isChoosingModel = false
	@State private var isShowingModelMarketplace = false
	@State private var downloadingModel: BeaconModel?
	@State private var isOnboardingSetup = false
	@State private var onboardingDownloadQueue: [BeaconModel] = []
	@State private var onboardingDownloadModels: [BeaconModel] = []
	@State private var onboardingCompletedDownloadGB = 0.0
	@State private var onboardingPrimaryModel: BeaconModel?
	@State private var downloadAlert: DownloadAlert?
	@State private var isShowingModelRoutingUpdate = false
	@State private var isShowingAttention = false
	@ObservedObject private var notificationRouter: NotificationRouter

	init(modelRuntime: BeaconModelRuntime, notificationRouter: NotificationRouter) {
		self.modelRuntime = modelRuntime
		self.notificationRouter = notificationRouter
	}

	var body: some View {
		Group {
			if let downloadingModel {
				ModelDownloadView(
					model: downloadingModel,
					runtime: modelRuntime,
					downloadTitle: isOnboardingSetup ? "Chat Core" : nil,
					bundleModels: isOnboardingSetup ? onboardingDownloadModels : nil,
					completedBundleModelCount: max(0, onboardingDownloadModels.count - onboardingDownloadQueue.count),
					completedBundleDownloadGB: onboardingCompletedDownloadGB,
						onComplete: {
						if isOnboardingSetup {
							onboardingCompletedDownloadGB += modelRuntime.totalUnitCount.map { Double($0) / 1_000_000_000 }
								?? NSDecimalNumber(decimal: downloadingModel.sizeInGB).doubleValue
							recordDownloaded(downloadingModel)
						recordModelDownload(downloadingModel)

						if let nextModel = onboardingDownloadQueue.dropFirst().first {
							onboardingDownloadQueue.removeFirst()
							self.downloadingModel = nil
							Task { @MainActor in
								await Task.yield()
								guard isOnboardingSetup else { return }
								self.downloadingModel = nextModel
							}
						} else {
							onboardingDownloadQueue.removeAll()
							onboardingDownloadModels.removeAll()
							onboardingCompletedDownloadGB = 0
							downloadAlert = .completed(onboardingPrimaryModel?.onboardingName ?? downloadingModel.onboardingName)
							finishOnboarding(with: onboardingPrimaryModel ?? downloadingModel)
						}
					} else {
						downloadAlert = .completed(downloadingModel.name)
						recordModelDownload(downloadingModel)
						select(downloadingModel)
					}
					}, onCancel: {
					cancelDownload(for: downloadingModel)
						downloadAlert = .cancelled(isOnboardingSetup ? "Chat Core" : downloadingModel.name)
						isOnboardingSetup = false
						onboardingDownloadQueue.removeAll()
						onboardingDownloadModels.removeAll()
						onboardingCompletedDownloadGB = 0
						self.downloadingModel = nil
					}, onError: { message in
						downloadAlert = .failed(isOnboardingSetup ? "Chat Core" : downloadingModel.name, message)
					}
				)
				.id(downloadingModel.id)
			} else if hasCompletedWelcome {
				ChatView(
					runtime: modelRuntime,
					memoryStore: memoryStore,
					models: models,
					onDownloadModel: prepare,
					notificationRouter: notificationRouter
				)
			} else if isShowingModelMarketplace {
				ModelMarketPlaceView(
					models: models,
					isOnboarding: true,
					onClose: { isShowingModelMarketplace = false },
					onDownload: prepare,
					onSelect: select
				)
			} else if isChoosingModel {
				WelcomeModelSelectView(
					models: ModelCatalog.coreOnboardingModels(in: models),
					onDownloadModels: prepareOnboardingModels,
					onChooseLater: completeOnboardingLater,
					onBack: { isChoosingModel = false }
				)
			} else {
				WelcomeView(onNewToLocalModels: {
					isChoosingModel = true
				}, onUsedLocalModels: {
					isShowingModelMarketplace = true
				})
			}
		}
		.overlay {
			if isShowingModelRoutingUpdate {
				ModelRoutingUpdateOverlay(
					onKeepModels: dismissModelRoutingUpdate,
					onReplaceModels: replaceModelsWithBundle
				)
			}
		}
		.alert(item: $downloadAlert) { alert in
			Alert(
				title: Text(alert.title),
				message: Text(alert.message),
				dismissButton: .default(Text("OK"))
			)
		}
		.sheet(isPresented: $isShowingAttention, onDismiss: markAttentionSeen) {
			if let attention = AttentionContent.current {
				AttentionView(
					content: attention,
					onClose: { isShowingAttention = false },
					onAction: { action in
						switch action.kind {
						case .requestReview:
							isShowingAttention = false
							Task { @MainActor in
								try? await Task.sleep(for: .milliseconds(350))
								requestReview()
							}
						}
					}
				)
			}
		}
		.onChange(of: notificationRouter.quickActionToOpen) { _, action in
			if action != nil {
				isShowingAttention = false
			}
		}
		.task {
			ModelIDMigration.migrate()
			guard hasCompletedWelcome, notificationRouter.quickActionToOpen == nil else { return }
			if !hasSeenModelRoutingUpdate, !downloadedModelIDs.isEmpty {
				withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
					isShowingModelRoutingUpdate = true
				}
				return
			} else if !hasSeenModelRoutingUpdate {
				hasSeenModelRoutingUpdate = true
			}
			presentAttentionIfNeeded()
		}
	}

	private func presentAttentionIfNeeded() {
		guard let attention = AttentionContent.current, lastSeenAttentionID != attention.id else { return }
		isShowingAttention = true
	}

	private func markAttentionSeen() {
		guard let attention = AttentionContent.current else { return }
		lastSeenAttentionID = attention.id
	}

	private func recordDownloaded(_ model: BeaconModel) {
		var ids = Set(downloadedModelIDs.split(separator: ",").map(String.init))
		ids.insert(model.id)
		downloadedModelIDs = ids.sorted().joined(separator: ",")
	}

	private func removeDownloaded(_ model: BeaconModel) {
		var ids = Set(downloadedModelIDs.split(separator: ",").map(String.init))
		ids.remove(model.id)
		downloadedModelIDs = ids.sorted().joined(separator: ",")
	}

	private func prepare(_ model: BeaconModel) {
		let compatibility = ModelDeviceCompatibility.current(for: model)
		guard compatibility.canUse else {
			downloadAlert = .unavailable(model.name, compatibility.message ?? "Choose a model marked Works with this iPhone instead.")
			return
		}

		if model.isBuiltIn {
			select(model)
		} else {
			switch ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: downloadedModelIDs, in: models) {
			case .available:
				break
			case .appStorageFull:
				downloadAlert = .failed(model.name, "Delete a downloaded model to free up Beacon's 10 GB model storage limit.")
				return
			case let .deviceStorageLow(requiredGB, availableGB):
				downloadAlert = .failed(model.name, "This model needs about \(ModelStorageLimit.formattedGB(requiredGB)) free. You have \(ModelStorageLimit.formattedGB(availableGB)) available.")
				return
			}

			downloadingModel = model
		}
	}

	private func prepareOnboardingModels(_ selectedModels: [BeaconModel], _ primaryModel: BeaconModel) {
		guard models.contains(primaryModel), selectedModels.contains(primaryModel) else { return }
		guard selectedModels.allSatisfy({ models.contains($0) }) else { return }

		for model in selectedModels {
			let compatibility = ModelDeviceCompatibility.current(for: model)
			guard compatibility.canUse else {
				downloadAlert = .unavailable(model.onboardingName, compatibility.message ?? "This model isn't supported on this iPhone.")
				return
			}
		}

		var simulatedDownloadedIDs = Set(downloadedModelIDs.split(separator: ",").map(String.init))
		for model in selectedModels where !isDownloaded(model) {
			let simulatedIDs = simulatedDownloadedIDs.sorted().joined(separator: ",")
			switch ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: simulatedIDs, in: models) {
			case .available:
				simulatedDownloadedIDs.insert(model.id)
			case .appStorageFull:
				downloadAlert = .failed(model.onboardingName, "Delete a downloaded model to free up Beacon's 10 GB model storage limit.")
				return
			case let .deviceStorageLow(requiredGB, availableGB):
				downloadAlert = .failed(model.onboardingName, "This model needs about \(ModelStorageLimit.formattedGB(requiredGB)) free. You have \(ModelStorageLimit.formattedGB(availableGB)) available.")
				return
			}
		}

		onboardingPrimaryModel = primaryModel
		onboardingDownloadModels = selectedModels.filter { !isDownloaded($0) }
		onboardingDownloadQueue = onboardingDownloadModels
		onboardingCompletedDownloadGB = 0
		guard let firstModel = onboardingDownloadQueue.first else {
			finishOnboarding(with: primaryModel)
			return
		}

		isOnboardingSetup = true
		downloadingModel = firstModel
	}

	private func completeOnboardingLater() {
		hasSeenModelRoutingUpdate = true
		let downloadedChatModel = ModelCatalog.coreOnboardingModels(in: models).first(where: { isDownloaded($0) })
		selectedModelID = downloadedChatModel?.id ?? ModelCatalog.defaultModel(in: models).id
		if let attention = AttentionContent.current {
			lastSeenAttentionID = attention.id
		}
		hasCompletedWelcome = true
	}

	private func recordModelDownload(_ model: BeaconModel) {
		guard !model.isBuiltIn else { return }
		Task {
			await ModelDownloadAnalyticsClient().recordDownload(modelID: model.id)
		}
	}

	private func finishOnboarding(with model: BeaconModel) {
		hasSeenModelRoutingUpdate = true
		guard models.contains(model), isDownloaded(model) else {
			isOnboardingSetup = false
							onboardingDownloadQueue.removeAll()
							onboardingDownloadModels.removeAll()
							onboardingCompletedDownloadGB = 0
			return
		}
		isOnboardingSetup = false
		onboardingPrimaryModel = nil
		selectedModelID = model.id
		if let attention = AttentionContent.current {
			lastSeenAttentionID = attention.id
		}
		hasCompletedWelcome = true
		downloadingModel = nil
	}

	private func dismissModelRoutingUpdate() {
		withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
			isShowingModelRoutingUpdate = false
		}
		hasSeenModelRoutingUpdate = true
	}

	private func replaceModelsWithBundle() {
		let previousModels = models.filter { !$0.isBuiltIn && isDownloaded($0) }
		_ = modelRuntime.unloadIfIdle()

		do {
			try DownloadedModelStorage.delete(previousModels)
		} catch {
			downloadAlert = .failed("Models", "Beacon couldn't remove the previous models. Please try again.")
			return
		}

		downloadedModelIDs = ""
		selectedModelID = ""
		hasSeenModelRoutingUpdate = true
		withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
			isShowingModelRoutingUpdate = false
		}

		let bundle = ModelCatalog.coreOnboardingModels(in: models)
			.filter { ModelDeviceCompatibility.current(for: $0).canUse }
		guard let primaryModel = bundle.first(where: { $0.onboardingRole == .chatCore }) ?? bundle.first else { return }
		prepareOnboardingModels(bundle, primaryModel)
	}

	private func isDownloaded(_ model: BeaconModel) -> Bool {
		model.isBuiltIn || Set(downloadedModelIDs.split(separator: ",").map(String.init)).contains(model.id)
	}

	private func select(_ model: BeaconModel) {
		if !model.isBuiltIn {
			recordDownloaded(model)
		}

		selectedModelID = model.id
		hasCompletedWelcome = true
		downloadingModel = nil
	}

	private func cancelDownload(for model: BeaconModel) {
		guard !model.isBuiltIn else { return }
		removeDownloaded(model)
		try? DownloadedModelStorage.delete([model])
		if isOnboardingSetup {
			onboardingDownloadQueue.removeAll()
			onboardingDownloadModels.removeAll()
			onboardingCompletedDownloadGB = 0
			onboardingPrimaryModel = nil
			isOnboardingSetup = false
		}
	}
}

private struct ModelRoutingUpdateOverlay: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	let onKeepModels: () -> Void
	let onReplaceModels: () -> Void

	var body: some View {
		GeometryReader { proxy in
			ZStack(alignment: .bottom) {
				Color.black.opacity(0.25)
					.ignoresSafeArea()

				VStack(spacing: 18) {
					Capsule()
						.fill(Color.secondary.opacity(0.35))
						.frame(width: 38, height: 5)

					VStack(spacing: 10) {
						Text("Beacon just got easier")
							.font(.openRunde(size: 24, weight: .semibold))
						Text("We updated Beacon so it can choose the right model for each message. Your chats and memories are saved.")
							.font(.openRunde(size: 16, weight: .medium))
							.foregroundStyle(.secondary)
							.lineSpacing(3)
					}
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)

					VStack(spacing: 12) {
						BeaconButton("Replace with Chat Core", variant: .black, size: .large, isFullWidth: true, action: onReplaceModels)
						BeaconButton("Keep my models", variant: .secondary, size: .large, isFullWidth: true, action: onKeepModels)
					}
				}
				.padding(.horizontal, 24)
				.padding(.top, 20)
				.padding(.bottom, 24)
				.frame(maxWidth: 560)
				.frame(height: min(390, max(0, proxy.size.height - proxy.safeAreaInsets.top - 24)))
				.background(Color(uiColor: .systemBackground))
				.clipShape(UnevenRoundedRectangle(
					topLeadingRadius: 40,
					bottomLeadingRadius: 52,
					bottomTrailingRadius: 52,
					topTrailingRadius: 40,
					style: .continuous
				))
				.shadow(color: .black.opacity(0.12), radius: 24, y: 8)
				.padding(.horizontal, 8)
				.padding(.bottom, 8)
				.transition(reduceMotion ? .move(edge: .bottom) : .move(edge: .bottom).combined(with: .scale(scale: 0.94, anchor: .bottom)))
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.ignoresSafeArea()
		.accessibilityAddTraits(.isModal)
	}
}

private struct DownloadAlert: Identifiable {
	let id = UUID()
	let title: String
	let message: String

	static func completed(_ modelName: String) -> DownloadAlert {
		DownloadAlert(title: "Model downloaded", message: "\(modelName) is ready to use.")
	}

	static func cancelled(_ modelName: String) -> DownloadAlert {
		DownloadAlert(title: "Download cancelled", message: "\(modelName) was cancelled and removed from available models.")
	}

	static func failed(_ modelName: String, _ errorMessage: String) -> DownloadAlert {
		DownloadAlert(title: "Download failed", message: "\(modelName) could not be downloaded. \(errorMessage)")
	}

	static func unavailable(_ modelName: String, _ message: String) -> DownloadAlert {
		DownloadAlert(title: "\(modelName) isn't available", message: message)
	}
}

#Preview {
	ContentView(modelRuntime: BeaconModelRuntime(), notificationRouter: NotificationRouter())
}
