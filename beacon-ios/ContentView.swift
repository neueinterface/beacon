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
	@StateObject private var modelRuntime = BeaconModelRuntime()
	@State private var isChoosingModel = false
	@State private var downloadingModel: BeaconModel?

    var body: some View {
		if let downloadingModel {
			ModelDownloadView(model: downloadingModel, runtime: modelRuntime) {
				selectedModelID = downloadingModel.id
				hasCompletedWelcome = true
				self.downloadingModel = nil
			}
		} else if hasCompletedWelcome {
			ChatView(runtime: modelRuntime)
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
}

#Preview {
    ContentView()
}
