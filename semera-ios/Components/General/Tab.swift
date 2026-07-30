//
//  Tab.swift
//  semera-ios
//
//  Created by Armond Schneider on 6/19/26.
//

import SwiftUI

struct Tabs<Selection: Hashable, Content: View>: View {
	enum Size {
		case regular
		case small

		var font: Font {
			switch self {
			case .regular:
				.system(size: 17, weight: .medium)
			case .small:
				.system(size: 13, weight: .semibold)
			}
		}

		var horizontalPadding: CGFloat {
			switch self {
			case .regular:
				22
			case .small:
				14
			}
		}

		var verticalPadding: CGFloat {
			switch self {
			case .regular:
				16
			case .small:
				9
			}
		}

		var spacing: CGFloat {
			switch self {
			case .regular:
				16
			case .small:
				8
			}
		}

		var contentSpacing: CGFloat {
			switch self {
			case .regular:
				18
			case .small:
				14
			}
		}

		var animation: Animation {
			switch self {
			case .regular:
				.smooth(duration: 0.14)
			case .small:
				.snappy(duration: 0.18, extraBounce: 0)
			}
		}

		var contentTransition: AnyTransition {
			switch self {
			case .regular:
				.opacity.combined(with: .move(edge: .bottom))
			case .small:
				.opacity.combined(with: .scale(scale: 0.985))
			}
		}
	}

	let options: [Selection]
	@Binding var selection: Selection
	var size: Size = .regular
	var title: (Selection) -> String
	@ViewBuilder var content: (Selection) -> Content

	@Namespace private var selectionNamespace

	init(
		options: [Selection],
		selection: Binding<Selection>,
		size: Size = .regular,
		title: @escaping (Selection) -> String,
		@ViewBuilder content: @escaping (Selection) -> Content
	) {
		self.options = options
		self._selection = selection
		self.size = size
		self.title = title
		self.content = content
	}

	var body: some View {
		VStack(alignment: .leading, spacing: size.contentSpacing) {
			ScrollView(.horizontal) {
				HStack(spacing: size.spacing) {
					ForEach(options, id: \.self) { option in
						tabButton(for: option)
					}
				}
				.fixedSize(horizontal: true, vertical: false)
			}
			.scrollIndicators(.hidden)
			.frame(maxWidth: .infinity, alignment: .leading)

			content(selection)
				.frame(maxWidth: .infinity, alignment: .leading)
				.id(selection)
				.transition(size.contentTransition)
		}
		.sensoryFeedback(.selection, trigger: selection)
	}

	private func tabButton(for option: Selection) -> some View {
		let isSelected = selection == option

		return Button {
			withAnimation(size.animation) {
				selection = option
			}
		} label: {
			Text(title(option))
				.font(size.font)
				.foregroundStyle(foregroundStyle(isSelected: isSelected))
				.padding(.horizontal, size.horizontalPadding)
				.padding(.vertical, size.verticalPadding)
				.background {
					if isSelected {
						Capsule(style: .continuous)
							.fill(selectedBackground)
							.matchedGeometryEffect(id: "selected-tab", in: selectionNamespace)
							.shadow(color: selectedShadowColor, radius: 10, y: 4)
					}
				}
				.contentShape(Capsule(style: .continuous))
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	private var selectedBackground: Color {
		switch size {
		case .regular:
			Color(uiColor: .systemGray6)
		case .small:
			Color(uiColor: .systemGray6)
		}
	}

	private var selectedShadowColor: Color {
		switch size {
		case .regular:
			.clear
		case .small:
			.clear
		}
	}

	private func foregroundStyle(isSelected: Bool) -> Color {
		guard size == .small else { return .primary }
		return isSelected ? .primary : .secondary
	}
}

extension Tabs where Selection == String {
	init(
		options: [String],
		selection: Binding<String>,
		size: Size = .regular,
		@ViewBuilder content: @escaping (String) -> Content
	) {
		self.init(
			options: options,
			selection: selection,
			size: size,
			title: { $0 },
			content: content
		)
	}
}

#Preview {
	@Previewable @State var selection = "Option 2"

	Tabs(
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
