//
//  SemeraApp.swift
//  semera-ios
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI
import UserNotifications

private struct AppearanceStyleUpdater: UIViewRepresentable {
	let scheme: AppearanceColorScheme

	func makeUIView(context: Context) -> UIView {
		UIView(frame: .zero)
	}

	func updateUIView(_ uiView: UIView, context: Context) {
		let style = scheme.userInterfaceStyle

		DispatchQueue.main.async {
			guard let windowScene = uiView.window?.windowScene ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }

			for window in windowScene.windows {
				window.overrideUserInterfaceStyle = style
			}
		}
	}
}

private extension AppearanceColorScheme {
	var userInterfaceStyle: UIUserInterfaceStyle {
		switch self {
		case .system: .unspecified
		case .light: .light
		case .dark: .dark
		}
	}
}

@main
struct SemeraApp: App {
	#if canImport(UIKit)
	@UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var appNotificationDelegate
	#endif
	@Environment(\.scenePhase) private var scenePhase
	@AppStorage("appearanceColorScheme") private var selectedScheme = AppearanceColorScheme.system.rawValue
	@StateObject private var modelRuntime = BeaconModelRuntime()
	@StateObject private var notificationRouter = NotificationRouter()

	private var appearanceScheme: AppearanceColorScheme {
		AppearanceColorScheme(rawValue: selectedScheme) ?? .system
	}

	var body: some Scene {
		WindowGroup {
			ContentView(modelRuntime: modelRuntime, notificationRouter: notificationRouter)
				.background(AppearanceStyleUpdater(scheme: appearanceScheme).frame(width: 0, height: 0))
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
