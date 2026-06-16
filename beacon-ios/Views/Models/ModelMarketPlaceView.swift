//
//  ModelMarketPlaceView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 6/14/26.
//

import SwiftUI
import UIKit

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
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 40) {
					Text("Download, delete and learn more about the local models you use.")
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
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
								onSelect: {
									selectedModelID = model.id
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
			.scrollEdgeEffectStyle(.soft, for: .top)
			.navigationTitle("Model Marketplace")
			.navigationBarTitleDisplayMode(.large)
			.background(ModelMarketplaceNavigationAppearance())
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(action: onClose) {
						Image(systemName: "xmark")
							.font(.system(size: 16, weight: .semibold))
							.foregroundStyle(.primary)
							.frame(width: 34, height: 34)
					}
					.buttonStyle(.plain)
				}
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

	private var downloadedIDs: Set<String> {
		Set(downloadedModelIDs.split(separator: ",").map(String.init))
	}

	private func isDownloaded(_ model: BeaconModel) -> Bool {
		if model.isBuiltIn { return true }
		return downloadedIDs.contains(model.id) || FileManager.default.fileExists(atPath: cacheDirectory(for: model).path)
	}

	private func delete(_ model: BeaconModel) {
		guard !model.isBuiltIn else { return }

		deleteErrorMessage = nil
		deletingModelID = model.id

		defer { deletingModelID = nil }

		do {
			let fileManager = FileManager.default
			let cacheURL = cacheDirectory(for: model)
			let metadataURL = metadataDirectory(for: model)
			let lockURL = lockDirectory(for: model)

			if fileManager.fileExists(atPath: cacheURL.path) {
				try fileManager.removeItem(at: cacheURL)
			}

			if fileManager.fileExists(atPath: metadataURL.path) {
				try fileManager.removeItem(at: metadataURL)
			}

			if fileManager.fileExists(atPath: lockURL.path) {
				try fileManager.removeItem(at: lockURL)
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

	private func lockDirectory(for model: BeaconModel) -> URL {
		huggingFaceHubCacheDirectory
			.appendingPathComponent(".locks")
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

private struct ModelMarketplaceNavigationAppearance: UIViewControllerRepresentable {
	func makeUIViewController(context: Context) -> UIViewController {
		UIViewController()
	}

	func updateUIViewController(_ viewController: UIViewController, context: Context) {
		Task { @MainActor in
			guard let navigationBar = viewController.navigationController?.navigationBar else { return }
			let appearance = navigationBar.standardAppearance.copy()
			appearance.largeTitleTextAttributes[.font] = UIFont.systemFont(ofSize: 28, weight: .semibold)
			navigationBar.standardAppearance = appearance
			navigationBar.scrollEdgeAppearance = appearance
		}
	}
}

private struct ModelMarketPlaceRow: View {
	let model: BeaconModel
	let isDownloaded: Bool
	let isSelected: Bool
	let isDeleting: Bool
	var showsDownloadInProgress = false
	var onDownload: () -> Void
	var onSelect: () -> Void
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
		onSelect: @escaping () -> Void = { },
		onDelete: @escaping () -> Void,
		onOpenLink: @escaping () -> Void = { }
	) {
		self.model = model
		self.isDownloaded = isDownloaded
		self.isSelected = isSelected
		self.isDeleting = isDeleting
		self.showsDownloadInProgress = showsDownloadInProgress
		self.onDownload = onDownload
		self.onSelect = onSelect
		self.onDelete = onDelete
		self.onOpenLink = onOpenLink
		self._isDownloading = State(initialValue: showsDownloadInProgress)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			VStack(alignment: .leading, spacing: 12) {
				Text(model.name)
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(.primary)

				Text(descriptionText)
					.font(.system(size: 16, weight: .regular))
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
			}

			VStack(alignment: .leading, spacing: 14) {
				HStack(spacing: 10) {
					if isDownloaded {
						DownloadedModelButton(title: model.isBuiltIn ? "Built in" : "Downloaded")
					} else {
						BeaconButton("Download", variant: .secondary, size: .small, trailingAssetIcon: "download.icon", isLoading: isDownloading) {
							isDownloading = true
							onDownload()
						}
					}

					if !model.isBuiltIn {
						BeaconButton("View on Hugging Face", variant: .subtle, size: .small, trailingIcon: "arrow.up.right") {
							onOpenLink()
						}
					}
				}

				if isDownloaded {
					VStack(alignment: .leading, spacing: 10) {
						HStack(spacing: 10) {
							if !model.isBuiltIn {
								BeaconButton(isDeleting ? "Deleting" : "Delete", variant: .destructive, size: .small, isDisabled: isSelected, isLoading: isDeleting) {
									onDelete()
								}
							}

							if !isSelected {
								BeaconButton("Use", variant: .secondary, size: .small) {
									onSelect()
								}
							}
						}

						if isSelected && !model.isBuiltIn {
							Text("Switch to another model before deleting this one.")
								.font(.system(size: 14, weight: .regular))
								.foregroundStyle(.secondary)
						}
					}
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var descriptionText: String {
		let trimmedDescription = model.description.trimmingCharacters(in: .whitespacesAndNewlines)
		let recommendation = "Recommended for \(model.recommendedDevice)."

		if trimmedDescription.hasSuffix(".") {
			return "\(trimmedDescription) \(recommendation)"
		}

		return "\(trimmedDescription). \(recommendation)"
	}
}

private struct DownloadedModelButton: View {
	var title = "Downloaded"

	var body: some View {
		HStack(spacing: 8) {
			Text(title)
				.font(.system(size: 14, weight: .semibold))

			Image(systemName: "checkmark")
				.font(.system(size: 14, weight: .bold))
		}
		.foregroundStyle(Color(uiColor: .systemGreen))
		.padding(.horizontal, 14)
		.frame(minHeight: 34)
		.background(Color(uiColor: .systemGreen).opacity(0.14), in: Capsule())
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
