
import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
	@ObservedObject var chatHistoryViewModel: ChatHistoryViewModel
	@ObservedObject var memoryStore: MemoryStore
	var models = ModelCatalog.availableModels
	var onDownloadModel: (BeaconModel) async -> Void = { _ in }
	var onDownloadBundle: () async -> Void = { }
	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@AppStorage("notificationsEnabled") private var notificationsEnabled = false
	#if false // Web search is not currently available.
	@AppStorage("webSearchEnabled") private var webSearchEnabled = false
	@AppStorage("hasSeenWebSearchInfo") private var hasSeenWebSearchInfo = false
	#endif
	@State private var isConfirmingDeleteAllChats = false
	@State private var isConfirmingDeleteModels = false
	@State private var isDeletingModels = false
	@State private var isShowingReviewLinkError = false
	@State private var isShowingModelManager = false
	#if false // Web search is not currently available.
	@State private var isShowingWebSearchInfo = false
	#endif
	@StateObject private var safariViewModel = SafariViewModel()

	private var appVersion: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.1"
	}

	private var buildNumber: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
	}

	private var bugReportURL: URL {
		var components = URLComponents()
		components.scheme = "mailto"
		components.path = "armondschneider@gmail.com"
		components.queryItems = [
			URLQueryItem(name: "subject", value: "Beacon Bug Report - v\(appVersion) (\(buildNumber))"),
			URLQueryItem(name: "body", value: bugReportBody)
		]

		return components.url ?? URL(string: "mailto:armondschneider@gmail.com")!
	}

	private var bugReportBody: String {
		"""



		---
		Please write any extra details above this line.

		App: Beacon
		Version: v\(appVersion) (\(buildNumber))
		Device: \(deviceDescription)
		"""
	}

	private var deviceDescription: String {
		#if canImport(UIKit)
		let device = UIDevice.current
		return "\(device.model), \(device.systemName) \(device.systemVersion)"
		#else
		return "Unknown"
		#endif
	}

	private var downloadedStorageGB: Decimal {
		ModelStorageLimit.downloadedSizeGB(downloadedModelIDs: downloadedModelIDs, in: models)
	}

	private var downloadedModels: [BeaconModel] {
		models.filter { isDownloaded($0) }
	}

	private func isDownloaded(_ model: BeaconModel) -> Bool {
		Set(downloadedModelIDs.split(separator: ",").map(String.init)).contains(model.id)
	}

	private func deleteAllDownloadedModels() async {
		defer { isDeletingModels = false }
		let urls = downloadedModels.flatMap { DownloadedModelStorage.cacheURLs(for: $0) }
		do {
			try await Task.detached(priority: .userInitiated) {
				let fileManager = FileManager.default
				for url in urls where fileManager.fileExists(atPath: url.path) {
					try fileManager.removeItem(at: url)
				}
			}.value
			downloadedModelIDs = ""
		} catch {
			// Keep recorded downloads when removal fails so the user can retry.
		}
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 26) {
					settingsSection("General") {
						SettingsLinkRow(title: "Memory", icon: "memory") {
							MemorySettingsView(memoryStore: memoryStore)
						}
						SettingsListDivider()

						SettingsLinkRow(title: "Appearance", icon: "appearance.icon") {
							AppearancePlaceholderView()
						}
						SettingsListDivider()
						SettingsLinkRow(title: "App Icon", icon: "appicon.icon") {
							AppIconPickerView()
						}
						SettingsListDivider()

						SettingsToggleRow(title: "Notifications", icon: "bell.icon", isOn: notificationsBinding)
						SettingsListDivider()

						#if false // Web search is not currently available.
						#if false // Web search is not part of the current release.
						SettingsToggleRow(title: "Web Search", icon: "globe.icon", subtitle: "Daily search limits apply", isOn: webSearchBinding)
						SettingsListDivider()
						#endif
						#endif

						SettingsButtonRow(title: "Report a bug", icon: "bug.icon") {
							openURL(bugReportURL)
						}
						SettingsListDivider()

						SettingsButtonRow(title: "Rate on App Store", icon: "review.icon") {
							openURL(AppStoreLinks.review) { accepted in
								isShowingReviewLinkError = !accepted
								if accepted { ReviewPromptScheduler().recordReviewPageOpened() }
							}
						}
					}

					settingsSection("Legal") {
						SettingsButtonRow(title: "Terms of Service", icon: "legal.icon") {
							safariViewModel.open(URL(string: "https://beacon.neueinterface.com/terms-of-service")!)
						}
						SettingsListDivider()

						SettingsButtonRow(title: "Privacy Policy", icon: "privacy.icon") {
							safariViewModel.open(URL(string: "https://beacon.neueinterface.com/privacy-policy")!)
						}
					}

					VStack(alignment: .leading, spacing: 16) {
						SettingsSectionTitle("Chat")

						ModelStorageUsagePill(usedGB: downloadedStorageGB, maxGB: ModelStorageLimit.maxGB)

						VStack(spacing: 0) {
							SettingsButtonRow(title: "Model Marketplace", icon: "playground.icon") {
								isShowingModelManager = true
							}
							.disabled(isDeletingModels)
						}
						.padding(.vertical, 6)
						.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

						BeaconButton(
							"Delete Downloaded Models",
							variant: .destructive,
							size: .large,
							isFullWidth: true,
							isDisabled: downloadedModels.isEmpty,
							isLoading: isDeletingModels
						) {
							isConfirmingDeleteModels = true
						}

						BeaconButton(
							"Delete All Chats",
							variant: .destructive,
							size: .large,
							isFullWidth: true,
							isDisabled: chatHistoryViewModel.chats.isEmpty
						) {
							isConfirmingDeleteAllChats = true
						}
					}

					SettingsFooterView {
						safariViewModel.open(URL(string: "https://beacon.neueinterface.com")!)
					}
				}
				.padding(.horizontal, 20)
				.padding(.top, 16)
				.padding(.bottom, 42)
			}
			.scrollEdgeEffectStyle(.soft, for: .top)
			.background(Color(uiColor: .systemGroupedBackground))
			.navigationTitle("Settings")
			#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
			.toolbarVisibility(.visible, for: .navigationBar)
			#endif
			.toolbar {
				#if os(macOS)
				ToolbarItem(placement: .automatic) {
					SettingsCloseButton { dismiss() }
				}
				#else
				ToolbarItem(placement: .topBarTrailing) {
					SettingsCloseButton { dismiss() }
				}
				#endif
			}
			.alert("Could not open App Store", isPresented: $isShowingReviewLinkError) {
				Button("OK", role: .cancel) { }
			} message: {
				Text("Please try again, or search for Beacon – Local AI Chat in the App Store to leave a review.")
			}
			.alert("Delete all chats?", isPresented: $isConfirmingDeleteAllChats) {
				Button("Cancel", role: .cancel) { }
				Button("Delete All Chats (\(chatHistoryViewModel.chats.count))", role: .destructive) {
					withAnimation(.smooth(duration: 0.24)) {
						chatHistoryViewModel.clearAll()
					}
				}
			} message: {
				Text("Are you sure you want to delete all saved chats? This cannot be undone.")
			}
			.alert("Delete all downloaded models?", isPresented: $isConfirmingDeleteModels) {
				Button("Cancel", role: .cancel) { }
				Button("Delete Models (\(downloadedModels.count))", role: .destructive) {
					isDeletingModels = true
				}
			} message: {
				Text("This removes every downloaded model from Beacon. You can download them again later.")
			}
			#if false // Web search is not currently available.
			.alert("Web Search", isPresented: $isShowingWebSearchInfo) {
				Button("Continue") { }
			} message: {
				Text("Web Search can send your search query to Beacon to retrieve current results. Daily search limits apply.")
			}
			#endif
			.sheet(item: $safariViewModel.page) { page in
				SafariView(url: page.url)
			}
			.sheet(isPresented: $isShowingModelManager) {
				ModelMarketPlaceView(
					models: models,
					onClose: { isShowingModelManager = false },
					onDownload: { model in
						await onDownloadModel(model)
						isShowingModelManager = false
					},
					onDownloadBundle: {
						await onDownloadBundle()
						isShowingModelManager = false
					}
				)
			}
			.task(id: isDeletingModels) {
				guard isDeletingModels else { return }
				await deleteAllDownloadedModels()
			}
		}
	}

	private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			SettingsSectionTitle(title)

			VStack(spacing: 0) {
				content()
			}
			.padding(.vertical, 6)
			.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
	}

	private var notificationsBinding: Binding<Bool> {
		Binding(
			get: { notificationsEnabled },
			set: { isEnabled in
				if isEnabled {
					requestNotificationPermission()
				} else {
					notificationsEnabled = false
					UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
				}
			}
		)
	}

	#if false // Web search is not currently available.
	private var webSearchBinding: Binding<Bool> {
		Binding(
			get: { webSearchEnabled },
			set: { isEnabled in
				webSearchEnabled = isEnabled
				if isEnabled && !hasSeenWebSearchInfo {
					hasSeenWebSearchInfo = true
					isShowingWebSearchInfo = true
				}
			}
		)
	}
	#endif

	private func requestNotificationPermission() {
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
			Task { @MainActor in
				notificationsEnabled = granted
			}
		}
	}

}

private struct ModelStorageUsagePill: View {
	let usedGB: Decimal
	let maxGB: Decimal

	private var progress: Double {
		let used = NSDecimalNumber(decimal: usedGB).doubleValue
		let maxValue = NSDecimalNumber(decimal: maxGB).doubleValue
		guard maxValue > 0 else { return 0 }
		return min(max(used / maxValue, 0), 1)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .firstTextBaseline) {
				VStack(alignment: .leading, spacing: 4) {
					Text("Model Storage")
						.font(.beaconFont(size: 16, weight: .semibold))
						.foregroundStyle(.primary)

					Text("Downloads are capped to protect device storage.")
						.font(.beaconFont(size: 13, weight: .regular))
						.foregroundStyle(.secondary)
				}

				Spacer(minLength: 12)

				Text("\(ModelStorageLimit.formattedGB(usedGB)) / \(ModelStorageLimit.formattedGB(maxGB))")
					.font(.beaconFont(size: 14, weight: .semibold))
					.foregroundStyle(Color(uiColor: .systemBlue))
			}

			GeometryReader { proxy in
				ZStack(alignment: .leading) {
					Capsule()
						.fill(Color(uiColor: .systemGray5))

					Capsule()
						.fill(Color(uiColor: .systemBlue))
						.frame(width: proxy.size.width * progress)
				}
			}
			.frame(height: 8)
		}
		.padding(16)
		.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
	}
}

#Preview {
	SettingsView(chatHistoryViewModel: ChatHistoryViewModel(conversations: []), memoryStore: MemoryStore())
}
