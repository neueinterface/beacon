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
		let view = UIView(frame: .zero)
		Self.applyStyle(scheme.userInterfaceStyle, to: view)
		return view
	}

	func updateUIView(_ uiView: UIView, context: Context) {
		Self.applyStyle(scheme.userInterfaceStyle, to: uiView)
	}

	/// Sets `overrideUserInterfaceStyle` on every window in every connected scene.
	/// Applies synchronously when windows are already available, and falls back to
	/// the next run loop for the `makeUIView` case where the view isn't in the
	/// hierarchy yet.
	private static func applyStyle(_ style: UIUserInterfaceStyle, to view: UIView) {
		let windows = resolvedWindows(for: view)

		guard !windows.isEmpty else {
			DispatchQueue.main.async { [weak view] in
				guard let view else { return }
				for window in resolvedWindows(for: view) {
					window.overrideUserInterfaceStyle = style
				}
			}
			return
		}

		for window in windows {
			window.overrideUserInterfaceStyle = style
		}
	}

	/// Returns every window across all connected scenes so that style changes
	/// reach sheet windows (which live in their own `UIWindow` on iOS 26+) as
	/// well as the main window.
	private static func resolvedWindows(for view: UIView) -> [UIWindow] {
		UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.flatMap { $0.windows }
	}
}

extension AppearanceColorScheme {
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
