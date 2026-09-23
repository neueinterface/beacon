import SwiftUI
import MarkdownView
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct MessageBubble: View {
	@Namespace private var attachmentTransition
	@State private var isShowingCopied = false
	@State private var copyResetTask: Task<Void, Never>?
	@State private var selectedSource: Source?
	let text: String
	var imageData: Data?
	var imageDatas: [Data] = []
	var informationCard: InformationCardContent?
	var sources: [Source] = []
	let role: ChatMessage.Role
	var animatesEntrance = false
	var isWaitingForResponse = false
	var thinkingText = ""
	var onOpenSource: (URL) -> Void = { _ in }
	var showsRetry = false
	var onRetry: () -> Void = {}
	var onCopy: () -> Void = {}

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
				copyToClipboard(text)
				onCopy()
			} label: {
				Label("Copy", systemImage: "doc.on.doc")
			}
		}
	}

	private var assistantText: some View {
		VStack(alignment: .leading, spacing: 10) {
			if isWaitingForResponse, text.isEmpty {
				ThinkingStatusText(text: thinkingText.isEmpty ? "Thinking" : thinkingText)
			}

			if let informationCard, !displayText.isEmpty {
				InformationCardView(
					title: informationCard.title,
					text: displayText,
					imageURL: informationCard.imageURL,
					sources: sources,
					onOpenSource: onOpenSource
				)
			} else if !displayText.isEmpty {
				MarkdownView(displayText)
					.font(.beaconFont(size: 16, weight: .medium), for: .body)
					.lineSpacing(0)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h1)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h2)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h3)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h4)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h5)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h6)
					.font(.system(size: 16, design: .monospaced), for: .codeBlock)
					.foregroundStyle(.primary)
					.tint(.secondary, for: .inlineCodeBlock)
					.markdownElementRenderer(
						.link(SourceReferenceLinkRenderer { selectSource(at: $0) }, urlScheme: "beacon-source")
					)
			}

			if let selectedSource {
				InlineSourceCard(source: selectedSource, onOpen: onOpenSource)
					.transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
			}

			if informationCard == nil, !isWaitingForResponse {
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

			if !isWaitingForResponse, !displayText.isEmpty {
				Button {
					copyToClipboard(displayText)
					onCopy()
					showCopiedState()
				} label: {
					ZStack {
						if isShowingCopied {
							Image(systemName: "checkmark")
								.font(.system(size: 15, weight: .semibold))
								.foregroundStyle(.green)
								.transition(.blurFade.combined(with: .scale(scale: 0.8)))
						} else {
							Image("copy.icon")
								.renderingMode(.template)
								.resizable()
								.scaledToFit()
								.frame(width: 18, height: 18)
								.foregroundStyle(.secondary)
								.transition(.blurFade.combined(with: .scale(scale: 0.8)))
						}
					}
					.frame(width: 32, height: 32)
					.animation(.spring(response: 0.32, dampingFraction: 0.72), value: isShowingCopied)
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Copy message")
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var displayText: String {
		guard role == .assistant, !sources.isEmpty else { return text }
		return text.removingRenderedSourceSection()
	}

	private func copyToClipboard(_ value: String) {
		#if canImport(UIKit)
		UIPasteboard.general.string = value
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		#elseif canImport(AppKit)
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(value, forType: .string)
		#endif
	}

	private func showCopiedState() {
		copyResetTask?.cancel()
		withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
			isShowingCopied = true
		}

		copyResetTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.9))
			guard !Task.isCancelled else { return }
			withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
				isShowingCopied = false
			}
		}
	}

	private func selectSource(at index: Int) {
		guard sources.indices.contains(index) else { return }
		withAnimation(.smooth(duration: 0.2)) {
			selectedSource = sources[index]
		}
	}

	private var userBubble: some View {
		VStack(alignment: .trailing, spacing: 8) {
			if !imageDatas.isEmpty || imageData != nil {
				ChatAttachedImages(data: imageDatas.isEmpty ? [imageData].compactMap { $0 } : imageDatas, transitionNamespace: attachmentTransition)
			}

			if !text.isEmpty {
				Text(text)
					.font(.beaconFont(size: 16, weight: .medium))
					.lineSpacing(0)
					.foregroundStyle(.primary)
					.padding(.horizontal, 16)
					.padding(.vertical, 14)
					.background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
			}
		}
		.frame(maxWidth: .infinity, alignment: .trailing)
	}
}

private struct ChatAttachedImages: View {
	private let transitionID = "attached-image"
	let data: [Data]
	let transitionNamespace: Namespace.ID

	var body: some View {
		Group {
			if data.count >= 4 {
				LazyVGrid(columns: Array(repeating: GridItem(.fixed(96), spacing: 8), count: 2), spacing: 8) {
					imageLinks
				}
			} else {
				HStack(spacing: 8) {
					imageLinks
				}
			}
		}
		.accessibilityLabel("Attached images, \(data.count)")
	}

	@ViewBuilder
	private var imageLinks: some View {
		ForEach(Array(data.enumerated()), id: \.offset) { index, imageData in
			NavigationLink {
				AttachedImageViewer(data: imageData)
			} label: {
				thumbnail(imageData)
					.matchedTransitionSource(id: "\(transitionID)-\(index)", in: transitionNamespace)
			}
			.buttonStyle(.plain)
	}
	}

	@ViewBuilder
	private func thumbnail(_ data: Data) -> some View {
		#if canImport(UIKit)
		if let image = UIImage(data: data) {
			Image(uiImage: image)
				.resizable()
				.scaledToFill()
				.frame(width: 96, height: 96)
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
		#elseif canImport(AppKit)
		if let image = NSImage(data: data) {
			Image(nsImage: image)
				.resizable()
				.scaledToFill()
				.frame(width: 96, height: 96)
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
			.font(.beaconFont(size: 16, weight: .medium))
			.foregroundStyle(.secondary)
			.shimmering()
			.id(displayText)
			.transition(.blurFade)
			.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var displayText: String {
		text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Thinking" : text.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private var isSearchingWeb: Bool {
		text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("searching web:")
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

private var previewAttachmentDatas: [Data] {
	Array(repeating: previewAttachmentData, count: 3).compactMap { $0 }
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

#Preview("Stacked image attachments") {
	NavigationStack {
		VStack {
			Spacer()
			MessageBubble(
				text: "Can you compare these images?",
				imageDatas: previewAttachmentDatas,
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
