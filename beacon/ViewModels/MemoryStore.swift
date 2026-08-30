import Combine
import Foundation

enum MemoryStoreError: Error, Equatable {
	case loadFailed
	case saveFailed
}

@MainActor
final class MemoryStore: ObservableObject {
	@Published private(set) var memories: [UserMemory]
	@Published private(set) var lastError: MemoryStoreError?

	var summary: String {
		MemorySummary.text(from: memories)
	}

	private let storageURL: URL

	init(storageURL: URL? = nil) {
		self.storageURL = storageURL ?? Self.defaultStorageURL

		do {
			self.memories = try Self.load(from: self.storageURL)
			self.lastError = nil
			print("MemoryStore: loaded \(memories.count) memories from \(self.storageURL.path)")
		} catch {
			self.memories = []
			self.lastError = .loadFailed
			print("MemoryStore: failed to load memories: \(error.localizedDescription)")
		}
	}

	@discardableResult
	func add(_ text: String, sourceConversationID: UUID? = nil) -> UserMemory? {
		let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalizedText.isEmpty else {
			print("MemoryStore: ignored empty memory")
			return nil
		}

		guard !memories.contains(where: { $0.text.localizedCaseInsensitiveCompare(normalizedText) == .orderedSame }) else {
			print("MemoryStore: ignored duplicate memory")
			return nil
		}

		let memory = UserMemory(text: normalizedText, sourceConversationID: sourceConversationID)
		var updatedMemories = memories
		updatedMemories.insert(memory, at: 0)
		guard save(updatedMemories) else { return nil }
		memories = updatedMemories
		print("MemoryStore: added memory \(memory.id.uuidString)")
		return memory
	}

	func delete(_ memory: UserMemory) {
		guard memories.contains(memory) else { return }
		let updatedMemories = memories.filter { $0.id != memory.id }
		guard save(updatedMemories) else { return }
		memories = updatedMemories
		print("MemoryStore: deleted memory \(memory.id.uuidString)")
	}

	func clearAll() {
		guard !memories.isEmpty else { return }
		guard save([]) else { return }
		memories.removeAll()
		print("MemoryStore: deleted all memories")
	}

	@discardableResult
	private func save(_ memories: [UserMemory]) -> Bool {
		do {
			try FileManager.default.createDirectory(
				at: storageURL.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(memories)
			try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
			lastError = nil
			print("MemoryStore: saved \(memories.count) memories locally to \(storageURL.path)")
			return true
		} catch {
			lastError = .saveFailed
			print("MemoryStore: failed to save memories: \(error.localizedDescription)")
			return false
		}
	}

	private static func load(from url: URL) throws -> [UserMemory] {
		guard FileManager.default.fileExists(atPath: url.path) else { return [] }

		let data = try Data(contentsOf: url)
		return try JSONDecoder().decode([UserMemory].self, from: data)
	}

	private static var defaultStorageURL: URL {
		FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Beacon", isDirectory: true)
			.appendingPathComponent("memories.json")
	}
}
