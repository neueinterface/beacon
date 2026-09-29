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
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	let models: [BeaconModel]
	var onDownloadModel: (BeaconModel) -> Void
	var onBack: () -> Void = { }

	@State private var hasAppeared = false
	@State private var selectedModelID = ModelCatalog.defaultModel.id

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 40) {
				Button(action: onBack) {
					Label("Back", systemImage: "chevron.left")
						.font(.beaconFont(size: 16, weight: .medium))
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Back to welcome")

				header
					.modelSelectEntrance(hasAppeared, delay: 0.04)

				VStack(alignment: .leading, spacing: 0) {
					ForEach(Array(orderedModels.enumerated()), id: \.element.id) { index, model in
						Button {
							selectedModelID = model.id
						} label: {
							WelcomeModelSelectRow(model: model, isSelected: selectedModelID == model.id)
						}
						.buttonStyle(.plain)
						.disabled(!ModelDeviceCompatibility.current(for: model).canUse)
						.modelSelectEntrance(hasAppeared, delay: 0.12 + Double(index) * 0.06)

						if index < orderedModels.count - 1 {
							Divider()
								.padding(.vertical, 20)
								.modelSelectEntrance(hasAppeared, delay: 0.1 + Double(index) * 0.06)
						}
					}
				}

				BeaconButton(
					selectedModel.map { isDownloaded($0) ? "Use \($0.name)" : "Download \($0.name)" } ?? "Choose a chat model",
					size: .large,
					trailingIcon: selectedModel.map { isDownloaded($0) ? "checkmark" : "arrow.down" },
					isDisabled: selectedModel == nil,
					action: {
						if let selectedModel { onDownloadModel(selectedModel) }
					}
				)
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

	private var selectedModel: BeaconModel? {
		models.first { $0.id == selectedModelID && ModelDeviceCompatibility.current(for: $0).canUse }
	}

	private func isDownloaded(_ model: BeaconModel) -> Bool {
		Set(downloadedModelIDs.split(separator: ",").map(String.init)).contains(model.id)
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Choose your first chat model.")
				.font(.openRunde(size: 28, weight: .medium))
				.foregroundStyle(.primary)
				.lineSpacing(2)

			Text(hasUsableModel
				? "Pick one small model to download now. You can explore more later; questions about images need a separate, optional vision model."
				: "These chat models aren't supported on this iPhone. You can go back, but you can't complete setup on this device yet.")
				.font(.openRunde(size: 16, weight: .regular))
				.foregroundStyle(.secondary)
				.lineSpacing(3)
		}
	}
}

private struct WelcomeModelSelectRow: View {
	let model: BeaconModel
	let isSelected: Bool

	private var compatibility: ModelDeviceCompatibility {
		.current(for: model)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			VStack(alignment: .leading, spacing: 12) {
				HStack {
					Text(model.name)
						.font(.openRunde(size: 18, weight: .medium))
						.foregroundStyle(.primary)
					Spacer()
					Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
						.font(.system(size: 22))
						.foregroundStyle(isSelected ? .primary : .secondary)
				}

				Text(model.description)
					.font(.openRunde(size: 16, weight: .regular))
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
						.font(.openRunde(size: 13, weight: .regular))
						.foregroundStyle(compatibility.tint)
				}
			}

		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.contentShape(Rectangle())
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
	WelcomeModelSelectView(models: ModelCatalog.onboardingModels, onDownloadModel: { _ in })
}
