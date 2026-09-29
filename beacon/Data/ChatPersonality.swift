import Foundation
import SwiftUI

enum ChatPersonality: String, CaseIterable, Codable, Identifiable {
	case yackYack
	case coolGuy
	case professorBug

	var id: String { rawValue }

	var name: String {
		switch self {
		case .yackYack: "YackYack"
		case .coolGuy: "Ace"
		case .professorBug: "Oliver"
		}
	}

	var description: String {
		switch self {
		case .yackYack: "LOUD noises, surprise emojis, and absolutely no indoor voice."
		case .coolGuy: "Chill, direct replies. Usually just a few words."
		case .professorBug: "A thoughtful bulldog with answers that make sense."
		}
	}

	var avatarAsset: String {
		switch self {
		case .yackYack: "personality1"
		case .coolGuy: "personality2"
		case .professorBug: "personality3"
		}
	}

	var avatarBackground: Color {
		switch self {
		case .yackYack: Color(uiColor: .systemPink).opacity(0.16)
		case .coolGuy: Color(uiColor: .systemBlue).opacity(0.16)
		case .professorBug: Color(uiColor: .systemYellow).opacity(0.20)
		}
	}

	var instructions: String {
		switch self {
		case .yackYack:
			"Write only YackYack's reply. YackYack is a frantic, drum-loving fictional creature who answers the user accurately in a short, gleefully chaotic voice."
		case .coolGuy:
			"Write only Ace's reply. Ace is laid-back, direct, and casual. Give a complete answer in as few words as practical, using lowercase without forced slang, emojis, or performative reactions."
		case .professorBug:
			"Write only Oliver's reply. Oliver is a thoughtful English bulldog: calm, clever, warm, and well-spoken. Answer like a trusted friend, with concise reasoning when it helps and honest uncertainty when needed."
		}
	}

	var suggestedPrompts: [String] {
		switch self {
		case .yackYack:
			[
				"Tell me a wildly dramatic bedtime story about a frog who steals the moon.",
				"Turn a boring grocery trip into a chaotic victory anthem.",
				"Give me a ridiculous pep talk before I clean my room."
			]
		case .coolGuy:
			[
				"Help me write a casual text to my mom saying I'll be home late.",
				"Give me a simple plan for asking someone to hang out this weekend.",
				"Rewrite this to sound confident but not rude: I need an answer today."
			]
		case .professorBug:
			[
				"Explain why the sky changes color at sunset in simple terms.",
				"Help me make a realistic plan to finish a project by Friday.",
				"Talk me through how to apologize to a friend after missing their birthday."
			]
		}
	}

	static let generalSuggestedPrompts = [
		"Explain why hurricanes form in simple terms.",
		"Help me plan three realistic priorities for this week.",
		"Help me write a warm birthday message to my mom."
	]

	var needsStyledResponse: Bool { self != .professorBug }

	func displayResponse(_ response: String) -> String {
		switch self {
		case .yackYack: YackYackStyle.apply(to: response)
		case .coolGuy: CoolGuyStyle.apply(to: response)
		case .professorBug: response
		}
	}
}
