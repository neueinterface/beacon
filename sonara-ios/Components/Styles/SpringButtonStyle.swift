//
//  SpringButtonStyle.swift
//  sonara-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SpringButtonStyle: ButtonStyle {
	var pressedScale: CGFloat = 0.96

	func makeBody(configuration: Configuration) -> some View {
		SpringButtonStyleBody(
			configuration: configuration,
			pressedScale: pressedScale
		)
	}
}

private struct SpringButtonStyleBody: View {
	let configuration: ButtonStyle.Configuration
	let pressedScale: CGFloat

	@State private var didTriggerPressFeedback = false

	var body: some View {
		configuration.label
			.scaleEffect(configuration.isPressed ? pressedScale : 1)
			.animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
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
}

#Preview {
	Button("Press") { }
		.buttonStyle(.spring)
		.padding()
}
