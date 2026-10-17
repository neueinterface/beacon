import SwiftUI

struct VerifiedBadge: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
			ZStack {
				Image("badge.icon")
					.renderingMode(.template)
					.resizable()
					.scaledToFit()
					.foregroundStyle(.green)
					.rotationEffect(.degrees(reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8) / 8 * 360))

				Image(systemName: "checkmark")
					.font(.system(size: 11, weight: .black))
					.foregroundStyle(.white)
			}
			.frame(width: 30, height: 30)
		}
		.accessibilityLabel("Recommended for your iPhone")
	}
}
