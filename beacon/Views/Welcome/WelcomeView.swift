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
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	private enum Destination: Hashable {
		case bundle
		case marketplace
	}
	@State private var destination: Destination?
	@State private var hasAppeared = false
	@State private var logoScale = 1.0
	@State private var isAnimatingLogo = false
	@State private var isLogoShimmering = false
	@State private var logoShimmerOffset = -3.0

	var onNewToLocalModels: () -> Void = { }
	var onUsedLocalModels: () -> Void = { }

	var body: some View {
		GeometryReader { proxy in
			if proxy.size.height < 450 {
				HStack(alignment: .center, spacing: 24) {
					headerContainer(compact: true)
					.frame(maxWidth: .infinity, alignment: .center)
					actions
						.frame(maxWidth: .infinity)
				}
				.padding(.vertical, 12)
				.frame(width: proxy.size.width, height: proxy.size.height)
			} else {
			VStack(alignment: .center, spacing: 0) {
				headerContainer()
					.layoutPriority(1)

				Spacer(minLength: 24)

				actions
					.fixedSize(horizontal: false, vertical: true)
					.layoutPriority(1)
			}
			.padding(.top, proxy.size.height < 700 ? 16 : 32)
			.padding(.bottom, proxy.size.height < 700 ? 12 : 24)
			.frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
			}
		}
		.padding(.horizontal, 24)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
		.background(Color(uiColor: .systemBackground))
		.onAppear {
			hasAppeared = true
			playInitialLogoShimmer()
		}
		.task(id: destination) {
			guard let destination else { return }
			do {
				try await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.35))
			} catch {
				return
			}
			guard !Task.isCancelled else { return }
			switch destination {
			case .bundle: onNewToLocalModels()
			case .marketplace: onUsedLocalModels()
			}
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
		.frame(width: 54, height: 54)
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

	private func headerContainer(compact: Bool = false) -> some View {
		VStack(spacing: compact ? 16 : 20) {
			logo
			header(compact: compact)
		}
		.welcomeEntrance(hasAppeared, delay: 0.05, offset: -12)
	}

	private func header(compact: Bool = false) -> some View {
		VStack(alignment: .center, spacing: compact ? 12 : 20) {
			Text("Beacon is your personal local AI")
				.font(.openRunde(size: compact ? 26 : 28, weight: .semibold))
				.foregroundStyle(.primary)
				.fixedSize(horizontal: false, vertical: true)

			Text("Beacon provides private, on-device AI that feels simple and approachable.")
				.font(.openRunde(size: compact ? 16 : 18, weight: .medium))
				.foregroundStyle(.primary)
				.lineSpacing(3)
				.fixedSize(horizontal: false, vertical: true)
		}
		.multilineTextAlignment(.center)
		.frame(maxWidth: .infinity)
	}

	private var actions: some View {
		VStack(spacing: 14) {
			BeaconButton(
				"I haven't used Local Models",
				size: .large,
				isFullWidth: true,
				isDisabled: destination != nil,
				action: { leave(for: .bundle) }
			)
			.welcomeEntrance(hasAppeared, delay: 0.22, offset: 14)
			BeaconButton(
				"I've used Local Models",
				variant: .secondary,
				size: .large,
				isFullWidth: true,
				isDisabled: destination != nil,
				action: { leave(for: .marketplace) }
			)
			.welcomeEntrance(hasAppeared, delay: 0.34, offset: 14)

			ViewThatFits(in: .horizontal) {
				HStack(spacing: 12) {
					privacyLink
					termsLink
				}
				VStack(spacing: 8) {
					privacyLink
					termsLink
				}
			}
			.font(.openRunde(size: 13, weight: .regular))
			.foregroundStyle(.secondary)
			.padding(.top, 4)
			.welcomeEntrance(hasAppeared, delay: 0.46, offset: 8)
		}
		.disabled(destination != nil)
	}

	private func leave(for destination: Destination) {
		guard self.destination == nil else { return }
		self.destination = destination
		hasAppeared = false
	}

	private var privacyLink: some View {
		Link(destination: URL(string: "https://beacon.neueinterface.com/privacy-policy")!) {
			Text("Read our Privacy Policy").underline()
		}
	}

	private var termsLink: some View {
		Link(destination: URL(string: "https://beacon.neueinterface.com/terms-of-service")!) {
			Text("Read our Terms of Service").underline()
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

private struct WelcomeEntranceModifier: ViewModifier {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	let isVisible: Bool
	let delay: Double
	let offset: CGFloat

	func body(content: Content) -> some View {
		content
			.opacity(isVisible ? 1 : 0)
			.offset(y: isVisible || reduceMotion ? 0 : offset)
			.animation(
				(reduceMotion ? Animation.easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.88))
					.delay(reduceMotion || !isVisible ? 0 : delay),
				value: isVisible
			)
	}
}

private extension View {
	func welcomeEntrance(_ isVisible: Bool, delay: Double, offset: CGFloat) -> some View {
		modifier(WelcomeEntranceModifier(isVisible: isVisible, delay: delay, offset: offset))
	}
}

#Preview {
	WelcomeView()
}

#Preview("Small welcome") {
	WelcomeView()
		.previewLayout(.fixed(width: 320, height: 568))
}

#Preview("Landscape welcome") {
	WelcomeView()
		.previewLayout(.fixed(width: 667, height: 300))
}
