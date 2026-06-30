import Combine
import Foundation

@MainActor
final class ChatHistoryViewModel: ObservableObject {
	@Published private(set) var conversations: [ChatConversation] {
		didSet { saveConversations() }
	}
	@Published private(set) var currentMessages: [ChatMessage]
	@Published var selectedChatID: ChatConversation.ID?

	private static let storageKey = "chatConversations"
	private static let readyMessageText = "Your model is ready."

	private let timeFormatter: DateFormatter
	private let calendar = Calendar.current
	private var currentConversationID: ChatConversation.ID?

	var chats: [ChatConversation] {
		conversations.sorted { $0.updatedAt > $1.updatedAt }
	}

	var currentChatID: ChatConversation.ID? {
		currentConversationID
	}

	init(conversations: [ChatConversation]? = nil) {
		self.conversations = Self.sanitized(conversations ?? Self.loadConversations()).sorted { $0.updatedAt > $1.updatedAt }
		self.currentMessages = []

		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		self.timeFormatter = formatter
	}

	func select(_ chat: ChatConversation) {
		selectedChatID = chat.id
		currentConversationID = chat.id
		currentMessages = chat.messages
	}

	@discardableResult
	func selectChat(id: ChatConversation.ID) -> ChatConversation? {
		guard let chat = conversations.first(where: { $0.id == id }) else { return nil }
		select(chat)
		return chat
	}

	func startNewChat() {
		selectedChatID = nil
		currentConversationID = nil
		currentMessages = []
	}

	func delete(_ chat: ChatConversation) {
		conversations.removeAll { $0.id == chat.id }

		if currentConversationID == chat.id || selectedChatID == chat.id {
			selectedChatID = nil
			currentConversationID = nil
			currentMessages = []
		}
	}

	func clearAll() {
		conversations.removeAll()
		selectedChatID = nil
		currentConversationID = nil
		currentMessages = []
	}

	func appendUserMessage(_ text: String, modelName: String) -> ChatMessage.ID {
		let userMessage = ChatMessage(text: text, role: .user)
		let assistantMessage = ChatMessage(text: "", modelName: modelName, role: .assistant)

		if let currentConversationID, let index = conversations.firstIndex(where: { $0.id == currentConversationID }) {
			conversations[index].messages.append(userMessage)
			conversations[index].messages.append(assistantMessage)
			conversations[index].updatedAt = .now
			currentMessages = conversations[index].messages
		} else {
			let conversation = ChatConversation(
				modelName: modelName,
				messages: [userMessage, assistantMessage]
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

	func appendAssistantThinking(_ chunk: String, to messageID: ChatMessage.ID) {
		updateMessage(messageID) { message in
			message.thinkingText += chunk
		}
	}

	func replaceAssistantSources(_ sources: [Source], for messageID: ChatMessage.ID) {
		updateMessage(messageID) { message in
			message.sources = sources
		}
	}

	func replaceMessage(_ messageID: ChatMessage.ID, with text: String) {
		updateMessage(messageID) { message in
			message.text = text
		}
	}

	func formattedTime(for chat: ChatConversation) -> String {
		if calendar.isDateInToday(chat.updatedAt) {
			return timeFormatter.string(from: chat.updatedAt)
		}

		let startOfToday = calendar.startOfDay(for: .now)
		let startOfChatDay = calendar.startOfDay(for: chat.updatedAt)
		let daysAgo = calendar.dateComponents([.day], from: startOfChatDay, to: startOfToday).day ?? 0

		if daysAgo <= 1 {
			return "Yesterday"
		}

		if daysAgo < 7 {
			return "\(daysAgo) days ago"
		}

		if daysAgo < 30 {
			return relativeLabel(value: max(1, daysAgo / 7), unit: "week")
		}

		if daysAgo < 365 {
			return relativeLabel(value: max(1, daysAgo / 30), unit: "month")
		}

		return relativeLabel(value: max(1, daysAgo / 365), unit: "year")
	}

	private func relativeLabel(value: Int, unit: String) -> String {
		if value == 1 {
			return "1 \(unit) ago"
		}

		return "\(value) \(unit)s ago"
	}

	func lastUserMessageID(in chat: ChatConversation) -> ChatMessage.ID? {
		chat.messages.last { $0.role == .user }?.id
	}

	func firstMessageID(in chat: ChatConversation) -> ChatMessage.ID? {
		chat.messages.first?.id
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

	private static func sanitized(_ conversations: [ChatConversation]) -> [ChatConversation] {
		conversations.map { conversation in
			var conversation = conversation
			conversation.messages.removeAll { message in
				message.role == .assistant && message.text == readyMessageText
			}
			return conversation
		}
	}
}
