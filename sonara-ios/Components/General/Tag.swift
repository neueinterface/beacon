//
//  Tag.swift
//  sonara-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI

struct Tag: View {
	let title: String
	var color: Color = .gray

	var body: some View {
		Text(title)
			.font(.system(size: 12, weight: .semibold))
			.foregroundStyle(color)
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
	}
}

#Preview {
	HStack(spacing: 12) {
		Tag(title: "vision", color: .indigo)
		Tag(title: "deep research", color: .orange)
	}
	.padding()
}
