import Foundation
import Testing
@testable import beacon

@Suite("App Store links")
@MainActor
struct AppStoreLinksTests {
	@Test("Settings links directly to Beacon's review page without a fixed region")
	func reviewLink() throws {
		let components = try #require(URLComponents(url: AppStoreLinks.review, resolvingAgainstBaseURL: false))
		#expect(components.scheme == "https")
		#expect(components.host == "apps.apple.com")
		#expect(components.path == "/app/id6786421295")
		#expect(components.queryItems?.contains(URLQueryItem(name: "action", value: "write-review")) == true)
	}
}
