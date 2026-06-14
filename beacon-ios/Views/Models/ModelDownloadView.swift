//
//  ModelDownloadView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI

struct ModelDownloadView: View {
	let model: BeaconModel
	@ObservedObject var runtime: BeaconModelRuntime
	var onComplete: () -> Void = { }
	var startsAutomatically = true

	@State private var hasStarted = false

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
							Task { await startLoading() }
						}
					}
				}

				VStack(alignment: .leading, spacing: 10) {
					Text(model.name)
						.font(.system(size: 20, weight: .semibold))
						.foregroundStyle(.primary)

					Text("Approx. \(model.formattedSize)")
						.font(.system(size: 17, weight: .regular))
						.foregroundStyle(.secondary)
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
			Task {
				await startLoading()
			}
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
		await runtime.load(model)

		if runtime.isReady(for: model) {
			onComplete()
		}
	}
}

#Preview {
	ModelDownloadView(model: ModelCatalog.defaultModel, runtime: BeaconModelRuntime(), startsAutomatically: false)
}
