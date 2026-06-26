//
//  Loader.swift
//  semera-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI

struct BeaconLoader: View {
	var size: CGFloat = 16
	var lineWidth: CGFloat = 2
	var color: Color = .black
	var trackColor: Color = Color(uiColor: .systemGray4)

	@State private var startDate = Date.now

	var body: some View {
		TimelineView(.animation) { timeline in
			ZStack {
				Circle()
					.stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

				Circle()
					.trim(from: 0.08, to: 0.66)
					.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
					.rotationEffect(.degrees(rotationAngle(at: timeline.date)))
			}
		}
		.frame(width: size, height: size)
		.onAppear {
			startDate = .now
		}
	}

	private func rotationAngle(at date: Date) -> Double {
		let duration = 1.35
		let elapsed = date.timeIntervalSince(startDate)
		let progress = elapsed.truncatingRemainder(dividingBy: duration) / duration
		let pulse = sin(progress * 2 * .pi) / (2 * .pi)
		let fluidProgress = progress - 0.48 * pulse
		return fluidProgress * 360
	}
}

#Preview {
	VStack(spacing: 20) {
		BeaconLoader()
		BeaconLoader(size: 24, lineWidth: 2.5, color: .black)
	}
	.padding()
}
