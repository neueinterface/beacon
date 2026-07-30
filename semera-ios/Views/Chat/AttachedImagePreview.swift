import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AttachedImagePreview: View {
	let data: Data
	let onRemove: () -> Void

	var body: some View {
		ZStack(alignment: .topTrailing) {
			#if canImport(UIKit)
			if let image = UIImage(data: data) {
				Image(uiImage: image)
					.resizable()
					.scaledToFill()
					.frame(width: 90, height: 90)
					.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
			}
			#endif

			Button(action: onRemove) {
				Image(systemName: "xmark")
					.font(.system(size: 14, weight: .bold))
					.foregroundStyle(.primary)
					.frame(width: 22, height: 22)
					.background(Color(uiColor: .systemBackground), in: Circle())
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Remove attached image")
			.padding(10)
		}
	}
}
