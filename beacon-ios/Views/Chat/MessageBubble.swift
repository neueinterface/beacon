import SwiftUI
import MarkdownView

struct MessageBubble: View {
	let text: String
	let role: ChatMessage.Role

	var body: some View {
		HStack {
			if role == .assistant {
				assistantText
			} else {
				Spacer(minLength: 56)
				userBubble
            }
        }
        .frame(maxWidth: .infinity)
    }

	private var assistantText: some View {
		MarkdownView(text)
			.font(.body, for: .body)
			.font(.system(size: 20, weight: .semibold), for: .h1)
			.font(.system(size: 18, weight: .semibold), for: .h2)
			.font(.system(size: 16, weight: .semibold), for: .h3)
			.font(.system(.body, design: .monospaced), for: .codeBlock)
			.foregroundStyle(.primary)
			.tint(.secondary, for: .inlineCodeBlock)
			.frame(maxWidth: .infinity, alignment: .leading)
	}

    private var userBubble: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
			.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
	VStack(spacing: 12) {
		MessageBubble(text: """
			Here are a few things:

			- **Private** by default
			- Supports `inline code`
			- Handles markdown lists cleanly
			""", role: .assistant)
		MessageBubble(text: "Great, can you explain local inference in simple terms?", role: .user)
	}
    .padding()
	.background(Color(uiColor: .systemBackground))
}
