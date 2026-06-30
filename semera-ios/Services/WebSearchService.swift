import Foundation
import Security

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

struct BackendStatus: Decodable, Equatable {
	let ok: Bool
	let features: BackendFeatures

	var allowsRemoteModels: Bool {
		ok && features.backend && features.models
	}

	var allowsWebSearch: Bool {
		ok && features.backend && features.webSearch
	}
}

struct BackendFeatures: Decodable, Equatable {
	let backend: Bool
	let models: Bool
	let webSearch: Bool
}

struct BackendStatusService {
	private let decoder = SearchJSONDecoder.make()

	func status() async throws -> BackendStatus {
		let url = BackendConfig.baseURL.appendingPathComponent("status")
		let (data, response) = try await URLSession.shared.data(from: url)

		guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
			throw URLError(.badServerResponse)
		}

		return try decoder.decode(BackendStatus.self, from: data)
	}
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
		case unauthorized
		case backendDisabled(String?)
		case webSearchDisabled
		case requestFailed(Int, String?)
		case dailyLimitExceeded(SearchQuota)

		var errorDescription: String? {
			switch self {
			case .invalidResponse:
				"The web search response was invalid."
			case .unauthorized:
				"Web search is temporarily unavailable."
			case .backendDisabled:
				"Remote features are temporarily unavailable."
			case .webSearchDisabled:
				"Web search is temporarily unavailable."
			case let .requestFailed(statusCode, message):
				message ?? "Web search failed with status code \(statusCode)."
			case let .dailyLimitExceeded(quota):
				"Daily web search limit reached. Web search will be available again \(quota.resetAt.formatted(date: .omitted, time: .shortened))."
			}
		}
	}

	private struct SearchRequest: Encodable {
		let query: String
	}

	private struct SearchResponse: Decodable {
		let results: [WebSearchResult]
		let quota: SearchQuota?
	}

	private struct QuotaUnavailableResponse: Decodable {
		let available: Bool
		let reason: String?
	}

	private let endpoint = BackendConfig.baseURL.appendingPathComponent("search")
	private let deviceIDProvider = SearchDeviceIDProvider()
	private let decoder = SearchJSONDecoder.make()

	private var appAPIKey: String {
		let key = ProcessInfo.processInfo.environment["APP_API_KEY"]
			?? Bundle.main.object(forInfoDictionaryKey: "APP_API_KEY") as? String
			?? ""
		let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedKey.isEmpty, !trimmedKey.contains("$(") else { return "" }
		return trimmedKey
	}

	private var hasAppAPIKey: Bool {
		!appAPIKey.isEmpty
	}

	func search(_ query: String, chatID: ChatConversation.ID?) async throws -> WebSearchResponse {
		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(deviceIDProvider.deviceID(), forHTTPHeaderField: "X-Device-ID")

		if let chatID {
			request.setValue(chatID.uuidString, forHTTPHeaderField: "X-Chat-ID")
		}

		if !appAPIKey.isEmpty {
			request.setValue("Bearer \(appAPIKey)", forHTTPHeaderField: "Authorization")
		}

		request.httpBody = try JSONEncoder().encode(SearchRequest(query: query))

		let (data, response) = try await URLSession.shared.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw WebSearchError.invalidResponse
		}

		try validateSearchResponse(data: data, response: httpResponse)

		let searchResponse = try decoder.decode(SearchResponse.self, from: data)
		return WebSearchResponse(results: searchResponse.results, quota: searchResponse.quota)
	}

	func quota(chatID: ChatConversation.ID?) async throws -> SearchQuota {
		var request = URLRequest(url: endpoint.appendingPathComponent("quota"))
		request.httpMethod = "GET"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(deviceIDProvider.deviceID(), forHTTPHeaderField: "X-Device-ID")
		if let chatID {
			request.setValue(chatID.uuidString, forHTTPHeaderField: "X-Chat-ID")
		}

		if !appAPIKey.isEmpty {
			request.setValue("Bearer \(appAPIKey)", forHTTPHeaderField: "Authorization")
		}

		let (data, response) = try await URLSession.shared.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw WebSearchError.invalidResponse
		}

		try validateSearchResponse(data: data, response: httpResponse)

		if let unavailable = try? decoder.decode(QuotaUnavailableResponse.self, from: data), unavailable.available == false {
			if unavailable.reason == "web_search_disabled" {
				throw WebSearchError.webSearchDisabled
			}

			throw WebSearchError.requestFailed(httpResponse.statusCode, unavailable.reason)
		}

		if let envelope = try? decoder.decode(SearchQuotaEnvelope.self, from: data) {
			return envelope.quota
		}

		return try decoder.decode(SearchQuota.self, from: data)
	}

	private func validateSearchResponse(data: Data, response: HTTPURLResponse) throws {
		guard !(200 ..< 300).contains(response.statusCode) else { return }

		let backendError = try? decoder.decode(BackendErrorResponse.self, from: data).error
		if response.statusCode == 401 {
			#if DEBUG
			print("Web search auth failed. APP_API_KEY configured: \(hasAppAPIKey)")
			#endif
			throw WebSearchError.unauthorized
		}

		if response.statusCode == 429, let quota = limitExceededQuota(from: data, response: response) {
			throw WebSearchError.dailyLimitExceeded(quota)
		}

		if response.statusCode == 503 {
			switch backendError?.code {
			case "web_search_disabled":
				throw WebSearchError.webSearchDisabled
			case "backend_disabled":
				throw WebSearchError.backendDisabled(backendError?.message)
			default:
				break
			}
		}

		throw WebSearchError.requestFailed(response.statusCode, backendError?.message)
	}

	private func limitExceededQuota(from data: Data, response: HTTPURLResponse) -> SearchQuota? {
		let backendError = try? decoder.decode(BackendErrorResponse.self, from: data).error
		guard backendError?.code == "daily_search_limit_exceeded" else { return nil }

		if let quota = try? decoder.decode(SearchQuota.self, from: data) {
			return quota
		}

		if let quotaEnvelope = try? decoder.decode(SearchQuotaEnvelope.self, from: data) {
			return quotaEnvelope.quota
		}

		let resetAt = response.searchQuotaResetAt ?? Date().addingTimeInterval(24 * 60 * 60)
		return SearchQuota(
			limit: response.searchQuotaLimit ?? 5,
			remaining: response.searchQuotaRemaining ?? 0,
			resetAt: resetAt
		)
	}
}

struct WebSearchResponse: Equatable {
	let results: [WebSearchResult]
	let quota: SearchQuota?
}

struct SearchQuota: Decodable, Equatable {
	let limit: Int
	let remaining: Int
	let resetAt: Date

	var isExhausted: Bool {
		remaining <= 0 && resetAt > Date()
	}
}

private struct SearchQuotaEnvelope: Decodable {
	let quota: SearchQuota
}

private enum SearchJSONDecoder {
	static func make() -> JSONDecoder {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .custom { decoder in
			let container = try decoder.singleValueContainer()
			let value = try container.decode(String.self)

			if let date = ISO8601DateFormatter.searchWithFractionalSeconds.date(from: value)
				?? ISO8601DateFormatter.search.date(from: value) {
				return date
			}

			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
		}
		return decoder
	}
}

private extension ISO8601DateFormatter {
	static let searchWithFractionalSeconds: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()

	static let search: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime]
		return formatter
	}()
}

private extension HTTPURLResponse {
	var searchQuotaLimit: Int? {
		headerInt(["X-Search-Limit", "X-RateLimit-Limit", "X-Rate-Limit-Limit"])
	}

	var searchQuotaRemaining: Int? {
		headerInt(["X-Search-Remaining", "X-RateLimit-Remaining", "X-Rate-Limit-Remaining"])
	}

	var searchQuotaResetAt: Date? {
		for name in ["X-Search-Reset-At", "X-RateLimit-Reset-At", "X-Rate-Limit-Reset-At"] {
			if let value = value(forHTTPHeaderField: name),
			   let date = ISO8601DateFormatter.searchWithFractionalSeconds.date(from: value) ?? ISO8601DateFormatter.search.date(from: value) {
				return date
			}
		}

		for name in ["X-Search-Reset", "X-RateLimit-Reset", "X-Rate-Limit-Reset"] {
			if let value = value(forHTTPHeaderField: name), let seconds = TimeInterval(value) {
				return Date(timeIntervalSince1970: seconds)
			}
		}

		return nil
	}

	private func headerInt(_ names: [String]) -> Int? {
		for name in names {
			if let value = value(forHTTPHeaderField: name), let int = Int(value) {
				return int
			}
		}
		return nil
	}
}

private struct SearchDeviceIDProvider {
	private let service = "me.armond.semera-ios.search"
	private let account = "device-id"

	func deviceID() -> String {
		if let existing = readDeviceID() {
			return existing
		}

		let created = UUID().uuidString
		storeDeviceID(created)
		return created
	}

	private func readDeviceID() -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]

		var item: CFTypeRef?
		guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
			let data = item as? Data,
			let id = String(data: data, encoding: .utf8),
			!id.isEmpty else {
			return nil
		}

		return id
	}

	private func storeDeviceID(_ id: String) {
		let data = Data(id.utf8)
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account
		]
		let attributes: [String: Any] = [kSecValueData as String: data]

		let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
		guard status == errSecItemNotFound else { return }

		var addQuery = query
		addQuery[kSecValueData as String] = data
		SecItemAdd(addQuery as CFDictionary, nil)
	}
}
