//
//  Tab.swift
//  semera-ios
//
//  Created by Armond Schneider on 6/19/26.
//

import SwiftUI

struct BeaconTabs<Selection: Hashable, Content: View>: View {
	let options: [Selection]
	@Binding var selection: Selection
	var title: (Selection) -> String
	@ViewBuilder var content: (Selection) -> Content

	@Namespace private var selectionNamespace

	init(
		options: [Selection],
		selection: Binding<Selection>,
		title: @escaping (Selection) -> String,
		@ViewBuilder content: @escaping (Selection) -> Content
	) {
		self.options = options
		self._selection = selection
		self.title = title
		self.content = content
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 18) {
			ScrollView(.horizontal) {
				HStack(spacing: 16) {
					ForEach(options, id: \.self) { option in
						tabButton(for: option)
					}
				}
				.fixedSize(horizontal: true, vertical: false)
			}
			.scrollIndicators(.hidden)
			.scrollClipDisabled()
			.frame(maxWidth: .infinity, alignment: .leading)

			content(selection)
				.frame(maxWidth: .infinity, alignment: .leading)
				.id(selection)
				.transition(.opacity.combined(with: .move(edge: .bottom)))
		}
	}

	private func tabButton(for option: Selection) -> some View {
		let isSelected = selection == option

		return Button {
			withAnimation(.smooth(duration: 0.24)) {
				selection = option
			}
		} label: {
			Text(title(option))
				.font(.system(size: 17, weight: .medium))
				.foregroundStyle(.primary)
				.padding(.horizontal, 22)
				.padding(.vertical, 16)
				.background {
					if isSelected {
						Capsule(style: .continuous)
							.fill(Color(uiColor: .systemGray6))
							.matchedGeometryEffect(id: "selected-tab", in: selectionNamespace)
					}
				}
				.contentShape(Capsule(style: .continuous))
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}

extension BeaconTabs where Selection == String {
	init(
		options: [String],
		selection: Binding<String>,
		@ViewBuilder content: @escaping (String) -> Content
	) {
		self.init(
			options: options,
			selection: selection,
			title: { $0 },
			content: content
		)
	}
}

#Preview {
	@Previewable @State var selection = "Option 2"

	BeaconTabs(
		options: ["Option", "Option 2", "Option 3", "Option 4"],
		selection: $selection
	) { option in
		Text("Content for \(option)")
			.font(.system(size: 16, weight: .medium))
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	}
	.padding()
}
