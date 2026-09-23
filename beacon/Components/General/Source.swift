//
//  Source.swift
//  beacon
//
//  Created by Armond Schneider on 6/21/26.
//

import MarkdownView
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
	enum Variant: Equatable {
		case inline
		case pill
	}

	let sources: [Source]
	var onOpen: (URL) -> Void
	var variant: Variant = .inline

	@State private var isExpanded = false
	@State private var isShowingSources = false

	var body: some View {
		if !sources.isEmpty {
				if variant == .pill {
					pill
						.sheet(isPresented: $isShowingSources) {
							SourcesSheet(sources: sources, onOpen: onOpen)
						}
				} else {
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
	}

	private var pill: some View {
		Button {
			#if canImport(UIKit)
			UIImpactFeedbackGenerator(style: .light).impactOccurred()
			#endif
			isShowingSources = true
		} label: {
			Text("Sources")
				.font(.beaconFont(size: 13, weight: .medium))
				.foregroundStyle(.primary)
				.padding(.horizontal, 14)
				.frame(minHeight: 36)
				.background(Color(uiColor: .systemGray6), in: Capsule())
		}
		.buttonStyle(.spring)
		.accessibilityLabel("Show \(sources.count) source\(sources.count == 1 ? "" : "s")")
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
							.font(.openRunde(size: 14, weight: .semibold))
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

struct SourceReferenceLinkRenderer: MarkdownLinkRenderer {
	let onSelect: (Int) -> Void

	func makeBody(configuration: Configuration) -> some View {
		SourceReferenceLinkView(configuration: configuration, onSelect: onSelect)
	}
}

private struct SourceReferenceLinkView: View {
	let configuration: MarkdownLinkRendererConfiguration
	let onSelect: (Int) -> Void

	private var sourceIndex: Int? {
		guard configuration.url.scheme == "beacon-source",
			  let host = configuration.url.host,
			  let sourceNumber = Int(host),
			  sourceNumber > 0 else {
			return nil
		}

		return sourceNumber - 1
	}

	var body: some View {
		if let sourceIndex {
			Button {
				onSelect(sourceIndex)
			} label: {
				configuration.label
					.foregroundStyle(Color(uiColor: .systemBlue))
					.overlay(alignment: .bottom) {
						Capsule()
							.stroke(
								Color(uiColor: .systemBlue),
								style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 3])
							)
							.frame(height: 1)
					}
			}
			.buttonStyle(.plain)
		} else {
			configuration.label
		}
	}
}

struct InlineSourceCard: View {
	let source: Source
	var onOpen: (URL) -> Void

	var body: some View {
		Button {
			onOpen(source.url)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				Text(source.displayHost)
					.font(.beaconFont(size: 14, weight: .semibold))
					.foregroundStyle(.secondary)

				Text(source.title)
					.font(.beaconFont(size: 16, weight: .medium))
					.foregroundStyle(.primary)
					.lineLimit(2)

				if !source.description.isEmpty {
					Text(source.description)
						.font(.beaconFont(size: 14))
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
			}
			.padding(14)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color(uiColor: .systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
		.buttonStyle(.spring)
		.accessibilityLabel("Open source: \(source.title)")
	}
}

private struct SourcesSheet: View {
	@Environment(\.dismiss) private var dismiss
	let sources: [Source]
	var onOpen: (URL) -> Void

	var body: some View {
		NavigationStack {
			List(sources) { source in
				Button {
					onOpen(source.url)
					dismiss()
				} label: {
					VStack(alignment: .leading, spacing: 4) {
						Text(source.title.isEmpty ? source.displayHost : source.title)
							.font(.beaconFont(size: 14, weight: .medium))
							.foregroundStyle(.primary)

						Text(source.displayHost)
							.font(.beaconFont(size: 14))
							.foregroundStyle(.secondary)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.buttonStyle(.plain)
			}
			.listStyle(.insetGrouped)
			.navigationTitle("Sources")
			#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.toolbar {
				#if os(macOS)
				ToolbarItem(placement: .automatic) {
					Button("Done") {
						dismiss()
					}
				}
				#else
				ToolbarItem(placement: .topBarTrailing) {
					Button("Done") {
						dismiss()
					}
				}
				#endif
			}
		}
		#if !os(macOS)
		.presentationDetents([.medium, .large])
		#endif
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

#Preview("Sources pill") {
	SourceTag(
		sources: [
			Source(title: "Example source", url: URL(string: "https://vox.com")!),
			Source(title: "Another source", url: URL(string: "https://apple.com/newsroom")!)
		],
		onOpen: { _ in },
		variant: .pill
	)
	.padding()
}
