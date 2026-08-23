import SwiftUI

struct SettingsSectionTitle: View {
	let title: String

	init(_ title: String) {
		self.title = title
	}

	var body: some View {
		Text(title)
			.font(.system(size: 18, weight: .semibold))
			.foregroundStyle(Color(uiColor: .systemGray))
	}
}

struct SettingsLinkRow<Destination: View>: View {
	let title: String
	let icon: String
	let destination: Destination

	init(title: String, icon: String, @ViewBuilder destination: () -> Destination) {
		self.title = title
		self.icon = icon
		self.destination = destination()
	}

	var body: some View {
		NavigationLink {
			destination
		} label: {
			SettingsRowLabel(title: title, icon: icon) {
				SettingsChevron()
			}
		}
		.buttonStyle(.plain)
	}
}

struct SettingsButtonRow: View {
	let title: String
	let icon: String
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			SettingsRowLabel(title: title, icon: icon) {
				SettingsChevron()
			}
		}
		.buttonStyle(.plain)
	}
}

struct SettingsToggleRow: View {
	let title: String
	let icon: String
	var subtitle: String? = nil
	@Binding var isOn: Bool

	var body: some View {
		SettingsRowLabel(title: title, icon: icon, subtitle: subtitle) {
			Toggle("", isOn: $isOn)
				.labelsHidden()
				.tint(Color(uiColor: .systemBlue))
		}
	}
}

struct SettingsListDivider: View {
	var body: some View {
		Rectangle()
			.fill(Color(uiColor: .separator).opacity(0.45))
			.frame(height: 1)
			.padding(.leading, 58)
			.padding(.trailing, 16)
	}
}

private struct SettingsChevron: View {
	var body: some View {
		Image(systemName: "chevron.right")
			.font(.system(size: 15, weight: .semibold))
			.foregroundStyle(Color(uiColor: .systemGray2))
	}
}

private struct SettingsRowLabel<Trailing: View>: View {
	let title: String
	let icon: String
	var subtitle: String? = nil
	let trailing: Trailing

	init(title: String, icon: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
		self.title = title
		self.icon = icon
		self.subtitle = subtitle
		self.trailing = trailing()
	}

	var body: some View {
		HStack(alignment: .center, spacing: 14) {
			Image(icon)
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
				.foregroundStyle(.primary)
				.frame(width: 22, height: 22)

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(.primary)

				if let subtitle {
					Text(subtitle)
						.font(.system(size: 13, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(2)
				}
			}

			Spacer(minLength: 12)

			trailing
		}
		.padding(.horizontal, 18)
		.frame(minHeight: 48)
		.contentShape(Rectangle())
	}
}
