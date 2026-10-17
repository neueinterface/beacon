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
	var downloadTitle: String?
	var bundleModels: [BeaconModel]?
	var completedBundleModelCount = 0
	var completedBundleByteCounts: [String: Int64] = [:]
	var isDownloadComplete = false
	var onComplete: () -> Void = { }
	var onContinue: () -> Void = { }
	var onCancel: () -> Void = { }
	var onError: (String) -> Void = { _ in }
	var startsAutomatically = true

	@State private var hasStarted = false
	@State private var retryAttempt = 0
	@State private var isCancelled = false
	@State private var displayedProgress = 0.0
	@State private var lastLoadingHapticProgress = 0.0

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				DownloadProgressBar(progress: bundleProgress, isLoading: isProgressActive)

				VStack(alignment: .leading, spacing: 12) {
					Text(isDownloadComplete ? "You’re ready to go" : (runtime.progress >= 1 ? "Preparing models" : "Downloading models"))
						.font(.openRunde(size: 24, weight: .semibold))
						.foregroundStyle(.primary)
						.fixedSize(horizontal: false, vertical: true)

					Text(statusText)
						.font(.openRunde(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
						.fixedSize(horizontal: false, vertical: true)
				}

				if let errorMessage = runtime.errorMessage {
					VStack(alignment: .leading, spacing: 14) {
						Text(errorMessage)
							.font(.openRunde(size: 16, weight: .regular))
							.foregroundStyle(.red)
							.fixedSize(horizontal: false, vertical: true)

						BeaconButton("Try again", variant: .secondary, size: .small, asyncAction: {
							retryAttempt += 1
						})
					}
				}

				HStack(alignment: .top, spacing: 16) {
					VStack(alignment: .leading, spacing: 8) {
						Text(displayTitle)
							.font(.openRunde(size: 18, weight: .medium))
							.foregroundStyle(.primary)
							.fixedSize(horizontal: false, vertical: true)

						Text(downloadSizeText)
							.font(.openRunde(size: 14, weight: .medium))
							.foregroundStyle(.secondary)
					}

					Spacer(minLength: 12)

					if !isDownloadComplete {
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
				}
				.padding(18)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

				DownloadTicTacToeView()
					.frame(maxWidth: .infinity)
			}
		.padding(.horizontal, 28)
		.padding(.vertical, 24)
		}
		.scrollBounceBehavior(.basedOnSize)
		.safeAreaInset(edge: .bottom, spacing: 0) {
			BeaconButton(
				isDownloadComplete ? "Continue" : (runtime.errorMessage == nil ? "Downloading" : "Download paused"),
				variant: isDownloadComplete ? .black : .secondary,
				size: .large,
				isFullWidth: true,
				isDisabled: runtime.errorMessage != nil,
				isLoading: !isDownloadComplete && runtime.errorMessage == nil,
				asyncAction: { onContinue() }
			)
			.padding(.horizontal, 28)
			.padding(.vertical, 12)
			.background(Color(uiColor: .systemBackground))
		}
		.background(Color(uiColor: .systemBackground))
		.onAppear {
			if !startsAutomatically { displayedProgress = runtime.progress }
		}
		.task(id: "\(model.id)-\(retryAttempt)") {
			guard startsAutomatically else { return }
			hasStarted = false
			displayedProgress = 0
			await startLoading()
		}
		.onChange(of: runtime.isLoading) { _, isLoading in
			if isLoading {
				lastLoadingHapticProgress = 0
			} else {
				finishProgress(success: runtime.isReady(for: model))
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
		}
	}

	private var statusText: String {
		if isDownloadComplete {
			return "Your models are ready. Finish your game or tap Continue to start chatting."
		}
		if runtime.errorMessage != nil {
			return "Something went wrong while preparing \(displayTitle)."
		}
		if runtime.progress >= 1 {
			return "Download complete. Preparing \(model.name) for use on your device."
		}

		if bundleModels != nil {
			return "Keep this screen open while Beacon downloads the recommended models. This only needs to happen once."
		}

		return "Keep this screen open while \(model.name) downloads to your device. This only needs to happen once."
	}

	private var displayTitle: String {
		if bundleModels != nil { return "Recommended models" }
		return downloadTitle ?? model.name
	}

	private var isProgressActive: Bool {
		!isDownloadComplete && runtime.errorMessage == nil && displayedProgress < 1
	}

	private var downloadSizeText: String {
		if isDownloadComplete { return "Ready to use" }
		if bundleModels != nil {
			return "\(formattedDownloadSize(completedBundleDownloadGB + currentBundleDownloadGB)) / about \(formattedDownloadSize(bundleTotalGB))"
		}

		if let completedUnitCount = runtime.completedUnitCount,
		   let totalUnitCount = runtime.totalUnitCount,
		   completedUnitCount >= 0,
		   totalUnitCount > 0 {
			let totalGB = Double(totalUnitCount) / 1_000_000_000
			let exactCompletedGB = min(Double(completedUnitCount), Double(totalUnitCount)) / 1_000_000_000
			return "\(formattedDownloadSize(exactCompletedGB)) / \(formattedDownloadSize(totalGB))"
		}

		return "Preparing download · about \(formattedGB(downloadTotalGB)) GB"
	}

	private var downloadTotalGB: Double {
		if let totalUnitCount = runtime.totalUnitCount, totalUnitCount > 0 {
			return Double(totalUnitCount) / 1_000_000_000
		}

		return NSDecimalNumber(decimal: model.sizeInGB).doubleValue
	}

	private var currentDownloadedGB: Double {
		if let completedUnitCount = runtime.completedUnitCount, completedUnitCount >= 0 {
			return Double(completedUnitCount) / 1_000_000_000
		}

		return 0
	}

	private var bundleTotalGB: Double {
		guard let bundleModels, !bundleModels.isEmpty else { return downloadTotalGB }
		return max(bundleModels.reduce(0.0) { total, model in
			if let bytes = completedBundleByteCounts[model.id] {
				return total + Double(bytes) / 1_000_000_000
			}
			if model.id == self.model.id {
				return total + downloadTotalGB
			}
			return total + NSDecimalNumber(decimal: model.sizeInGB).doubleValue
		}, 0.01)
	}

	private var completedBundleDownloadGB: Double {
		guard let bundleModels else { return 0 }
		return bundleModels.prefix(completedBundleModelCount).reduce(0.0) { total, model in
			total + Double(completedBundleByteCounts[model.id] ?? 0) / 1_000_000_000
		}
	}

	private var currentBundleDownloadGB: Double {
		min(currentDownloadedGB, downloadTotalGB)
	}

	private var bundleProgress: Double {
		if isDownloadComplete { return 1 }
		guard let bundleModels, !bundleModels.isEmpty else { return displayedProgress }
		return min(max((completedBundleDownloadGB + currentBundleDownloadGB) / bundleTotalGB, 0), 1)
	}

	private func formattedGB(_ value: Double) -> String {
		String(format: "%.2f", value)
	}

	private func formattedDownloadSize(_ valueGB: Double) -> String {
		if valueGB < 1 {
			return String(format: "%.1f MB", valueGB * 1_000)
		}
		return "\(formattedGB(valueGB)) GB"
	}

	private func startLoading() async {
		guard !hasStarted else { return }
		hasStarted = true
		isCancelled = false
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		#endif
		await runtime.load(model)
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
		displayedProgress = 0
		lastLoadingHapticProgress = 0
		#if canImport(UIKit)
		UINotificationFeedbackGenerator().notificationOccurred(.warning)
		#endif
		onCancel()
	}

	private func updateDisplayedProgress(with progress: Double) {
		guard progress.isFinite else { return }
		let clampedProgress = min(max(progress, 0), 1)
		guard clampedProgress > displayedProgress else { return }

		withAnimation(.smooth(duration: 0.24)) {
			displayedProgress = clampedProgress
		}

		playLoadingHapticIfNeeded(for: clampedProgress)
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

struct DownloadTicTacToe {
	enum Mark: String {
		case x = "X"
		case o = "O"
	}

	enum Phase: Equatable {
		case player, computer, won, lost, draw
	}

	private(set) var cells: [Mark?] = Array(repeating: nil, count: 9)
	private(set) var phase: Phase = .player
	private static let lines = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8],
		[0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]
	]

	mutating func play(at index: Int) {
		guard phase == .player, cells.indices.contains(index), cells[index] == nil else { return }
		cells[index] = .x
		finishTurn(next: .computer)
	}

	mutating func playComputer(at preferredIndex: Int? = nil) {
		guard phase == .computer else { return }
		let empty = cells.indices.filter { cells[$0] == nil }
		// Take a winning move, otherwise play casually so the user can win too.
		let winning = empty.first { index in
			var candidate = cells
			candidate[index] = .o
			return Self.lines.contains { $0.allSatisfy { candidate[$0] == .o } }
		}
		let preferred = preferredIndex.flatMap { empty.contains($0) ? $0 : nil }
		guard let index = winning ?? preferred ?? empty.randomElement() else { return }
		cells[index] = .o
		finishTurn(next: .player)
	}

	private mutating func finishTurn(next: Phase) {
		if Self.lines.contains(where: { $0.allSatisfy { cells[$0] == .x } }) {
			phase = .won
		} else if Self.lines.contains(where: { $0.allSatisfy { cells[$0] == .o } }) {
			phase = .lost
		} else if cells.allSatisfy({ $0 != nil }) {
			phase = .draw
		} else {
			phase = next
		}
	}
}

struct DownloadTicTacToeView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var game = DownloadTicTacToe()
	@State private var isResetting = false

	private var tint: Color {
		switch game.phase {
		case .won: .green
		case .lost: .red
		default: .primary
		}
	}

	private var status: String {
		if isResetting { return "New round…" }
		return switch game.phase {
		case .player: "Your turn"
		case .computer: "Beacon’s turn…"
		case .won: "You won! Let’s play again."
		case .lost: "Beacon won. Another round?"
		case .draw: "A draw. Let’s try again."
		}
	}

	var body: some View {
		VStack(spacing: 16) {
			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
				ForEach(0..<9, id: \.self) { index in
					Button {
						game.play(at: index)
					} label: {
						ZStack {
							RoundedRectangle(cornerRadius: 18, style: .continuous)
								.fill(game.phase == .won || game.phase == .lost ? tint.opacity(0.12) : Color(uiColor: .tertiarySystemBackground))
								.animation(.easeInOut(duration: 0.35), value: game.phase)
							if let mark = game.cells[index] {
								Image(systemName: mark == .x ? "xmark" : "circle")
									.font(.system(size: 36, weight: .black, design: .rounded))
									.foregroundStyle(game.phase == .won || game.phase == .lost ? tint : (mark == .x ? Color.indigo : Color.orange))
									.animation(.easeInOut(duration: 0.35), value: game.phase)
									.rotationEffect(.degrees(mark == .x ? -6 : 5))
									.scaleEffect(isResetting && !reduceMotion ? 0.25 : 1, anchor: .center)
									.opacity(isResetting ? 0 : 1)
									.animation(
										reduceMotion ? .easeOut(duration: 0.15) : .easeIn(duration: 0.22).delay(Double(index) * 0.025),
										value: isResetting
									)
									.transition(
										reduceMotion ? .opacity : .asymmetric(
											insertion: .scale(scale: 0.35).combined(with: .opacity)
												.animation(.spring(response: 0.38, dampingFraction: 0.56)),
											removal: .identity
										)
									)
							}
						}
						.aspectRatio(1, contentMode: .fit)
						.animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.56), value: game.cells[index])
					}
					.buttonStyle(SpringButtonStyle())
					.disabled(isResetting || game.phase != .player || game.cells[index] != nil)
					.accessibilityLabel("Row \(index / 3 + 1), column \(index % 3 + 1): \(game.cells[index]?.rawValue ?? "empty")")
				}
			}
			.padding(12)
			.background(
				game.phase == .won || game.phase == .lost ? tint.opacity(0.16) : Color(uiColor: .secondarySystemBackground),
				in: RoundedRectangle(cornerRadius: 28, style: .continuous)
			)
			.animation(.easeInOut(duration: 0.35), value: game.phase)
			.frame(maxWidth: 360)

			Text(status)
				.font(.openRunde(size: 14, weight: .semibold))
				.foregroundStyle(tint)
				.multilineTextAlignment(.center)
				.animation(.easeInOut(duration: 0.35), value: game.phase)
		}
		.padding(.vertical, 8)
		.task(id: game.phase) {
			switch game.phase {
			case .computer:
				do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
				game.playComputer()
			case .won, .lost, .draw:
				do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
				isResetting = true
				do { try await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.5)) } catch { return }
				var resetTransaction = Transaction(animation: nil)
				resetTransaction.disablesAnimations = true
				withTransaction(resetTransaction) {
					game = DownloadTicTacToe()
					isResetting = false
				}
			case .player:
				break
			}
		}
	}
}

private struct DownloadProgressBar: View {
	let progress: Double
	let isLoading: Bool

	private let height: CGFloat = 10

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

#Preview("Ready to continue") {
	ModelDownloadView(
		model: ModelCatalog.defaultModel,
		runtime: PreviewModelDownloadRuntime(progress: 1, isLoading: false),
		isDownloadComplete: true,
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
