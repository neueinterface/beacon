import Foundation

struct InformationCardContent: Hashable, Codable {
	let title: String
	let imageURL: URL?

	init(title: String, imageURL: URL? = nil) {
		self.title = title
		self.imageURL = imageURL
	}
}

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
	var imageDatas: [Data]
	var informationCard: InformationCardContent?
	var modelName: String?
	let role: Role

	init(id: UUID = UUID(), text: String, thinkingText: String = "", sources: [Source] = [], imageData: Data? = nil, imageDatas: [Data] = [], informationCard: InformationCardContent? = nil, modelName: String? = nil, role: Role) {
		self.id = id
		self.text = text
		self.thinkingText = thinkingText
		self.sources = sources
		self.imageData = imageData
		self.imageDatas = imageDatas.isEmpty ? imageData.map { [$0] } ?? [] : imageDatas
		self.informationCard = informationCard
		self.modelName = modelName
		self.role = role
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case text
		case thinkingText
		case sources
		case imageData
		case imageDatas
		case informationCard
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
		imageDatas = try container.decodeIfPresent([Data].self, forKey: .imageDatas) ?? imageData.map { [$0] } ?? []
		informationCard = try container.decodeIfPresent(InformationCardContent.self, forKey: .informationCard)
		modelName = try container.decodeIfPresent(String.self, forKey: .modelName)
		role = try container.decode(Role.self, forKey: .role)
	}
}
