//
//  Source.swift
//  sonara-ios
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
					.zIndex(1)

				if isExpanded {
					sourceList
						.transition(
							.asymmetric(
								insertion: .opacity.combined(with: .move(edge: .top)),
								removal: .opacity.combined(with: .move(edge: .top))
							)
						)
				}
			}
			.animation(.smooth(duration: 0.24), value: isExpanded)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}

	private var header: some View {
		Button {
			isExpanded.toggle()
		} label: {
			HStack(spacing: 8) {
				Text("From \(sources.count) Source\(sources.count == 1 ? "" : "s")")
					.font(.system(size: 15, weight: .medium))

				Image(systemName: "chevron.down")
					.font(.system(size: 15, weight: .semibold))
					.rotationEffect(.degrees(isExpanded ? 180 : 0))
			}
			.foregroundStyle(.secondary)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	private var sourceList: some View {
		VStack(alignment: .leading, spacing: 12) {
			ForEach(sources) { source in
				Button {
					onOpen(source.url)
				} label: {
					VStack(alignment: .leading, spacing: 3) {
						Text(source.displayHost)
							.font(.system(size: 15, weight: .semibold))
							.foregroundStyle(.secondary)

						if !source.title.isEmpty {
							Text(source.title)
								.font(.system(size: 13))
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
		.background(.regularMaterial.opacity(0.001))
		.mask(alignment: .top) {
			LinearGradient(
				stops: [
					.init(color: .clear, location: 0),
					.init(color: .black, location: 0.08),
					.init(color: .black, location: 1)
				],
				startPoint: .top,
				endPoint: .bottom
			)
		}
		.clipped()
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
