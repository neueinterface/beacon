//
//  Tag.swift
//  beacon
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI

struct Tag: View {
	let title: String
	var color: Color = .gray

	var body: some View {
		Text(title)
			.font(.openRunde(size: 12, weight: .semibold))
			.foregroundStyle(color)
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
	}
}

struct ModelSwitchToast: View {
	let modelName: String

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 16, weight: .semibold))

			Text("Switched to '\(modelName)'")
				.font(.openRunde(size: 14, weight: .semibold))
		}
		.foregroundStyle(.primary)
		.padding(.horizontal, 16)
		.frame(minHeight: 42)
		.background(Color(uiColor: .systemGray6), in: Capsule())
		.overlay {
			Capsule()
				.stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
		}
		.shadow(color: .black.opacity(0.12), radius: 18, y: 8)
	}
}

#Preview {
	HStack(spacing: 12) {
		Tag(title: "vision", color: .indigo)
		Tag(title: "deep research", color: .orange)
	}
	.padding()
}
