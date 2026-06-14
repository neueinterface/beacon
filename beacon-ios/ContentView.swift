//
//  ContentView.swift
//  beacon-ios
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

    var body: some View {
		if let downloadingModel {
			ModelDownloadView(model: downloadingModel, runtime: modelRuntime) {
				recordDownloaded(downloadingModel)
				selectedModelID = downloadingModel.id
				hasCompletedWelcome = true
				self.downloadingModel = nil
			}
		} else if hasCompletedWelcome {
			ChatView(runtime: modelRuntime) { model in
				downloadingModel = model
			}
		} else if isChoosingModel {
			WelcomeModelSelectView(models: ModelCatalog.availableModels) { model in
				downloadingModel = model
			}
		} else {
			WelcomeView(onGetStarted: {
				isChoosingModel = true
			})
		}
    }

	private func recordDownloaded(_ model: BeaconModel) {
		var ids = Set(downloadedModelIDs.split(separator: ",").map(String.init))
		ids.insert(model.id)
		downloadedModelIDs = ids.sorted().joined(separator: ",")
	}
}

#Preview {
    ContentView()
}
