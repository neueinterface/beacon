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
	@AppStorage("usesChatCore") private var usesChatCore = true
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@AppStorage("hasSeenModelRoutingUpdate") private var hasSeenModelRoutingUpdate = false
	@AppStorage("lastSeenWhatsNewRelease") private var lastSeenAttentionID = ""
	@ObservedObject private var modelRuntime: BeaconModelRuntime
	@StateObject private var memoryStore = MemoryStore()
	private let models = ModelCatalog.availableModels
	@State private var isChoosingModel = false
	@State private var isShowingModelMarketplace = false
	@State private var downloadingModel: BeaconModel?
	@State private var isDownloadComplete = false
	@State private var isOnboardingSetup = false
	@State private var onboardingDownloadQueue: [BeaconModel] = []
	@State private var onboardingDownloadModels: [BeaconModel] = []
	@State private var onboardingDownloadByteCounts: [String: Int64] = [:]
	@State private var onboardingPrimaryModel: BeaconModel?
	@State private var downloadAlert: DownloadAlert?
	@State private var isPreparingModelSetup = false
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
					completedBundleByteCounts: onboardingDownloadByteCounts,
					isDownloadComplete: isDownloadComplete,
					onComplete: {
						if isOnboardingSetup, let bytes = modelRuntime.totalUnitCount, bytes > 0 {
							onboardingDownloadByteCounts[downloadingModel.id] = bytes
						}
						recordDownloaded(downloadingModel)
						recordModelDownload(downloadingModel)
						if isOnboardingSetup, let nextModel = onboardingDownloadQueue.dropFirst().first {
							onboardingDownloadQueue.removeFirst()
							self.downloadingModel = nextModel
						} else {
							isDownloadComplete = true
						}
					}, onContinue: {
						guard isDownloadComplete else { return }
						if isOnboardingSetup {
							onboardingDownloadQueue.removeAll()
							onboardingDownloadModels.removeAll()
							finishOnboarding(with: onboardingPrimaryModel ?? downloadingModel)
						} else {
							select(downloadingModel)
						}
					}, onCancel: {
					cancelDownload(for: downloadingModel)
						downloadAlert = .cancelled(isOnboardingSetup ? "Chat Core" : downloadingModel.name)
						isOnboardingSetup = false
						onboardingDownloadQueue.removeAll()
						onboardingDownloadModels.removeAll()
						self.downloadingModel = nil
					}, onError: { message in
						downloadAlert = .failed(isOnboardingSetup ? "Chat Core" : downloadingModel.name, message)
					}
				)
			} else if hasCompletedWelcome {
				ChatView(
					runtime: modelRuntime,
					memoryStore: memoryStore,
					models: models,
					onDownloadModel: prepare,
					onDownloadBundle: prepareRecommendedBundle,
					notificationRouter: notificationRouter
				)
			} else if isShowingModelMarketplace {
				ModelMarketPlaceView(
					models: models,
					isOnboarding: true,
					onClose: { isShowingModelMarketplace = false },
					onDownload: prepare,
					onSelect: select,
					onDownloadBundle: prepareRecommendedBundle
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
					onUseChatCore: continueWithChatCore
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
			// New release notes take precedence over the older Chat Core intro.
			// Users should receive one current announcement, not stacked popups.
			if let attention = AttentionContent.current, lastSeenAttentionID != attention.id {
				presentAttentionIfNeeded()
				return
			}
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
		hasSeenModelRoutingUpdate = true
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

	private func prepare(_ model: BeaconModel) async {
		guard !isPreparingModelSetup else { return }
		isPreparingModelSetup = true
		defer { isPreparingModelSetup = false }
		let compatibility = ModelDeviceCompatibility.current(for: model)
		guard compatibility.canUse else {
			downloadAlert = .unavailable(model.name, compatibility.message ?? "Choose a model marked Works with this iPhone instead.")
			return
		}

		if model.isBuiltIn {
			select(model)
		} else {
			let availableGB = await Task.detached(priority: .userInitiated) {
				ModelStorageLimit.availableDeviceStorageGB()
			}.value
			guard !Task.isCancelled else { return }
			switch ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: downloadedModelIDs, in: models, availableGB: availableGB) {
			case .available:
				break
			case .appStorageFull:
				downloadAlert = .failed(model.name, "Delete a downloaded model to free up Beacon's 10 GB model storage limit.")
				return
			case let .deviceStorageLow(requiredGB, availableGB):
				downloadAlert = .failed(model.name, "This model needs about \(ModelStorageLimit.formattedGB(requiredGB)) free. You have \(ModelStorageLimit.formattedGB(availableGB)) available.")
				return
			}

			isDownloadComplete = false
			downloadingModel = model
		}
	}

	private func prepareOnboardingModels(_ selectedModels: [BeaconModel], _ primaryModel: BeaconModel) async {
		guard !isPreparingModelSetup else { return }
		isPreparingModelSetup = true
		defer { isPreparingModelSetup = false }
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
		var remainingStorageGB = await Task.detached(priority: .userInitiated) {
			ModelStorageLimit.availableDeviceStorageGB()
		}.value
		guard !Task.isCancelled else { return }
		for model in selectedModels where !isDownloaded(model) {
			let simulatedIDs = simulatedDownloadedIDs.sorted().joined(separator: ",")
			switch ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: simulatedIDs, in: models, availableGB: remainingStorageGB) {
			case .available:
				simulatedDownloadedIDs.insert(model.id)
				remainingStorageGB = remainingStorageGB.map { $0 - NSDecimalNumber(decimal: model.sizeInGB).doubleValue * 1.1 }
			case .appStorageFull:
				downloadAlert = .failed(model.onboardingName, "Delete a downloaded model to free up Beacon's 10 GB model storage limit.")
				return
			case let .deviceStorageLow(requiredGB, availableGB):
				downloadAlert = .failed(model.onboardingName, "This model needs about \(ModelStorageLimit.formattedGB(requiredGB)) free. You have \(ModelStorageLimit.formattedGB(availableGB)) available.")
				return
			}
		}

		onboardingPrimaryModel = primaryModel
		onboardingDownloadByteCounts = [:]
		onboardingDownloadModels = selectedModels.filter { !isDownloaded($0) }
		onboardingDownloadQueue = onboardingDownloadModels
		guard let firstModel = onboardingDownloadQueue.first else {
			finishOnboarding(with: primaryModel)
			return
		}

		isOnboardingSetup = true
		isDownloadComplete = false
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
			return
		}
		isOnboardingSetup = false
		onboardingPrimaryModel = nil
		selectedModelID = model.id
		usesChatCore = true
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

	private func continueWithChatCore() async {
		// Add only missing bundle models. Adopting Chat Core must never erase
		// previous downloads or clear the current selection if setup fails.
		await prepareRecommendedBundle()
		guard !Task.isCancelled else { return }
		dismissModelRoutingUpdate()
	}

	private func prepareRecommendedBundle() async {
		let bundle = ModelCatalog.coreOnboardingModels(in: models)
		guard let primaryModel = ModelCatalog.primaryChatModel(in: bundle) ?? bundle.first else {
			downloadAlert = .unavailable("Chat Core", "No recommended bundle fits this device. Choose an individual model in the marketplace.")
			return
		}
		await prepareOnboardingModels(bundle, primaryModel)
	}

	private func isDownloaded(_ model: BeaconModel) -> Bool {
		model.isBuiltIn || Set(downloadedModelIDs.split(separator: ",").map(String.init)).contains(model.id)
	}

	private func select(_ model: BeaconModel) {
		if !model.isBuiltIn {
			recordDownloaded(model)
		}

		selectedModelID = model.id
		usesChatCore = false
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
			onboardingPrimaryModel = nil
			isOnboardingSetup = false
		}
	}
}

private struct ModelRoutingUpdateOverlay: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	let onKeepModels: () -> Void
	let onUseChatCore: () async -> Void

	var body: some View {
		GeometryReader { proxy in
			ZStack(alignment: .bottom) {
				Color.black.opacity(0.25)
					.ignoresSafeArea()

				ScrollView {
					VStack(spacing: 18) {
						Capsule()
							.fill(Color.secondary.opacity(0.35))
							.frame(width: 38, height: 5)

						VStack(spacing: 10) {
							Text("Meet Chat Core")
								.font(.openRunde(size: 24, weight: .semibold))
							Text("Chat Core brings together models selected for your iPhone and automatically chooses the right one for each message—so you don’t have to.")
								.font(.openRunde(size: 16, weight: .medium))
								.foregroundStyle(.secondary)
								.lineSpacing(3)
							Text("Your previous models, chats, and memories stay saved either way. You can still download other models in Settings → Model Marketplace.")
								.font(.openRunde(size: 15, weight: .regular))
								.foregroundStyle(.secondary)
								.lineSpacing(3)
						}
						.multilineTextAlignment(.center)
						.fixedSize(horizontal: false, vertical: true)

						VStack(spacing: 12) {
							BeaconButton("Continue with Chat Core", variant: .black, size: .large, isFullWidth: true, asyncAction: onUseChatCore)
							BeaconButton("Keep previous models", variant: .secondary, size: .large, isFullWidth: true, action: onKeepModels)
						}
					}
					.padding(.horizontal, 24)
					.padding(.top, 20)
					.padding(.bottom, 24)
				}
				.scrollBounceBehavior(.basedOnSize)
				.frame(maxWidth: 560)
				.frame(height: min(480, max(0, proxy.size.height - proxy.safeAreaInsets.top - 24)))
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
