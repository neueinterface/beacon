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
			BeaconButton(icon: "line.3.horizontal", variant: .secondary, size: .large, action: onOpenHistory)

			Spacer()

			BeaconButton(assetIcon: "chat.icon", variant: .secondary, size: .large, action: onNewChat)
		}
		.padding(.horizontal, 46)
		.padding(.top, 20)
		.padding(.bottom, 24)
	}
}

#Preview {
	HeaderView(onOpenHistory: { }, onNewChat: { })
}
