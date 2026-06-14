import Combine
import Foundation

@MainActor
final class ChatHistoryViewModel: ObservableObject {
	@Published private(set) var conversations: [ChatConversation] {
		didSet { saveConversations() }
	}
	@Published private(set) var currentMessages: [ChatMessage]
	@Published var selectedChatID: StartedChat.ID?

	private static let storageKey = "chatConversations"

	private let timeFormatter: DateFormatter
	private var currentConversationID: ChatConversation.ID?
	private let readyMessage = ChatMessage(text: "Your model is ready.", role: .assistant)

	var chats: [StartedChat] {
		conversations
			.sorted { $0.updatedAt > $1.updatedAt }
			.map {
				StartedChat(
					id: $0.id,
					firstMessage: $0.historyTitle,
					modelName: $0.modelName,
					updatedAt: $0.updatedAt,
					unreadCount: 0
				)
			}
	}

	init(conversations: [ChatConversation]? = nil) {
		self.conversations = (conversations ?? Self.loadConversations()).sorted { $0.updatedAt > $1.updatedAt }
		self.currentMessages = [readyMessage]

		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		self.timeFormatter = formatter
	}

	func select(_ chat: StartedChat) {
		selectedChatID = chat.id
		currentConversationID = chat.id
		currentMessages = conversations.first { $0.id == chat.id }?.messages ?? [readyMessage]
	}

	func startNewChat() {
		selectedChatID = nil
		currentConversationID = nil
		currentMessages = [readyMessage]
	}

	func appendUserMessage(_ text: String, modelName: String) -> ChatMessage.ID {
		let userMessage = ChatMessage(text: text, role: .user)
		let assistantMessage = ChatMessage(text: "", role: .assistant)

		if let currentConversationID, let index = conversations.firstIndex(where: { $0.id == currentConversationID }) {
			conversations[index].messages.append(userMessage)
			conversations[index].messages.append(assistantMessage)
			conversations[index].updatedAt = .now
			currentMessages = conversations[index].messages
		} else {
			let conversation = ChatConversation(
				modelName: modelName,
				messages: [readyMessage, userMessage, assistantMessage]
			)
			conversations.insert(conversation, at: 0)
			currentConversationID = conversation.id
			selectedChatID = conversation.id
			currentMessages = conversation.messages
		}

		return assistantMessage.id
	}

	func appendAssistantChunk(_ chunk: String, to messageID: ChatMessage.ID) {
		updateMessage(messageID) { message in
			message.text += chunk
		}
	}

	func replaceMessage(_ messageID: ChatMessage.ID, with text: String) {
		updateMessage(messageID) { message in
			message.text = text
		}
	}

	func formattedTime(for chat: StartedChat) -> String {
		timeFormatter.string(from: chat.updatedAt)
	}

	private func updateMessage(_ messageID: ChatMessage.ID, mutate: (inout ChatMessage) -> Void) {
		guard let currentConversationID,
			  let conversationIndex = conversations.firstIndex(where: { $0.id == currentConversationID }),
			  let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }

		mutate(&conversations[conversationIndex].messages[messageIndex])
		conversations[conversationIndex].updatedAt = .now
		currentMessages = conversations[conversationIndex].messages
	}

	private func saveConversations() {
		guard let data = try? JSONEncoder().encode(conversations) else { return }
		UserDefaults.standard.set(data, forKey: Self.storageKey)
	}

	private static func loadConversations() -> [ChatConversation] {
		guard let data = UserDefaults.standard.data(forKey: storageKey),
			  let conversations = try? JSONDecoder().decode([ChatConversation].self, from: data) else {
			return []
		}

		return conversations
	}
}
