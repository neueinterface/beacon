import SwiftUI

struct PersonalityCard: View {
	let personality: ChatPersonality

	var body: some View {
		HStack(spacing: 14) {
			Image(personality.avatarAsset)
				.resizable()
				.scaledToFit()
				.frame(width: 48, height: 48)
				.background(personality.avatarBackground, in: Circle())
				.clipShape(Circle())

			VStack(alignment: .leading, spacing: 4) {
				Text(personality.name)
					.font(.beaconFont(size: 16, weight: .semibold))
					.foregroundStyle(.primary)
				Text(personality.description)
					.font(.beaconFont(size: 13, weight: .regular))
					.foregroundStyle(.secondary)
			}
			Spacer(minLength: 0)
		}
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(uiColor: .systemGray6).opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
		.contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
		.accessibilityElement(children: .combine)
	}
}

#Preview {
    ZStack {
        PersonalityCard(personality: .professorBug)
            .padding()
    }
}
