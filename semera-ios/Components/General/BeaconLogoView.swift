//
//  BeaconLogoView.swift
//  semera-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI

struct BeaconLogoView: View {
	var size: CGFloat = 42
	var playsShimmerOnAppear: Bool = false

	@State private var isAnimating = false
	@State private var isShimmering = false
	@State private var shimmerOffset = 0.0
	@State private var logoScale = 1.0

	var body: some View {
		ZStack {
			Image("beacon.logo")
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
				.foregroundStyle(.primary)

			if isShimmering {
				LogoShimmerMask(offset: shimmerOffset)
					.transition(.opacity)
			}
		}
		.frame(width: size, height: size)
		.scaleEffect(logoScale)
		.contentShape(Rectangle())
		.onTapGesture {
			animateShimmer()
		}
		.onAppear {
			if playsShimmerOnAppear {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
					animateShimmer()
				}
			}
		}
		.accessibilityLabel("Beacon logo")
	}

	/// Plays a left-to-right rainbow shimmer sweep across the logo.
	/// The gradient starts off-screen to the left, sweeps through the rainbow
	/// (indigo → purple → pink → orange → yellow), and exits to the right.
	private func animateShimmer() {
		guard !isAnimating else { return }

		isAnimating = true

		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.45)
		#endif

		// Scale bounce
		withAnimation(.spring(response: 0.24, dampingFraction: 0.52)) {
			logoScale = 1.12
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
			withAnimation(.spring(response: 0.32, dampingFraction: 0.64)) {
				logoScale = 1.0
			}
		}

		// Place gradient off-screen to the left, then reveal the shimmer layer
		shimmerOffset = -3
		isShimmering = true

		// Animate the sweep on the next run loop so SwiftUI registers the
		// offset change as an animated transition (not a jump)
		DispatchQueue.main.async {
			withAnimation(.linear(duration: 0.42)) {
				shimmerOffset = 0
			}
		}

		// Fade out the shimmer layer after the sweep completes
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
			withAnimation(.smooth(duration: 0.08)) {
				isShimmering = false
			}
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
			isAnimating = false
		}
	}
}

// MARK: - Shimmer Layer

private struct LogoShimmerMask: View {
	let offset: Double

	var body: some View {
		GeometryReader { proxy in
			LinearGradient(
				colors: [
					Color.primary.opacity(0.25),
					Color.primary.opacity(0.25),
					Color.indigo,
					Color.purple,
					Color.pink,
					Color.orange,
					Color.yellow,
					Color.primary.opacity(0.25),
					Color.primary.opacity(0.25)
				],
				startPoint: .leading,
				endPoint: .trailing
			)
			.frame(width: proxy.size.width * 4, height: proxy.size.height)
			.offset(x: proxy.size.width * offset)
		}
		.mask {
			Image("beacon.logo")
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
		}
		.allowsHitTesting(false)
	}
}

#Preview {
	VStack(spacing: 40) {
		BeaconLogoView(size: 42)
		BeaconLogoView(size: 80, playsShimmerOnAppear: true)
	}
	.padding()
}
