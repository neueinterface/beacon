import SwiftUI

struct MemorySettingsView: View {
	@ObservedObject var memoryStore: MemoryStore
	@AppStorage("memoryEnabled") private var memoryEnabled = true
	@State private var isConfirmingClear = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				VStack(alignment: .leading, spacing: 14) {
					HStack(spacing: 12) {
						Image(systemName: "brain.head.profile")
							.font(.system(size: 19, weight: .semibold))
							.foregroundStyle(Color(uiColor: .systemBlue))
						Toggle("Remember Details", isOn: $memoryEnabled)
							.font(.beaconFont(size: 16, weight: .semibold))
							.tint(Color(uiColor: .systemBlue))
					}
					Text("Beacon saves useful, lasting details on this device and checks them when they are relevant to a response.")
						.font(.beaconFont(size: 14, weight: .regular))
						.foregroundStyle(.secondary)
						.lineSpacing(3)
				}
				.padding(16)
				.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

				HStack(alignment: .firstTextBaseline) {
					Text("Saved memories")
						.font(.beaconFont(size: 18, weight: .semibold))
					Spacer()
					Text("\(memoryStore.memories.count)")
						.font(.beaconFont(size: 14, weight: .semibold))
						.foregroundStyle(.secondary)
				}

				if memoryStore.memories.isEmpty {
					VStack(spacing: 12) {
						Image(systemName: "tray")
							.font(.system(size: 24, weight: .medium))
							.foregroundStyle(.tertiary)
						Text("No memories yet")
							.font(.beaconFont(size: 16, weight: .semibold))
						Text("Names, lasting preferences, projects, and goals you share can appear here.")
							.font(.beaconFont(size: 14, weight: .regular))
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
					}
					.frame(maxWidth: .infinity)
					.padding(.horizontal, 24)
					.padding(.vertical, 32)
					.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
				} else {
					VStack(spacing: 0) {
						ForEach(Array(memoryStore.memories.enumerated()), id: \.element.id) { index, memory in
							HStack(alignment: .top, spacing: 12) {
								Image(systemName: "sparkles")
									.font(.system(size: 14, weight: .semibold))
									.foregroundStyle(Color(uiColor: .systemBlue))
									.frame(width: 28, height: 28)
									.background(Color(uiColor: .systemBlue).opacity(0.1), in: Circle())
								Text(memory.text)
									.font(.beaconFont(size: 15, weight: .regular))
									.frame(maxWidth: .infinity, alignment: .leading)
								Button(role: .destructive) { memoryStore.delete(memory) } label: {
									Image(systemName: "trash")
										.font(.system(size: 14, weight: .semibold))
										.foregroundStyle(.secondary)
										.frame(width: 32, height: 32)
										.background(Color(uiColor: .systemGray6), in: Circle())
								}
								.buttonStyle(.plain)
								.accessibilityLabel("Delete memory: \(memory.text)")
							}
							.padding(16)
							if index < memoryStore.memories.count - 1 {
								Divider().padding(.leading, 56)
							}
						}
					}
					.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

					BeaconButton("Clear All Memories", variant: .destructive, size: .large, isFullWidth: true) {
						isConfirmingClear = true
					}
				}
			}
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.background(Color(uiColor: .systemGroupedBackground))
		.navigationTitle("Memory")
		#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
		.confirmationDialog("Clear all memories?", isPresented: $isConfirmingClear) {
			Button("Clear All Memories", role: .destructive) { memoryStore.clearAll() }
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("Beacon will forget every saved detail. This cannot be undone.")
		}
	}
}

struct ModelLicensesPlaceholderView: View {
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Text("Model licenses will live here.")
					.font(.beaconFont(size: 24, weight: .medium))
					.foregroundStyle(.primary)

				Text("Add license details, source links, and usage notes for each downloadable model before release.")
					.font(.beaconFont(size: 16, weight: .regular))
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
