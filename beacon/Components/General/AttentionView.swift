import SwiftUI

struct AttentionContent {
	struct Action {
		enum Kind {
			case requestReview
		}

		let kind: Kind
		let title: String
		let systemImage: String
	}

	let id: String
	let heroImageName: String
	let title: String
	let subtitle: String
	let details: [String]
	let action: Action?

	/// Set to nil to disable the launch-time attention sheet for the current build.
	static let current: AttentionContent? = .version106

	static let version106 = AttentionContent(
		id: "1.0.6",
		heroImageName: "whatsnew",
		title: "What's New in 1.0.6",
		subtitle: "More models. More choice. Still private.",
		details: [
			"The Model Marketplace is back with 50 local models, organized by company, plus Chat Core and Recommended models tabs.",
			"Chat Core selects a model bundle for your device and automatically routes each message. Or choose a downloaded model yourself with the restored picker in chat.",
			"RAM-based recommendations replace iPhone-generation restrictions. Look for the green verified tag or orange memory warning when choosing a model.",
			"Downloads now show live progress while files arrive, with clearer loading feedback when it’s needed.",
			"Your existing models, chats, and memories stay saved. Add more models anytime from Settings or chat history."
		],
		action: nil
	)

	static let ratingRequest = AttentionContent(
		id: "rating-request-1",
		heroImageName: "whatsnew",
		title: "Enjoying Beacon?",
		subtitle: "A quick rating helps more people discover private, on-device AI.",
		details: [
			"Your rating takes only a moment and makes a real difference."
		],
		action: Action(kind: .requestReview, title: "Rate Beacon", systemImage: "star.fill")
	)

	static let version103 = AttentionContent(
		id: "1.0.3",
		heroImageName: "whatsnew",
		title: "What's New in 1.0.3",
		subtitle: "The latest improvements in Beacon.",
		details: [
			"Web search is fixed and more reliable than before.",
			"Beacon can now remember useful details across conversations, kept private on your device and clearable anytime."
		],
		action: nil
	)

	static let version102 = AttentionContent(
		id: "1.0.2",
		heroImageName: "whatsnew",
		title: "What's New in 1.0.2",
		subtitle: "The latest improvements in Beacon.",
		details: [
			"Web search is now supported, bringing current information into your conversations.",
			"Model pages now include more details to help you choose the right model."
		],
		action: nil
	)

	static let modelMarketplace = AttentionContent(
		id: "2026-07-models",
		heroImageName: "whatsnew",
		title: "What's New",
		subtitle: "The latest improvements in Beacon.",
		details: [
			"Manage Beacon's curated collection of on-device models.",
			"Choose models that fit your device, download them, and switch whenever you need.",
			"Keep every conversation and model on your device."
		],
		action: nil
	)
}

struct AttentionView: View {
	/// Matches the screen-level horizontal padding used across the app.
	static let contentHorizontalPadding: CGFloat = 20

	let content: AttentionContent
	var onClose: () -> Void = { }
	var onAction: (AttentionContent.Action) -> Void = { _ in }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				hero

				VStack(alignment: .leading, spacing: 24) {
					VStack(alignment: .leading, spacing: 10) {
						Text(content.title)
							.font(.openRunde(size: 32, weight: .semibold))
							.foregroundStyle(.primary)

						Text(content.subtitle)
							.font(.openRunde(size: 16, weight: .regular))
							.foregroundStyle(.secondary)
							.lineSpacing(3)
					}

					if !content.details.isEmpty {
						VStack(alignment: .leading, spacing: 14) {
							ForEach(content.details, id: \.self) { detail in
								HStack(alignment: .firstTextBaseline, spacing: 10) {
									Text("•")
										.font(.system(size: 18, weight: .semibold))
										.foregroundStyle(.primary)

									Text(detail)
										.font(.openRunde(size: 16, weight: .regular))
										.foregroundStyle(.primary)
										.lineSpacing(3)
								}
							}
						}
					}

					if let action = content.action {
						BeaconButton(
							action.title,
							variant: .primary,
							size: .large,
							isFullWidth: true,
							leadingIcon: action.systemImage,
							action: { onAction(action) }
						)
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
			Image(content.heroImageName)
				.resizable()
				.scaledToFit()
				.frame(maxWidth: .infinity)
				.accessibilityIdentifier("attentionHeroImage")

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
			AttentionView(content: .version106)
		}
}
