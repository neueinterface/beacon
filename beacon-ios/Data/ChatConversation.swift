import Foundation

struct ChatConversation: Identifiable, Hashable, Codable {
	let id: UUID
	var modelName: String
	var messages: [ChatMessage]
	var updatedAt: Date

	init(id: UUID = UUID(), modelName: String, messages: [ChatMessage], updatedAt: Date = .now) {
		self.id = id
		self.modelName = modelName
		self.messages = messages
		self.updatedAt = updatedAt
	}

	var historyTitle: String {
		messages.first { $0.role == .user && !$0.text.isEmpty }?.text ?? "New chat"
	}
}
