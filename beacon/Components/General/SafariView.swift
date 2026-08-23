//
//  SafariView.swift
//  beacon
//
//  Created by Armond Schneider on 6/14/26.
//

import Combine
import SwiftUI
#if canImport(UIKit) && canImport(SafariServices)
import SafariServices
#elseif canImport(AppKit)
import AppKit
#endif

struct SafariPage: Identifiable {
	let id = UUID()
	let url: URL
}

@MainActor
final class SafariViewModel: ObservableObject {
	@Published var page: SafariPage?

	func open(_ url: URL) {
		page = SafariPage(url: url)
	}

	func close() {
		page = nil
	}
}

#if canImport(UIKit) && canImport(SafariServices)
struct SafariView: UIViewControllerRepresentable {
	let url: URL

	func makeUIViewController(context: Context) -> SFSafariViewController {
		let configuration = SFSafariViewController.Configuration()
		configuration.entersReaderIfAvailable = false
		configuration.barCollapsingEnabled = true

		let controller = SFSafariViewController(url: url, configuration: configuration)
		controller.preferredControlTintColor = .label
		controller.dismissButtonStyle = .close
		return controller
	}

	func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}
#else
struct SafariView: View {
	let url: URL

	var body: some View {
		Link(url.absoluteString, destination: url)
			.padding()
			.onAppear {
				#if canImport(AppKit)
				NSWorkspace.shared.open(url)
				#endif
			}
	}
}
#endif

#Preview {
	SafariView(url: URL(string: "https://huggingface.co")!)
}
