import SwiftUI

struct SheetView<Content: View>: View {
	let title: String
	var subtitle: String? = nil
	var showsLogo = false
	var onClose: () -> Void = { }
	@ViewBuilder var content: () -> Content

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 30) {
				header
				content()
			}
			.padding(.horizontal, 20)
			.padding(.top, 26)
			.padding(.bottom, 60)
		}
		.scrollEdgeEffectStyle(.soft, for: .top)
		.background(Color(uiColor: .systemBackground))
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 18) {
			HStack(alignment: .top) {
				if showsLogo {
					SemeraLogoView(size: 42)
				}

				Spacer(minLength: 16)

				Button(action: onClose) {
					Image(systemName: "xmark")
						.font(.system(size: 15, weight: .semibold))
						.foregroundStyle(.primary)
						.frame(width: 34, height: 34)
						.background(Color(uiColor: .secondarySystemBackground), in: Circle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Close")
			}

			VStack(alignment: .leading, spacing: 8) {
				Text(title)
					.font(.system(size: 32, weight: .semibold))
					.foregroundStyle(.primary)

				if let subtitle {
					Text(subtitle)
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
				}
			}
		}
	}
}

struct UpdatesView: View {
	var onClose: () -> Void = { }
	var updates: [UpdateItem] = UpdateItem.defaultItems

	var body: some View {
		SheetView(
			title: "What's New",
			subtitle: "Latest improvements in Semera.",
			showsLogo: true,
			onClose: onClose
		) {
			VStack(alignment: .leading, spacing: 14) {
				ForEach(updates) { update in
					UpdateCard(update: update)
				}
			}
		}
	}
}

struct UpdateItem: Identifiable, Hashable {
	let id = UUID()
	let title: String
	let description: String
	let systemImage: String
	let tint: Color

	static let defaultItems = [
		UpdateItem(
			title: "More Local Models",
			description: "Explore new chat models from major open model labs in the marketplace.",
			systemImage: "square.stack.3d.up.fill",
			tint: .indigo
		),
		UpdateItem(
			title: "Web Search Controls",
			description: "Turn web search on or off and keep local chat behavior clear.",
			systemImage: "globe",
			tint: .blue
		),
		UpdateItem(
			title: "Storage Limit",
			description: "Model downloads are capped to help protect storage on your device.",
			systemImage: "internaldrive.fill",
			tint: .orange
		)
	]
}

private struct UpdateCard: View {
	let update: UpdateItem

	var body: some View {
		HStack(alignment: .top, spacing: 14) {
			Image(systemName: update.systemImage)
				.font(.system(size: 17, weight: .semibold))
				.foregroundStyle(update.tint)
				.frame(width: 38, height: 38)
				.background(update.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

			VStack(alignment: .leading, spacing: 6) {
				Text(update.title)
					.font(.system(size: 17, weight: .semibold))
					.foregroundStyle(.primary)

				Text(update.description)
					.font(.system(size: 15, weight: .regular))
					.foregroundStyle(.secondary)
					.lineSpacing(3)
			}
		}
		.padding(16)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}
}

#Preview("Updates") {
	UpdatesView()
}

#Preview("Sheet") {
	SheetView(title: "Sheet Title", subtitle: "Reusable Semera sheet content.", showsLogo: true) {
		Text("Custom content goes here.")
			.font(.system(size: 16, weight: .regular))
			.foregroundStyle(.secondary)
			.padding(16)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}
}
