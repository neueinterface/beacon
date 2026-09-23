import SwiftUI

struct ActionToast: View {
	let text: String
	var onDismiss: () -> Void = {}
	@State private var dragOffset: CGFloat = 0
	@State private var isDismissing = false

	var body: some View {
		HStack(spacing: 9) {
			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 13, weight: .bold))

			Text(text)
				.font(.beaconFont(size: 16, weight: .medium))
		}
		.foregroundStyle(.white)
		.padding(.horizontal, 20)
        .padding(.vertical, 12)
		.background(.black, in: Rectangle())
        .cornerRadius(12)
		.shadow(color: .black.opacity(0.1), radius: 16, y: 7)
		.offset(y: dragOffset)
		.opacity(max(0, 1 - Double(abs(dragOffset) / 100)))
		.scaleEffect(isDismissing ? 0.96 : 1)
		.gesture(
			DragGesture(minimumDistance: 8)
				.onChanged { value in
					guard value.translation.height < 0 else { return }
					dragOffset = value.translation.height
				}
				.onEnded { value in
					guard value.translation.height < -36 else {
						withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
							dragOffset = 0
						}
						return
					}

					isDismissing = true
					withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
						dragOffset = -120
					}
					Task { @MainActor in
						try? await Task.sleep(for: .milliseconds(260))
						onDismiss()
					}
				}
		)
	}
}

#Preview {
	ActionToast(text: "Copied")
		.padding()
}
