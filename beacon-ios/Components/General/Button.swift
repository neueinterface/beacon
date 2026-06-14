//
//  Button.swift
//  beacon-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI

struct BeaconButton: View {
	enum Variant {
		case primary
		case secondary
		case subtle
	}

	enum Size {
		case small
		case `default`
		case large
	}

	private let title: String?
	private let leadingIcon: String?
	private let leadingAssetIcon: String?
	private let trailingIcon: String?
	private let trailingAssetIcon: String?
	private let icon: String?
	private let variant: Variant
	private let size: Size
	private let isDisabled: Bool
	private let isLoading: Bool
	private let action: () -> Void

	init(
		_ title: String,
		variant: Variant = .primary,
		size: Size = .default,
		leadingIcon: String? = nil,
		leadingAssetIcon: String? = nil,
		trailingIcon: String? = nil,
		trailingAssetIcon: String? = nil,
		isDisabled: Bool = false,
		isLoading: Bool = false,
		action: @escaping () -> Void
	) {
		self.title = title
		self.leadingIcon = leadingIcon
		self.leadingAssetIcon = leadingAssetIcon
		self.trailingIcon = trailingIcon
		self.trailingAssetIcon = trailingAssetIcon
		self.icon = nil
		self.variant = variant
		self.size = size
		self.isDisabled = isDisabled
		self.isLoading = isLoading
		self.action = action
	}

	init(
		icon: String,
		variant: Variant = .primary,
		size: Size = .default,
		isDisabled: Bool = false,
		isLoading: Bool = false,
		action: @escaping () -> Void
	) {
		self.title = nil
		self.leadingIcon = nil
		self.leadingAssetIcon = nil
		self.trailingIcon = nil
		self.trailingAssetIcon = nil
		self.icon = icon
		self.variant = variant
		self.size = size
		self.isDisabled = isDisabled
		self.isLoading = isLoading
		self.action = action
	}

	var body: some View {
		SwiftUI.Button(action: action) {
			content
		}
		.buttonStyle(SpringButtonStyle())
		.disabled(isDisabled || isLoading)
		.opacity(isDisabled ? 0.45 : 1)
	}

	@ViewBuilder
	private var content: some View {
		if let icon {
			Image(systemName: icon)
				.font(iconFont)
				.foregroundStyle(foregroundStyle)
				.frame(width: iconButtonLength, height: iconButtonLength)
				.background(backgroundStyle, in: Circle())
		} else {
			HStack(spacing: 8) {
				if let leadingIcon {
					Image(systemName: leadingIcon)
						.font(iconFont)
				} else if let leadingAssetIcon {
					assetIcon(leadingAssetIcon)
				}

				if let title {
					Text(title)
						.font(textFont)
				}

				if isLoading {
					BeaconLoader(size: loaderSize, lineWidth: 2, color: foregroundStyle)
				} else if let trailingAssetIcon {
					assetIcon(trailingAssetIcon)
				} else if let trailingIcon {
					Image(systemName: trailingIcon)
						.font(iconFont)
				}
			}
			.foregroundStyle(foregroundStyle)
			.padding(.horizontal, horizontalPadding)
			.frame(minHeight: height)
			.background(backgroundStyle, in: Capsule())
		}
	}

	private func assetIcon(_ name: String) -> some View {
		Image(name)
			.renderingMode(.template)
			.resizable()
			.scaledToFit()
			.frame(width: 20, height: 20)
	}

	private var textFont: Font {
		switch size {
		case .small:
			.system(size: 14, weight: .semibold)
		case .default:
			.system(size: 16, weight: .semibold)
		case .large:
			.system(size: 17, weight: .semibold)
		}
	}

	private var iconFont: Font {
		switch size {
		case .small:
			.system(size: 14, weight: .semibold)
		case .default:
			.system(size: 16, weight: .semibold)
		case .large:
			.system(size: 16, weight: .semibold)
		}
	}

	private var loaderSize: CGFloat {
		switch size {
		case .small:
			13
		case .default:
			15
		case .large:
			16
		}
	}

	private var height: CGFloat {
		switch size {
		case .small:
			34
		case .default:
			44
		case .large:
			54
		}
	}

	private var iconButtonLength: CGFloat {
		switch size {
		case .small:
			34
		case .default:
			42
		case .large:
			50
		}
	}

	private var horizontalPadding: CGFloat {
		switch size {
		case .small:
			14
		case .default:
			18
		case .large:
			22
		}
	}

	private var foregroundStyle: Color {
		switch variant {
		case .primary:
			Color(uiColor: .systemBackground)
		case .secondary, .subtle:
			.primary
		}
	}

	private var backgroundStyle: Color {
		switch variant {
		case .primary:
			.primary
		case .secondary:
			Color(uiColor: .secondarySystemBackground)
		case .subtle:
			.clear
		}
	}
}

#Preview {
	VStack(spacing: 16) {
		BeaconButton("Continue", trailingIcon: "arrow.right") { }
		BeaconButton("Download", variant: .secondary, leadingIcon: "arrow.down") { }
		BeaconButton("Small", size: .small) { }
		BeaconButton("Large", size: .large, leadingIcon: "sparkles") { }
		BeaconButton(icon: "plus") { }
	}
	.padding()
}
