import SwiftUI

struct ChatHistoryDrawerView: View {
	@ObservedObject var viewModel: ChatHistoryViewModel
	var onClose: () -> Void
	var onNewChat: () -> Void
	var onOpenModels: () -> Void = { }
	var onSelect: (StartedChat) -> Void

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			VStack(alignment: .leading, spacing: 0) {
				header

				if viewModel.chats.isEmpty {
					emptyState
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
				}
			}

			Button(action: onNewChat) {
				HStack(spacing: 12) {
					Image("chat.icon")
						.renderingMode(.template)
						.resizable()
						.scaledToFit()
						.frame(width: 24, height: 24)

					Text("New Chat")
						.font(.system(size: 18, weight: .semibold))
				}
				.foregroundStyle(.white)
				.padding(.horizontal, 24)
				.frame(height: 60)
				.background(.black, in: Capsule())
				.shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)
			}
			.buttonStyle(SpringButtonStyle())
			.padding(.trailing, 20)
			.padding(.bottom, 24)
		}
		.background(Color(uiColor: .systemBackground))
	}

	private var header: some View {
		HStack(spacing: 16) {
			ChatHistoryGlassPill(title: "Models", assetIcon: "playground.icon", action: onOpenModels)

			Spacer()

			ChatHistoryGlassIconButton("settings.icon") { }
			ChatHistoryGlassIconButton(systemName: "arrow.right", action: onClose)
		}
		.padding(.horizontal, 20)
		.padding(.top, 20)
		.padding(.bottom, 40)
		.background(alignment: .top) {
			LinearGradient(
				colors: [
					Color(uiColor: .systemBackground),
					Color(uiColor: .systemBackground).opacity(0.92),
					Color(uiColor: .systemBackground).opacity(0)
				],
				startPoint: .top,
				endPoint: .bottom
			)
			.frame(height: 132)
		}
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

private struct ChatHistoryGlassPill: View {
	let title: String
	let assetIcon: String
	var action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: 10) {
				Image(assetIcon)
					.renderingMode(.template)
					.resizable()
					.scaledToFit()
					.frame(width: 24, height: 24)

				Text(title)
					.font(.system(size: 21, weight: .medium))
			}
			.foregroundStyle(.primary)
			.padding(.horizontal, 18)
			.frame(height: 52)
			.background(Color(uiColor: .systemGray6), in: Capsule())
			.shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
		}
		.buttonStyle(SpringButtonStyle())
	}
}

private struct ChatHistoryGlassIconButton: View {
	let assetIcon: String?
	let systemName: String?
	var action: () -> Void

	init(_ assetIcon: String, action: @escaping () -> Void) {
		self.assetIcon = assetIcon
		self.systemName = nil
		self.action = action
	}

	init(systemName: String, action: @escaping () -> Void) {
		self.assetIcon = nil
		self.systemName = systemName
		self.action = action
	}

	var body: some View {
		Button(action: action) {
			icon
				.foregroundStyle(.primary)
				.frame(width: 52, height: 52)
				.background(Color(uiColor: .systemGray6), in: Circle())
				.shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
		}
		.buttonStyle(SpringButtonStyle())
	}

	@ViewBuilder
	private var icon: some View {
		if let assetIcon {
			Image(assetIcon)
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
				.frame(width: 25, height: 25)
		} else if let systemName {
			Image(systemName: systemName)
				.font(.system(size: 25, weight: .regular))
		}
	}
}

private struct ChatHistoryRow: View {
	let chat: StartedChat
	let timeText: String
	let showsDivider: Bool
	var onSelect: () -> Void

	var body: some View {
		Button(action: onSelect) {
			VStack(alignment: .leading, spacing: 0) {
				VStack(alignment: .leading, spacing: 18) {
				HStack(alignment: .firstTextBaseline, spacing: 14) {
					Text(chat.firstMessage)
						.font(.system(size: 18, weight: .medium))
						.foregroundStyle(.primary)
						.lineLimit(1)

					Spacer(minLength: 12)

					Text(timeText)
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}

				Tag(title: chat.modelName, color: .gray)
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
		}
		.buttonStyle(.plain)
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
				ChatMessage(text: "Most bulldogs live 8 to 10 years.", role: .assistant)
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
