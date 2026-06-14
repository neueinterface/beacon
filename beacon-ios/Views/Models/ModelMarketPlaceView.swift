//
//  ModelMarketPlaceView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 6/14/26.
//

import SwiftUI

struct ModelMarketPlaceView: View {
	let models: [BeaconModel]
	var onClose: () -> Void = { }
	var onDownload: (BeaconModel) -> Void = { _ in }

	@AppStorage("selectedModelID") private var selectedModelID = ""
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@StateObject private var safariViewModel = SafariViewModel()
	@State private var hasAppeared = false
	@State private var deletingModelID: String?
	@State private var deleteErrorMessage: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			ScrollView {
				VStack(alignment: .leading, spacing: 40) {
					header
						.modelMarketplaceEntrance(hasAppeared, delay: 0.04)

					if let deleteErrorMessage {
						Text(deleteErrorMessage)
							.font(.system(size: 14, weight: .regular))
							.foregroundStyle(.red)
							.padding(16)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
							.modelMarketplaceEntrance(hasAppeared, delay: 0.08)
					}

					VStack(alignment: .leading, spacing: 0) {
						ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
							ModelMarketPlaceRow(
								model: model,
								isDownloaded: isDownloaded(model),
								isSelected: selectedModelID == model.id,
								isDeleting: deletingModelID == model.id,
								onDownload: {
									onDownload(model)
								},
								onDelete: {
									delete(model)
								},
								onOpenLink: {
									safariViewModel.open(model.huggingFaceURL)
								}
							)
							.modelMarketplaceEntrance(hasAppeared, delay: 0.12 + Double(index) * 0.06)

							if index < models.count - 1 {
								Divider()
									.padding(.vertical, 20)
									.modelMarketplaceEntrance(hasAppeared, delay: 0.1 + Double(index) * 0.06)
							}
						}
					}
				}
				.padding(.horizontal, 20)
				.padding(.bottom, 60)
			}
		}
		.background(Color(uiColor: .systemBackground))
		.sheet(item: $safariViewModel.page) { page in
			SafariView(url: page.url)
				.ignoresSafeArea()
		}
		.onAppear {
			hasAppeared = true
		}
	}

	private var header: some View {
		HStack(alignment: .top, spacing: 18) {
			VStack(alignment: .leading, spacing: 8) {
				Text("Model Marketplace")
					.font(.system(size: 28, weight: .semibold))
					.foregroundStyle(.primary)

				Text("Download, delete and learn more about the local models you use.")
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(.secondary)
					.lineSpacing(3)
			}

			Spacer(minLength: 12)

			Button(action: onClose) {
				Image(systemName: "xmark")
					.font(.system(size: 16, weight: .semibold))
					.foregroundStyle(.primary)
					.frame(width: 34, height: 34)
					.background(Color(uiColor: .systemGray6), in: Circle())
			}
			.buttonStyle(SpringButtonStyle())
		}
		.padding(.top, 20)
	}

	private var downloadedIDs: Set<String> {
		Set(downloadedModelIDs.split(separator: ",").map(String.init))
	}

	private func isDownloaded(_ model: BeaconModel) -> Bool {
		downloadedIDs.contains(model.id) || FileManager.default.fileExists(atPath: cacheDirectory(for: model).path)
	}

	private func delete(_ model: BeaconModel) {
		deleteErrorMessage = nil
		deletingModelID = model.id

		defer { deletingModelID = nil }

		do {
			let fileManager = FileManager.default
			let cacheURL = cacheDirectory(for: model)
			let metadataURL = metadataDirectory(for: model)

			if fileManager.fileExists(atPath: cacheURL.path) {
				try fileManager.removeItem(at: cacheURL)
			}

			if fileManager.fileExists(atPath: metadataURL.path) {
				try fileManager.removeItem(at: metadataURL)
			}

			var ids = downloadedIDs
			ids.remove(model.id)
			downloadedModelIDs = ids.sorted().joined(separator: ",")

			if selectedModelID == model.id {
				selectedModelID = ""
			}
		} catch {
			deleteErrorMessage = "Could not delete \(model.name): \(error.localizedDescription)"
		}
	}

	private func cacheDirectory(for model: BeaconModel) -> URL {
		huggingFaceHubCacheDirectory.appendingPathComponent(cacheDirectoryName(for: model))
	}

	private func metadataDirectory(for model: BeaconModel) -> URL {
		huggingFaceHubCacheDirectory
			.appendingPathComponent(".metadata")
			.appendingPathComponent(cacheDirectoryName(for: model))
	}

	private func cacheDirectoryName(for model: BeaconModel) -> String {
		"models--\(model.repositoryID.replacingOccurrences(of: "/", with: "--"))"
	}

	private var huggingFaceHubCacheDirectory: URL {
		FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("huggingface")
			.appendingPathComponent("hub")
	}
}

private struct ModelMarketPlaceRow: View {
	let model: BeaconModel
	let isDownloaded: Bool
	let isSelected: Bool
	let isDeleting: Bool
	var showsDownloadInProgress = false
	var onDownload: () -> Void
	var onDelete: () -> Void
	var onOpenLink: () -> Void

	@State private var isDownloading: Bool

	init(
		model: BeaconModel,
		isDownloaded: Bool,
		isSelected: Bool,
		isDeleting: Bool,
		showsDownloadInProgress: Bool = false,
		onDownload: @escaping () -> Void,
		onDelete: @escaping () -> Void,
		onOpenLink: @escaping () -> Void = { }
	) {
		self.model = model
		self.isDownloaded = isDownloaded
		self.isSelected = isSelected
		self.isDeleting = isDeleting
		self.showsDownloadInProgress = showsDownloadInProgress
		self.onDownload = onDownload
		self.onDelete = onDelete
		self.onOpenLink = onOpenLink
		self._isDownloading = State(initialValue: showsDownloadInProgress)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .firstTextBaseline, spacing: 10) {
					Text(model.name)
						.font(.system(size: 18, weight: .medium))
						.foregroundStyle(.primary)

					if isSelected {
						Tag(title: "active", color: .green)
					}
				}

				Text(model.description)
					.font(.system(size: 18, weight: .regular))
					.foregroundStyle(.secondary)
					.lineSpacing(3)
			}

			HStack(spacing: 12) {
				Tag(title: model.formattedSize, color: .indigo)

				if model.type == .reasoning {
					Tag(title: "reasoning", color: .orange)
				} else {
					Tag(title: "chat", color: .gray)
				}

				Tag(title: isDownloaded ? "downloaded" : "available", color: isDownloaded ? .green : .gray)
			}

			VStack(alignment: .leading, spacing: 10) {
				if isDownloaded {
					BeaconButton(isDeleting ? "Deleting" : "Delete", variant: .destructive, size: .small, isDisabled: isSelected, isLoading: isDeleting) {
						onDelete()
					}

					if isSelected {
						Text("Switch to another model before deleting this one.")
							.font(.system(size: 14, weight: .regular))
							.foregroundStyle(.secondary)
					}
				} else {
					BeaconButton("Download", variant: .secondary, size: .small, trailingAssetIcon: "download.icon", isLoading: isDownloading) {
						isDownloading = true
						onDownload()
					}
				}

				BeaconButton("View on Hugging Face", variant: .subtle, size: .small, trailingIcon: "arrow.up.right") {
					onOpenLink()
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

private struct ModelMarketplaceEntranceModifier: ViewModifier {
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
	func modelMarketplaceEntrance(_ isVisible: Bool, delay: Double) -> some View {
		modifier(ModelMarketplaceEntranceModifier(isVisible: isVisible, delay: delay))
	}
}

private extension BeaconModel {
	var huggingFaceURL: URL {
		URL(string: "https://huggingface.co/\(repositoryID)")!
	}
}

#Preview("Marketplace") {
	ModelMarketPlaceView(models: ModelCatalog.availableModels)
}

#Preview("Available Model") {
	ModelMarketPlaceRow(
		model: ModelCatalog.availableModels[0],
		isDownloaded: false,
		isSelected: false,
		isDeleting: false,
		onDownload: { },
		onDelete: { }
	)
	.padding(20)
	.background(Color(uiColor: .systemBackground))
}

#Preview("Downloaded Model") {
	ModelMarketPlaceRow(
		model: ModelCatalog.availableModels[0],
		isDownloaded: true,
		isSelected: false,
		isDeleting: false,
		onDownload: { },
		onDelete: { }
	)
	.padding(20)
	.background(Color(uiColor: .systemBackground))
}

#Preview("Deleting Model") {
	ModelMarketPlaceRow(
		model: ModelCatalog.availableModels[0],
		isDownloaded: true,
		isSelected: false,
		isDeleting: true,
		onDownload: { },
		onDelete: { }
	)
	.padding(20)
	.background(Color(uiColor: .systemBackground))
}

#Preview("Active Downloaded Model") {
	ModelMarketPlaceRow(
		model: ModelCatalog.availableModels[0],
		isDownloaded: true,
		isSelected: true,
		isDeleting: false,
		onDownload: { },
		onDelete: { }
	)
	.padding(20)
	.background(Color(uiColor: .systemBackground))
}
