//
//  ModelDownloadView.swift
//  sonara-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
	var onError: (String) -> Void = { _ in }
	var startsAutomatically = true

	@State private var hasStarted = false
	@State private var isCancelled = false
	@State private var loadingTask: Task<Void, Never>?
	@State private var progressAnimationTask: Task<Void, Never>?
	@State private var displayedProgress = 0.02

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Spacer()

			VStack(alignment: .leading, spacing: 28) {
				ProgressView(value: displayedProgress)
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

						BeaconButton("Try again", variant: .secondary, size: .small) {
							hasStarted = false
							displayedProgress = 0.02
							loadingTask = Task { await startLoading() }
						}
					}
				}

				HStack(alignment: .top, spacing: 16) {
					VStack(alignment: .leading, spacing: 8) {
						Text(model.name)
							.font(.system(size: 18, weight: .medium))
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
				startProgressAnimation()
			} else {
				stopProgressAnimation(finished: runtime.isReady(for: model))
			}
		}
		.onChange(of: runtime.progress) { _, progress in
			updateDisplayedProgress(with: progress)
		}
		.onChange(of: runtime.errorMessage) { _, errorMessage in
			guard let errorMessage else { return }
			#if canImport(UIKit)
			UINotificationFeedbackGenerator().notificationOccurred(.error)
			#endif
			onError(errorMessage)
		}
		.onDisappear {
			if !runtime.isReady(for: model) {
				isCancelled = true
			}
			loadingTask?.cancel()
			progressAnimationTask?.cancel()
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
		isCancelled = false
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		#endif
		startProgressAnimation()
		await runtime.load(model)
		stopProgressAnimation(finished: runtime.isReady(for: model))

		if !isCancelled && !Task.isCancelled && runtime.isReady(for: model) {
			#if canImport(UIKit)
			UINotificationFeedbackGenerator().notificationOccurred(.success)
			#endif
			onComplete()
		}
	}

	private func cancelDownload() {
		isCancelled = true
		loadingTask?.cancel()
		loadingTask = nil
		progressAnimationTask?.cancel()
		displayedProgress = 0.02
		#if canImport(UIKit)
		UINotificationFeedbackGenerator().notificationOccurred(.warning)
		#endif
		onCancel()
	}

	private func updateDisplayedProgress(with progress: Double) {
		let clampedProgress = min(max(progress, 0.02), 1)
		guard clampedProgress > displayedProgress else { return }

		withAnimation(.smooth(duration: 0.24)) {
			displayedProgress = clampedProgress
		}
	}

	private func startProgressAnimation() {
		guard progressAnimationTask == nil else { return }

		updateDisplayedProgress(with: runtime.progress)
		progressAnimationTask = Task { @MainActor in
			while !Task.isCancelled {
				try? await Task.sleep(for: .milliseconds(350))
				guard !Task.isCancelled else { return }

				let reportedProgress = min(max(runtime.progress, 0.02), 1)
				let fallbackProgress = min(displayedProgress + max((0.92 - displayedProgress) * 0.08, 0.006), 0.92)
				let nextProgress = max(reportedProgress, fallbackProgress)

				withAnimation(.smooth(duration: 0.32)) {
					displayedProgress = nextProgress
				}
			}
		}
	}

	private func stopProgressAnimation(finished: Bool) {
		progressAnimationTask?.cancel()
		progressAnimationTask = nil

		guard finished else { return }
		withAnimation(.smooth(duration: 0.2)) {
			displayedProgress = 1
		}
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
