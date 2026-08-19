import SwiftUI

struct SettingsFooterView: View {
	var onOpenWebsite: () -> Void = { }

	var body: some View {
		VStack(spacing: 10) {
			BeaconLogoView(size: 42, playsShimmerOnAppear: true)
				.background(Color(uiColor: .systemGroupedBackground))

			Text(appVersionText)
				.font(.system(size: 16, weight: .medium))
				.foregroundStyle(.secondary)

			Button(action: onOpenWebsite) {
				Text("Learn more")
					.font(.system(size: 16, weight: .medium))
					.underline()
					.foregroundStyle(.secondary)
			}
			.buttonStyle(.plain)
		}
		.frame(maxWidth: .infinity)
		.padding(.top, 18)
	}

	private var appVersionText: String {
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.1"
		return "v\(version)"
	}
}

struct SettingsCloseButton: View {
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Image(systemName: "xmark")
				.font(.system(size: 17, weight: .medium))
				.foregroundStyle(.primary)
				.frame(width: 32, height: 32)
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Close settings")
	}
}
