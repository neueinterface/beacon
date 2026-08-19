//
//  FAQView.swift
//  semera-ios
//
//  Created by Armond Schneider on 6/13/26.
//

import SwiftUI

struct FAQView: View {
	var onClose: () -> Void = { }

	private let items = [
		FAQItem(
			question: "What is Beacon?",
			answer: "Beacon is a local-first AI chat app. It helps you discover, download, and chat with models directly on your device."
		),
		FAQItem(
			question: "Do my conversations leave my device?",
			answer: "Beacon is designed around private, on-device conversations. Your chats stay local by default."
		),
		FAQItem(
			question: "Do I need to understand AI models?",
			answer: "No. Beacon keeps model setup simple and presents clear choices so you can start chatting without technical configuration."
		),
		FAQItem(
			question: "Why do I need to download a model?",
			answer: "Models power the chat experience locally. Downloading one lets Beacon run AI on your device instead of relying on a remote service."
		),
		FAQItem(
			question: "Can I delete models later?",
			answer: "Yes. Downloaded models are stored on your device and can be removed whenever you want to free up space."
		)
	]

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 40) {
				header
				questions
			}
			.padding(.horizontal, 20)
			.padding(.top, 40)
			.padding(.bottom, 60)
		}
		.background(Color(uiColor: .systemBackground))
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 10) {
				Text("FAQ")
					.font(.system(size: 32, weight: .medium))
					.foregroundStyle(.primary)

			Text("A few simple answers before you start chatting locally.")
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(.secondary)
				.lineSpacing(3)
		}
	}

	private var questions: some View {
		VStack(alignment: .leading, spacing: 28) {
			ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
				VStack(alignment: .leading, spacing: 28) {
					FAQRow(item: item)

					if index < items.count - 1 {
						Divider()
					}
				}
			}
		}
	}
}

private struct FAQItem: Identifiable {
	let id = UUID()
	let question: String
	let answer: String
}

private struct FAQRow: View {
	let item: FAQItem

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(item.question)
				.font(.system(size: 16, weight: .medium))
				.foregroundStyle(.primary)

			Text(item.answer)
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(.secondary)
				.lineSpacing(4)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.bottom, 2)
	}
}

#Preview {
	FAQView()
}
