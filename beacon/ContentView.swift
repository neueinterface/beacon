//
//  ContentView.swift
//  beacon
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI

struct ContentView: View {
	@AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
	@AppStorage("selectedModelID") private var selectedModelID = ""
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@AppStorage("lastSeenWhatsNewRelease") private var lastSeenWhatsNewRelease = ""
	@ObservedObject private var modelRuntime: BeaconModelRuntime
	private let models = ModelCatalog.availableModels
	@State private var isChoosingModel = false
	@State private var downloadingModel: BeaconModel?
	@State private var onboardingDownloadQueue: [BeaconModel] = []
	@State private var isOnboardingSetup = false
	@State private var downloadAlert: DownloadAlert?
	@State private var isShowingWhatsNew = false
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
						completeDownload(downloadingModel)
					} else {
						recordModelDownload(downloadingModel)
						select(downloadingModel)
					}
				}, onCancel: {
					cancelDownload(for: downloadingModel)
					downloadAlert = .cancelled(downloadingModel.name)
					onboardingDownloadQueue = []
					isOnboardingSetup = false
					self.downloadingModel = nil
				}, onError: { message in
					downloadAlert = .failed(downloadingModel.name, message)
				})
			} else if hasCompletedWelcome {
				ChatView(
					runtime: modelRuntime,
					models: models,
					onDownloadModel: prepare,
					notificationRouter: notificationRouter
				)
			} else if isChoosingModel {
				WelcomeModelSelectView(models: ModelCatalog.requiredOnboardingModels(in: models), onDownloadModels: {
					prepareOnboardingModels()
				})
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
		.sheet(isPresented: $isShowingWhatsNew, onDismiss: markWhatsNewReleaseSeen) {
			if let release = WhatsNewRelease.current {
				WhatsNewView(release: release, onClose: {
					isShowingWhatsNew = false
				})
			}
		}
		.onChange(of: notificationRouter.quickActionToOpen) { _, action in
			if action != nil {
				isShowingWhatsNew = false
			}
		}
		.task {
			ModelIDMigration.migrate()
			guard notificationRouter.quickActionToOpen == nil else { return }
			presentWhatsNewIfNeeded()
		}
	}

	private func presentWhatsNewIfNeeded() {
		guard let release = WhatsNewRelease.current, lastSeenWhatsNewRelease != release.id else { return }
		isShowingWhatsNew = true
	}

	private func markWhatsNewReleaseSeen() {
		guard let release = WhatsNewRelease.current else { return }
		lastSeenWhatsNewRelease = release.id
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

	private func prepareOnboardingModels() {
		isOnboardingSetup = true
		onboardingDownloadQueue = ModelCatalog.requiredOnboardingModels(in: models).compactMap { model in
			guard !isDownloaded(model) else { return nil }
			return model
		}

		guard let first = onboardingDownloadQueue.first else {
			finishOnboarding()
			return
		}

		onboardingDownloadQueue.removeFirst()
		prepare(first)
	}

	private func completeDownload(_ model: BeaconModel) {
		recordDownloaded(model)
		recordModelDownload(model)
		guard !onboardingDownloadQueue.isEmpty else {
			finishOnboarding()
			return
		}

		let next = onboardingDownloadQueue.removeFirst()
		prepare(next)
	}

	private func recordModelDownload(_ model: BeaconModel) {
		guard !model.isBuiltIn else { return }
		Task {
			await ModelDownloadAnalyticsClient().recordDownload(modelID: model.id)
		}
	}

	private func finishOnboarding() {
		onboardingDownloadQueue = []
		isOnboardingSetup = false
		selectedModelID = "beacon"
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

		let fileManager = FileManager.default
		for url in cacheURLs(for: model) where fileManager.fileExists(atPath: url.path) {
			try? fileManager.removeItem(at: url)
		}
	}

	private func cacheURLs(for model: BeaconModel) -> [URL] {
		let cacheDirectoryName = "models--\(model.repositoryID.replacingOccurrences(of: "/", with: "--"))"
		let hubDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("huggingface")
			.appendingPathComponent("hub")

		return [
			hubDirectory.appendingPathComponent(cacheDirectoryName),
			hubDirectory.appendingPathComponent(".metadata").appendingPathComponent(cacheDirectoryName),
			hubDirectory.appendingPathComponent(".locks").appendingPathComponent(cacheDirectoryName)
		]
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
