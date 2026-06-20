//
//  Input.swift
//  beacon-ios
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI
import UIKit

struct Input: View {
	@Binding var text: String
	var placeholder: String = "Message"
	var onSend: (String) -> Void

	@State private var textFieldHeight: CGFloat = 0
	@State private var inputHeight: CGFloat = 52
	@State private var resetID = UUID()

	private var hasTypedText: Bool {
		!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private var cornerRadius: CGFloat {
		let singleLineHeight: CGFloat = 22
		let multilineAmount = min(max((textFieldHeight - singleLineHeight) / singleLineHeight, 0), 1)
		let singleLineRadius: CGFloat = 30
		return singleLineRadius - (multilineAmount * (singleLineRadius - 16))
	}

	var body: some View {
		inputCapsule
		.frame(maxWidth: .infinity)
		.animation(.smooth(duration: 0.22), value: cornerRadius)
		.onChange(of: text) { _, newText in
			guard newText.isEmpty else { return }

			withAnimation(.smooth(duration: 0.18)) {
				textFieldHeight = 22
				inputHeight = 52
				resetID = UUID()
			}
		}
	}

	private var inputCapsule: some View {
		HStack(alignment: .bottom, spacing: 8) {
			TextField(placeholder, text: $text, axis: .vertical)
				.id(resetID)
				.frame(maxWidth: .infinity, alignment: .leading)
				.lineLimit(1 ... 4)
				.textInputAutocapitalization(.sentences)
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

			Button {
				let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !trimmed.isEmpty else { return }
				text = ""
				onSend(trimmed)
			} label: {
				Image(systemName: "arrow.up")
					.font(.system(size: 16, weight: .bold))
					.frame(width: 28, height: 28)
					.foregroundStyle(hasTypedText ? Color(uiColor: .systemBackground) : .secondary)
					.background(hasTypedText ? Color.primary : Color(uiColor: .systemGray4), in: Circle())
			}
			.buttonStyle(.plain)
			.disabled(!hasTypedText)
			.opacity(hasTypedText ? 1 : 0.9)
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
}

#Preview {
	InputPreviewContainer()
}

private struct InputPreviewContainer: View {
	@State private var previewText = ""

	var body: some View {
		Input(text: $previewText) { _ in }
			.padding()
			.background(Color(uiColor: .systemBackground))
	}
}
