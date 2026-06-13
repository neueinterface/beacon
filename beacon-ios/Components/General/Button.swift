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
	private let trailingIcon: String?
	private let icon: String?
	private let variant: Variant
	private let size: Size
	private let isDisabled: Bool
	private let action: () -> Void

	init(
		_ title: String,
		variant: Variant = .primary,
		size: Size = .default,
		leadingIcon: String? = nil,
		trailingIcon: String? = nil,
		isDisabled: Bool = false,
		action: @escaping () -> Void
	) {
		self.title = title
		self.leadingIcon = leadingIcon
		self.trailingIcon = trailingIcon
		self.icon = nil
		self.variant = variant
		self.size = size
		self.isDisabled = isDisabled
		self.action = action
	}

	init(
		icon: String,
		variant: Variant = .primary,
		size: Size = .default,
		isDisabled: Bool = false,
		action: @escaping () -> Void
	) {
		self.title = nil
		self.leadingIcon = nil
		self.trailingIcon = nil
		self.icon = icon
		self.variant = variant
		self.size = size
		self.isDisabled = isDisabled
		self.action = action
	}

	var body: some View {
		SwiftUI.Button(action: action) {
			content
		}
		.buttonStyle(SpringButtonStyle())
		.disabled(isDisabled)
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
				}

				if let title {
					Text(title)
						.font(textFont)
				}

				if let trailingIcon {
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
			.system(size: 13, weight: .semibold)
		case .default:
			.system(size: 15, weight: .semibold)
		case .large:
			.system(size: 16, weight: .semibold)
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
			.white
		case .secondary, .subtle:
			.primary
		}
	}

	private var backgroundStyle: Color {
		switch variant {
		case .primary:
			.black
		case .secondary:
			Color(uiColor: .systemGray6)
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
