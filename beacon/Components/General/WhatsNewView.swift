import SwiftUI

struct WhatsNewRelease {
	let id: String
	let heroImageName: String
	let title: String
	let subtitle: String
	let updates: [String]

	/// Set to nil to disable What's New for the current build.
	static let current: WhatsNewRelease? = .version102

	static let version102 = WhatsNewRelease(
		id: "1.0.2",
		heroImageName: "whatsnew",
		title: "What's New in 1.0.2",
		subtitle: "The latest improvements in Beacon.",
		updates: [
			"Web search is now supported, bringing current information into your conversations.",
			"Model pages now include more details to help you choose the right model."
		]
	)

	static let modelMarketplace = WhatsNewRelease(
		id: "2026-07-model-marketplace",
		heroImageName: "whatsnew",
		title: "What's New",
		subtitle: "The latest improvements in Beacon.",
		updates: [
			"Browse a larger collection of local models from the marketplace.",
			"Choose models that fit your device, download them, and switch whenever you need.",
			"Keep every conversation and model on your device."
		]
	)
}

struct WhatsNewView: View {
	/// Matches the screen-level horizontal padding used across the app.
	static let contentHorizontalPadding: CGFloat = 20

	let release: WhatsNewRelease
	var onClose: () -> Void = { }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				hero

				VStack(alignment: .leading, spacing: 24) {
				VStack(alignment: .leading, spacing: 10) {
					Text(release.title)
						.font(.system(size: 32, weight: .semibold))
						.foregroundStyle(.primary)

					Text(release.subtitle)
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
				}

				VStack(alignment: .leading, spacing: 14) {
					ForEach(release.updates, id: \.self) { update in
						HStack(alignment: .firstTextBaseline, spacing: 10) {
							Text("•")
								.font(.system(size: 18, weight: .semibold))
								.foregroundStyle(.primary)

							Text(update)
								.font(.system(size: 16, weight: .regular))
								.foregroundStyle(.primary)
								.lineSpacing(3)
						}
					}
				}
				}
				.padding(.horizontal, Self.contentHorizontalPadding)
				.padding(.bottom, 48)
			}
		}
		.scrollEdgeEffectStyle(.soft, for: .top)
		.background(Color(uiColor: .systemBackground))
		.presentationDetents([.height(560)])
		.presentationDragIndicator(.visible)
	}

	private var hero: some View {
		ZStack(alignment: .topTrailing) {
			Image(release.heroImageName)
				.resizable()
				.scaledToFit()
				.frame(maxWidth: .infinity)
				.accessibilityIdentifier("whatsNewHeroImage")

			Button(action: onClose) {
				Image(systemName: "xmark")
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(.primary)
					.frame(width: 34, height: 34)
					.background(.ultraThinMaterial, in: Circle())
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Close")
			.padding(.trailing, 20)
			.padding(.vertical, 20)
		}
	}
}

#Preview {
	Color.clear
		.sheet(isPresented: .constant(true)) {
			WhatsNewView(release: .version102)
		}
}
