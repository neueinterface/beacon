//
//  SonaraApp.swift
//  sonara-ios
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI

@main
struct SonaraApp: App {
	@StateObject private var modelRuntime = BeaconModelRuntime()

	var body: some Scene {
		WindowGroup {
			ContentView(modelRuntime: modelRuntime)
		}
	}
}
