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

	private var hasTypedText: Bool {
		!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var body: some View {
		HStack(alignment: .bottom, spacing: 8) {
			TextField(placeholder, text: $text, axis: .vertical)
				.lineLimit(1 ... 4)
				.textInputAutocapitalization(.sentences)
				.autocorrectionDisabled(false)
				.padding(.vertical, 4)

			Button {
				let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !trimmed.isEmpty else { return }
				onSend(trimmed)
				withAnimation(.easeInOut(duration: 0.18)) {
					text = ""
				}
			} label: {
				Image(systemName: "arrow.up")
					.font(.system(size: 16, weight: .bold))
					.frame(width: 28, height: 28)
					.foregroundStyle(hasTypedText ? .white : .secondary)
					.background(hasTypedText ? Color.black : Color(UIColor.systemGray4), in: Circle())
			}
			.buttonStyle(.plain)
			.disabled(!hasTypedText)
			.opacity(hasTypedText ? 1 : 0.9)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 12)
		.background(Color(UIColor.systemGray6), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
		.animation(.easeInOut(duration: 0.18), value: text)
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
			.background(Color.white)
	}
}
