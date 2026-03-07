//
//  ChatHistoryView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI

struct ChatHistoryView: View {
	let chats: [StartedChat]

	var body: some View {
		NavigationStack {
			List {
				ForEach(chats) { chat in
					VStack(alignment: .leading, spacing: 6) {
						HStack {
							Text(chat.firstMessage)
								.font(.body.weight(.medium))
							@State private var chats: [StartedChat]
							@State private var search = ""
							@State private var selection: UUID?

							init(chats: [StartedChat]) {
								_chats = State(initialValue: chats)
							}

							Spacer()

									ZStack {
										List(selection: $selection) {
											ForEach(filteredChats) { chat in
												VStack(alignment: .leading, spacing: 6) {
													HStack {
														Text(chat.firstMessage)
															.font(.body.weight(.medium))
															.lineLimit(2)

														Spacer()

														Text(chat.updatedAt, style: .relative)
															.font(.caption)
															.foregroundStyle(.secondary)
													}

													Text(chat.modelName)
														.font(.caption)
														.foregroundStyle(.secondary)

													if chat.unreadCount > 0 {
														Text("\(chat.unreadCount) new")
															.font(.caption.weight(.semibold))
															.padding(.horizontal, 8)
															.padding(.vertical, 3)
															.background(Color(UIColor.systemGray5), in: Capsule())
													}
												}
												.padding(.vertical, 6)
												.tag(chat.id)
											}
											.onDelete(perform: deleteChats)
										}

										if filteredChats.isEmpty {
											ContentUnavailableView(
												search.isEmpty ? "No chats yet" : "No results",
												systemImage: "message"
											)
										}
			id: UUID(),
									.navigationTitle("Chats")
									.navigationBarTitleDisplayMode(.inline)
									.searchable(text: $search, prompt: "Search")
									.toolbar {
										ToolbarItem(placement: .topBarTrailing) {
											Button {
												createNewChat()
											} label: {
												Image(systemName: "plus")
											}
										}
									}
			modelName: "Code Assistant",
			updatedAt: .now.addingTimeInterval(-2000),

							private var filteredChats: [StartedChat] {
								chats.filter { chat in
									search.isEmpty || chat.firstMessage.localizedCaseInsensitiveContains(search)
								}
							}

							private func createNewChat() {
								chats.insert(
									StartedChat(
										id: UUID(),
										firstMessage: "New chat",
										modelName: "Llama 3.2 3B",
										updatedAt: .now,
										unreadCount: 0
									),
									at: 0
								)
							}

							private func deleteChats(at offsets: IndexSet) {
								let idsToDelete = offsets.map { filteredChats[$0].id }
								chats.removeAll { idsToDelete.contains($0.id) }
							}
			unreadCount: 1
		),
		StartedChat(
			id: UUID(),
			firstMessage: "Break this refactor into small milestones.",
			modelName: "DeepSeek Distill",
			updatedAt: .now.addingTimeInterval(-8200),
			unreadCount: 0
		)
	])
}

