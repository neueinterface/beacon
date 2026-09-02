#if os(macOS)
import SwiftUI

@main
struct BeaconMacApp: App {
	@Environment(\.scenePhase) private var scenePhase
	@StateObject private var modelRuntime = BeaconModelRuntime()
	@StateObject private var memoryStore = MemoryStore()
	@StateObject private var notificationRouter = NotificationRouter()

	init() {
		AppTypography.registerFonts()
	}

	var body: some Scene {
		WindowGroup {
			MacRootView(
				modelRuntime: modelRuntime,
				memoryStore: memoryStore,
				notificationRouter: notificationRouter
			)
			.onChange(of: scenePhase) { _, phase in
				guard phase == .background else { return }
				_ = modelRuntime.unloadIfIdle()
			}
		}
		.defaultSize(width: 1_180, height: 760)
		.windowResizability(.contentMinSize)
		.commands {
			CommandGroup(replacing: .newItem) {
				Button("New Chat") {
					notificationRouter.openQuickAction(.newChat)
				}
				.keyboardShortcut("n", modifiers: .command)
			}

			CommandMenu("Models") {
				Button("Model Marketplace") {
					notificationRouter.openQuickAction(.seeModels)
				}
				.keyboardShortcut("m", modifiers: [.command, .shift])
			}
		}
	}
}

private struct MacRootView: View {
	@Environment(\.colorScheme) private var systemColorScheme
	@AppStorage("appearanceColorScheme") private var selectedScheme = AppearanceColorScheme.system.rawValue
	@ObservedObject var modelRuntime: BeaconModelRuntime
	@ObservedObject var memoryStore: MemoryStore
	@ObservedObject var notificationRouter: NotificationRouter

	private var resolvedColorScheme: ColorScheme {
		let selection = AppearanceColorScheme(rawValue: selectedScheme) ?? .system
		return selection.preferredColorScheme ?? systemColorScheme
	}

	var body: some View {
		ContentView(
			modelRuntime: modelRuntime,
			memoryStore: memoryStore,
			notificationRouter: notificationRouter
		)
		.environment(\.colorScheme, resolvedColorScheme)
		.font(.openRunde(size: 17))
		.frame(minWidth: 760, minHeight: 560)
	}
}
#endif
