import SwiftUI

struct SettingsView: View {
	@ObservedObject var chatHistoryViewModel: ChatHistoryViewModel
	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL
	@AppStorage("notificationsEnabled") private var notificationsEnabled = true
	@State private var isConfirmingDeleteAllChats = false

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

						SettingsToggleRow(title: "Notifications", icon: "bell.icon", isOn: $notificationsEnabled)
						SettingsListDivider()

						SettingsButtonRow(title: "Report a bug", icon: "bug.icon") {
							openURL(URL(string: "mailto:semeraco@gmail.com?subject=Semera%20Bug%20Report")!)
						}
						SettingsListDivider()

						SettingsButtonRow(title: "Leave a review in the App Store", icon: "review.icon") {
							openURL(URL(string: "https://semera.co")!)
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

					SettingsFooterView()
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
}

#Preview {
	SettingsView(chatHistoryViewModel: ChatHistoryViewModel(conversations: []))
}
