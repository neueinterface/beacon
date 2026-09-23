import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppIconPickerView: View {
	@State private var selectedIconName = currentAlternateIconName
	@State private var errorMessage: String?

	private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
	private let iconOptions = AppIconOption.allCases

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				Text("Choose an icon")
					.font(.openRunde(size: 24, weight: .medium))
					.foregroundStyle(.primary)

				Text("Pick the version of Beacon you want to show on your Home Screen.")
					.font(.openRunde(size: 16, weight: .regular))
					.foregroundStyle(.secondary)
					.lineSpacing(3)

				LazyVGrid(columns: columns, spacing: 16) {
					ForEach(iconOptions) { option in
						Button {
							select(option)
						} label: {
							AppIconOptionCell(option: option, isSelected: selectedIconName == option.alternateIconName)
						}
						.buttonStyle(.plain)
					}
				}
			}
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.background(Color(uiColor: .systemGroupedBackground))
		.navigationTitle("App Icon")
		#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
		.alert("Could not change icon", isPresented: Binding(
			get: { errorMessage != nil },
			set: { isPresented in
				if !isPresented { errorMessage = nil }
			}
		)) {
			Button("OK", role: .cancel) { }
		} message: {
			Text(errorMessage ?? "Try again later.")
		}
	}

	private func select(_ option: AppIconOption) {
		#if canImport(UIKit)
		guard UIApplication.shared.supportsAlternateIcons else {
			errorMessage = "This device does not support alternate app icons."
			return
		}

		guard selectedIconName != option.alternateIconName else { return }

		#if targetEnvironment(simulator)
		errorMessage = "Alternate app icons can't be changed in the iOS Simulator. Build and run on a real device to test icon switching."
		#else
		UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
			Task { @MainActor in
				if let error {
					errorMessage = error.localizedDescription
				} else {
					withAnimation(.smooth(duration: 0.24)) {
						selectedIconName = option.alternateIconName
					}
				}
			}
		}
		#endif
		#else
		errorMessage = "Alternate app icons are only available on iOS."
		#endif
	}
}

private var currentAlternateIconName: String? {
	#if canImport(UIKit)
	UIApplication.shared.alternateIconName
	#else
	nil
	#endif
}

private struct AppIconOptionCell: View {
	let option: AppIconOption
	let isSelected: Bool

	var body: some View {
		VStack(spacing: 8) {
			Image(option.assetName)
				.resizable()
				.scaledToFit()
				.frame(width: isSelected ? 66 : 64, height: isSelected ? 66 : 64)
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
				.overlay {
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.stroke(isSelected ? Color.primary.opacity(0.55) : Color.primary.opacity(0.12), lineWidth: 1)
				}

			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 18, weight: .semibold))
				.foregroundStyle(.primary)
				.scaleEffect(isSelected ? 1 : 0.72)
				.opacity(isSelected ? 1 : 0)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 6)
		.animation(.smooth(duration: 0.24), value: isSelected)
		.accessibilityLabel(option.title)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}

private struct AppIconOption: Identifiable, CaseIterable {
	let title: String
	let assetName: String
	let alternateIconName: String?

	var id: String { alternateIconName ?? "AppIcon" }

	static let allCases: [AppIconOption] = [
		AppIconOption(title: "Default", assetName: "icon-preview", alternateIconName: nil),
		AppIconOption(title: "Icon 2", assetName: "icon2-preview", alternateIconName: "icon2"),
		AppIconOption(title: "Icon 3", assetName: "icon3-preview", alternateIconName: "icon3"),
		AppIconOption(title: "Icon 4", assetName: "icon4-preview", alternateIconName: "icon4"),
		AppIconOption(title: "Icon 5", assetName: "icon5-preview", alternateIconName: "icon5"),
		AppIconOption(title: "Icon 6", assetName: "icon6-preview", alternateIconName: "icon6"),
		AppIconOption(title: "Icon 7", assetName: "icon7-preview", alternateIconName: "icon7"),
		AppIconOption(title: "Icon 8", assetName: "icon8-preview", alternateIconName: "icon8")
	]
}

#Preview {
	NavigationStack {
		AppIconPickerView()
	}
}
