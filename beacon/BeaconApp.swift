//
//  BeaconApp.swift
//  beacon
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI
import UserNotifications

private struct AppAppearanceRoot<Content: View>: View {
	@Environment(\.colorScheme) private var systemColorScheme
	@AppStorage("appearanceColorScheme") private var selectedScheme = AppearanceColorScheme.system.rawValue
	let content: Content

	private var resolvedColorScheme: ColorScheme {
		let selection = AppearanceColorScheme(rawValue: selectedScheme) ?? .system
		return selection.preferredColorScheme ?? systemColorScheme
	}

	var body: some View {
		content
			.environment(\.colorScheme, resolvedColorScheme)
			.font(.openRunde(size: 17))
	}
}

#if !os(macOS)
@main
struct BeaconApp: App {
	#if canImport(UIKit)
	@UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var appNotificationDelegate
	#endif
	@Environment(\.scenePhase) private var scenePhase
	@StateObject private var modelRuntime = BeaconModelRuntime()
	@StateObject private var notificationRouter = NotificationRouter()

	init() {
		AppTypography.registerFonts()
	}

	var body: some Scene {
		WindowGroup {
			AppAppearanceRoot(
				content: ContentView(modelRuntime: modelRuntime, notificationRouter: notificationRouter)
			)
				.onAppear {
					#if canImport(UIKit)
					appNotificationDelegate.notificationRouter = notificationRouter
					#endif
				}
				.onChange(of: scenePhase) { _, phase in
					guard phase == .background else { return }
					_ = modelRuntime.unloadIfIdle()
				}
				.onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
					_ = modelRuntime.unloadIfIdle()
				}
		}
	}
}
#endif
