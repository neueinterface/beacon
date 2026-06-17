//
//  WelcomeModelSelectView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI
import UIKit

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
					ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
						WelcomeModelSelectRow(model: model) {
							onSelect(model)
						}
						.modelSelectEntrance(hasAppeared, delay: 0.12 + Double(index) * 0.06)

						if index < models.count - 1 {
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

	private var header: some View {
		Text("Choose an initial model to use.")
			.font(.system(size: 28, weight: .medium))
			.foregroundStyle(.primary)
			.lineSpacing(2)
	}
}

private struct WelcomeModelSelectRow: View {
	let model: BeaconModel
	var onDownload: () -> Void

	@State private var isDownloading = false

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

			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 12) {
					Tag(title: model.formattedSize, color: .indigo)

					if model.type == .reasoning {
						Tag(title: "reasoning", color: .orange)
					} else {
						Tag(title: "chat", color: .gray)
					}
				}

				Tag(title: "Recommended: \(model.recommendedDevice)", color: .green)
			}

			BeaconButton(
				model.isBuiltIn ? "Use" : "Download",
				variant: .secondary,
				size: .small,
				trailingIcon: model.isBuiltIn ? "checkmark" : nil,
				trailingAssetIcon: model.isBuiltIn ? nil : "download.icon",
				isLoading: isDownloading
			) {
				UIImpactFeedbackGenerator(style: .medium).impactOccurred()
				isDownloading = !model.isBuiltIn
				onDownload()
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
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
