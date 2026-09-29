import Combine
import Foundation

@MainActor
final class MemoryStore: ObservableObject {
	@Published private(set) var memories: [UserMemory]
	private let storageURL: URL
	private(set) var revision = 0

	init(storageURL: URL? = nil) {
		self.storageURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Beacon", isDirectory: true)
			.appendingPathComponent("memories.json")
		self.memories = (try? JSONDecoder().decode([UserMemory].self, from: Data(contentsOf: self.storageURL))) ?? []
	}

	@discardableResult
	func add(_ text: String, sourceConversationID: UUID? = nil) -> UserMemory? {
		let normalized = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
		guard !normalized.isEmpty, normalized.count <= 240,
			  !memories.contains(where: { $0.text.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) else { return nil }
		let memory = UserMemory(text: normalized, sourceConversationID: sourceConversationID)
		let subject = Self.subjectKey(for: normalized)
		let updated = [memory] + memories.filter { existing in
			guard let subject else { return true }
			return Self.subjectKey(for: existing.text) != subject
		}
		guard save(updated) else { return nil }
		memories = updated
		return memory
	}

	func delete(_ memory: UserMemory) {
		let updated = memories.filter { $0.id != memory.id }
		guard save(updated) else { return }
		memories = updated
		revision += 1
	}

	func clearAll() {
		guard save([]) else { return }
		memories = []
		revision += 1
	}

	private func save(_ updated: [UserMemory]) -> Bool {
		do {
			try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			let data = try JSONEncoder().encode(updated)
			try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
			return true
		} catch {
			return false
		}
	}

	private static func subjectKey(for text: String) -> String? {
		let patterns = [
			#"(?i)^The user's (name|wife|husband|partner|spouse|son|daughter|mother|mom|father|dad) (?:is|is named) "#,
			#"(?i)^The user's favorite ([a-z ]{2,30}) is "#,
			#"(?i)^The user (works as|is working on) "#,
			#"(?i)^The user's (goal) is "#
		]
		for pattern in patterns {
			guard let range = text.range(of: pattern, options: .regularExpression) else { continue }
			return String(text[range]).lowercased()
		}
		return nil
	}
}
