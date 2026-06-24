//
//  SettingsView.swift
//  sonara-ios
//
//  Created by Armond Schneider on 6/16/26.
//

import SwiftUI

struct SettingsView: View {
	@ObservedObject var chatHistoryViewModel: ChatHistoryViewModel
	@Environment(\.dismiss) private var dismiss
	@State private var isConfirmingDeleteAllChats = false

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {
					SettingsCard(title: "Chat History", caption: "Manage conversations saved on this device.") {
						SettingsActionRow(
							title: "Delete All Chats",
							subtitle: chatCountText,
							icon: "trash",
							style: .destructive,
							isDisabled: chatHistoryViewModel.chats.isEmpty
						) {
							isConfirmingDeleteAllChats = true
						}
					}

					SettingsCard(title: "Appearance", caption: "Customize how Sonara looks on your Home Screen.") {
						SettingsNavigationRow(title: "App Icon", subtitle: "Choose from 6 icon options", icon: "app.badge") {
							AppIconPickerView()
						}
					}

					SettingsCard(title: "Legal", caption: "Local-first policies and usage notes.") {
						SettingsNavigationRow(title: "Privacy Policy", subtitle: "Local-first data handling", icon: "lock") {
							SettingsTextDetailView(title: "Privacy Policy", paragraphs: privacyPolicyParagraphs)
						}

						SettingsDivider()

						SettingsNavigationRow(title: "Terms", subtitle: "Basic app usage terms", icon: "doc.text") {
							SettingsTextDetailView(title: "Terms", paragraphs: termsParagraphs)
						}
					}

					SettingsCard(title: "Models", caption: "Review model attribution before public release.") {
						SettingsNavigationRow(title: "Model Licenses", subtitle: "Coming soon", icon: "scroll") {
							ModelLicensesPlaceholderView()
						}
					}
				}
				.padding(.horizontal, 20)
				.padding(.top, 12)
				.padding(.bottom, 34)
			}
			.scrollEdgeEffectStyle(.soft, for: .top)
			.background(Color(uiColor: .systemGroupedBackground))
			.navigationTitle("Settings")
			#if !os(macOS)
			.navigationBarTitleDisplayMode(.large)
			.toolbarVisibility(.visible, for: .navigationBar)
			#endif
			.toolbar {
				#if os(macOS)
				ToolbarItem(placement: .automatic) {
					Button("Done") {
						dismiss()
					}
					.font(.system(size: 16, weight: .semibold))
				}
				#else
				ToolbarItem(placement: .topBarTrailing) {
					Button("Done") {
						dismiss()
					}
					.font(.system(size: 16, weight: .semibold))
				}
				#endif
			}
			.confirmationDialog(
				"Delete all chats?",
				isPresented: $isConfirmingDeleteAllChats,
				titleVisibility: .visible
			) {
				Button("Delete All Chats", role: .destructive) {
					withAnimation(.smooth(duration: 0.24)) {
						chatHistoryViewModel.clearAll()
					}
				}

				Button("Cancel", role: .cancel) { }
			} message: {
				Text("This cannot be undone.")
			}
		}
	}

	private var chatCountText: String {
		let count = chatHistoryViewModel.chats.count
		return count == 1 ? "1 saved chat" : "\(count) saved chats"
	}

	private var privacyPolicyParagraphs: [String] {
		[
			"Sonara is designed to keep chats and downloaded models on your device.",
			"Your saved conversations are stored locally on this iPhone. Deleting all chats removes those saved conversations from local app storage.",
			"Downloaded models are stored locally so Sonara can run them on-device. You can remove downloaded models from the model marketplace.",
			"Sonara does not require an account for local chat. If future features use network services, this policy should be updated before those features ship."
		]
	}

	private var termsParagraphs: [String] {
		[
			"Sonara provides local AI chat tools and model management features.",
			"AI responses can be inaccurate. Review important information before relying on it.",
			"Downloaded models may be governed by their own licenses and usage terms. Review model licenses before using a model for sensitive, commercial, or redistributed work.",
			"These basic terms are a placeholder and should be replaced with final legal terms before public release."
		]
	}
}

#Preview {
	SettingsView(chatHistoryViewModel: ChatHistoryViewModel(conversations: []))
}
