import SwiftUI

enum UserMessageBubbleColor: String, CaseIterable {
	case `default` = "default"
	case blue
	case pink
	case green

	var title: String {
		switch self {
		case .default: "Default"
		case .blue: "Blue"
		case .pink: "Pink"
		case .green: "Green"
		}
	}

	var tintColor: Color {
		switch self {
		case .default: .primary
		case .blue: Color(uiColor: .systemBlue)
		case .pink: Color(uiColor: .systemPink)
		case .green: Color(uiColor: .systemGreen)
		}
	}

	var bubbleBackground: Color {
		switch self {
		case .default: Color(uiColor: .systemGray5)
		case .blue, .pink, .green: tintColor.opacity(0.10)
		}
	}

	var newChatButtonVariant: BeaconButton.Variant {
		switch self {
		case .default, .blue: .blue
		case .pink: .pink
		case .green: .green
		}
	}
}
