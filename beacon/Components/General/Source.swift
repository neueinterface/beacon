//
//  Source.swift
//  beacon
//
//  Created by Armond Schneider on 6/21/26.
//

import SwiftUI

struct Source: Identifiable, Hashable, Codable {
	let id: UUID
	let title: String
	let url: URL
	let description: String

	init(id: UUID = UUID(), title: String, url: URL, description: String = "") {
		self.id = id
		self.title = title
		self.url = url
		self.description = description
	}

	var displayHost: String {
		url.host()?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
	}
}

struct SourceTag: View {
	let sources: [Source]
	var onOpen: (URL) -> Void

	@State private var isExpanded = false

	var body: some View {
		if !sources.isEmpty {
			VStack(alignment: .leading, spacing: 10) {
				header

				if isExpanded {
					sourceList
						.transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}

	private var header: some View {
		Button {
			#if canImport(UIKit)
			UIImpactFeedbackGenerator(style: .light).impactOccurred()
			#endif

			withAnimation(.easeOut(duration: 0.2)) {
				isExpanded.toggle()
			}
		} label: {
			HStack(spacing: 8) {
				Text("From \(sources.count) Source\(sources.count == 1 ? "" : "s")")
					.font(.openRunde(size: 14, weight: .medium))

				Image(systemName: "chevron.down")
					.font(.system(size: 14, weight: .medium))
					.rotationEffect(.degrees(isExpanded ? 180 : 0))
			}
			.foregroundStyle(.secondary)
			.padding(.vertical, 2)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	private var sourceList: some View {
		VStack(alignment: .leading, spacing: 12) {
			ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
				Button {
					#if canImport(UIKit)
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
					#endif
					onOpen(source.url)
				} label: {
					VStack(alignment: .leading, spacing: 3) {
						Text("[\(index + 1)] \(source.displayHost)")
							.font(.openRunde(size: 16, weight: .semibold))
							.foregroundStyle(.secondary)

						if !source.title.isEmpty {
							Text(source.title)
								.font(.openRunde(size: 13))
								.foregroundStyle(.tertiary)
								.lineLimit(2)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
			}
		}
		.padding(.top, 2)
		.padding(.bottom, 4)
	}
}

#Preview {
	SourceTag(
		sources: [
			Source(title: "Example source", url: URL(string: "https://vox.com")!),
			Source(title: "Another source", url: URL(string: "https://apple.com/newsroom")!)
		],
		onOpen: { _ in }
	)
	.padding()
}
