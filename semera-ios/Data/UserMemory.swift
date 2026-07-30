import Combine
import Foundation

struct UserMemory: Identifiable, Hashable, Codable {
	let id: UUID
	let text: String
	let createdAt: Date

	init(id: UUID = UUID(), text: String, createdAt: Date = .now) {
		self.id = id
		self.text = text
		self.createdAt = createdAt
	}
}

@MainActor
final class UserMemoryStore: ObservableObject {
	@Published private(set) var memories: [UserMemory] {
		didSet { saveMemories() }
	}

	private static let storageKey = "userMemories"

	init(memories: [UserMemory]? = nil) {
		self.memories = memories ?? Self.loadMemories()
	}

	@discardableResult
	func store(from message: String) -> Bool {
		guard let text = Self.memoryText(from: message) else { return false }
		guard !memories.contains(where: { $0.text.caseInsensitiveCompare(text) == .orderedSame }) else { return false }

		memories.insert(UserMemory(text: text), at: 0)
		return true
	}

	func delete(_ memory: UserMemory) {
		memories.removeAll { $0.id == memory.id }
	}

	func clearAll() {
		memories.removeAll()
	}

	nonisolated static func memoryText(from message: String) -> String? {
		let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !message.isEmpty else { return nil }

		let relationshipPrefixes = [
			("my wife is ", "User's wife is "),
			("my wife works as ", "User's wife works as "),
			("my husband is ", "User's husband is "),
			("my husband works as ", "User's husband works as "),
			("my partner is ", "User's partner is "),
			("my partner works as ", "User's partner works as ")
		]

		for (prefix, memoryPrefix) in relationshipPrefixes {
			if let fact = fact(after: prefix, in: message) {
				return memoryPrefix + fact
			}
		}

		for (prefix, memoryPrefix) in [("i work as ", "User works as "), ("i live in ", "User lives in "), ("my name is ", "User's name is ")] {
			if let fact = fact(after: prefix, in: message) {
				return memoryPrefix + fact
			}
		}

		for prefix in ["i am a ", "i am an ", "i'm a ", "i'm an "] {
			if let fact = fact(after: prefix, in: message) {
				return "User is " + fact
			}
		}

		return nil
	}

	private nonisolated static func fact(after prefix: String, in message: String) -> String? {
		guard message.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil else { return nil }
		let fact = String(message.dropFirst(prefix.count))
			.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
		guard !fact.isEmpty, fact.count <= 120 else { return nil }
		return fact
	}

	private func saveMemories() {
		guard let data = try? JSONEncoder().encode(memories) else { return }
		UserDefaults.standard.set(data, forKey: Self.storageKey)
	}

	private static func loadMemories() -> [UserMemory] {
		guard let data = UserDefaults.standard.data(forKey: storageKey),
			  let memories = try? JSONDecoder().decode([UserMemory].self, from: data) else {
			return []
		}

		return memories
	}
}
