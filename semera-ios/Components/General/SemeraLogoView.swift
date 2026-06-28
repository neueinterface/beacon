//
//  SemeraLogoView.swift
//  semera-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI

/// Animated Semera logo composed of four capsule petals.
/// Tapping triggers a subtle sequential scale-down-and-spring-back
/// across each petal, accompanied by a light haptic impact.
struct SemeraLogoView: View {
	var size: CGFloat = 42

	@State private var scales: [CGFloat] = [1, 1, 1, 1]
	@State private var isAnimating = false

	/// Clockwise sweep order: top-left → top-right → bottom-right → bottom-left.
	private let animationOrder = [2, 3, 1, 0]

	var body: some View {
		ZStack {
			ForEach(0..<4, id: \.self) { i in
				PetalShape(sourcePath: SemeraLogoPaths.petals[i])
					.fill(.primary)
					.scaleEffect(scales[i], anchor: .center)
			}
		}
		.frame(width: size, height: size)
		.contentShape(Rectangle())
		.onTapGesture {
			guard !isAnimating else { return }
			animate()
		}
		.accessibilityLabel("Semera logo")
	}

	private func animate() {
		isAnimating = true

		let stagger: Double = 0.06
		let retractDuration: Double = 0.22
		let restoreDuration: Double = 0.30

		#if canImport(UIKit)
		let haptic = UIImpactFeedbackGenerator(style: .light)
		haptic.prepare()
		#endif

		for (step, petalIndex) in animationOrder.enumerated() {
			let retractDelay = Double(step) * stagger
			let restoreDelay = retractDelay + retractDuration

			DispatchQueue.main.asyncAfter(deadline: .now() + retractDelay) {
				#if canImport(UIKit)
				haptic.impactOccurred(intensity: 0.35)
				#endif
				withAnimation(.easeInOut(duration: retractDuration)) {
					scales[petalIndex] = 0.88
				}
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
				withAnimation(.spring(duration: restoreDuration, bounce: 0.25)) {
					scales[petalIndex] = 1.0
				}
			}
		}

		let total = Double(animationOrder.count - 1) * stagger + retractDuration + restoreDuration
		DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.05) {
			isAnimating = false
		}
	}
}

// MARK: - Petal Shape

private struct PetalShape: Shape {
	let sourcePath: Path

	func path(in rect: CGRect) -> Path {
		let scale = min(rect.width, rect.height) / 94
		return sourcePath.applying(CGAffineTransform(scaleX: scale, y: scale))
	}
}

// MARK: - SVG Path Data (viewBox 0 0 94 94)

private enum SemeraLogoPaths {
	static let petals: [Path] = [petal0, petal1, petal2, petal3]

	/// Bottom-left petal.
	private static let petal0: Path = {
		var p = Path()
		p.move(to: CGPoint(x: 2.83665, y: 51.3792))
		p.addCurve(to: CGPoint(x: 33.7155, y: 60.2845),
		           control1: CGPoint(x: 8.90448, y: 45.3114),
		           control2: CGPoint(x: 22.7294, y: 49.2984))
		p.addCurve(to: CGPoint(x: 42.6209, y: 91.1634),
		           control1: CGPoint(x: 44.7016, y: 71.2706),
		           control2: CGPoint(x: 48.6887, y: 85.0956))
		p.addCurve(to: CGPoint(x: 11.7419, y: 82.258),
		           control1: CGPoint(x: 36.5531, y: 97.2312),
		           control2: CGPoint(x: 22.728, y: 93.2441))
		p.addCurve(to: CGPoint(x: 2.83665, y: 51.3792),
		           control1: CGPoint(x: 0.755792, y: 71.2719),
		           control2: CGPoint(x: -3.23116, y: 57.447))
		p.closeSubpath()
		return p
	}()

	/// Bottom-right petal.
	private static let petal1: Path = {
		var p = Path()
		p.move(to: CGPoint(x: 60.2845, y: 60.2845))
		p.addCurve(to: CGPoint(x: 91.1634, y: 51.3792),
		           control1: CGPoint(x: 71.2707, y: 49.2984),
		           control2: CGPoint(x: 85.0956, y: 45.3113))
		p.addCurve(to: CGPoint(x: 82.258, y: 82.258),
		           control1: CGPoint(x: 97.2312, y: 57.447),
		           control2: CGPoint(x: 93.2441, y: 71.2719))
		p.addCurve(to: CGPoint(x: 51.3792, y: 91.1634),
		           control1: CGPoint(x: 71.2719, y: 93.2441),
		           control2: CGPoint(x: 57.447, y: 97.2312))
		p.addCurve(to: CGPoint(x: 60.2845, y: 60.2845),
		           control1: CGPoint(x: 45.3113, y: 85.0956),
		           control2: CGPoint(x: 49.2984, y: 71.2707))
		p.closeSubpath()
		return p
	}()

	/// Top-left petal.
	private static let petal2: Path = {
		var p = Path()
		p.move(to: CGPoint(x: 11.7419, y: 11.7419))
		p.addCurve(to: CGPoint(x: 42.6209, y: 2.83665),
		           control1: CGPoint(x: 22.728, y: 0.75577),
		           control2: CGPoint(x: 36.5531, y: -3.23116))
		p.addCurve(to: CGPoint(x: 33.7155, y: 33.7155),
		           control1: CGPoint(x: 48.6886, y: 8.9045),
		           control2: CGPoint(x: 44.7016, y: 22.7294))
		p.addCurve(to: CGPoint(x: 2.83665, y: 42.6209),
		           control1: CGPoint(x: 22.7294, y: 44.7016),
		           control2: CGPoint(x: 8.9045, y: 48.6886))
		p.addCurve(to: CGPoint(x: 11.7419, y: 11.7419),
		           control1: CGPoint(x: -3.23116, y: 36.5531),
		           control2: CGPoint(x: 0.75577, y: 22.728))
		p.closeSubpath()
		return p
	}()

	/// Top-right petal.
	private static let petal3: Path = {
		var p = Path()
		p.move(to: CGPoint(x: 51.3792, y: 2.83665))
		p.addCurve(to: CGPoint(x: 82.258, y: 11.7419),
		           control1: CGPoint(x: 57.447, y: -3.23116),
		           control2: CGPoint(x: 71.2719, y: 0.755792))
		p.addCurve(to: CGPoint(x: 91.1634, y: 42.6209),
		           control1: CGPoint(x: 93.2441, y: 22.728),
		           control2: CGPoint(x: 97.2312, y: 36.5531))
		p.addCurve(to: CGPoint(x: 60.2845, y: 33.7155),
		           control1: CGPoint(x: 85.0956, y: 48.6887),
		           control2: CGPoint(x: 71.2706, y: 44.7016))
		p.addCurve(to: CGPoint(x: 51.3792, y: 2.83665),
		           control1: CGPoint(x: 49.2984, y: 22.7294),
		           control2: CGPoint(x: 45.3114, y: 8.90448))
		p.closeSubpath()
		return p
	}()
}

#Preview {
	VStack(spacing: 40) {
		SemeraLogoView(size: 42)
		SemeraLogoView(size: 80)
	}
	.padding()
}
