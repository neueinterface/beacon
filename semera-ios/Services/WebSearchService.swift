import Foundation

enum BackendConfig {
	static let baseURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "SEARCH_API_BASE_URL") as? String ?? "https://beacon-search.armondschneider.workers.dev")!
}

struct BackendErrorResponse: Decodable {
	let error: BackendError
}

struct BackendError: Decodable {
	let code: String
	let message: String
}

struct RemoteModelCatalogResponse: Decodable {
	let models: [RemoteModel]
}

struct RemoteModel: Decodable {
	let id: String
	let name: String
	let description: String
	let repositoryId: String
	let sizeInGb: Decimal
	let type: String
	let recommendedDevice: String
	let isAvailableDuringOnboarding: Bool
	let isBuiltIn: Bool
	let huggingFaceUrl: URL?
}

final class ModelCatalogService {
	func fetchModels() async throws -> [BeaconModel] {
		let url = BackendConfig.baseURL.appendingPathComponent("models")
		let (data, response) = try await URLSession.shared.data(from: url)

		guard let httpResponse = response as? HTTPURLResponse else {
			throw URLError(.badServerResponse)
		}

		guard (200 ..< 300).contains(httpResponse.statusCode) else {
			if let message = try? JSONDecoder().decode(BackendErrorResponse.self, from: data).error.message {
				throw ModelCatalogServiceError.requestFailed(message)
			}

			throw URLError(.badServerResponse)
		}

		let catalog = try JSONDecoder().decode(RemoteModelCatalogResponse.self, from: data)
		return catalog.models.map(\.beaconModel)
	}
}

enum ModelCatalogServiceError: LocalizedError {
	case requestFailed(String)

	var errorDescription: String? {
		switch self {
		case let .requestFailed(message):
			message
		}
	}
}

private extension RemoteModel {
	var beaconModel: BeaconModel {
		BeaconModel(
			id: id,
			name: name,
			description: description,
			repositoryID: repositoryId,
			sizeInGB: sizeInGb,
			type: modelType,
			recommendedDevice: recommendedDevice,
			isAvailableDuringOnboarding: isAvailableDuringOnboarding,
			isBuiltIn: isBuiltIn
		)
	}

	var modelType: BeaconModel.ModelType {
		switch type.lowercased() {
		case "reasoning":
			.reasoning
		default:
			.regular
		}
	}
}

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
		case requestFailed(Int, String?)

		var errorDescription: String? {
			switch self {
			case .invalidResponse:
				"The web search response was invalid."
			case let .requestFailed(statusCode, message):
				message ?? "Web search failed with status code \(statusCode)."
			}
		}
	}

	private struct SearchRequest: Encodable {
		let query: String
	}

	private struct SearchResponse: Decodable {
		let results: [WebSearchResult]
	}

	private let endpoint = BackendConfig.baseURL.appendingPathComponent("search")

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
			let message = try? JSONDecoder().decode(BackendErrorResponse.self, from: data).error.message
			throw WebSearchError.requestFailed(httpResponse.statusCode, message)
		}

		return try JSONDecoder().decode(SearchResponse.self, from: data).results
	}
}
