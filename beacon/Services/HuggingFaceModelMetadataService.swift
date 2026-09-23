import Foundation

struct HuggingFaceModelMetadata: Equatable {
	let downloads: Int?
	let lastModified: Date?
	let readme: String?
	let contextLength: Int?
}

struct HuggingFaceModelMetadataService {
	private struct CacheEntry {
		let metadata: HuggingFaceModelMetadata
		let fetchedAt: Date
	}

	private static var cache: [String: CacheEntry] = [:]
	private static let cacheLifetime: TimeInterval = 6 * 60 * 60
	private let session: URLSession

	init(session: URLSession = .shared) {
		self.session = session
	}

	func fetch(repositoryID: String) async throws -> HuggingFaceModelMetadata {
		if let cached = Self.cache[repositoryID],
		   Date.now.timeIntervalSince(cached.fetchedAt) < Self.cacheLifetime {
			return cached.metadata
		}

		async let modelResponse = optionalRequest { try await fetchModel(repositoryID: repositoryID) }
		async let configResponse = optionalRequest { try await fetchConfig(repositoryID: repositoryID) }

		let (model, config) = try await (modelResponse, configResponse)
		guard model != nil || config != nil else {
			throw HuggingFaceMetadataError.invalidResponse
		}
		let metadata = HuggingFaceModelMetadata(
			downloads: model?.downloads,
			lastModified: model?.lastModified.flatMap(Self.parseDate),
			readme: nil,
			contextLength: config?.maxPositionEmbeddings
		)
		try Task.checkCancellation()
		Self.cache[repositoryID] = CacheEntry(metadata: metadata, fetchedAt: .now)
		return metadata
	}

	private func optionalRequest<Value>(_ operation: () async throws -> Value) async throws -> Value? {
		do {
			return try await operation()
		} catch is CancellationError {
			throw CancellationError()
		} catch {
			return nil
		}
	}

	private func fetchModel(repositoryID: String) async throws -> ModelResponse {
		let data = try await data(from: try endpoint(path: "/api/models/\(repositoryID)"))
		return try JSONDecoder().decode(ModelResponse.self, from: data)
	}

	private func fetchConfig(repositoryID: String) async throws -> ConfigResponse {
		let data = try await data(from: try endpoint(path: "/\(repositoryID)/raw/main/config.json"))
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(ConfigResponse.self, from: data)
	}

	private func data(from url: URL) async throws -> Data {
		var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)
		request.setValue("application/json, text/plain;q=0.9", forHTTPHeaderField: "Accept")
		let (data, response) = try await session.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse,
			  (200..<300).contains(httpResponse.statusCode) else {
			throw HuggingFaceMetadataError.invalidResponse
		}
		return data
	}

	private func endpoint(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
		var components = URLComponents()
		components.scheme = "https"
		components.host = "huggingface.co"
		components.path = path
		components.queryItems = queryItems.isEmpty ? nil : queryItems
		guard let url = components.url else { throw HuggingFaceMetadataError.invalidURL }
		return url
	}

	static func removingFrontMatter(from readme: String) -> String {
		guard readme.hasPrefix("---") else { return readme }
		let lines = readme.split(separator: "\n", omittingEmptySubsequences: false)
		guard let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
			return readme
		}
		return lines[lines.index(after: closingIndex)...].joined(separator: "\n")
	}

	private static func parseDate(_ value: String) -> Date? {
		if let date = try? Date(value, strategy: .iso8601) {
			return date
		}
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return formatter.date(from: value)
	}
}

private extension HuggingFaceModelMetadataService {
	struct ModelResponse: Decodable {
		let downloads: Int?
		let lastModified: String?
	}

	struct ConfigResponse: Decodable {
		let maxPositionEmbeddings: Int?
	}
}

private enum HuggingFaceMetadataError: Error {
	case invalidURL
	case invalidResponse
}
