import SwiftUI

struct PersonalityHeaderView: View {
	let personality: ChatPersonality

	var body: some View {
		Image(personality.avatarAsset)
			.resizable()
			.scaledToFit()
			.frame(width: 32, height: 32)
			.clipShape(Circle())
			.glassEffect(.regular, in: Circle())
			.frame(width: 42, height: 42)
			.contentShape(Circle())
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("Chatting with \(personality.name)")
	}
}
