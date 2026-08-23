//
//  HeaderView.swift
//  beacon
//
//  Created by Armond Schneider on 3/7/26.
//

import SwiftUI

struct HeaderView: View {
	var onOpenHistory: () -> Void
	var onOpenModels: () -> Void
	var onNewChat: () -> Void

	var body: some View {
		HStack(spacing: 10) {
			BeaconButton(icon: "line.3.horizontal", variant: .secondary, action: onOpenHistory)
			BeaconButton(assetIcon: "playground.icon", variant: .secondary, action: onOpenModels)

			Spacer()

			BeaconButton(assetIcon: "chat.icon", variant: .secondary, action: onNewChat)
		}
		.padding(.horizontal, 20)
		.padding(.top, 8)
		.padding(.bottom, 12)
	}
}

#Preview {
	HeaderView(onOpenHistory: { }, onOpenModels: { }, onNewChat: { })
}
