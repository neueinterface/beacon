//
//  Tab.swift
//  beacon
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
				.openRunde(size: 17, weight: .medium)
			case .small:
				.openRunde(size: 13, weight: .semibold)
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
				.spring(response: 0.18, dampingFraction: 0.82)
			}
		}

		var contentTransition: AnyTransition {
			switch self {
			case .regular:
				.opacity.combined(with: .move(edge: .bottom))
			case .small:
				.opacity
			}
		}
	}

	let options: [Selection]
	@Binding var selection: Selection
	var size: Size = .regular
	var horizontalScrollOverflow: CGFloat = 0
	var title: (Selection) -> String
	@ViewBuilder var content: (Selection) -> Content

	@Namespace private var selectionNamespace

	init(
		options: [Selection],
		selection: Binding<Selection>,
		size: Size = .regular,
		horizontalScrollOverflow: CGFloat = 0,
		title: @escaping (Selection) -> String,
		@ViewBuilder content: @escaping (Selection) -> Content
	) {
		self.options = options
		self._selection = selection
		self.size = size
		self.horizontalScrollOverflow = horizontalScrollOverflow
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
				.padding(.horizontal, horizontalScrollOverflow)
			}
			.scrollIndicators(.hidden)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, -horizontalScrollOverflow)

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
						selectionBackground
					}
				}
				.contentShape(Capsule(style: .continuous))
		}
		.buttonStyle(SpringButtonStyle(pressedScale: size == .small ? 0.96 : 1))
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	@ViewBuilder
	private var selectionBackground: some View {
		switch size {
		case .regular:
			Capsule(style: .continuous)
				.fill(selectedBackground)
				.matchedGeometryEffect(id: "selected-tab", in: selectionNamespace)
		case .small:
			Capsule(style: .continuous)
				.fill(selectedBackground)
				.transition(.asymmetric(
					insertion: .scale(scale: 0.88).combined(with: .opacity),
					removal: .opacity
				))
		}
	}

	private var selectedBackground: Color {
		switch size {
		case .regular:
			Color(uiColor: .systemGray6)
		case .small:
			Color(uiColor: .systemGray6)
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
		horizontalScrollOverflow: CGFloat = 0,
		@ViewBuilder content: @escaping (String) -> Content
	) {
		self.init(
			options: options,
			selection: selection,
			size: size,
			horizontalScrollOverflow: horizontalScrollOverflow,
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
			.font(.openRunde(size: 16, weight: .medium))
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	}
	.padding()
}
