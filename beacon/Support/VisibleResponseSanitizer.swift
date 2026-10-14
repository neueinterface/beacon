import Foundation

enum VisibleResponseSanitizer {
	static func clean(_ response: String) -> String {
		var result = response.trimmingCharacters(in: .whitespacesAndNewlines)
		if let label = result.range(of: #"^(?:\*\*)?(?:Beacon|Assistant|Answer)(?:\*\*)?\s*:(?:\*\*)?\s*"#, options: [.regularExpression, .caseInsensitive]) {
			result.removeSubrange(label)
		}
		let patterns = [
			#"(?is)(?:^|(?<=[.!?])\s+|\n+)no need to (?:elaborate|explain|ask|mention|add)[^\n]*$"#,
			#"(?is)(?:^|(?<=[.!?])\s+|\n+)(?:i|we) (?:should|need to|will) (?:answer|respond|acknowledge|mention|keep|avoid)[^\n]*$"#,
			#"(?is)(?:^|(?<=[.!?])\s+|\n+)(?:the )?(?:answer|response|reply) should (?:be (?:brief|concise|direct|friendly)|only contain|not mention)[^\n]*$"#,
			#"(?is)(?:^|(?<=[.!?])\s+|\n+)just acknowledge(?: the user)?(?:[,. ]|$)[^\n]*$"#,
			#"(?is)(?:^|(?<=[.!?])\s+|\n+)keep (?:it|the (?:answer|response|reply)) (?:brief|concise|short|friendly)[^\n]*$"#
		]

		for pattern in patterns {
			guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
			let range = NSRange(result.startIndex..., in: result)
			result = expression.stringByReplacingMatches(in: result, range: range, withTemplate: "")
				.trimmingCharacters(in: .whitespacesAndNewlines)
		}

		return result
	}
}
