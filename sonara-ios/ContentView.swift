//
//  ContentView.swift
//  sonara-ios
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI

struct ContentView: View {
	@AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
	@AppStorage("selectedModelID") private var selectedModelID = ""
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@StateObject private var modelRuntime = BeaconModelRuntime()
	@State private var isChoosingModel = false
	@State private var downloadingModel: BeaconModel?
	@State private var downloadAlert: DownloadAlert?

	var body: some View {
		Group {
			if let downloadingModel {
				ModelDownloadView(model: downloadingModel, runtime: modelRuntime, onComplete: {
					downloadAlert = .completed(downloadingModel.name)
					select(downloadingModel)
				}, onCancel: {
					cancelDownload(for: downloadingModel)
					downloadAlert = .cancelled(downloadingModel.name)
					self.downloadingModel = nil
				}, onError: { message in
					downloadAlert = .failed(downloadingModel.name, message)
				})
			} else if hasCompletedWelcome {
				ChatView(runtime: modelRuntime) { model in
					prepare(model)
				}
			} else if isChoosingModel {
				WelcomeModelSelectView(models: ModelCatalog.onboardingModels) { model in
					prepare(model)
				}
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
		if model.isBuiltIn {
			select(model)
		} else {
			downloadingModel = model
		}
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
}

#Preview {
    ContentView()
}
