import Foundation
import MarkdownView
import SwiftUI

struct InformationCardView: View {
	let title: String
	let text: String
	let imageURL: URL?
	let sources: [Source]
	var onOpenSource: (URL) -> Void = { _ in }
	@State private var selectedSource: Source?

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			if let imageURL {
				AsyncImage(url: imageURL) { phase in
					switch phase {
					case let .success(image):
						image
							.resizable()
							.scaledToFill()
					case .empty:
						ProgressView()
							.frame(maxWidth: .infinity, maxHeight: .infinity)
					case .failure:
						Image(systemName: "photo")
							.font(.system(size: 28))
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, maxHeight: .infinity)
					@unknown default:
						EmptyView()
					}
				}
				.frame(width: 88, height: 88)
				.background(Color(uiColor: .systemGray6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
				.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
			}

			VStack(alignment: .leading, spacing: 5) {
				Text(title)
					.font(.beaconFont(size: 16, weight: .bold))
					.foregroundStyle(.primary)

				MarkdownView(cleanText)
					.font(.beaconFont(size: 16, weight: .medium), for: .body)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h1)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h2)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h3)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h4)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h5)
					.font(.beaconFont(size: 16, weight: .semibold), for: .h6)
					.font(.system(size: 16, design: .monospaced), for: .codeBlock)
					.foregroundStyle(.primary)
					.lineSpacing(0)
					.markdownElementRenderer(
						.link(SourceReferenceLinkRenderer { selectSource(at: $0) }, urlScheme: "beacon-source")
					)
			}

			if let selectedSource {
				InlineSourceCard(source: selectedSource, onOpen: onOpenSource)
					.transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
			}

			if !sources.isEmpty {
				SourceTag(sources: sources, onOpen: onOpenSource, variant: .pill)
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 16)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
	}

	private var cleanText: String {
		let withoutCitations = text.replacingOccurrences(
			of: #"\s*\[\d+\]"#,
			with: "",
			options: .regularExpression
		)
		return withoutCitations.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private func selectSource(at index: Int) {
		guard sources.indices.contains(index) else { return }
		withAnimation(.smooth(duration: 0.2)) {
			selectedSource = sources[index]
		}
	}
}

#Preview {
	InformationCardView(
		title: "A little history on Mona Lisa",
		text: "Oh, the Mona Lisa has a much more interesting story than you might expect.Leonardo da Vinci started painting her around 1503, and she became famous through a strange mix of art, history, and one very dramatic theft.",
		imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/6/6a/Mona_Lisa.jpg"),
		sources: [Source(title: "The Louvre", url: URL(string: "https://www.louvre.fr")!)]
	)
	.padding()
	.background(Color(uiColor: .systemGray6))
}
