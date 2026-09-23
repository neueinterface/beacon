import Foundation
import SwiftUI

struct ModelDetailsView: View {
	@Environment(\.dismiss) private var dismiss

	let model: BeaconModel
	let isDownloaded: Bool
	let isSelected: Bool
	let isDeleting: Bool
	let deleteErrorMessage: String?
	let downloadAvailability: ModelStorageLimit.DownloadAvailability
	var onDownload: () -> Void
	var onSelect: () -> Void
	var onDelete: () -> Void
	var onOpenURL: (URL) -> Void

	@State private var huggingFaceMetadata: HuggingFaceModelMetadata?
	@State private var isLoadingHuggingFaceMetadata = false

	init(
		model: BeaconModel,
		isDownloaded: Bool = false,
		isSelected: Bool = false,
		isDeleting: Bool = false,
		deleteErrorMessage: String? = nil,
		downloadAvailability: ModelStorageLimit.DownloadAvailability = .available,
		onDownload: @escaping () -> Void = { },
		onSelect: @escaping () -> Void = { },
		onDelete: @escaping () -> Void = { },
		onOpenURL: @escaping (URL) -> Void = { _ in }
	) {
		self.model = model
		self.isDownloaded = isDownloaded
		self.isSelected = isSelected
		self.isDeleting = isDeleting
		self.deleteErrorMessage = deleteErrorMessage
		self.downloadAvailability = downloadAvailability
		self.onDownload = onDownload
		self.onSelect = onSelect
		self.onDelete = onDelete
		self.onOpenURL = onOpenURL
	}

	private var deviceCompatibility: ModelDeviceCompatibility {
		.current(for: model)
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 26) {
				VStack(alignment: .leading, spacing: 14) {
					Text(model.name)
						.font(.openRunde(size: 30, weight: .medium))
						.foregroundStyle(.primary)

					Text(model.description)
						.font(.openRunde(size: 16, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(4)
				}

				HStack(spacing: 12) {
					Tag(title: model.isBuiltIn ? "Built in" : model.compactDownloadSize, color: .indigo)
					Tag(title: "chat", color: .orange)
				}

				modelActions

				if let deleteErrorMessage {
					Text(deleteErrorMessage)
						.font(.openRunde(size: 14, weight: .regular))
						.foregroundStyle(Color(uiColor: .systemRed))
				}

				Divider()

				metadataSummary

				ModelStatsCard(
					storage: model.isBuiltIn ? "Built in" : model.compactDownloadSize,
					context: formattedContextLength,
					parameters: formattedParameterCount
				)

				if let readme = huggingFaceMetadata?.readme {
					Divider()
					readmeCard(readme)
				}

				if !model.isBuiltIn {
					BeaconButton("View on Hugging Face", variant: .secondary, trailingAssetIcon: "globe.icon") {
						onOpenURL(model.huggingFaceURL)
					}
				}
			}
			.padding(.horizontal, 24)
			.padding(.top, 30)
			.padding(.bottom, 48)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.scrollEdgeEffectStyle(.soft, for: .top)
		.background(Color(uiColor: .systemBackground))
		.navigationBarBackButtonHidden(true)
		.toolbar {
			#if os(macOS)
			ToolbarItemGroup(placement: .automatic) {
				closeButton
				if !isDownloaded, !model.isBuiltIn {
					BeaconButton(
						assetIcon: "download.icon",
						isDisabled: !canDownload
					) {
						onDownload()
					}
				}
			}
			#else
			ToolbarItem(placement: .topBarLeading) {
				closeButton
			}
			ToolbarItem(placement: .principal) {
				Text(model.name)
					.font(.openRunde(size: 18, weight: .semibold))
			}
			if !isDownloaded, !model.isBuiltIn {
				ToolbarItem(placement: .topBarTrailing) {
					BeaconButton(
						assetIcon: "download.icon",
						isDisabled: !canDownload
					) {
						onDownload()
					}
				}
			}
			#endif
		}
		#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		.toolbarBackground(.visible, for: .navigationBar)
		#endif
		.task(id: model.repositoryID) {
			await loadHuggingFaceMetadata()
		}
	}

	private var closeButton: some View {
		Button {
			dismiss()
		} label: {
			Image("close.icon")
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
				.frame(width: 20, height: 20)
				.foregroundStyle(.primary)
		}
		.accessibilityLabel("Close")
	}

	@ViewBuilder
	private var metadataSummary: some View {
		if let metadata = huggingFaceMetadata,
		   metadata.downloads != nil || metadata.lastModified != nil {
			ViewThatFits(in: .horizontal) {
				HStack(spacing: 24) {
					metadataSummaryContent(metadata)
				}
				VStack(alignment: .leading, spacing: 12) {
					metadataSummaryContent(metadata)
				}
			}
		} else if isLoadingHuggingFaceMetadata {
			ProgressView()
				.controlSize(.small)
		}
	}

	@ViewBuilder
	private func metadataSummaryContent(_ metadata: HuggingFaceModelMetadata) -> some View {
		if let downloads = metadata.downloads {
			metadataItem("\(downloads.formatted(.number.notation(.compactName))) Downloads", assetIcon: "download.icon")
		}
		if let lastModified = metadata.lastModified {
			metadataItem("Updated \(lastModified.formatted(.relative(presentation: .named)))", assetIcon: "switch.icon")
		}
	}

	private func metadataItem(_ title: String, assetIcon: String) -> some View {
		HStack(spacing: 7) {
			Image(assetIcon)
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
				.frame(width: 18, height: 18)
			Text(title)
		}
		.font(.openRunde(size: 14, weight: .medium))
		.foregroundStyle(.primary)
	}

	private func readmeCard(_ readme: String) -> some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("README")
				.font(.openRunde(size: 13, weight: .semibold))

			Text(readmeAttributedString(readme))
				.font(.openRunde(size: 15, weight: .regular))
				.lineSpacing(3)
				.foregroundStyle(.primary)
				.environment(\.openURL, OpenURLAction { url in
					openReadmeURL(url)
				})
		}
		.padding(20)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.stroke(Color(uiColor: .systemGray5), lineWidth: 1)
		}
	}

	@ViewBuilder
	private var modelActions: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 12) {
				if isSelected {
					DownloadedModelButton(title: "In use")
				} else if isDownloaded {
					BeaconButton("Use model", variant: .secondary, isDisabled: !deviceCompatibility.canUse) {
						onSelect()
					}
				} else if !model.isBuiltIn {
					BeaconButton(
						"Download",
						variant: .secondary,
						trailingAssetIcon: "download.icon",
						isDisabled: !canDownload
					) {
						onDownload()
					}
				}

				if isDownloaded, !model.isBuiltIn {
					BeaconButton("Delete", variant: .destructive, trailingAssetIcon: "trash.icon", isLoading: isDeleting) {
						onDelete()
					}
				}
			}

			if !isDownloaded, let message = downloadUnavailableMessage {
				Text(message)
					.font(.openRunde(size: 14, weight: .regular))
					.foregroundStyle(.secondary)
			}
		}
	}

	private var canDownload: Bool {
		downloadAvailability.canDownload && deviceCompatibility.canUse
	}

	private var formattedContextLength: String {
		guard let value = huggingFaceMetadata?.contextLength else { return "-" }
		if value >= 1_000_000 {
			return "\(String(format: "%g", Double(value) / 1_000_000))M"
		}
		if value >= 1_000 {
			return "\(String(format: "%g", Double(value) / 1_000))K"
		}
		return value.formatted()
	}

	private var formattedParameterCount: String {
		guard let value = model.parameterCountInBillions else { return "-" }
		return "\(String(format: "%g", NSDecimalNumber(decimal: value).doubleValue))B"
	}

	private var downloadUnavailableMessage: String? {
		guard deviceCompatibility.canUse else { return deviceCompatibility.message }
		return switch downloadAvailability {
		case .available:
			nil
		case .appStorageFull:
			"Delete a downloaded model to free up Beacon's 10 GB model storage limit."
		case let .deviceStorageLow(requiredGB, availableGB):
			"Requires about \(ModelStorageLimit.formattedGB(requiredGB)) free. You have \(ModelStorageLimit.formattedGB(availableGB)) available."
		}
	}

	@MainActor
	private func loadHuggingFaceMetadata() async {
		guard !model.isBuiltIn else { return }
		isLoadingHuggingFaceMetadata = true
		defer { isLoadingHuggingFaceMetadata = false }
		do {
			huggingFaceMetadata = try await HuggingFaceModelMetadataService().fetch(repositoryID: model.repositoryID)
		} catch {
			return
		}
	}

	private func readmeAttributedString(_ readme: String) -> AttributedString {
		(try? AttributedString(markdown: readme, options: .init(interpretedSyntax: .full))) ?? AttributedString(readme)
	}

	private func openReadmeURL(_ url: URL) -> OpenURLAction.Result {
		let resolvedURL: URL
		if url.scheme == nil {
			resolvedURL = URL(string: url.relativeString, relativeTo: model.huggingFaceURL.appendingPathComponent(""))?.absoluteURL ?? url
		} else {
			resolvedURL = url
		}
		guard resolvedURL.scheme?.lowercased() == "https" else { return .discarded }
		onOpenURL(resolvedURL)
		return .handled
	}
}

private struct ModelStatsCard: View {
	let storage: String
	let context: String
	let parameters: String

	var body: some View {
		HStack(spacing: 0) {
			stat(title: "Storage", value: storage, unit: "bytes")
			Divider()
			stat(title: "Context", value: context, unit: "tokens")
			Divider()
			stat(title: "Size", value: parameters, unit: "parameters")
		}
		.frame(height: 150)
		.background(Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.stroke(Color(uiColor: .systemGray5), lineWidth: 1)
		}
	}

	private func stat(title: String, value: String, unit: String) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(title)
				.font(.openRunde(size: 14, weight: .medium))
			Text(value)
				.font(.openRunde(size: 22, weight: .regular))
				.lineLimit(1)
				.minimumScaleFactor(0.7)
				.frame(maxWidth: .infinity, alignment: .leading)
			Text(unit)
				.font(.openRunde(size: 13, weight: .regular))
				.foregroundStyle(.secondary)
		}
		.padding(.horizontal, 18)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
	}
}

struct ModelMarketplaceTag: Identifiable {
	let title: String
	let color: Color

	var id: String { title }
}

extension BeaconModel {
	var company: String {
		let searchableText = "\(name) \(repositoryID)".lowercased()
		if searchableText.contains("deepseek") { return "DeepSeek" }
		if searchableText.contains("apple") || searchableText.contains("openelm") { return "Apple" }
		if searchableText.contains("qwen") { return "Alibaba" }
		if searchableText.contains("lfm") || searchableText.contains("liquid") { return "Liquid AI" }
		if searchableText.contains("llama") { return "Meta" }
		if searchableText.contains("gemma") { return "Google" }
		if searchableText.contains("phi") { return "Microsoft" }
		if searchableText.contains("mistral") || searchableText.contains("ministral") { return "Mistral AI" }
		if searchableText.contains("granite") { return "IBM" }
		if searchableText.contains("stablelm") { return "Stability AI" }
		if searchableText.contains("smollm") { return "Hugging Face" }
		if searchableText.contains("olmo") { return "Allen Institute" }
		if searchableText.contains("yi-") { return "01.AI" }
		if searchableText.contains("glm") { return "Zhipu" }
		if searchableText.contains("minicpm") { return "OpenBMB" }
		return repositoryID.split(separator: "/").first.map(String.init) ?? "Other"
	}

	var marketplaceTags: [ModelMarketplaceTag] {
		var tags = capabilityTags.map { ModelMarketplaceTag(title: $0, color: .indigo) }
		if let formattedParameterCount {
			tags.append(ModelMarketplaceTag(title: formattedParameterCount, color: .blue))
		}
		if !isBuiltIn {
			tags.append(ModelMarketplaceTag(title: compactDownloadSize, color: .teal))
		}
		if let quantizationLabel {
			tags.append(ModelMarketplaceTag(title: quantizationLabel, color: .cyan))
		}
		return tags
	}

	var compactDownloadSize: String {
		let size = NSDecimalNumber(decimal: sizeInGB).doubleValue
		if size < 1 {
			return String(format: "%.1f GB", size)
		}
		return String(format: "%.1f GB", size)
	}

	var quantizationLabel: String? {
		if repositoryID.localizedCaseInsensitiveContains("4bit") || name.localizedCaseInsensitiveContains("4-bit") {
			return "4-bit"
		}
		return nil
	}

	var huggingFaceURL: URL {
		URL(string: "https://huggingface.co/\(repositoryID)")!
	}
}

struct ModelTagLayout: Layout {
	var spacing: CGFloat = 8

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		let availableWidth = proposal.width ?? .infinity
		var rowWidth: CGFloat = 0
		var rowHeight: CGFloat = 0
		var totalHeight: CGFloat = 0
		var maximumWidth: CGFloat = 0
		for subview in subviews {
			let size = subview.sizeThatFits(.unspecified)
			if rowWidth > 0, rowWidth + spacing + size.width > availableWidth {
				maximumWidth = max(maximumWidth, rowWidth)
				totalHeight += rowHeight + spacing
				rowWidth = 0
				rowHeight = 0
			}
			rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
			rowHeight = max(rowHeight, size.height)
		}
		maximumWidth = max(maximumWidth, rowWidth)
		return CGSize(width: proposal.width ?? maximumWidth, height: totalHeight + rowHeight)
	}

	func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
		var position = CGPoint(x: bounds.minX, y: bounds.minY)
		var rowHeight: CGFloat = 0
		for subview in subviews {
			let size = subview.sizeThatFits(.unspecified)
			if position.x > bounds.minX, position.x + size.width > bounds.maxX {
				position.x = bounds.minX
				position.y += rowHeight + spacing
				rowHeight = 0
			}
			subview.place(at: position, anchor: .topLeading, proposal: ProposedViewSize(size))
			position.x += size.width + spacing
			rowHeight = max(rowHeight, size.height)
		}
	}
}

extension ModelDeviceCompatibility {
	var marketplaceTint: Color {
		switch self {
		case .goodFit: .green
		case .mayBeSlow: .orange
		case .unavailable: .gray
		}
	}
}

struct DownloadedModelButton: View {
	var title = "Downloaded"

	var body: some View {
		HStack(spacing: 8) {
			Text(title)
				.font(.openRunde(size: 14, weight: .semibold))
			Image("check.icon")
				.renderingMode(.template)
				.resizable()
				.scaledToFit()
				.frame(width: 14, height: 14)
		}
		.foregroundStyle(Color(uiColor: .systemGreen))
		.padding(.horizontal, 14)
		.frame(minHeight: 34)
		.background(Color(uiColor: .systemGreen).opacity(0.14), in: Capsule())
	}
}

#Preview("Available model details") {
	NavigationStack {
		ModelDetailsView(model: ModelCatalog.availableModels[0])
	}
}

#Preview("Downloaded model details") {
	NavigationStack {
		ModelDetailsView(model: ModelCatalog.availableModels[0], isDownloaded: true)
	}
}
