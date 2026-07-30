import Foundation

struct ChatMessage: Identifiable, Hashable, Codable {
	enum Role: Hashable, Codable {
		case user
		case assistant
	}

	let id: UUID
	var text: String
	var thinkingText: String
	var sources: [Source]
	var imageData: Data?
	var didStoreMemory: Bool
	var requiresVisionModel: Bool
	var modelName: String?
	let role: Role

	init(id: UUID = UUID(), text: String, thinkingText: String = "", sources: [Source] = [], imageData: Data? = nil, didStoreMemory: Bool = false, requiresVisionModel: Bool = false, modelName: String? = nil, role: Role) {
		self.id = id
		self.text = text
		self.thinkingText = thinkingText
		self.sources = sources
		self.imageData = imageData
		self.didStoreMemory = didStoreMemory
		self.requiresVisionModel = requiresVisionModel
		self.modelName = modelName
		self.role = role
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case text
		case thinkingText
		case sources
		case imageData
		case didStoreMemory
		case requiresVisionModel
		case modelName
		case role
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		text = try container.decode(String.self, forKey: .text)
		thinkingText = try container.decodeIfPresent(String.self, forKey: .thinkingText) ?? ""
		sources = try container.decodeIfPresent([Source].self, forKey: .sources) ?? []
		imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
		didStoreMemory = try container.decodeIfPresent(Bool.self, forKey: .didStoreMemory) ?? false
		requiresVisionModel = try container.decodeIfPresent(Bool.self, forKey: .requiresVisionModel) ?? false
		modelName = try container.decodeIfPresent(String.self, forKey: .modelName)
		role = try container.decode(Role.self, forKey: .role)
	}
}
