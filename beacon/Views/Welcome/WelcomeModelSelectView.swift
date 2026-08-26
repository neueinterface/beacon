//
//  WelcomeModelSelectView.swift
//  beacon
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WelcomeModelSelectView: View {
	let models: [BeaconModel]
	var onSelect: (BeaconModel) -> Void

	@State private var hasAppeared = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 40) {
				header
					.modelSelectEntrance(hasAppeared, delay: 0.04)

				VStack(alignment: .leading, spacing: 0) {
					ForEach(Array(orderedModels.enumerated()), id: \.element.id) { index, model in
						WelcomeModelSelectRow(model: model) {
							onSelect(model)
						}
						.modelSelectEntrance(hasAppeared, delay: 0.12 + Double(index) * 0.06)

						if index < orderedModels.count - 1 {
							Divider()
								.padding(.vertical, 20)
								.modelSelectEntrance(hasAppeared, delay: 0.1 + Double(index) * 0.06)
						}
					}
				}
			}
			.padding(.horizontal, 20)
			.padding(.top, 40)
			.padding(.bottom, 60)
		}
		.background(Color(uiColor: .systemBackground))
		.opacity(hasAppeared ? 1 : 0)
		.blur(radius: hasAppeared ? 0 : 18)
		.scaleEffect(hasAppeared ? 1 : 0.94)
		.animation(.spring(response: 0.54, dampingFraction: 0.86, blendDuration: 0.1), value: hasAppeared)
		.onAppear {
			hasAppeared = true
		}
	}

	private var orderedModels: [BeaconModel] {
		models.enumerated().sorted { left, right in
			let leftPriority = ModelDeviceCompatibility.current(for: left.element).sortPriority
			let rightPriority = ModelDeviceCompatibility.current(for: right.element).sortPriority
			return leftPriority == rightPriority ? left.offset < right.offset : leftPriority < rightPriority
		}.map(\.element)
	}

	private var hasUsableModel: Bool {
		models.contains { ModelDeviceCompatibility.current(for: $0).canUse }
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Choose a model for your iPhone.")
				.font(.system(size: 28, weight: .medium))
				.foregroundStyle(.primary)
				.lineSpacing(2)

			Text(hasUsableModel ? "Choose one marked Works with this iPhone. You can change it anytime." : "Beacon's models aren't supported on this iPhone yet.")
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(.secondary)
				.lineSpacing(3)
		}
	}
}

private struct WelcomeModelSelectRow: View {
	let model: BeaconModel
	var onDownload: () -> Void

	@State private var isDownloading = false

	private var compatibility: ModelDeviceCompatibility {
		.current(for: model)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			VStack(alignment: .leading, spacing: 12) {
				Text(model.name)
					.font(.system(size: 18, weight: .medium))
					.foregroundStyle(.primary)

				Text(model.description)
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(.secondary)
					.lineSpacing(3)
			}

			VStack(alignment: .leading, spacing: 10) {
				HStack(spacing: 10) {
					Tag(title: model.formattedSize, color: .indigo)

					if model.type == .reasoning {
						Tag(title: "reasoning", color: .orange)
					} else {
						Tag(title: "chat", color: .gray)
					}
				}

				Tag(title: compatibility.tagTitle, color: compatibility.tint)

				if let message = compatibility.message {
					Label(message, systemImage: compatibility.systemImage)
						.font(.system(size: 13, weight: .regular))
						.foregroundStyle(compatibility.tint)
				}
			}

			BeaconButton(
				compatibility.canUse ? (model.isBuiltIn ? "Use" : "Download") : "Unavailable",
				variant: .secondary,
				size: .small,
				trailingIcon: model.isBuiltIn ? "checkmark" : nil,
				trailingAssetIcon: model.isBuiltIn ? nil : "download.icon",
				isDisabled: !compatibility.canUse,
				isLoading: isDownloading
			) {
				#if canImport(UIKit)
				UIImpactFeedbackGenerator(style: .medium).impactOccurred()
				#endif
				isDownloading = compatibility.canUse && !model.isBuiltIn
				onDownload()
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

private extension ModelDeviceCompatibility {
	var tint: Color {
		switch self {
		case .goodFit: .green
		case .mayBeSlow: .orange
		case .unavailable: .gray
		}
	}
}

private struct ModelSelectEntranceModifier: ViewModifier {
	let isVisible: Bool
	let delay: Double

	func body(content: Content) -> some View {
		content
			.opacity(isVisible ? 1 : 0)
			.blur(radius: isVisible ? 0 : 14)
			.scaleEffect(isVisible ? 1 : 0.965, anchor: .topLeading)
			.rotation3DEffect(
				.degrees(isVisible ? 0 : 2.5),
				axis: (x: 1, y: -0.25, z: 0),
				anchor: .topLeading,
				perspective: 0.7
			)
			.offset(y: isVisible ? 0 : 12)
			.animation(.smooth(duration: 0.62).delay(delay), value: isVisible)
	}
}

private extension View {
	func modelSelectEntrance(_ isVisible: Bool, delay: Double) -> some View {
		modifier(ModelSelectEntranceModifier(isVisible: isVisible, delay: delay))
	}
}

#Preview {
	WelcomeModelSelectView(models: ModelCatalog.availableModels) { _ in }
}
