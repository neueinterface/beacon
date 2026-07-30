import SwiftUI

struct MemoriesView: View {
	@ObservedObject var memoryStore: UserMemoryStore
	@State private var isConfirmingDeleteAll = false

	var body: some View {
		List {
			if memoryStore.memories.isEmpty {
				ContentUnavailableView(
					"No Memories",
					systemImage: "brain.head.profile",
					description: Text("Helpful details you share, like work or family information, will appear here.")
				)
				.listRowBackground(Color.clear)
			} else {
				Section {
					ForEach(memoryStore.memories) { memory in
						Text(memory.text)
							.font(.system(size: 16))
							.padding(.vertical, 4)
					}
					.onDelete { indexSet in
						for index in indexSet.reversed() {
							memoryStore.delete(memoryStore.memories[index])
						}
					}
				} header: {
					Text("Stored on this device only")
				}

				Section {
					Button("Delete All Memories", role: .destructive) {
						isConfirmingDeleteAll = true
					}
				}
			}
		}
		.listStyle(.insetGrouped)
		.navigationTitle("Memories")
		#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
		.alert("Delete all memories?", isPresented: $isConfirmingDeleteAll) {
			Button("Cancel", role: .cancel) { }
			Button("Delete All", role: .destructive) {
				memoryStore.clearAll()
			}
		} message: {
			Text("This cannot be undone.")
		}
	}
}
