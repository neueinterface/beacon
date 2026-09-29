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
	@AppStorage("userMessageBubbleColor") private var selectedBubbleColor = UserMessageBubbleColor.default.rawValue
	@Environment(\.colorScheme) private var systemColorScheme

	private var selection: AppearanceColorScheme {
		AppearanceColorScheme(rawValue: selectedScheme) ?? .system
	}

	private var previewColorScheme: ColorScheme {
		selection.preferredColorScheme ?? systemColorScheme
	}

	private var bubbleColorSelection: UserMessageBubbleColor {
		UserMessageBubbleColor(rawValue: selectedBubbleColor) ?? .default
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 26) {
				VStack(alignment: .leading, spacing: 10) {
					Text("Color Scheme")
						.font(.beaconFont(size: 22, weight: .semibold))
						.foregroundStyle(.primary)

					Text("Turn on dark mode, or let Beacon visually match your device settings.")
						.font(.beaconFont(size: 15, weight: .regular))
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

				VStack(alignment: .leading, spacing: 12) {
					VStack(alignment: .leading, spacing: 5) {
						Text("Your message color")
							.font(.beaconFont(size: 18, weight: .semibold))
							.foregroundStyle(.primary)
						Text("Choose an accent for your chat bubbles.")
							.font(.beaconFont(size: 14, weight: .regular))
							.foregroundStyle(.secondary)
					}

					HStack(spacing: 16) {
						ForEach(UserMessageBubbleColor.allCases, id: \.self) { color in
							AppearanceBubbleColorOption(
								color: color,
								isSelected: bubbleColorSelection == color
							) {
								withAnimation(.easeInOut(duration: 0.25)) {
									selectedBubbleColor = color.rawValue
								}
							}
						}
					}
				}

				AppearanceChatPreview(colorScheme: previewColorScheme)
					.animation(.easeInOut(duration: 0.25), value: selectedBubbleColor)
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
		selectedScheme = scheme.rawValue
	}
}

private struct AppearanceBubbleColorOption: View {
	let color: UserMessageBubbleColor
	let isSelected: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Circle()
				.fill(color == .default ? Color(uiColor: .systemGray4) : color.tintColor)
				.frame(width: 42, height: 42)
				.overlay {
					if isSelected {
						Image(systemName: "checkmark")
							.font(.system(size: 17, weight: .bold))
							.foregroundStyle(color == .default ? Color.primary : Color.white)
					}
				}
				.padding(5)
				.overlay {
					Circle()
						.strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2)
				}
		}
		.buttonStyle(.plain)
		.accessibilityLabel("\(color.title) user message color")
		.accessibilityAddTraits(isSelected ? .isSelected : [])
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
					.font(.beaconFont(size: 16, weight: .semibold))
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
				.font(.beaconFont(size: 18, weight: .semibold))
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
					canAttachImages: false
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
		.environment(\.colorScheme, colorScheme)
	}
}

#Preview {
	NavigationStack {
		AppearancePlaceholderView()
	}
}
