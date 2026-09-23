//
//  Input.swift
//  beacon
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI
import Foundation

#if false // Web search input controls are not currently available.
struct Input: View {
	@Binding var text: String
	@Binding private var isWebSearchTagged: Bool
	var placeholder: String = "Message"
	var isGenerating = false
	var hasAttachment = false
	var isWebSearchEnabled = true
	var webSearchTitle = "Search Web"
	var isWebSearchUnavailable = false
	var webSearchUnavailableTitle = "Daily limit reached"
	var onStop: () -> Void = {}
	var onSend: (String) -> Void

	@State private var textFieldHeight: CGFloat = 0
	@State private var inputHeight: CGFloat = 52
	@State private var resetID = UUID()
	@FocusState private var isTextFieldFocused: Bool

	init(
		text: Binding<String>,
		isWebSearchTagged: Binding<Bool> = .constant(false),
		placeholder: String = "Message",
		isGenerating: Bool = false,
		isWebSearchEnabled: Bool = true,
		webSearchTitle: String = "Search Web",
		isWebSearchUnavailable: Bool = false,
		webSearchUnavailableTitle: String = "Daily limit reached",
		onStop: @escaping () -> Void = {},
		onSend: @escaping (String) -> Void
	) {
		self._text = text
		self._isWebSearchTagged = isWebSearchTagged
		self.placeholder = placeholder
		self.isGenerating = isGenerating
		self.isWebSearchEnabled = isWebSearchEnabled
		self.webSearchTitle = webSearchTitle
		self.isWebSearchUnavailable = isWebSearchUnavailable
		self.webSearchUnavailableTitle = webSearchUnavailableTitle
		self.onStop = onStop
		self.onSend = onSend
	}

	private var hasTypedText: Bool {
		!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private var canSend: Bool {
		hasTypedText || hasAttachment
	}

	private var showsWebSuggestion: Bool {
		isWebSearchEnabled && !isWebSearchTagged && text.contains("@")
	}

	private var cornerRadius: CGFloat {
		let singleLineHeight: CGFloat = 22
		let multilineAmount = min(max((textFieldHeight - singleLineHeight) / singleLineHeight, 0), 1)
		let singleLineRadius: CGFloat = 30
		return singleLineRadius - (multilineAmount * (singleLineRadius - 16))
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if showsWebSuggestion {
				Pill(
					title: isWebSearchUnavailable ? webSearchUnavailableTitle : webSearchTitle,
					size: .regular,
					image: "globe.icon"
				) {
					guard !isWebSearchUnavailable else { return }
					selectWebSearchTag()
				}
				.disabled(isWebSearchUnavailable)
				.blur(radius: isWebSearchUnavailable ? 0.6 : 0)
				.opacity(isWebSearchUnavailable ? 0.55 : 1)
				.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
			}

			inputCapsule
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.animation(.smooth(duration: 0.22), value: cornerRadius)
		.animation(.smooth(duration: 0.18), value: showsWebSuggestion)
		.onChange(of: text) { _, newText in
			if newText.isEmpty {
				withAnimation(.smooth(duration: 0.18)) {
					textFieldHeight = 22
					inputHeight = 52
					resetID = UUID()
				}
			}

			if isWebSearchTagged && newText.localizedCaseInsensitiveContains("@web") {
				text = text.removingWebTagTrigger()
				resetID = UUID()
			}
		}
	}

	private var inputCapsule: some View {
		VStack(alignment: .leading, spacing: isWebSearchEnabled && isWebSearchTagged ? 10 : 0) {
			if isWebSearchEnabled && isWebSearchTagged {
				Pill(title: isWebSearchUnavailable ? webSearchUnavailableTitle : webSearchTitle, size: .regular, image: "globe.icon", trailingSystemImage: "xmark") {
					withAnimation(.smooth(duration: 0.18)) {
						isWebSearchTagged = false
					}
					isTextFieldFocused = true
				}
				.blur(radius: isWebSearchUnavailable ? 0.6 : 0)
				.opacity(isWebSearchUnavailable ? 0.55 : 1)
				.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
			}

			HStack(alignment: .bottom, spacing: 8) {
				messageTextField

				Button {
					if isGenerating {
						onStop()
						return
					}

					let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
					guard canSend else { return }
					text = ""
					onSend(trimmed)
				} label: {
					Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
						.font(.system(size: 16, weight: .bold))
						.frame(width: 28, height: 28)
						.foregroundStyle((hasTypedText || isGenerating) ? Color(uiColor: .systemBackground) : .secondary)
						.background((hasTypedText || isGenerating) ? Color.primary : Color(uiColor: .systemGray4), in: Circle())
				}
				.buttonStyle(.plain)
				.disabled(!hasTypedText && !isGenerating)
				.opacity((hasTypedText || isGenerating) ? 1 : 0.9)
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 12)
		.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
		.background {
			GeometryReader { proxy in
				Color.clear
					.onAppear {
						inputHeight = proxy.size.height
					}
					.onChange(of: proxy.size.height) { _, newHeight in
						inputHeight = newHeight
					}
			}
		}
	}

	private var messageTextField: some View {
		TextField(placeholder, text: $text, axis: .vertical)
			.font(.beaconFont(size: 16, weight: .medium))
			.id(resetID)
			.focused($isTextFieldFocused)
			.frame(maxWidth: .infinity, alignment: .leading)
			.lineLimit(1 ... 4)
			#if !os(macOS)
			.textInputAutocapitalization(.sentences)
			#endif
			.autocorrectionDisabled(false)
			.padding(.vertical, 4)
			.background {
				GeometryReader { proxy in
					Color.clear
						.onAppear {
							textFieldHeight = proxy.size.height
						}
						.onChange(of: proxy.size.height) { _, newHeight in
							withAnimation(.smooth(duration: 0.22)) {
								textFieldHeight = newHeight
							}
						}
				}
			}
	}

	private func selectWebSearchTag() {
		guard !isWebSearchUnavailable else { return }

		withAnimation(.smooth(duration: 0.18)) {
			isWebSearchTagged = true
			text = text.removingWebTagTrigger().removingToolMentionTrigger()
			resetID = UUID()
		}

		Task { @MainActor in
			isTextFieldFocused = true
		}
	}
}

#else

struct Input: View {
	@Binding var text: String
	var placeholder: String = "Message"
	var isGenerating = false
	var hasAttachment = false
	var attachmentData: [Data] = []
	var onAttachImage: (() -> Void)?
	var canAttachImages = true
	var showsConversationStarters = true
	var onRemoveAttachment: (Int) -> Void = { _ in }
	var onStop: () -> Void = {}
	var onSend: (String) -> Void

	@State private var textFieldHeight: CGFloat = 0
	@State private var resetID = UUID()
	@FocusState private var isTextFieldFocused: Bool

	private var hasTypedText: Bool {
		!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private var canSend: Bool {
		hasTypedText || hasAttachment
	}

	private var cornerRadius: CGFloat {
		let singleLineHeight: CGFloat = 22
		let multilineAmount = min(max((textFieldHeight - singleLineHeight) / singleLineHeight, 0), 1)
		return 30 - (multilineAmount * 14)
	}

	private var showsSuggestions: Bool {
		showsConversationStarters && isTextFieldFocused && !hasTypedText && !hasAttachment && attachmentData.isEmpty && !isGenerating
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			if showsSuggestions {
				ChatSuggestionsView { suggestion in
					text = suggestion
					isTextFieldFocused = true
				}
				.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)).combined(with: .move(edge: .bottom)))
			}

			inputControls
		}
		.animation(.smooth(duration: 0.24), value: showsSuggestions)
	}

	private var inputControls: some View {
		VStack(alignment: .leading, spacing: 12) {
			if !attachmentData.isEmpty {
				AttachedImagePreview(data: attachmentData, onRemove: onRemoveAttachment)
			}

			TextField(placeholder, text: $text, axis: .vertical)
				.font(.beaconFont(size: 16, weight: .medium))
				.id(resetID)
				.focused($isTextFieldFocused)
				.frame(maxWidth: .infinity, alignment: .leading)
				.lineLimit(1 ... 4)
				#if !os(macOS)
				.textInputAutocapitalization(.sentences)
				#endif
				.autocorrectionDisabled(false)
				.padding(.vertical, 4)
				.background {
					GeometryReader { proxy in
						Color.clear.onChange(of: proxy.size.height) { _, newHeight in
							withAnimation(.smooth(duration: 0.22)) { textFieldHeight = newHeight }
						}
					}
				}

			HStack(spacing: 8) {
				if let onAttachImage {
					Button(action: onAttachImage) {
						Image(systemName: "plus")
							.font(.system(size: 17, weight: .medium))
							.foregroundStyle(canAttachImages ? .primary : .secondary)
							.frame(width: 32, height: 32)
						.background(Color(uiColor: .systemGray5), in: Circle())
					}
					.buttonStyle(.plain)
					.disabled(!canAttachImages)
					.accessibilityLabel("Attach image")
				}

				Spacer(minLength: 8)

				Button {
					if isGenerating {
						onStop()
						return
					}
					let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
					guard canSend else { return }
					text = ""
					onSend(trimmed)
				} label: {
					Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
						.font(.system(size: 16, weight: .bold))
						.frame(width: 32, height: 32)
						.foregroundStyle((canSend || isGenerating) ? Color.white : Color.secondary)
						.background((canSend || isGenerating) ? Color.black : Color(uiColor: .systemGray4), in: Circle())
				}
				.buttonStyle(.plain)
				.disabled(!canSend && !isGenerating)
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 12)
		.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
	}
}

#endif

private struct ChatSuggestionsView: View {
	private struct Suggestion: Identifiable {
		let text: String

		var id: String { text }
	}

	let onSelect: (String) -> Void
	@State private var isVisible = false
	@State private var displayedSuggestions: [Suggestion] = []

	private let allSuggestions = [
		Suggestion(text: "Tell me about hurricanes"),
		Suggestion(text: "Teach me something new"),
		Suggestion(text: "Give me a fun fact"),
		Suggestion(text: "Explain black holes simply"),
		Suggestion(text: "Help me plan my week"),
		Suggestion(text: "Help me write a message")
	]

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(Array(displayedSuggestions.enumerated()), id: \.element.id) { index, suggestion in
				Button {
					onSelect(suggestion.text)
				} label: {
					Text(suggestion.text)
						.font(.beaconFont(size: 16, weight: .medium))
						.foregroundStyle(.primary)
						.padding(.horizontal, 16)
						.padding(.vertical, 12)
						.background(Color.white.opacity(0.8), in: Capsule())
						.glassEffect(.regular, in: Capsule())
						.overlay {
							Capsule()
								.stroke(Color.white.opacity(0.8), lineWidth: 1)
						}
						.shadow(color: .black.opacity(0.06), radius: 12, y: 5)
				}
				.buttonStyle(.spring)
				.opacity(isVisible ? 1 : 0)
				.blur(radius: isVisible ? 0 : 10)
				.offset(y: isVisible ? 0 : 12)
				.animation(.smooth(duration: 0.32).delay(Double(index) * 0.05), value: isVisible)
			}
		}
		.onAppear {
			displayedSuggestions = Array(allSuggestions.shuffled().prefix(3))
			isVisible = true
		}
		.onDisappear {
			isVisible = false
		}
	}
}

#if false // Web search input triggers are not currently available.
extension String {
	func removingWebTagTrigger() -> String {
		var result = self
		while let range = result.range(of: "@web", options: [.caseInsensitive]) {
			result.removeSubrange(range)
		}

		return result
			.replacingOccurrences(of: "  ", with: " ")
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	func removingToolMentionTrigger() -> String {
		replacingOccurrences(of: "@", with: "")
			.replacingOccurrences(of: "  ", with: " ")
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
#endif

#Preview {
	InputPreviewContainer()
}

private struct InputPreviewContainer: View {
	@State private var previewText = ""

	var body: some View {
		Input(
			text: $previewText,
			onAttachImage: {}
		) { _ in }
			.padding()
			.background(Color(uiColor: .systemBackground))
	}
}
