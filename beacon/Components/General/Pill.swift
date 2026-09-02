//
//  Pill.swift
//  beacon
//
//  Created by Armond Schneider on 6/24/26.
//

import SwiftUI

struct Pill: View {
	enum Variant {
		case webTool

		var foregroundStyle: Color {
			switch self {
			case .webTool:
				.blue
			}
		}

		var backgroundStyle: Color {
			switch self {
			case .webTool:
				.blue.opacity(0.10)
			}
		}
	}

	enum Size {
		case compact
		case regular

		var iconSize: CGFloat {
			switch self {
			case .compact:
				12
			case .regular:
				13
			}
		}

		var textSize: CGFloat {
			switch self {
			case .compact:
				13
			case .regular:
				14
			}
		}

		var horizontalPadding: CGFloat {
			switch self {
			case .compact:
				11
			case .regular:
				13
			}
		}

		var verticalPadding: CGFloat {
			switch self {
			case .compact:
				7
			case .regular:
				9
			}
		}
	}

	enum Presentation {
		case filled
		case inline
	}

	let title: String
	var variant: Variant = .webTool
	var size: Size = .compact
	var presentation: Presentation = .filled
	var image: String?
	var systemImage: String?
	var trailingSystemImage: String?
	var action: (() -> Void)?

	var body: some View {
		Group {
			if let action {
				Button(action: action) {
					content
				}
				.buttonStyle(.spring)
			} else {
				content
			}
		}
	}

	private var content: some View {
		HStack(spacing: 7) {
			if let image {
				Image(image)
					.renderingMode(.template)
					.resizable()
					.scaledToFit()
					.frame(width: iconSize, height: iconSize)
			} else if let systemImage {
				Image(systemName: systemImage)
					.font(.system(size: iconSize, weight: .semibold))
			}

			Text(title)
				.font(.openRunde(size: textSize, weight: .semibold))

			if let trailingSystemImage {
				Image(systemName: trailingSystemImage)
					.font(.system(size: iconSize, weight: .bold))
			}
		}
		.foregroundStyle(variant.foregroundStyle)
		.padding(.horizontal, horizontalPadding)
		.padding(.vertical, verticalPadding)
		.background {
			if presentation == .filled {
				Capsule()
					.fill(variant.backgroundStyle)
			}
		}
	}

	private var iconSize: CGFloat {
		switch presentation {
		case .filled:
			size.iconSize
		case .inline:
			17
		}
	}

	private var textSize: CGFloat {
		switch presentation {
		case .filled:
			size.textSize
		case .inline:
			16
		}
	}

	private var horizontalPadding: CGFloat {
		switch presentation {
		case .filled:
			size.horizontalPadding
		case .inline:
			0
		}
	}

	private var verticalPadding: CGFloat {
		switch presentation {
		case .filled:
			size.verticalPadding
		case .inline:
			4
		}
	}
}

#Preview {
	VStack(alignment: .leading, spacing: 16) {
		HStack(spacing: 12) {
			Pill(title: "Search Web", image: "globe.icon")
			Pill(title: "Search Web", size: .regular, image: "globe.icon", trailingSystemImage: "plus")
		}

		Pill(title: "Search Web", presentation: .inline, image: "globe.icon")
	}
	.padding()
}
