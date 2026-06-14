//
//  HeaderView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI

struct HeaderView: View {
	let title: String
	var onOpenHistory: () -> Void

	var body: some View {
		HStack {
			BeaconButton(icon: "list.dash", variant: .subtle, size: .small, action: onOpenHistory)
				.background(Color(uiColor: .systemGray6), in: Circle())

			Spacer()

			Text(title)
				.font(.headline)

			Spacer()

			// Keeps the title centered while only showing a left action.
			Color.clear
				.frame(width: 34, height: 34)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(alignment: .top) {
			LinearGradient(
				colors: [
					Color(uiColor: .systemBackground),
					Color(uiColor: .systemBackground).opacity(0.92),
					Color(uiColor: .systemBackground).opacity(0)
				],
				startPoint: .top,
				endPoint: .bottom
			)
		}
	}
}

#Preview {
	HeaderView(title: "Local Model") { }
}
