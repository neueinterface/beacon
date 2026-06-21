import SwiftUI
import MarkdownView
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct MessageBubble: View {
	let text: String
	var thinkingText = ""
	var sources: [Source] = []
	let role: ChatMessage.Role
	var isWaitingForResponse = false
	var onOpenSource: (URL) -> Void = { _ in }

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
		.contentShape(Rectangle())
		.contextMenu {
			Button {
				#if canImport(UIKit)
				UIPasteboard.general.string = text
				#elseif canImport(AppKit)
				NSPasteboard.general.clearContents()
				NSPasteboard.general.setString(text, forType: .string)
				#endif
			} label: {
				Label("Copy", systemImage: "doc.on.doc")
			}
		}
	}

	private var assistantText: some View {
		VStack(alignment: .leading, spacing: 10) {
			if isWaitingForResponse {
				ThinkingStatusText(text: thinkingStatusText)
			}

			if text.isEmpty, isWaitingForResponse {
				EmptyView()
			} else {
				MarkdownView(text)
					.font(.system(size: 15), for: .body)
					.font(.system(size: 20, weight: .semibold), for: .h1)
					.font(.system(size: 18, weight: .semibold), for: .h2)
					.font(.system(size: 16, weight: .semibold), for: .h3)
					.font(.system(size: 15, design: .monospaced), for: .codeBlock)
					.foregroundStyle(.primary)
					.tint(.secondary, for: .inlineCodeBlock)
			}

			if !isWaitingForResponse {
				SourceTag(sources: sources, onOpen: onOpenSource)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var thinkingStatusText: String {
		let lines = thinkingText
			.split(whereSeparator: \.isNewline)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }

		return lines.last ?? "Thinking..."
	}

	private var userBubble: some View {
		Text(text)
			.font(.system(size: 15))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
			.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}
}

private struct ThinkingStatusText: View {
	let text: String

	var body: some View {
		Text(text)
			.font(.system(size: 15))
			.foregroundStyle(.secondary)
			.shimmering()
			.id(text)
			.transition(.blurFade)
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}

private struct BlurFadeModifier: ViewModifier {
	let radius: CGFloat
	let opacity: Double

	func body(content: Content) -> some View {
		content
			.blur(radius: radius)
			.opacity(opacity)
	}
}

private extension AnyTransition {
	static var blurFade: AnyTransition {
		.modifier(
			active: BlurFadeModifier(radius: 8, opacity: 0),
			identity: BlurFadeModifier(radius: 0, opacity: 1)
		)
	}
}

#Preview {
	VStack(spacing: 12) {
		MessageBubble(text: "", role: .assistant, isWaitingForResponse: true)
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
