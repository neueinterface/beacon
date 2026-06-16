//
//  HeaderView.swift
//  beacon-ios
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI

struct HeaderView: View {
	var onOpenHistory: () -> Void
	var onNewChat: () -> Void

	var body: some View {
		HStack {
			BeaconButton(icon: "line.3.horizontal", variant: .secondary, action: onOpenHistory)

			Spacer()

			BeaconButton(assetIcon: "chat.icon", variant: .secondary, action: onNewChat)
		}
		.padding(.horizontal, 20)
		.padding(.top, 8)
		.padding(.bottom, 12)
	}
}

#Preview {
	HeaderView(onOpenHistory: { }, onNewChat: { })
}
