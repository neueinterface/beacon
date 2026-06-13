//
//  WelcomeView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI

struct WelcomeView: View {
	@State private var isShowingFAQ = false
	@State private var hasAppeared = false

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
		.background(.white)
		.sheet(isPresented: $isShowingFAQ) {
			FAQView {
				isShowingFAQ = false
			}
			.presentationDragIndicator(.visible)
		}
		.onAppear {
			hasAppeared = true
		}
	}


	private var logo: some View {
		Image("beacon.logo")
			.resizable()
			.scaledToFit()
			.frame(width: 50, height: 50)
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Chat with AI, locally.")
				.font(.system(size: 32, weight: .medium))
				.foregroundStyle(.black)

			Text("Beacon provides private, on-device AI that feels simple and approachable.")
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(.gray)
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
			BeaconButton("Get Started", action: onGetStarted)
			BeaconButton("Read FAQ", variant: .secondary) {
				onReadFAQ()
				isShowingFAQ = true
			}
		}
	}
}

private struct FeatureRow: View {
	let icon: String
	let title: String
	let description: String

	var body: some View {
		HStack(alignment: .top, spacing: 10) {
			Image(icon)
				.resizable()
				.scaledToFit()
				.frame(width: 24, height: 24)
				.padding(.top, 2)

			VStack(alignment: .leading, spacing: 8) {
				Text(title)
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(.black)

				Text(description)
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(.gray)
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
