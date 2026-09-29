import Foundation

enum VisibleResponseSanitizer {
	static func clean(_ response: String) -> String {
		var result = response.trimmingCharacters(in: .whitespacesAndNewlines)
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

enum CoolGuyStyle {
	static func apply(to response: String) -> String {
		let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let expression = try? NSRegularExpression(pattern: #"https?://\S+|beacon-source://\d+"#, options: [.caseInsensitive]) else {
			return trimmed.lowercased()
		}
		let matches = expression.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
		var output = ""
		var cursor = trimmed.startIndex
		for match in matches {
			guard let range = Range(match.range, in: trimmed) else { continue }
			output += trimmed[cursor..<range.lowerBound].lowercased()
			output += trimmed[range]
			cursor = range.upperBound
		}
		output += trimmed[cursor...].lowercased()
		return output
	}
}

enum YackYackStyle {
	static let intro = ["BWAHAHA!! 🥁", "YAAAHH!! 🐸", "BRRZZT!! ⚡️"].randomElement() ?? "BWAHAHA!! 🥁"
	static let outro = "YAAACK! 🌀"

	static func apply(to response: String) -> String {
		let words = response.split(whereSeparator: \.isWhitespace)
		let answer = words.enumerated().map { styleWord(String($0.element), at: $0.offset) }.joined(separator: " ")
		return "\(intro) \(answer.isEmpty ? "WAT WAS THAT?!" : answer) \(outro)"
	}

	static func styleWord(_ original: String, at index: Int) -> String {
		if original.contains("beacon-source://") { return original }
		let ending = String(original.reversed().prefix(while: { ".,!?".contains($0) }).reversed())
		let base = String(original.dropLast(ending.count))
		var styled = misspell(base)
		if index % 5 == 1 { styled = styled.uppercased() }
		var result = styled + ending
		if index % 7 == 3 { result += " \(["🥁", "🐸", "⚡️", "🌀"].randomElement() ?? "🥁")" }
		if index % 9 == 6 { result += " BRRZZT!" }
		return result
	}

	private static func misspell(_ word: String) -> String {
		switch word.lowercased() {
		case "the": "teh"
		case "you": "yoo"
		case "your": "yer"
		case "really": "REELI"
		case "because": "cuz"
		case "is": "iz"
		case "are": "arr"
		case "great": "GR8"
		default: word
		}
	}
}

struct YackYackResponseStreamer {
	private var remainder = ""
	private var wordIndex = 0
	private var hasStarted = false
	private var hasFinished = false

	mutating func append(_ chunk: String) -> String {
		guard !hasFinished else { return "" }
		remainder += chunk
		guard let lastWhitespace = remainder.lastIndex(where: \.isWhitespace) else { return "" }
		let ready = String(remainder[..<lastWhitespace])
		remainder = String(remainder[remainder.index(after: lastWhitespace)...])
		return render(ready.split(whereSeparator: \.isWhitespace).map(String.init))
	}

	mutating func finish() -> String {
		guard !hasFinished else { return "" }
		hasFinished = true
		let finalWords = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
		remainder = ""
		let rendered = render(finalWords)
		if !hasStarted {
			hasStarted = true
			return "\(YackYackStyle.intro) WAT WAS THAT?! \(YackYackStyle.outro)"
		}
		return rendered + YackYackStyle.outro
	}

	private mutating func render(_ words: [String]) -> String {
		guard !words.isEmpty else { return "" }
		var output = ""
		if !hasStarted {
			hasStarted = true
			output = "\(YackYackStyle.intro) "
		}
		for word in words {
			if !output.isEmpty && !output.hasSuffix(" ") { output += " " }
			output += YackYackStyle.styleWord(word, at: wordIndex)
			wordIndex += 1
		}
		return output + " "
	}
}
