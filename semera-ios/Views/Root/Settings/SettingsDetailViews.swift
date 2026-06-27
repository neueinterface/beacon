import SwiftUI

struct SettingsTextDetailView: View {
	let title: String
	let paragraphs: [String]

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				ForEach(paragraphs, id: \.self) { paragraph in
					SettingsLegalParagraph(text: paragraph)
				}
			}
			.padding(.horizontal, 20)
			.padding(.top, 18)
			.padding(.bottom, 40)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.background(Color(uiColor: .systemBackground))
		.navigationTitle(title)
		#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
	}
}

private struct SettingsLegalParagraph: View {
	let text: String

	private var lines: [String] {
		text.components(separatedBy: .newlines).filter { !$0.isEmpty }
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			if let heading = lines.first {
				Text(heading)
					.font(.system(size: headingFontSize, weight: .semibold))
					.foregroundStyle(.primary)
					.lineSpacing(3)
			}

			ForEach(Array(lines.dropFirst()), id: \.self) { line in
				SettingsLegalLine(text: line)
			}
		}
	}

	private var headingFontSize: CGFloat {
		lines.count == 1 ? 17 : 19
	}
}

private struct SettingsLegalLine: View {
	let text: String

	var body: some View {
		if text.hasPrefix("- ") {
			HStack(alignment: .top, spacing: 8) {
				Text("•")
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(.secondary)

				Text(styledText(String(text.dropFirst(2))))
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(.primary)
					.lineSpacing(4)
			}
		} else {
			Text(styledText(text))
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(.primary)
				.lineSpacing(4)
		}
	}

	private func styledText(_ text: String) -> AttributedString {
		var attributed = AttributedString(text)

		for token in ["semeraco@gmail.com", "Hugging Face", "semera.co"] {
			if let range = attributed.range(of: token) {
				attributed[range].foregroundColor = .blue
				attributed[range].underlineStyle = .single
			}
		}

		return attributed
	}
}

struct ModelLicensesPlaceholderView: View {
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Text("Model licenses will live here.")
					.font(.system(size: 24, weight: .medium))
					.foregroundStyle(.primary)

				Text("Add license details, source links, and usage notes for each downloadable model before release.")
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(.secondary)
					.lineSpacing(4)
			}
			.padding(20)
			.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.background(Color(uiColor: .systemGroupedBackground))
		.navigationTitle("Model Licenses")
		#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
	}
}
