import SwiftUI
import MarkdownView
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct MessageBubble: View {
	@Namespace private var attachmentTransition
	let text: String
	var imageData: Data?
	var requiresVisionModel = false
	var onDownloadVisionModel: () -> Void = {}
	var sources: [Source] = []
	let role: ChatMessage.Role
	var animatesEntrance = false
	var isWaitingForResponse = false
	var waitingText = "Thinking"
	var onOpenSource: (URL) -> Void = { _ in }
	var showsRetry = false
	var onRetry: () -> Void = {}

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
		.modifier(UserMessageEntranceModifier(isEnabled: role == .user && animatesEntrance))
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
				ThinkingStatusText(text: waitingText)
			}

			if text.isEmpty, isWaitingForResponse {
				EmptyView()
			} else if !displayText.isEmpty {
				MarkdownView(displayText)
					.font(.openRunde(size: 16), for: .body)
					.lineSpacing(4)
					.font(.openRunde(size: 18, weight: .semibold), for: .h1)
					.font(.openRunde(size: 17, weight: .semibold), for: .h2)
					.font(.openRunde(size: 16, weight: .semibold), for: .h3)
					.font(.openRunde(size: 16, weight: .semibold), for: .h4)
					.font(.openRunde(size: 16, weight: .semibold), for: .h5)
					.font(.openRunde(size: 16, weight: .semibold), for: .h6)
					.font(.system(size: 14, design: .monospaced), for: .codeBlock)
					.foregroundStyle(.primary)
					.tint(.secondary, for: .inlineCodeBlock)
			}

			if !isWaitingForResponse {
				SourceTag(sources: sources, onOpen: onOpenSource)
			}

			if showsRetry, !isWaitingForResponse {
				BeaconButton(
					"Retry",
					variant: .secondary,
					size: .small,
					trailingIcon: "arrow.clockwise",
					action: onRetry
				)
			}

			if requiresVisionModel, !isWaitingForResponse {
				Button("Download vision model", action: onDownloadVisionModel)
					.buttonStyle(.bordered)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var displayText: String {
		guard role == .assistant, !sources.isEmpty else { return text }
		return text.removingRenderedSourceSection()
	}

	private var userBubble: some View {
		VStack(alignment: .trailing) {
			if !text.isEmpty {
				Text(text)
					.font(.openRunde(size: 16))
					.foregroundStyle(.primary)
					.padding(.horizontal, 14)
					.padding(.vertical, 14)
					.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
					.overlay(alignment: .topTrailing) {
						if let imageData {
							ChatAttachedImage(data: imageData, transitionNamespace: attachmentTransition)
								.offset(x: -14, y: -116)
						}
					}
					.padding(.top, imageData == nil ? 0 : 116)
			} else if let imageData {
				ChatAttachedImage(data: imageData, transitionNamespace: attachmentTransition)
			}
		}
		.frame(maxWidth: .infinity, alignment: .trailing)
	}
}

private struct ChatAttachedImage: View {
	private let transitionID = "attached-image"
	let data: Data
	let transitionNamespace: Namespace.ID

	var body: some View {
		NavigationLink {
			#if os(macOS)
			AttachedImageViewer(data: data)
			#else
			AttachedImageViewer(data: data)
				.navigationTransition(.zoom(sourceID: transitionID, in: transitionNamespace))
			#endif
		} label: {
			thumbnail
				.matchedTransitionSource(id: transitionID, in: transitionNamespace)
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Open attached image")
	}

	@ViewBuilder
	private var thumbnail: some View {
		#if canImport(UIKit)
		if let image = UIImage(data: data) {
			Image(uiImage: image)
				.resizable()
				.scaledToFill()
				.frame(width: 96, height: 116)
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
				.padding(4)
				.background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
				.rotationEffect(.degrees(4))
		}
		#elseif canImport(AppKit)
		if let image = NSImage(data: data) {
			Image(nsImage: image)
				.resizable()
				.scaledToFill()
				.frame(width: 96, height: 116)
				.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
				.padding(4)
				.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
				.rotationEffect(.degrees(4))
		}
		#endif
	}
}

struct AttachedImageViewer: View {
	let data: Data

	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()

			#if canImport(UIKit)
			if let image = UIImage(data: data) {
				Image(uiImage: image)
					.resizable()
					.scaledToFit()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			#elseif canImport(AppKit)
			if let image = NSImage(data: data) {
				Image(nsImage: image)
					.resizable()
					.scaledToFit()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			#endif
		}
		#if !os(macOS)
		.toolbarBackground(.hidden, for: .navigationBar)
		.toolbarColorScheme(.dark, for: .navigationBar)
		#endif
	}
}

private struct ThinkingStatusText: View {
	let text: String
	@State private var rotatingStatus = "Thinking"

	private let rotatingStatuses = ["Thinking", "Tokenizing the thought", "Ummm...", "Pulling it together"]

	var body: some View {
		HStack(spacing: 7) {
			if isSearchingWeb {
				Image("websearch.icon")
					.resizable()
					.scaledToFit()
					.frame(width: 17, height: 17)
					.accessibilityHidden(true)
			}

			Text(displayText)
		}
			.font(.openRunde(size: 16))
			.foregroundStyle(.secondary)
			.shimmering()
			.id(displayText)
			.transition(.blurFade)
			.frame(maxWidth: .infinity, alignment: .leading)
			.task {
				rotatingStatus = rotatingStatuses.randomElement() ?? "Thinking"

				while !Task.isCancelled {
					try? await Task.sleep(for: .seconds(3))
					guard shouldRotate else { continue }

					withAnimation(.smooth(duration: 0.22)) {
						let nextStatuses = rotatingStatuses.filter { $0 != rotatingStatus }
						rotatingStatus = (nextStatuses.randomElement() ?? rotatingStatuses.randomElement()) ?? "Thinking"
					}
				}
			}
	}

	private var displayText: String {
		shouldRotate ? rotatingStatus : text
	}

	private var shouldRotate: Bool {
		text == "Thinking"
	}

	private var isSearchingWeb: Bool {
		text == "Searching the web"
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

private struct UserMessageEntranceModifier: ViewModifier {
	let isEnabled: Bool
	@State private var isVisible = false

	func body(content: Content) -> some View {
		content
			.scaleEffect(isEnabled && !isVisible ? 0.97 : 1, anchor: .bottomTrailing)
			.offset(y: isEnabled && !isVisible ? 8 : 0)
			.opacity(isEnabled && !isVisible ? 0 : 1)
			.onAppear {
				showIfNeeded()
			}
			.onChange(of: isEnabled) { _, enabled in
				guard enabled else { return }
				showIfNeeded()
			}
	}

	private func showIfNeeded() {
		guard isEnabled, !isVisible else { return }
		withAnimation(.spring(duration: 0.32, bounce: 0.08)) {
			isVisible = true
		}
	}
}

extension AnyTransition {
	static var blurFade: AnyTransition {
		.modifier(
			active: BlurFadeModifier(radius: 8, opacity: 0),
			identity: BlurFadeModifier(radius: 0, opacity: 1)
		)
	}
}

private extension String {
	func removingRenderedSourceSection() -> String {
		var lines = components(separatedBy: .newlines)
		let sourceHeadingIndex = lines.lastIndex { line in
			let normalized = line
				.trimmingCharacters(in: .whitespacesAndNewlines)
				.trimmingCharacters(in: CharacterSet(charactersIn: "#*:"))
				.trimmingCharacters(in: .whitespacesAndNewlines)
				.lowercased()

			return ["source", "sources", "reference", "references", "citation", "citations"].contains(normalized)
		}

		if let sourceHeadingIndex, lines[(sourceHeadingIndex + 1)...].contains(where: \.looksLikeSourceLine) {
			lines.removeSubrange(sourceHeadingIndex...)
		}

		return lines
			.joined(separator: "\n")
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private var looksLikeSourceLine: Bool {
		let trimmed = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard !trimmed.isEmpty else { return false }

		return trimmed.hasPrefix("-")
			|| trimmed.hasPrefix("*")
			|| trimmed.hasPrefix("[")
			|| trimmed.hasPrefix("http://")
			|| trimmed.hasPrefix("https://")
			|| trimmed.contains("](http")
	}
}

private var previewAttachmentData: Data? {
	#if canImport(UIKit)
	UIImage(named: "whylocal")?.jpegData(compressionQuality: 0.8)
	#elseif canImport(AppKit)
	NSImage(named: NSImage.Name("whylocal"))?.tiffRepresentation
	#endif
}

#Preview("Image attachment") {
	NavigationStack {
		VStack {
			Spacer()
			MessageBubble(
				text: "What can you tell me about this library?",
				imageData: previewAttachmentData,
				role: .user
			)
			Spacer()
		}
		.padding(20)
		.background(Color(uiColor: .systemBackground))
	}
	.frame(width: 390, height: 420)
}

#Preview("Conversation") {
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
