import Foundation

struct ChatMessage: Identifiable, Hashable, Codable {
	enum Role: Hashable, Codable {
		case user
		case assistant
	}

	let id: UUID
	var text: String
	let role: Role

	init(id: UUID = UUID(), text: String, role: Role) {
		self.id = id
		self.text = text
		self.role = role
	}
}
