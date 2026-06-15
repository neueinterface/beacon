//
//  ModelDownloadView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import Combine
import SwiftUI
import UIKit

@MainActor
protocol ModelDownloadRuntime: ObservableObject {
	var progress: Double { get }
	var isLoading: Bool { get }
	var errorMessage: String? { get set }

	func isReady(for model: BeaconModel) -> Bool
	func load(_ model: BeaconModel) async
}

struct ModelDownloadView<Runtime: ModelDownloadRuntime>: View {
	let model: BeaconModel
	@ObservedObject var runtime: Runtime
	var onComplete: () -> Void = { }
	var onCancel: () -> Void = { }
	var startsAutomatically = true

	@StateObject private var haptics = ModelDownloadHaptics()
	@State private var hasStarted = false
	@State private var loadingTask: Task<Void, Never>?

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Spacer()

			VStack(alignment: .leading, spacing: 28) {
				ProgressView(value: runtime.progress)
					.progressViewStyle(.linear)
					.tint(.primary)

				VStack(alignment: .leading, spacing: 12) {
					Text(runtime.isLoading ? "Downloading model" : "Preparing model")
						.font(.system(size: 24, weight: .medium))
						.foregroundStyle(.primary)

					Text(statusText)
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
				}

				if let errorMessage = runtime.errorMessage {
					VStack(alignment: .leading, spacing: 14) {
						Text(errorMessage)
							.font(.system(size: 16, weight: .regular))
							.foregroundStyle(.red)

						BeaconButton("Try again", variant: .secondary) {
							hasStarted = false
							loadingTask = Task { await startLoading() }
						}
					}
				}

				HStack(alignment: .top, spacing: 16) {
					VStack(alignment: .leading, spacing: 8) {
						Text(model.name)
							.font(.system(size: 16, weight: .semibold))
							.foregroundStyle(.primary)

						Text("Approx. \(model.formattedSize)")
							.font(.system(size: 14, weight: .medium))
							.foregroundStyle(.secondary)
					}

					Spacer(minLength: 12)

					Button(action: cancelDownload) {
						Image(systemName: "xmark")
							.font(.system(size: 14, weight: .semibold))
							.foregroundStyle(.secondary)
							.frame(width: 30, height: 30)
							.background(Color(uiColor: .systemGray5), in: Circle())
					}
					.buttonStyle(SpringButtonStyle())
					.accessibilityLabel("Cancel download")
				}
				.padding(18)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
			}
		}
		.padding(.horizontal, 20)
		.padding(.bottom, 40)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		.background(Color(uiColor: .systemBackground))
		.onAppear {
			guard startsAutomatically else { return }
			guard !hasStarted else { return }
			loadingTask = Task {
				await startLoading()
			}
		}
		.onChange(of: runtime.isLoading) { _, isLoading in
			if isLoading {
				haptics.start()
			} else {
				haptics.stop()
			}
		}
		.onDisappear {
			loadingTask?.cancel()
			haptics.stop()
		}
	}

	private var statusText: String {
		if runtime.errorMessage != nil {
			return "Something went wrong while loading \(model.name)."
		}

		return "Keep this screen open while \(model.name) downloads to your device. This only needs to happen once."
	}

	private func startLoading() async {
		guard !hasStarted else { return }
		hasStarted = true
		if runtime.isLoading {
			haptics.start()
		}
		await runtime.load(model)
		haptics.stop()

		if runtime.isReady(for: model) {
			onComplete()
		}
	}

	private func cancelDownload() {
		loadingTask?.cancel()
		loadingTask = nil
		haptics.stop()
		onCancel()
	}
}

@MainActor
private final class ModelDownloadHaptics: ObservableObject {
	private var task: Task<Void, Never>?
	private let generator = UIImpactFeedbackGenerator(style: .medium)

	func start() {
		guard task == nil else { return }
		generator.prepare()

		task = Task { [weak self] in
			guard let self else { return }

			while !Task.isCancelled {
				let steps = 7

				for step in 0..<steps {
					guard !Task.isCancelled else { return }

					let progress = Double(step) / Double(steps - 1)
					let eased = 0.5 - cos(progress * .pi) / 2
					let intensity = 0.34 + eased * 0.62

					generator.impactOccurred(intensity: intensity)
					generator.prepare()

					let interval = 0.12 - eased * 0.04
					try? await Task.sleep(for: .seconds(interval))
				}

				try? await Task.sleep(for: .seconds(0.28))
			}
		}
	}

	func stop() {
		task?.cancel()
		task = nil
	}
}

#Preview("Downloading") {
	ModelDownloadView(
		model: ModelCatalog.defaultModel,
		runtime: PreviewModelDownloadRuntime(progress: 0.38, isLoading: true),
		startsAutomatically: false
	)

}

#Preview("Preparing") {
	ModelDownloadView(
		model: ModelCatalog.defaultModel,
		runtime: PreviewModelDownloadRuntime(progress: 1, isLoading: false),
		startsAutomatically: false
	)
}

#Preview("Error") {
	ModelDownloadView(
		model: ModelCatalog.defaultModel,
		runtime: PreviewModelDownloadRuntime(
			progress: 0.24,
			isLoading: false,
			errorMessage: "The download could not be completed. Check your connection and try again."
		),
		startsAutomatically: false
	)
}

private final class PreviewModelDownloadRuntime: ModelDownloadRuntime {
	@Published var progress: Double
	@Published var isLoading: Bool
	@Published var errorMessage: String?

	init(progress: Double, isLoading: Bool, errorMessage: String? = nil) {
		self.progress = progress
		self.isLoading = isLoading
		self.errorMessage = errorMessage
	}

	func isReady(for model: BeaconModel) -> Bool { false }
	func load(_ model: BeaconModel) async { }
}
