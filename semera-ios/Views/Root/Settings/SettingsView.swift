import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
	@ObservedObject var chatHistoryViewModel: ChatHistoryViewModel
	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL
	@AppStorage("notificationsEnabled") private var notificationsEnabled = false
	@State private var isConfirmingDeleteAllChats = false
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
		components.path = "semeraco@gmail.com"
		components.queryItems = [
			URLQueryItem(name: "subject", value: "Semera Bug Report - v\(appVersion) (\(buildNumber))"),
			URLQueryItem(name: "body", value: bugReportBody)
		]

		return components.url ?? URL(string: "mailto:semeraco@gmail.com")!
	}

	private var bugReportBody: String {
		"""



		---
		Please write any extra details above this line.

		App: Semera
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

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 26) {
					settingsSection("General") {
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

						SettingsButtonRow(title: "Report a bug", icon: "bug.icon") {
							openURL(bugReportURL)
						}
						SettingsListDivider()

						SettingsButtonRow(title: "Leave a review in the App Store", icon: "review.icon") {
							openURL(URL(string: "https://semera.co")!)
						}
						SettingsListDivider()

						SettingsLinkRow(title: "Why Local Models", icon: "flower.icon") {
							WhyLocalModelsView()
						}
					}

					settingsSection("Legal") {
						SettingsLinkRow(title: "Terms of Service", icon: "legal.icon") {
							SettingsTextDetailView(title: "Terms of Service", paragraphs: SettingsLegalContent.terms)
						}
						SettingsListDivider()

						SettingsLinkRow(title: "Privacy Policy", icon: "privacy.icon") {
							SettingsTextDetailView(title: "Privacy Policy", paragraphs: SettingsLegalContent.privacyPolicy)
						}
					}

					VStack(alignment: .leading, spacing: 16) {
						SettingsSectionTitle("Chat")

						Button {
							isConfirmingDeleteAllChats = true
						} label: {
							Text("Delete All Chats")
								.font(.system(size: 16, weight: .medium))
								.foregroundStyle(Color(uiColor: .systemRed))
								.frame(maxWidth: .infinity)
								.frame(height: 54)
								.background(Color(uiColor: .systemRed).opacity(0.10), in: Capsule())
						}
						.buttonStyle(.plain)
						.disabled(chatHistoryViewModel.chats.isEmpty)
						.opacity(chatHistoryViewModel.chats.isEmpty ? 0.55 : 1)
					}

					SettingsFooterView {
						safariViewModel.open(URL(string: "https://semera.co")!)
					}
				}
				.padding(.horizontal, 14)
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
			.sheet(item: $safariViewModel.page) { page in
				SafariView(url: page.url)
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

	private func requestNotificationPermission() {
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
			Task { @MainActor in
				notificationsEnabled = granted
			}
		}
	}
}

private struct WhyLocalModelsView: View {
	private let openingParagraphs = [
		"Artificial intelligence is quickly becoming one of the most powerful technologies of our time, but today much of it depends on cloud infrastructure, subscriptions, and a reliable internet connection. We believe AI should be available wherever people are, not just where powerful servers are.",
		"Local models run directly on your device. That means they can continue working on a plane, while traveling, in classrooms with unreliable connectivity, or anywhere an internet connection isn’t guaranteed. It also gives people more control over their conversations and reduces the need to send personal information to external services.",
		"As mobile hardware continues to improve, we’re entering a new era where capable AI can live alongside the apps we use every day. Instead of relying on distant servers for every interaction, our devices are becoming intelligent companions that are faster, more personal, and available the moment we need them."
	]

	private let closingParagraphs = [
		"At Semera, we don’t see local AI as a replacement for cloud intelligence. We see it as an important part of a future where people can choose the experience that best fits their needs. Some questions will benefit from the web. Others should stay entirely on your device. Great software should make that choice feel effortless.",
		"Most importantly, local AI has the potential to make powerful technology more accessible. Students, educators, creators, travelers, healthcare workers, and communities with limited infrastructure shouldn’t be left behind because they lack a constant internet connection or the resources to pay for cloud services. As models become smaller, faster, and more capable, we believe AI can reach more people than ever before.",
		"Our goal isn’t simply to bring AI onto your device. It’s to explore how on-device intelligence can create experiences that feel more private, more reliable, and ultimately more human."
	]

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				header

				ForEach(openingParagraphs, id: \.self) { paragraph in
					bodyText(paragraph)
				}

				Image("whylocal")
					.resizable()
					.scaledToFill()
					.frame(maxWidth: .infinity)
					.frame(height: 220)
					.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
					.clipped()

				ForEach(closingParagraphs, id: \.self) { paragraph in
					bodyText(paragraph)
				}
			}
			.padding(.horizontal, 20)
			.padding(.top, 18)
			.padding(.bottom, 42)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.background(Color(uiColor: .systemGroupedBackground))
		.navigationTitle("Why Local AI?")
		#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Why Local AI?")
				.font(.system(size: 28, weight: .semibold))
				.foregroundStyle(.primary)

			Text("A more private, reliable, and accessible direction for intelligent software.")
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(.secondary)
				.lineSpacing(4)
		}
	}

	private func bodyText(_ text: String) -> some View {
		Text(text)
			.font(.system(size: 17, weight: .regular))
			.foregroundStyle(.primary)
			.lineSpacing(5)
	}
}

#Preview {
	SettingsView(chatHistoryViewModel: ChatHistoryViewModel(conversations: []))
}
