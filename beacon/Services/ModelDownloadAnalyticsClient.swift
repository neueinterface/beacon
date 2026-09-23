import Foundation

struct ModelDownloadAnalyticsClient: Sendable {
	private let endpoint: URL?
	private let installationID: String

	init(bundle: Bundle = .main) {
		#if DEBUG
		let configurationName = "LocalConfiguration"
		#else
		let configurationName = "ReleaseConfiguration"
		#endif
		let configuredValue = bundle.url(forResource: configurationName, withExtension: "plist")
			.flatMap { try? Data(contentsOf: $0) }
			.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
			.flatMap { $0["ModelDownloadsURL"] as? String }
		endpoint = configuredValue.flatMap(URL.init(string:))?.withPath("/model-downloads")
		let defaults = UserDefaults.standard
		if let existingID = defaults.string(forKey: "modelDownloadInstallationID") {
			installationID = existingID
		} else {
			let newID = UUID().uuidString.lowercased()
			defaults.set(newID, forKey: "modelDownloadInstallationID")
			installationID = newID
		}
	}

	func recordDownload(modelID: String) async {
		guard let endpoint else { return }
		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.timeoutInterval = 10
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try? JSONSerialization.data(withJSONObject: [
			"modelID": modelID,
			"installationID": installationID
		])
		_ = try? await URLSession.shared.data(for: request)
	}

	func fetchCounts() async -> [String: Int] {
		guard let endpoint else { return [:] }
		guard let (data, response) = try? await URLSession.shared.data(from: endpoint),
			  (response as? HTTPURLResponse)?.statusCode == 200,
			  let payload = try? JSONDecoder().decode(DownloadCountsResponse.self, from: data) else { return [:] }
		return payload.counts
	}

	private struct DownloadCountsResponse: Decodable {
		let counts: [String: Int]
	}
}

private extension URL {
	func withPath(_ path: String) -> URL {
		var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
		components?.path = path
		return components?.url ?? self
	}
}
