import Foundation

struct WebSearchMCPClient: Sendable {
	struct Result: Decodable, Sendable {
		let title: String
		let url: URL
		let description: String
		let content: String?
	}

	struct SearchResponse: Decodable, Sendable {
		let query: String
		let results: [Result]
	}

	enum ClientError: LocalizedError {
		case notConfigured
		case invalidResponse
		case requestFailed(String)
		case rateLimited(Date?)

		var errorDescription: String? {
			switch self {
			case .notConfigured:
				"Web search is not configured for this build."
			case .invalidResponse:
				"Web search returned an unreadable response."
			case let .requestFailed(message):
				"Web search failed. \(message)"
			case let .rateLimited(resetAt):
				if let resetAt {
					"The free web search limit has been reached. Try again after \(resetAt.formatted(date: .abbreviated, time: .shortened))."
				} else {
					"The free web search limit has been reached. Try again later."
				}
			}
		}
	}

	private struct RPCResponse: Decodable {
		struct Result: Decodable {
			struct Content: Decodable {
				let type: String
				let text: String?
			}

			let content: [Content]
			let isError: Bool?
		}

		struct RPCError: Decodable {
			let message: String
		}

		let result: Result?
		let error: RPCError?
	}

	private struct RateLimitResponse: Decodable {
		let resetsAt: Date?
	}

	let endpoint: URL?

	init(bundle: Bundle = .main) {
		#if DEBUG
		let configurationName = "LocalConfiguration"
		#else
		let configurationName = "ReleaseConfiguration"
		#endif
		let configuredValue = bundle.url(forResource: configurationName, withExtension: "plist")
			.flatMap { try? Data(contentsOf: $0) }
			.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
			.flatMap { $0["WebSearchMCPURL"] as? String }
		let candidate = configuredValue.flatMap(URL.init(string:))
		endpoint = candidate?.scheme == "https" ? candidate : nil
	}

	var isConfigured: Bool {
		endpoint != nil
	}

	func search(_ query: String) async throws -> SearchResponse {
		guard let endpoint else { throw ClientError.notConfigured }

		let payload: [String: Any] = [
			"jsonrpc": "2.0",
			"id": UUID().uuidString,
			"method": "tools/call",
			"params": [
				"name": "search_web",
				"arguments": [
					"query": String(query.prefix(200)),
					"limit": 5,
					"includeContent": true,
					"maxContentLength": 2_500
				]
			]
		]

		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.timeoutInterval = 35
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
		request.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version")
		request.httpBody = try JSONSerialization.data(withJSONObject: payload)

		let (data, response) = try await URLSession.shared.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else { throw ClientError.invalidResponse }

		if httpResponse.statusCode == 429 {
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			throw ClientError.rateLimited(try? decoder.decode(RateLimitResponse.self, from: data).resetsAt)
		}

		guard (200..<300).contains(httpResponse.statusCode) else {
			throw ClientError.requestFailed(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
		}

		let rpcResponse = try decodeRPCResponse(data, contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"))
		if let error = rpcResponse.error { throw ClientError.requestFailed(error.message) }
		if rpcResponse.result?.isError == true {
			let message = rpcResponse.result?.content.first(where: { $0.type == "text" })?.text
			throw ClientError.requestFailed(message ?? "The search provider is unavailable.")
		}
		guard let text = rpcResponse.result?.content.first(where: { $0.type == "text" })?.text,
			  let textData = text.data(using: .utf8) else {
			throw ClientError.invalidResponse
		}

		return try JSONDecoder().decode(SearchResponse.self, from: textData)
	}

	private func decodeRPCResponse(_ data: Data, contentType: String?) throws -> RPCResponse {
		let decoder = JSONDecoder()
		guard contentType?.localizedCaseInsensitiveContains("text/event-stream") == true else {
			return try decoder.decode(RPCResponse.self, from: data)
		}

		for payload in Self.eventStreamPayloads(from: data) {
			guard let response = try? decoder.decode(RPCResponse.self, from: payload),
				  response.result != nil || response.error != nil else { continue }
			return response
		}

		throw ClientError.invalidResponse
	}

	nonisolated static func eventStreamPayloads(from data: Data) -> [Data] {
		guard let stream = String(data: data, encoding: .utf8) else { return [] }
		return stream.replacingOccurrences(of: "\r\n", with: "\n")
			.components(separatedBy: "\n\n")
			.compactMap { event in
				let payload = event.components(separatedBy: .newlines)
					.filter { $0.hasPrefix("data:") }
					.map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
					.joined(separator: "\n")
				return payload.isEmpty ? nil : payload.data(using: .utf8)
			}
	}
}
