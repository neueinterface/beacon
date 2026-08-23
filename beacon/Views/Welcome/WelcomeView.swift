//
//  WelcomeView.swift
//  beacon
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WelcomeView: View {
	@State private var isShowingFAQ = false
	@State private var hasAppeared = false
	@State private var logoScale = 1.0
	@State private var isAnimatingLogo = false
	@State private var isLogoShimmering = false
	@State private var logoShimmerOffset = -3.0

	var onGetStarted: () -> Void = { }
	var onReadFAQ: () -> Void = { }

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Spacer()

			VStack(alignment: .leading, spacing: 40) {
				logo
					.staggeredBlurIn(hasAppeared, delay: 0.05)
				header
					.staggeredBlurIn(hasAppeared, delay: 0.14)
				features
					.staggeredBlurIn(hasAppeared, delay: 0.23)
				actions
					.staggeredBlurIn(hasAppeared, delay: 0.34)
			}
		}
		.padding(.horizontal, 20)
		.padding(.bottom, 60)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		.background(Color(uiColor: .systemBackground))
		.sheet(isPresented: $isShowingFAQ) {
			FAQView {
				isShowingFAQ = false
			}
			.presentationDragIndicator(.visible)
		}
		.onAppear {
			hasAppeared = true
			playInitialLogoShimmer()
		}
	}


	private var logo: some View {
		ZStack {
			Image("beacon.logo")
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
				.foregroundStyle(.primary)

			if isLogoShimmering {
				LogoShimmerMask(offset: logoShimmerOffset)
					.transition(.opacity)
			}
		}
		.frame(width: 50, height: 50)
		.scaleEffect(logoScale)
		.contentShape(Rectangle())
		.onTapGesture {
			animateLogo()
		}
	}

	private func playInitialLogoShimmer() {
		Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.58))
			logoShimmerOffset = -3
			isLogoShimmering = true

			withAnimation(.linear(duration: 0.32)) {
				logoShimmerOffset = 0
			}

			try? await Task.sleep(for: .seconds(0.32))
			withAnimation(.smooth(duration: 0.08)) {
				isLogoShimmering = false
			}
		}
	}

	private func animateLogo() {
		guard !isAnimatingLogo else { return }

		isAnimatingLogo = true
		playLogoHapticDance()

		withAnimation(.spring(response: 0.24, dampingFraction: 0.52)) {
			logoScale = 1.16
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
			withAnimation(.spring(response: 0.32, dampingFraction: 0.64)) {
				logoScale = 1
			}
		}

		logoShimmerOffset = -3
		isLogoShimmering = true

		withAnimation(.linear(duration: 0.42)) {
			logoShimmerOffset = 0
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
			withAnimation(.smooth(duration: 0.08)) {
				isLogoShimmering = false
			}
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
			isAnimatingLogo = false
		}
	}

	private func playLogoHapticDance() {
		#if canImport(UIKit)
		Task { @MainActor in
			let generator = UIImpactFeedbackGenerator(style: .light)
			generator.prepare()

			generator.impactOccurred(intensity: 0.42)
			try? await Task.sleep(for: .seconds(0.07))
			generator.impactOccurred(intensity: 0.72)
			try? await Task.sleep(for: .seconds(0.09))
			generator.impactOccurred(intensity: 0.52)
			try? await Task.sleep(for: .seconds(0.06))
			UISelectionFeedbackGenerator().selectionChanged()
		}
		#endif
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Chat with AI, locally.")
				.font(.system(size: 32, weight: .medium))
				.foregroundStyle(.primary)

			Text("Beacon provides private, on-device AI that feels simple and approachable.")
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(.secondary)
				.lineSpacing(3)
		}
	}

	private var features: some View {
		VStack(alignment: .leading, spacing: 20) {
			FeatureRow(
				icon: "shield.icon",
				title: "Private by default",
				description: "Your conversations stay on your device."
			)

			FeatureRow(
				icon: "aibox.icon",
				title: "Curated models",
				description: "Discover and download the right models for you."
			)

			FeatureRow(
				icon: "rocket.icon",
				title: "Fast and efficient",
				description: "Optimized for speed and storage."
			)
		}
	}

	private var actions: some View {
		HStack(spacing: 12) {
			BeaconButton("Choose model", trailingAssetIcon: "download.icon", action: onGetStarted)
			BeaconButton("Read FAQ", variant: .secondary) {
				onReadFAQ()
				isShowingFAQ = true
			}
		}
	}
}

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

private struct FeatureRow: View {
	let icon: String
	let title: String
	let description: String

	var body: some View {
		HStack(alignment: .top, spacing: 10) {
			Image(icon)
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
				.frame(width: 24, height: 24)
				.foregroundStyle(.primary)
				.padding(.top, 2)

			VStack(alignment: .leading, spacing: 8) {
				Text(title)
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(.primary)

				Text(description)
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(.secondary)
					.lineSpacing(3)
			}
		}
	}
}

private struct StaggeredBlurInModifier: ViewModifier {
	let isVisible: Bool
	let delay: Double

	func body(content: Content) -> some View {
		content
			.opacity(isVisible ? 1 : 0)
			.blur(radius: isVisible ? 0 : 10)
			.offset(y: isVisible ? 0 : 10)
			.animation(.smooth(duration: 0.55).delay(delay), value: isVisible)
	}
}

private extension View {
	func staggeredBlurIn(_ isVisible: Bool, delay: Double) -> some View {
		modifier(StaggeredBlurInModifier(isVisible: isVisible, delay: delay))
	}
}

#Preview {
	WelcomeView()
}
