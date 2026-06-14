import SwiftUI

struct ChatView: View {
	@ObservedObject var runtime: BeaconModelRuntime
	@StateObject private var historyViewModel = ChatHistoryViewModel()
	@AppStorage("selectedModelID") private var selectedModelID = ""
	@State private var inputText = ""
	@State private var isShowingHistory = false

	private var selectedModel: BeaconModel {
		ModelCatalog.model(id: selectedModelID) ?? ModelCatalog.defaultModel
	}

	var body: some View {
		GeometryReader { geometry in
			ZStack(alignment: .leading) {
				ChatHistoryDrawerView(
					viewModel: historyViewModel,
					onClose: {
						withAnimation(.smooth(duration: 0.32)) {
							isShowingHistory = false
						}
					},
					onNewChat: {
						historyViewModel.startNewChat()
						withAnimation(.smooth(duration: 0.32)) {
							isShowingHistory = false
						}
					}
				) { _ in
					withAnimation(.smooth(duration: 0.28)) {
						isShowingHistory = false
					}
				}
				.frame(width: geometry.size.width)
				.frame(maxHeight: .infinity)
				.offset(x: isShowingHistory ? 0 : -geometry.size.width)

				chatContent
					.offset(x: isShowingHistory ? geometry.size.width : 0)
			}
			.animation(.smooth(duration: 0.32), value: isShowingHistory)
		}
		.background(Color(uiColor: .systemBackground))
		.task {
			guard !runtime.isReady(for: selectedModel) else { return }
			await runtime.load(selectedModel)
		}
	}

	private var chatContent: some View {
		VStack(spacing: 0) {
			HeaderView(title: selectedModel.name) {
				withAnimation(.smooth(duration: 0.28)) {
					isShowingHistory = true
				}
			}

			ScrollView {
				LazyVStack(alignment: .leading, spacing: 20) {
					ForEach(historyViewModel.currentMessages) { message in
						MessageBubble(text: message.text, role: message.role)
					}
				}
				.padding(.horizontal, 18)
				.padding(.top, 24)
				.padding(.bottom, 18)
			}

			Input(text: $inputText) { text in
				send(text)
			}
			.disabled(runtime.isLoading || runtime.isGenerating)
			.opacity(runtime.isLoading ? 0.5 : 1)
			.padding(.horizontal, 14)
			.padding(.vertical, 12)
		}
		.background(Color(uiColor: .systemBackground))
    }

	private func send(_ text: String) {
		let responseID = historyViewModel.appendUserMessage(text, modelName: selectedModel.name)

		Task {
			do {
				try await runtime.streamResponse(to: text) { chunk in
					historyViewModel.appendAssistantChunk(chunk, to: responseID)
				}
			} catch {
				historyViewModel.replaceMessage(responseID, with: error.localizedDescription)
			}
		}
	}
}

#Preview {
	ChatView(runtime: BeaconModelRuntime())
}
