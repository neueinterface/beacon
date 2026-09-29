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
	@AppStorage("lastSeenWhatsNewRelease") private var lastSeenAttentionID = ""
	@ObservedObject private var modelRuntime: BeaconModelRuntime
	@StateObject private var memoryStore = MemoryStore()
	private let models = ModelCatalog.availableModels
	@State private var isChoosingModel = false
	@State private var downloadingModel: BeaconModel?
	@State private var isOnboardingSetup = false
	@State private var downloadAlert: DownloadAlert?
	@State private var isShowingAttention = false
	@ObservedObject private var notificationRouter: NotificationRouter

	init(modelRuntime: BeaconModelRuntime, notificationRouter: NotificationRouter) {
		self.modelRuntime = modelRuntime
		self.notificationRouter = notificationRouter
	}

	var body: some View {
		Group {
			if let downloadingModel {
				ModelDownloadView(model: downloadingModel, runtime: modelRuntime, onComplete: {
					downloadAlert = .completed(downloadingModel.name)
					if isOnboardingSetup {
						recordDownloaded(downloadingModel)
						recordModelDownload(downloadingModel)
						finishOnboarding(with: downloadingModel)
					} else {
						recordModelDownload(downloadingModel)
						select(downloadingModel)
					}
				}, onCancel: {
					cancelDownload(for: downloadingModel)
					downloadAlert = .cancelled(downloadingModel.name)
					isOnboardingSetup = false
					self.downloadingModel = nil
				}, onError: { message in
					downloadAlert = .failed(downloadingModel.name, message)
				})
			} else if hasCompletedWelcome {
				ChatView(
					runtime: modelRuntime,
					memoryStore: memoryStore,
					models: models,
					onDownloadModel: prepare,
					notificationRouter: notificationRouter
				)
			} else if isChoosingModel {
				WelcomeModelSelectView(
					models: ModelCatalog.onboardingModels(in: models),
					onDownloadModel: prepareOnboardingModel,
					onBack: { isChoosingModel = false }
				)
			} else {
				WelcomeView(onGetStarted: {
					isChoosingModel = true
				})
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

	private func prepareOnboardingModel(_ model: BeaconModel) {
		guard ModelCatalog.onboardingModels(in: models).contains(model) else { return }
		let compatibility = ModelDeviceCompatibility.current(for: model)
		guard compatibility.canUse else {
			downloadAlert = .unavailable(model.name, compatibility.message ?? "This model isn't supported on this iPhone.")
			return
		}
		if isDownloaded(model) {
			finishOnboarding(with: model)
			return
		}
		switch ModelStorageLimit.downloadAvailability(for: model, downloadedModelIDs: downloadedModelIDs, in: models) {
		case .available:
			isOnboardingSetup = true
			downloadingModel = model
		case .appStorageFull:
			downloadAlert = .failed(model.name, "Delete a downloaded model to free up Beacon's 10 GB model storage limit.")
		case let .deviceStorageLow(requiredGB, availableGB):
			downloadAlert = .failed(model.name, "This model needs about \(ModelStorageLimit.formattedGB(requiredGB)) free. You have \(ModelStorageLimit.formattedGB(availableGB)) available.")
		}
	}

	private func recordModelDownload(_ model: BeaconModel) {
		guard !model.isBuiltIn else { return }
		Task {
			await ModelDownloadAnalyticsClient().recordDownload(modelID: model.id)
		}
	}

	private func finishOnboarding(with model: BeaconModel) {
		guard ModelCatalog.onboardingModels(in: models).contains(model), isDownloaded(model) else {
			isOnboardingSetup = false
			return
		}
		isOnboardingSetup = false
		selectedModelID = model.id
		if let attention = AttentionContent.current {
			lastSeenAttentionID = attention.id
		}
		hasCompletedWelcome = true
		downloadingModel = nil
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
