import SwiftUI

struct SettingsCard<Content: View>: View {
	let title: String
	let caption: String
	let content: Content

	init(title: String, caption: String, @ViewBuilder content: () -> Content) {
		self.title = title
		self.caption = caption
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(.secondary)

				Text(caption)
					.font(.system(size: 14, weight: .regular))
					.foregroundStyle(.secondary)
			}

			VStack(spacing: 0) {
				content
			}
			.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
		}
	}
}

struct SettingsNavigationRow<Destination: View>: View {
	let title: String
	let subtitle: String
	let icon: String
	let destination: Destination

	init(title: String, subtitle: String, icon: String, @ViewBuilder destination: () -> Destination) {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.destination = destination()
	}

	var body: some View {
		NavigationLink {
			destination
		} label: {
			SettingsRowContent(title: title, subtitle: subtitle, icon: icon, style: .normal) {
				Image(systemName: "chevron.right")
					.font(.system(size: 13, weight: .bold))
					.foregroundStyle(.tertiary)
			}
		}
		.buttonStyle(.plain)
	}
}

struct SettingsActionRow: View {
	let title: String
	let subtitle: String
	let icon: String
	var style: SettingsRowStyle = .normal
	var isDisabled = false
	var action: () -> Void

	var body: some View {
		Button(action: action) {
			SettingsRowContent(title: title, subtitle: subtitle, icon: icon, style: style) {
				Image(systemName: "arrow.up.right")
					.font(.system(size: 13, weight: .bold))
					.foregroundStyle(style.foregroundColor.opacity(0.65))
			}
		}
		.buttonStyle(SpringButtonStyle())
		.disabled(isDisabled)
		.opacity(isDisabled ? 0.45 : 1)
	}
}

struct SettingsDivider: View {
	var body: some View {
		Rectangle()
			.fill(Color(uiColor: .separator).opacity(0.45))
			.frame(height: 1)
			.padding(.horizontal, 14)
			.padding(.vertical, 4)
	}
}

enum SettingsRowStyle {
	case normal
	case destructive

	var foregroundColor: Color {
		switch self {
		case .normal:
			.primary
		case .destructive:
			.red
		}
	}

	var iconBackgroundColor: Color {
		switch self {
		case .normal:
			Color(uiColor: .tertiarySystemGroupedBackground)
		case .destructive:
			.red.opacity(0.12)
		}
	}
}

private struct SettingsRowContent<Trailing: View>: View {
	let title: String
	let subtitle: String
	let icon: String
	let style: SettingsRowStyle
	let trailing: Trailing

	init(title: String, subtitle: String, icon: String, style: SettingsRowStyle, @ViewBuilder trailing: () -> Trailing) {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.style = style
		self.trailing = trailing()
	}

	var body: some View {
		HStack(spacing: 14) {
			Image(systemName: icon)
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(style.foregroundColor)
				.frame(width: 32, height: 32)
				.background(style.iconBackgroundColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(style.foregroundColor)

				Text(subtitle)
					.font(.system(size: 13, weight: .regular))
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 12)

			trailing
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 12)
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
