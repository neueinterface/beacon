import SwiftUI

struct MemorySettingsView: View {
	@ObservedObject var memoryStore: MemoryStore
	@AppStorage("memoryEnabled") private var memoryEnabled = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 26) {
				VStack(alignment: .leading, spacing: 12) {
					HStack(spacing: 14) {
						Image("memory")
							.renderingMode(.template)
							.resizable()
							.scaledToFit()
							.foregroundStyle(.primary)
							.frame(width: 24, height: 24)

						Text("Enable Memory")
							.font(.system(size: 17, weight: .semibold))
							.foregroundStyle(.primary)

						Spacer(minLength: 12)

						Toggle("Enable Memory", isOn: $memoryEnabled)
							.labelsHidden()
							.tint(Color(uiColor: .systemBlue))
					}

					Text("Allow Beacon to remember useful details from your conversations. Memories stay on this device and can be cleared at any time.")
						.font(.system(size: 14, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
				}
				.padding(18)
				.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

				VStack(alignment: .leading, spacing: 10) {
					Text("Memory Summary")
						.font(.system(size: 18, weight: .semibold))
						.foregroundStyle(Color(uiColor: .systemGray))

					VStack(alignment: .leading, spacing: 18) {
						Text(memoryStore.summary.isEmpty ? "Memory will be added here as you chat." : memoryStore.summary)
							.font(.system(size: 16, weight: .regular))
							.foregroundStyle(memoryStore.summary.isEmpty ? .secondary : .primary)
							.lineSpacing(5)
							.frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)

						if !memoryStore.memories.isEmpty {
							Divider()

							Button("Clear Memory", role: .destructive) {
								memoryStore.clearAll()
							}
							.font(.system(size: 15, weight: .semibold))
						}
					}
					.padding(18)
					.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 20)
			.padding(.bottom, 40)
		}
		.background(Color(uiColor: .systemGroupedBackground))
		.navigationTitle("Memory")
		#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
		#if DEBUG
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("Add Test Memory") {
					memoryStore.add("The user is testing Beacon's local memory.")
				}
			}
		}
		#endif
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
