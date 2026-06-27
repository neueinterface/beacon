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
	@Binding var isOn: Bool

	var body: some View {
		SettingsRowLabel(title: title, icon: icon) {
			Toggle("", isOn: $isOn)
				.labelsHidden()
				.tint(Color(uiColor: .systemGreen))
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
	let trailing: Trailing

	init(title: String, icon: String, @ViewBuilder trailing: () -> Trailing) {
		self.title = title
		self.icon = icon
		self.trailing = trailing()
	}

	var body: some View {
		HStack(spacing: 14) {
			Image(icon)
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
				.foregroundStyle(.primary)
				.frame(width: 22, height: 22)

			Text(title)
				.font(.system(size: 16, weight: .medium))
				.foregroundStyle(.primary)

			Spacer(minLength: 12)

			trailing
		}
		.padding(.horizontal, 18)
		.frame(height: 48)
		.contentShape(Rectangle())
	}
}
