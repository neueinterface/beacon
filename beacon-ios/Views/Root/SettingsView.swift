//
//  SettingsView.swift
//  beacon-ios
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
			List {
				Section {
					SettingsRow(
						title: "Delete All Chats",
						detail: chatCountText,
						icon: "trash",
						role: .destructive
					) {
						isConfirmingDeleteAllChats = true
					}
					.disabled(chatHistoryViewModel.chats.isEmpty)
				} header: {
					Text("Chat History")
				} footer: {
					Text("This removes saved conversations from this device. It does not delete downloaded models.")
				}

				Section("Legal") {
					NavigationLink {
						SettingsTextDetailView(title: "Privacy Policy", paragraphs: privacyPolicyParagraphs)
					} label: {
						SettingsNavigationLabel(title: "Privacy Policy", subtitle: "Local-first data handling", icon: "lock")
					}

					NavigationLink {
						SettingsTextDetailView(title: "Terms", paragraphs: termsParagraphs)
					} label: {
						SettingsNavigationLabel(title: "Terms", subtitle: "Basic app usage terms", icon: "doc.text")
					}
				}

				Section("Model Licenses") {
					NavigationLink {
						ModelLicensesPlaceholderView()
					} label: {
						SettingsNavigationLabel(title: "Model Licenses", subtitle: "Coming soon", icon: "scroll")
					}
				}
			}
			.navigationTitle("Settings")
			.navigationBarTitleDisplayMode(.large)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Done") {
						dismiss()
					}
					.font(.system(size: 16, weight: .semibold))
				}
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
			"Beacon is designed to keep chats and downloaded models on your device.",
			"Your saved conversations are stored locally on this iPhone. Deleting all chats removes those saved conversations from local app storage.",
			"Downloaded models are stored locally so Beacon can run them on-device. You can remove downloaded models from the model marketplace.",
			"Beacon does not require an account for local chat. If future features use network services, this policy should be updated before those features ship."
		]
	}

	private var termsParagraphs: [String] {
		[
			"Beacon provides local AI chat tools and model management features.",
			"AI responses can be inaccurate. Review important information before relying on it.",
			"Downloaded models may be governed by their own licenses and usage terms. Review model licenses before using a model for sensitive, commercial, or redistributed work.",
			"These basic terms are a placeholder and should be replaced with final legal terms before public release."
		]
	}
}

private struct SettingsRow: View {
	let title: String
	let detail: String
	let icon: String
	var role: ButtonRole?
	var action: () -> Void

	var body: some View {
		Button(role: role, action: action) {
			SettingsNavigationLabel(title: title, subtitle: detail, icon: icon)
		}
	}
}

private struct SettingsNavigationLabel: View {
	let title: String
	let subtitle: String
	let icon: String

	var body: some View {
		HStack(spacing: 14) {
			Image(systemName: icon)
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(.primary)
				.frame(width: 34, height: 34)
				.background(Color(uiColor: .secondarySystemBackground), in: Circle())

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(.primary)

				Text(subtitle)
					.font(.system(size: 13, weight: .regular))
					.foregroundStyle(.secondary)
			}
		}
		.padding(.vertical, 4)
	}
}

private struct SettingsTextDetailView: View {
	let title: String
	let paragraphs: [String]

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				ForEach(paragraphs, id: \.self) { paragraph in
					Text(paragraph)
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(4)
				}
			}
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.navigationTitle(title)
		.navigationBarTitleDisplayMode(.inline)
	}
}

private struct ModelLicensesPlaceholderView: View {
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Text("Model licenses will live here.")
					.font(.system(size: 24, weight: .medium))
					.foregroundStyle(.primary)

				Text("Add license details, source links, and usage notes for each downloadable model before release.")
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(.secondary)
					.lineSpacing(4)
			}
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.navigationTitle("Model Licenses")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	SettingsView(chatHistoryViewModel: ChatHistoryViewModel(conversations: []))
}
