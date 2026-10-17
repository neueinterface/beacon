import Foundation
import Testing
@testable import beacon

@Suite("Release announcement")
@MainActor
struct ReleaseAnnouncementTests {
	@Test("Current announcement matches the shipped version and build")
	func releaseVersion() throws {
		let announcement = try #require(AttentionContent.current)
		#expect(announcement.id == "1.0.6")
		#expect(announcement.id != AttentionContent.version103.id)
		#expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == announcement.id)
		#expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String == "9")
	}

	@Test("Release notes explain the model changes and preserve user data")
	func releaseDetails() throws {
		let announcement = try #require(AttentionContent.current)
		let details = announcement.details.joined(separator: " ")
		#expect(details.contains("\(ModelCatalog.availableModels.count) local models"))
		#expect(details.contains("Chat Core"))
		#expect(details.contains("restored picker"))
		#expect(details.contains("RAM-based recommendations"))
		#expect(details.contains("live progress"))
		#expect(details.contains("models, chats, and memories stay saved"))
	}
}
