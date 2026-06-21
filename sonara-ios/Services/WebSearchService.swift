import Foundation

struct WebSearchResult: Decodable, Hashable {
	let title: String
	let url: URL
	let description: String
}

extension Source {
	init(_ result: WebSearchResult) {
		self.init(title: result.title, url: result.url, description: result.description)
	}
}

struct WebSearchService {
	enum WebSearchError: LocalizedError {
		case invalidResponse
		case requestFailed(Int)

		var errorDescription: String? {
			switch self {
			case .invalidResponse:
				"The web search response was invalid."
			case let .requestFailed(statusCode):
				"Web search failed with status code \(statusCode)."
			}
		}
	}

	private struct SearchRequest: Encodable {
		let query: String
	}

	private struct SearchResponse: Decodable {
		let results: [WebSearchResult]
	}

	private let endpoint = URL(string: "https://beacon-search.armondschneider.workers.dev/search")!

	private var appAPIKey: String {
		ProcessInfo.processInfo.environment["APP_API_KEY"] ?? ""
	}

	func search(_ query: String) async throws -> [WebSearchResult] {
		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		if !appAPIKey.isEmpty {
			request.setValue("Bearer \(appAPIKey)", forHTTPHeaderField: "Authorization")
		}

		request.httpBody = try JSONEncoder().encode(SearchRequest(query: query))

		let (data, response) = try await URLSession.shared.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw WebSearchError.invalidResponse
		}

		guard (200 ..< 300).contains(httpResponse.statusCode) else {
			throw WebSearchError.requestFailed(httpResponse.statusCode)
		}

		return try JSONDecoder().decode(SearchResponse.self, from: data).results
	}
}
