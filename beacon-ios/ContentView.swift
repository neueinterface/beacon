//
//  ContentView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI

struct ContentView: View {
	@AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false

    var body: some View {
		if hasCompletedWelcome {
			ChatView()
		} else {
			WelcomeView(onGetStarted: {
				hasCompletedWelcome = true
			})
		}
    }
}

#Preview {
    ContentView()
}
