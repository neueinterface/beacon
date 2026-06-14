import SwiftUI

struct ChatHistoryDrawerView: View {
	@ObservedObject var viewModel: ChatHistoryViewModel
	var onClose: () -> Void
	var onNewChat: () -> Void
	var onSelect: (StartedChat) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			header

			if viewModel.chats.isEmpty {
				emptyState
			} else {
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 0) {
						ForEach(Array(viewModel.chats.enumerated()), id: \.element.id) { index, chat in
							ChatHistoryRow(
								chat: chat,
								timeText: viewModel.formattedTime(for: chat)
							) {
								viewModel.select(chat)
								onSelect(chat)
							}

							if index < viewModel.chats.count - 1 {
								Divider()
									.padding(.horizontal, 20)
							}
						}
					}
				}
			}
		}
		.background(Color(uiColor: .systemBackground))
	}

	private var header: some View {
		HStack(spacing: 12) {
			Button(action: onClose) {
				Image(systemName: "chevron.left")
					.font(.system(size: 17, weight: .semibold))
					.frame(width: 34, height: 34)
					.foregroundStyle(.primary)
			}
			.buttonStyle(.plain)

			Text("History")
				.font(.system(size: 20, weight: .medium))
				.foregroundStyle(.primary)

			Spacer()

			Button(action: onNewChat) {
				Image(systemName: "square.and.pencil")
					.font(.system(size: 17, weight: .semibold))
					.frame(width: 34, height: 34)
					.foregroundStyle(.primary)
			}
			.buttonStyle(.plain)
		}
		.padding(.horizontal, 20)
		.padding(.top, 28)
		.padding(.bottom, 18)
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

			BeaconButton("Start a chat", variant: .secondary, trailingIcon: "arrow.right", action: onNewChat)
				.padding(.top, 8)
		}
		.padding(.horizontal, 20)
		.padding(.top, 48)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
}

private struct ChatHistoryRow: View {
	let chat: StartedChat
	let timeText: String
	var onSelect: () -> Void

	var body: some View {
		Button(action: onSelect) {
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
			.frame(maxWidth: .infinity, alignment: .leading)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
}

#Preview {
	ChatHistoryDrawerView(viewModel: ChatHistoryViewModel(), onClose: { }, onNewChat: { }) { _ in }
}
