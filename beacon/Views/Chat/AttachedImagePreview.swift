import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AttachedImagePreview: View {
	let data: [Data]
	let onRemove: (Int) -> Void

	var body: some View {
		attachmentLayout
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	@ViewBuilder
	private var attachmentLayout: some View {
		if data.count >= 4 {
			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
				attachmentItems
			}
		} else {
			HStack(spacing: 10) {
				attachmentItems
			}
		}
	}

	@ViewBuilder
	private var attachmentItems: some View {
		ForEach(Array(data.enumerated()), id: \.offset) { index, imageData in
			ZStack(alignment: .topTrailing) {
				image(imageData)

				Button {
					onRemove(index)
				} label: {
					Image(systemName: "xmark")
						.font(.system(size: 12, weight: .bold))
						.foregroundStyle(.primary)
						.frame(width: 22, height: 22)
						.background(Color(uiColor: .systemBackground), in: Circle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Remove image \(index + 1)")
				.padding(8)
			}
		}
	}

	@ViewBuilder
	private func image(_ data: Data) -> some View {
		#if canImport(UIKit)
		if let image = UIImage(data: data) {
			Image(uiImage: image)
				.resizable()
				.scaledToFill()
				.frame(width: 90, height: 90)
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
		#elseif canImport(AppKit)
		if let image = NSImage(data: data) {
			Image(nsImage: image)
				.resizable()
				.scaledToFill()
				.frame(width: 90, height: 90)
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
		#endif
	}
}
