//
//  SpringButtonStyle.swift
//  beacon
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SpringButtonStyle: ButtonStyle {
	enum Variant {
		case `default`
		case small
		case large

		var pressedScale: CGFloat {
			switch self {
			case .default:
				0.98
			case .small:
				0.97
			case .large:
				0.95
			}
		}

		var response: Double {
			switch self {
			case .default:
				0.28
			case .small:
				0.24
			case .large:
				0.32
			}
		}

		var dampingFraction: Double {
			switch self {
			case .default:
				0.82
			case .small:
				0.76
			case .large:
				0.68
			}
		}
	}

	let variant: Variant
	private let pressedScaleOverride: CGFloat?

	init(variant: Variant = .default) {
		self.variant = variant
		pressedScaleOverride = nil
	}

	init(pressedScale: CGFloat) {
		variant = .default
		pressedScaleOverride = pressedScale
	}

	func makeBody(configuration: Configuration) -> some View {
		SpringButtonStyleBody(
			configuration: configuration,
			variant: variant,
			pressedScale: pressedScaleOverride ?? variant.pressedScale
		)
	}
}

private struct SpringButtonStyleBody: View {
	let configuration: ButtonStyle.Configuration
	let variant: SpringButtonStyle.Variant
	let pressedScale: CGFloat

	@State private var didTriggerPressFeedback = false

	var body: some View {
		configuration.label
			.scaleEffect(configuration.isPressed ? pressedScale : 1)
			.animation(.spring(response: variant.response, dampingFraction: variant.dampingFraction), value: configuration.isPressed)
			.onChange(of: configuration.isPressed) { _, isPressed in
				guard isPressed, !didTriggerPressFeedback else {
					if !isPressed {
						didTriggerPressFeedback = false
					}
					return
				}

				#if canImport(UIKit)
				UIImpactFeedbackGenerator(style: .light).impactOccurred()
				#endif
				didTriggerPressFeedback = true
			}
	}
}

extension ButtonStyle where Self == SpringButtonStyle {
	static var spring: SpringButtonStyle {
		SpringButtonStyle()
	}

	static func spring(_ variant: SpringButtonStyle.Variant) -> SpringButtonStyle {
		SpringButtonStyle(variant: variant)
	}
}

#Preview {
	VStack(spacing: 16) {
		Button("Default") { }
			.font(.beaconFont(size: 16, weight: .medium))
			.foregroundStyle(.primary)
			.padding(.horizontal, 18)
			.frame(minHeight: 44)
			.background(Color(uiColor: .systemGray6), in: Capsule())
			.buttonStyle(.spring)

		Button("Small") { }
			.font(.beaconFont(size: 14, weight: .medium))
			.foregroundStyle(.primary)
			.padding(.horizontal, 14)
			.frame(minHeight: 34)
			.background(Color(uiColor: .systemGray6), in: Capsule())
			.buttonStyle(.spring(.small))

		Button("Large") { }
			.font(.beaconFont(size: 17, weight: .medium))
			.foregroundStyle(.primary)
			.padding(.horizontal, 22)
			.frame(minHeight: 54)
			.background(Color(uiColor: .systemGray6), in: Capsule())
			.buttonStyle(.spring(.large))
	}
	.padding()
}
