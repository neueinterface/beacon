//
//  ModelDownloadView.swift
//  beacon
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
	var completedUnitCount: Int64? { get }
	var totalUnitCount: Int64? { get }
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
	@State private var estimatedProgressTask: Task<Void, Never>?
	@State private var displayedProgress = 0.02
	@State private var lastLoadingHapticProgress = 0.0

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Spacer()

			VStack(alignment: .leading, spacing: 28) {
				DownloadProgressBar(progress: displayedProgress, isLoading: isProgressActive)

				VStack(alignment: .leading, spacing: 12) {
					Text(runtime.isLoading ? "Downloading model" : "Preparing model")
						.font(.openRunde(size: 24, weight: .medium))
						.foregroundStyle(.primary)

					Text(statusText)
						.font(.openRunde(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
				}

				if let errorMessage = runtime.errorMessage {
					VStack(alignment: .leading, spacing: 14) {
						Text(errorMessage)
							.font(.openRunde(size: 16, weight: .regular))
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
							.font(.openRunde(size: 18, weight: .medium))
							.foregroundStyle(.primary)

						Text(downloadSizeText)
							.font(.openRunde(size: 14, weight: .medium))
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
				.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
				startEstimatedProgressIfNeeded()
			} else {
				stopEstimatedProgress()
				finishProgress(success: runtime.isReady(for: model))
			}
		}
		.onChange(of: runtime.progress) { _, progress in
			updateDisplayedProgress(with: progress)
		}
		.onChange(of: runtime.completedUnitCount) { _, _ in
			// Force refresh — downloadSizeText reads this directly
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
			estimatedProgressTask?.cancel()
		}
	}

	private var statusText: String {
		if runtime.errorMessage != nil {
			return "Something went wrong while loading \(model.name)."
		}

		return "Keep this screen open while \(model.name) downloads to your device. This only needs to happen once."
	}

	private var isProgressActive: Bool {
		runtime.errorMessage == nil && displayedProgress < 1
	}

	private var downloadSizeText: String {
		if let completedUnitCount = runtime.completedUnitCount,
		   let totalUnitCount = runtime.totalUnitCount,
		   completedUnitCount >= 0,
		   totalUnitCount > 0 {
			let totalGB = Double(totalUnitCount) / 1_000_000_000
			let exactCompletedGB = min(Double(completedUnitCount), Double(totalUnitCount)) / 1_000_000_000
			let estimatedCompletedGB = min(max(totalGB * displayedProgress, 0), totalGB)
			let completedGB = max(exactCompletedGB, estimatedCompletedGB)
			return "\(formattedGB(completedGB))/\(formattedGB(totalGB)) GB"
		}

		let totalGB = downloadTotalGB
		let completedGB = min(max(totalGB * displayedProgress, 0), totalGB)
		return "\(formattedGB(completedGB))/\(formattedGB(totalGB)) GB"
	}

	private var downloadTotalGB: Double {
		if let totalUnitCount = runtime.totalUnitCount, totalUnitCount > 0 {
			return Double(totalUnitCount) / 1_000_000_000
		}

		return NSDecimalNumber(decimal: model.sizeInGB).doubleValue
	}

	private func formattedGB(_ value: Double) -> String {
		if value < 1 {
			return String(format: "%.2f", value)
		}

		return String(format: "%.1f", value)
	}

	private func startLoading() async {
		guard !hasStarted else { return }
		hasStarted = true
		isCancelled = false
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		#endif
		startEstimatedProgressIfNeeded()
		await runtime.load(model)
		stopEstimatedProgress()
		finishProgress(success: runtime.isReady(for: model))

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
		stopEstimatedProgress()
		displayedProgress = 0.02
		lastLoadingHapticProgress = 0
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

		playLoadingHapticIfNeeded(for: clampedProgress)
	}

	private func startEstimatedProgressIfNeeded() {
		guard estimatedProgressTask == nil else { return }

		estimatedProgressTask = Task { @MainActor in
			while !Task.isCancelled {
				try? await Task.sleep(for: .milliseconds(350))
				guard !Task.isCancelled, runtime.errorMessage == nil, !runtime.isReady(for: model) else { break }

				let targetProgress = min(displayedProgress + estimatedProgressStep, 0.92)
				guard targetProgress > displayedProgress else { continue }
				updateDisplayedProgress(with: targetProgress)
			}
		}
	}

	private func stopEstimatedProgress() {
		estimatedProgressTask?.cancel()
		estimatedProgressTask = nil
	}

	private var estimatedProgressStep: Double {
		let totalGB = max(downloadTotalGB, 0.2)
		return min(max(0.006 / totalGB, 0.003), 0.018)
	}

	private func playLoadingHapticIfNeeded(for progress: Double) {
		#if canImport(UIKit)
		guard runtime.isLoading else { return }
		guard progress - lastLoadingHapticProgress >= 0.12 || (progress >= 0.92 && lastLoadingHapticProgress < 0.92) else { return }

		UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.28)
		lastLoadingHapticProgress = progress
		#endif
	}

	private func finishProgress(success: Bool) {
		lastLoadingHapticProgress = 0

		guard success else { return }
		withAnimation(.smooth(duration: 0.2)) {
			displayedProgress = 1
		}
	}
}

private struct DownloadProgressBar: View {
	let progress: Double
	let isLoading: Bool

	private let height: CGFloat = 5

	var body: some View {
		GeometryReader { proxy in
			let clampedProgress = min(max(progress, 0), 1)
			let fillWidth = max(proxy.size.width * clampedProgress, clampedProgress > 0 ? height : 0)

			ZStack(alignment: .leading) {
				Capsule()
					.fill(Color(uiColor: .secondarySystemBackground))

				DownloadProgressFill(width: fillWidth, isLoading: isLoading)
			}
		}
		.frame(height: height)
		.animation(.smooth(duration: 0.24), value: progress)
	}
}

private struct DownloadProgressFill: View {
	let width: CGFloat
	let isLoading: Bool

	@State private var shimmerPhase = false

	private var shimmerWidth: CGFloat {
		max(width * 0.72, 64)
	}

	var body: some View {
		Capsule()
			.fill(Color.primary)
			.frame(width: width)
			.overlay(alignment: .leading) {
				if isLoading {
					LinearGradient(
						colors: [
							.clear,
							.white.opacity(0.16),
							.white.opacity(0.48),
							.white.opacity(0.16),
							.clear
						],
						startPoint: .leading,
						endPoint: .trailing
					)
					.frame(width: shimmerWidth)
					.offset(x: shimmerPhase ? width : -shimmerWidth)
					.blendMode(.plusLighter)
				}
			}
			.clipShape(Capsule())
			.onAppear {
				guard isLoading else { return }
				shimmerPhase = false
				withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
					shimmerPhase = true
				}
			}
			.onChange(of: isLoading) { _, isLoading in
				shimmerPhase = false
				guard isLoading else { return }
				withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
					shimmerPhase = true
				}
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
	@Published var completedUnitCount: Int64?
	@Published var totalUnitCount: Int64?
	@Published var isLoading: Bool
	@Published var errorMessage: String?

	init(progress: Double, isLoading: Bool, errorMessage: String? = nil) {
		self.progress = progress
		self.completedUnitCount = nil
		self.totalUnitCount = nil
		self.isLoading = isLoading
		self.errorMessage = errorMessage
	}

	func isReady(for model: BeaconModel) -> Bool { false }
	func load(_ model: BeaconModel) async { }
}
