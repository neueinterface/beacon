import Foundation

struct ChatConversation: Identifiable, Hashable, Codable {
	let id: UUID
	var modelName: String
	var messages: [ChatMessage]
	var updatedAt: Date
	var personality: ChatPersonality?

	init(id: UUID = UUID(), modelName: String, messages: [ChatMessage], updatedAt: Date = .now, personality: ChatPersonality? = nil) {
		self.id = id
		self.modelName = modelName
		self.messages = messages
		self.updatedAt = updatedAt
		self.personality = personality
	}

	private enum CodingKeys: String, CodingKey {
		case id, modelName, messages, updatedAt, personality
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		modelName = try container.decode(String.self, forKey: .modelName)
		messages = try container.decode([ChatMessage].self, forKey: .messages)
		updatedAt = try container.decode(Date.self, forKey: .updatedAt)
		personality = try container.decodeIfPresent(ChatPersonality.self, forKey: .personality)
	}

	var historyTitle: String {
		messages.first { $0.role == .user && !$0.text.isEmpty }?.text ?? "New chat"
	}

	var usedModelNames: [String] {
		var names: [String] = []

		if !modelName.isEmpty {
			names.append(modelName)
		}

		for message in messages {
			guard let modelName = message.modelName, !modelName.isEmpty, !names.contains(modelName) else { continue }
			names.append(modelName)
		}

		return names
	}
}
