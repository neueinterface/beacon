import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChatHistoryDrawerView: View {
	@ObservedObject var viewModel: ChatHistoryViewModel
	var onClose: () -> Void
	var onNewChat: () -> Void
	var onOpenModels: () -> Void = { }
	var onOpenSettings: () -> Void = { }
	var onSelect: (ChatConversation) -> Void

	var body: some View {
		NavigationStack {
			ZStack(alignment: .bottomTrailing) {
				historyContent

				BeaconButton("New Chat", size: .large, leadingAssetIcon: "chat.icon", action: onNewChat)
					.padding(.trailing, 20)
					.padding(.bottom, 24)
			}
			.background(Color(uiColor: .systemBackground))
			.navigationTitle("")
			#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
			.toolbarRole(.navigationStack)
			.toolbarVisibility(.visible, for: .navigationBar)
			#endif
			.toolbar {
				#if os(macOS)
				ToolbarItemGroup(placement: .automatic) {
					historyToolbarButtons
				}
				#else
				ToolbarItem(placement: .topBarLeading) {
					Button {
						playHeaderHaptic()
						onOpenModels()
					} label: {
						Image("playground.icon")
							.renderingMode(.template)
					}
					.accessibilityLabel("Open models")
				}

				ToolbarItemGroup(placement: .topBarTrailing) {
					Button {
						playHeaderHaptic()
						onOpenSettings()
					} label: {
						Image("settings.icon")
							.renderingMode(.template)
					}
					.accessibilityLabel("Open settings")

					Button {
						playHeaderHaptic()
						onClose()
					} label: {
						Image(systemName: "arrow.right")
					}
					.accessibilityLabel("Close chat history")
				}
				#endif
			}
		}
	}

	@ViewBuilder
	private var historyContent: some View {
		if viewModel.chats.isEmpty {
			ScrollView {
				emptyState
			}
			.scrollEdgeEffectStyle(.soft, for: .top)
		} else {
			List {
				ForEach(Array(viewModel.chats.enumerated()), id: \.element.id) { index, chat in
					ChatHistoryRow(
						chat: chat,
						timeText: viewModel.formattedTime(for: chat),
						showsDivider: index < viewModel.chats.count - 1
					) {
						viewModel.select(chat)
						onSelect(chat)
					}
					.listRowInsets(EdgeInsets())
					.listRowSeparator(.hidden)
					.listRowBackground(Color(uiColor: .systemBackground))
					.swipeActions(edge: .trailing, allowsFullSwipe: true) {
						Button(role: .destructive) {
							withAnimation(.smooth(duration: 0.24)) {
								viewModel.delete(chat)
							}
						} label: {
							Label("Delete", systemImage: "trash")
						}
					}
				}
			}
			.listStyle(.plain)
			.scrollContentBackground(.hidden)
			.scrollEdgeEffectStyle(.soft, for: .top)
		}
	}

	private var historyToolbarButtons: some View {
		Group {
			Button {
				playHeaderHaptic()
				onOpenModels()
			} label: {
				Image("playground.icon")
					.renderingMode(.template)
			}

			Button {
				playHeaderHaptic()
				onOpenSettings()
			} label: {
				Image("settings.icon")
					.renderingMode(.template)
			}

			Button {
				playHeaderHaptic()
				onClose()
			} label: {
				Image(systemName: "arrow.right")
			}
		}
	}

	private func playHeaderHaptic() {
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		#endif
	}

	private var emptyState: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text("No chat history yet.")
				.font(.system(size: 24, weight: .medium))
				.foregroundStyle(.primary)

			Text("Your conversations will show up here after you send your first message.")
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(.secondary)
				.lineSpacing(3)
		}
		.padding(.horizontal, 20)
		.padding(.top, 16)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
}

private struct ChatHistoryRow: View {
	let chat: ChatConversation
	let timeText: String
	let showsDivider: Bool
	var onSelect: () -> Void

	private var usedModelNames: [String] {
		chat.usedModelNames
	}

	private var modelTagTitle: String {
		guard usedModelNames.count > 1 else { return usedModelNames.first ?? chat.modelName }
		return "\(usedModelNames.count) models"
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			VStack(alignment: .leading, spacing: 18) {
				HStack(alignment: .firstTextBaseline, spacing: 14) {
					Text(chat.historyTitle)
						.font(.system(size: 14, weight: .medium))
						.foregroundStyle(.primary)
						.lineLimit(1)

					Spacer(minLength: 12)

					Text(timeText)
						.font(.system(size: 12, weight: .medium))
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}

				if usedModelNames.count > 1 {
					Menu {
						ForEach(usedModelNames, id: \.self) { modelName in
							Button(modelName) {}
						}
					} label: {
						HStack(spacing: 6) {
							Tag(title: modelTagTitle, color: .indigo)

							Image(systemName: "chevron.up.chevron.down")
								.font(.system(size: 10, weight: .bold))
								.foregroundStyle(.indigo)
						}
					}
				} else {
					Tag(title: modelTagTitle, color: .indigo)
				}
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 24)

			if showsDivider {
				Divider()
					.frame(maxWidth: .infinity)
					.padding(.horizontal, 20)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.contentShape(Rectangle())
		.onTapGesture(perform: onSelect)
	}
}

#Preview("Chat History") {
	ChatHistoryDrawerView(
		viewModel: ChatHistoryViewModel(conversations: ChatHistoryPreviewData.conversations),
		onClose: { },
		onNewChat: { },
		onOpenModels: { }
	) { _ in }
}

#Preview("Empty Chat History") {
	ChatHistoryDrawerView(
		viewModel: ChatHistoryViewModel(conversations: []),
		onClose: { },
		onNewChat: { },
		onOpenModels: { }
	) { _ in }
}

private enum ChatHistoryPreviewData {
	static let conversations: [ChatConversation] = [
		ChatConversation(
			modelName: "minimax-m3",
			messages: [
				ChatMessage(text: "How old can bulldogs live till?", role: .user),
				ChatMessage(text: "Most bulldogs live 8 to 10 years.", modelName: "minimax-m3", role: .assistant),
				ChatMessage(text: "Can you compare with pugs?", role: .user),
				ChatMessage(text: "Pugs often live slightly longer, around 12 to 15 years.", modelName: "maximus-b4", role: .assistant)
			],
			updatedAt: Calendar.current.date(bySettingHour: 18, minute: 12, second: 0, of: .now) ?? .now
		),
		ChatConversation(
			modelName: "maximus-b4",
			messages: [
				ChatMessage(text: "What is the average weight of a bulldog?", role: .user),
				ChatMessage(text: "Adult bulldogs usually weigh 40 to 50 pounds.", role: .assistant)
			],
			updatedAt: Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: .now) ?? .now
		),
		ChatConversation(
			modelName: "bella-x2",
			messages: [
				ChatMessage(text: "What is the lifespan of a bulldog?", role: .user),
				ChatMessage(text: "Usually 8 to 10 years, depending on health and care.", role: .assistant)
			],
			updatedAt: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
		),
		ChatConversation(
			modelName: "charlie-a3",
			messages: [
				ChatMessage(text: "What are the common health issues for bulldogs?", role: .user),
				ChatMessage(text: "Breathing, skin, joint, and overheating issues are common.", role: .assistant)
			],
			updatedAt: Calendar.current.date(bySettingHour: 10, minute: 15, second: 0, of: .now) ?? .now
		),
		ChatConversation(
			modelName: "daisy-c1",
			messages: [
				ChatMessage(text: "How often should bulldogs be exercised?", role: .user),
				ChatMessage(text: "Short daily walks and gentle play are best.", role: .assistant)
			],
			updatedAt: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: .now) ?? .now
		),
		ChatConversation(
			modelName: "rocky-d5",
			messages: [
				ChatMessage(text: "What is the ideal diet for a bulldog?", role: .user),
				ChatMessage(text: "A balanced diet with controlled portions helps prevent obesity.", role: .assistant)
			],
			updatedAt: Calendar.current.date(bySettingHour: 13, minute: 30, second: 0, of: .now) ?? .now
		)
	]
}
