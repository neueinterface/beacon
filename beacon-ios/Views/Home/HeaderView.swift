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
		.background(Color(uiColor: .systemBackground))
	}
}

#Preview {
	HeaderView(title: "Local Model") { }
}
