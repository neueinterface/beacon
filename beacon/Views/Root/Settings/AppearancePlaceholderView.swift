import SwiftUI

enum AppearanceColorScheme: String, CaseIterable {
	case system
	case light
	case dark

	var title: String {
		switch self {
		case .system: "System"
		case .light: "Light"
		case .dark: "Dark"
		}
	}

	var iconName: String {
		switch self {
		case .system: "circle.lefthalf.filled"
		case .light: "sun.max.fill"
		case .dark: "moon.fill"
		}
	}

	var preferredColorScheme: ColorScheme? {
		switch self {
		case .system: nil
		case .light: .light
		case .dark: .dark
		}
	}
}

struct AppearancePlaceholderView: View {
	@AppStorage("appearanceColorScheme") private var selectedScheme = AppearanceColorScheme.system.rawValue
	@Environment(\.colorScheme) private var systemColorScheme

	private var selection: AppearanceColorScheme {
		AppearanceColorScheme(rawValue: selectedScheme) ?? .system
	}

	private var previewColorScheme: ColorScheme {
		selection.preferredColorScheme ?? systemColorScheme
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 26) {
				VStack(alignment: .leading, spacing: 10) {
					Text("Color Scheme")
						.font(.system(size: 22, weight: .semibold))
						.foregroundStyle(.primary)

					Text("Turn on dark mode, or let Beacon visually match your device settings.")
						.font(.system(size: 15, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
				}

				HStack(spacing: 12) {
					ForEach(AppearanceColorScheme.allCases, id: \.self) { scheme in
						AppearanceSchemeCard(
							scheme: scheme,
							isSelected: selection == scheme
						) {
							select(scheme)
						}
					}
				}
				.animation(.easeInOut(duration: 0.18), value: selection)

				AppearanceChatPreview(colorScheme: previewColorScheme)
			}
			.padding(.horizontal, 20)
			.padding(.top, 26)
			.padding(.bottom, 44)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.background(Color(uiColor: .systemGroupedBackground))
		.navigationTitle("Appearance")
		#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
	}

	private func select(_ scheme: AppearanceColorScheme) {
		guard scheme != selection else { return }

		withAnimation(.easeInOut(duration: 0.18)) {
			selectedScheme = scheme.rawValue
		}
	}
}

private struct AppearanceSchemeCard: View {
	let scheme: AppearanceColorScheme
	let isSelected: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			VStack(alignment: .leading, spacing: 12) {
				Image(systemName: scheme.iconName)
					.font(.system(size: 21, weight: .semibold))

				Text(scheme.title)
					.font(.system(size: 16, weight: .semibold))
					.minimumScaleFactor(0.85)
			}
			.foregroundStyle(isSelected ? Color.primary : Color(uiColor: .systemGray2))
			.frame(maxWidth: .infinity, alignment: .leading)
			.frame(height: 84)
			.padding(.horizontal, 14)
			.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
			.overlay {
				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.stroke(Color(uiColor: .systemGray4), lineWidth: 1.5)

				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.stroke(Color.primary, lineWidth: 2.25)
					.opacity(isSelected ? 1 : 0)
			}
			.overlay(alignment: .topTrailing) {
				Image(systemName: "checkmark.circle.fill")
					.font(.system(size: 18, weight: .semibold))
					.foregroundStyle(.primary)
					.padding(9)
					.opacity(isSelected ? 1 : 0)
			}
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}

private struct AppearanceChatPreview: View {
	let colorScheme: ColorScheme
	@State private var previewText = ""

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text("Preview")
				.font(.system(size: 18, weight: .semibold))
				.foregroundStyle(.primary)

			VStack(spacing: 14) {
				VStack(spacing: 12) {
					MessageBubble(text: "How long do sea turtles live for?", role: .user)
					MessageBubble(text: "Sea turtles often live 50 to 100 years, depending on the species.", role: .assistant)
				}
				.padding(.horizontal, 14)
				.padding(.top, 18)

				Input(
					text: $previewText,
					placeholder: "Message",
					onAttachImage: {},
					canAttachImages: false,
					selectedModelName: "Qwen3 0.6B",
					onSelectModel: {}
				) { _ in }
				.allowsHitTesting(false)
				.padding(.horizontal, 14)
				.padding(.bottom, 14)
			}
			.background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
			.overlay {
				RoundedRectangle(cornerRadius: 26, style: .continuous)
					.stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
			}
		}
		.preferredColorScheme(colorScheme)
	}
}

#Preview {
	NavigationStack {
		AppearancePlaceholderView()
	}
}
