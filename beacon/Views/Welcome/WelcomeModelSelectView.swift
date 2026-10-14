//
//  WelcomeModelSelectView.swift
//  beacon
//

import Foundation
import SwiftUI

struct WelcomeModelSelectView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""

	let models: [BeaconModel]
	var onDownloadModels: ([BeaconModel], BeaconModel) -> Void
	var onChooseLater: () -> Void = { }
	var onBack: () -> Void = { }

	@State private var hasAppeared = false
	@State private var isShowingChooseLater = false
	@State private var isDismissingConfirmation = false

	private var bundledModels: [BeaconModel] {
		models.filter { ModelDeviceCompatibility.current(for: $0).canUse }
	}

	private var primaryModel: BeaconModel? {
		bundledModels.first(where: { $0.onboardingRole == .chatCore })
			?? bundledModels.first(where: { $0.onboardingRole == .chatLight })
			?? bundledModels.first
	}

	private var pendingModels: [BeaconModel] {
		let downloadedIDs = Set(downloadedModelIDs.split(separator: ",").map(String.init))
		return bundledModels.filter { !$0.isBuiltIn && !downloadedIDs.contains($0.id) }
	}

	private var bundleSize: String {
		let size = bundledModels.filter { !$0.isBuiltIn }.reduce(Decimal(0)) { $0 + $1.sizeInGB }
		return String(format: "%.2f GB", NSDecimalNumber(decimal: size).doubleValue)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack {
				BeaconButton(icon: "chevron.left", variant: .subtle, action: onBack)
					.accessibilityLabel("Back to welcome")
				Spacer()
			}
			.padding(.horizontal, 20)
			.padding(.top, 12)

			ScrollView(showsIndicators: false) {
				VStack(alignment: .leading, spacing: 28) {
					Text("Based on your hardware,\nhere’s your recommended setup.")
						.font(.openRunde(size: 20, weight: .semibold))
						.foregroundStyle(.primary)
						.fixedSize(horizontal: false, vertical: true)

					bundleCard

					Text("One download to get started. Beacon installs the models in this bundle one at a time. You can manage them later in Settings.")
						.font(.openRunde(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
						.fixedSize(horizontal: false, vertical: true)
				}
				.padding(.horizontal, 24)
				.padding(.vertical, 24)
			}
			.scrollBounceBehavior(.basedOnSize)
		}
		.safeAreaInset(edge: .bottom, spacing: 0) {
			VStack(spacing: 14) {
				BeaconButton(
					pendingModels.isEmpty ? "Use Chat Core" : "Download Chat Core",
					size: .large,
					isFullWidth: true,
					trailingAssetIcon: "download.icon",
					isDisabled: primaryModel == nil,
					action: downloadBundle
				)
				BeaconButton("Choose later", variant: .secondary, size: .large, isFullWidth: true) {
					withAnimation(confirmationAnimation) {
						isShowingChooseLater = true
					}
				}
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 12)
			.background(Color(uiColor: .systemBackground))
		}
		.background(Color(uiColor: .systemBackground))
		.opacity(hasAppeared ? 1 : 0)
		.offset(y: hasAppeared || reduceMotion ? 0 : 14)
		.animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.88), value: hasAppeared)
		.onAppear { hasAppeared = true }
		.accessibilityHidden(isShowingChooseLater)
		.overlay {
			GeometryReader { proxy in
				ZStack(alignment: .bottom) {
					if isShowingChooseLater {
						Color.black.opacity(0.25)
							.onTapGesture { dismissConfirmation() }
							.accessibilityHidden(true)

						ChooseLaterConfirmationView(
							onDownload: { dismissConfirmation(download: true) },
							onConfirm: { dismissConfirmation(confirmed: true) }
						)
						.frame(maxWidth: 560)
						.frame(height: min(340, max(0, proxy.size.height - proxy.safeAreaInsets.top - 24)))
						.clipShape(UnevenRoundedRectangle(
							topLeadingRadius: 40,
							bottomLeadingRadius: 52,
							bottomTrailingRadius: 52,
							topTrailingRadius: 40,
							style: .continuous
						))
						.shadow(color: .black.opacity(0.12), radius: 24, y: 8)
						.padding(.horizontal, 8)
						.padding(.bottom, 8)
						.accessibilityAddTraits(.isModal)
						.accessibilityAction(.escape) { dismissConfirmation() }
						.transition(confirmationTransition)
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			.ignoresSafeArea()
		}
	}

	private var confirmationAnimation: Animation {
		reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.32, dampingFraction: 0.84, blendDuration: 0.04)
	}

	private var confirmationTransition: AnyTransition {
		if reduceMotion {
			return .move(edge: .bottom)
		}

		return .asymmetric(
			insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.94, anchor: .bottom)),
			removal: .move(edge: .bottom).combined(with: .scale(scale: 0.98, anchor: .bottom))
		)
	}

	private func dismissConfirmation(confirmed: Bool = false, download: Bool = false) {
		guard isShowingChooseLater, !isDismissingConfirmation else { return }
		isDismissingConfirmation = true
		withAnimation(confirmationAnimation, completionCriteria: .removed) {
			isShowingChooseLater = false
		} completion: {
			isDismissingConfirmation = false
			if download {
				downloadBundle()
			} else if confirmed {
				onChooseLater()
			}
		}
	}

	private var bundleCard: some View {
		VStack(alignment: .leading, spacing: 20) {
			HStack(alignment: .center, spacing: 8) {
			Text("Chat Core")
				.font(.openRunde(size: 20, weight: .semibold))
				.fixedSize(horizontal: false, vertical: true)
				WelcomeVerifiedBadge()
			}

			Text("A curated bundle of local models for your iPhone. Get help with everyday questions, writing, and planning—without choosing individual models.")
				.font(.openRunde(size: 16, weight: .medium))
				.lineSpacing(4)
				.fixedSize(horizontal: false, vertical: true)

			if bundledModels.contains(where: \.supportsImages) {
				Text("Includes help with photos")
					.font(.openRunde(size: 15, weight: .medium))
					.fixedSize(horizontal: false, vertical: true)
			}

			ModelTagLayout(spacing: 8) {
				Tag(title: "Selected for your iPhone", color: .green)
				Tag(title: bundleSize, color: .indigo)
			}
		}
		.foregroundStyle(.primary)
		.padding(24)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
	}

	private func downloadBundle() {
		guard let primaryModel else { return }
		onDownloadModels(bundledModels, primaryModel)
	}
}

private struct ChooseLaterConfirmationView: View {
	let onDownload: () -> Void
	let onConfirm: () -> Void

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(spacing: 20) {
				VStack(spacing: 12) {
					Text("Set up later?")
						.font(.openRunde(size: 24, weight: .semibold))
					Text("To chat locally, Beacon needs an available model. You can skip this download and add a model later in Settings.")
						.font(.openRunde(size: 16, weight: .medium))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
				}
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)

				VStack(spacing: 12) {
					BeaconButton("Download Chat Core", variant: .black, size: .large, isFullWidth: true, action: onDownload)
					BeaconButton("Yes, choose later", variant: .secondary, size: .large, isFullWidth: true, action: onConfirm)
				}
				.padding(.top, 4)
			}
			.padding(.horizontal, 24)
			.padding(.top, 32)
			.padding(.bottom, 24)
		}
		.scrollBounceBehavior(.basedOnSize)
		.foregroundStyle(.primary)
		.background(Color(uiColor: .systemBackground))
	}
}

private struct WelcomeVerifiedBadge: View {
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

#Preview {
	WelcomeModelSelectView(
		models: ModelCatalog.coreOnboardingModels(in: ModelCatalog.availableModels),
		onDownloadModels: { _, _ in }
	)
}

#Preview("Small model setup") {
	WelcomeModelSelectView(
		models: ModelCatalog.coreOnboardingModels(in: ModelCatalog.availableModels),
		onDownloadModels: { _, _ in }
	)
	.previewLayout(.fixed(width: 320, height: 568))
}
