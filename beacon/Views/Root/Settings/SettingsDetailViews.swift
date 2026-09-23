import SwiftUI

struct ModelLicensesPlaceholderView: View {
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Text("Model licenses will live here.")
					.font(.openRunde(size: 24, weight: .medium))
					.foregroundStyle(.primary)

				Text("Add license details, source links, and usage notes for each downloadable model before release.")
					.font(.openRunde(size: 16, weight: .regular))
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
