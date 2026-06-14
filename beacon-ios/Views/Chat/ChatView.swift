import SwiftUI
import UIKit

struct ChatView: View {
	@ObservedObject var runtime: BeaconModelRuntime
	var onDownloadModel: (BeaconModel) -> Void = { _ in }
	@StateObject private var historyViewModel = ChatHistoryViewModel()
	@AppStorage("selectedModelID") private var selectedModelID = ""
	@State private var inputText = ""
	@State private var isShowingHistory = false
	@State private var isShowingModels = false

	private let screenSpring = Animation.spring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.12)

	private var selectedModel: BeaconModel {
		ModelCatalog.model(id: selectedModelID) ?? ModelCatalog.defaultModel
	}

	var body: some View {
		GeometryReader { geometry in
			ZStack(alignment: .leading) {
				chatContent
					.depthLayer(isActive: !isShowingHistory && !isShowingModels, edge: .trailing)
					.blur(radius: (isShowingHistory || isShowingModels) ? 10 : 0)
					.scaleEffect((isShowingHistory || isShowingModels) ? 0.94 : 1)
					.opacity((isShowingHistory || isShowingModels) ? 0.68 : 1)
					.zIndex(0)

				ChatHistoryDrawerView(
					viewModel: historyViewModel,
					onClose: {
						withAnimation(screenSpring) {
							isShowingHistory = false
							isShowingModels = false
						}
					},
					onNewChat: {
						historyViewModel.startNewChat()
						withAnimation(screenSpring) {
							isShowingHistory = false
							isShowingModels = false
						}
					},
					onOpenModels: {
						withAnimation(screenSpring) {
							isShowingModels = true
						}
					}
				) { _ in
					withAnimation(screenSpring) {
						isShowingHistory = false
						isShowingModels = false
					}
				}
				.frame(width: geometry.size.width)
				.frame(maxHeight: .infinity)
				.depthLayer(isActive: isShowingHistory && !isShowingModels, edge: .leading)
				.blur(radius: isShowingModels ? 10 : 0)
				.scaleEffect(isShowingModels ? 0.96 : 1)
				.opacity(isShowingHistory ? (isShowingModels ? 0.45 : 1) : 0)
				.allowsHitTesting(isShowingHistory && !isShowingModels)
				.zIndex(isShowingModels ? 1 : 2)

				ModelMarketPlaceView(
					models: ModelCatalog.availableModels,
					onClose: {
						withAnimation(screenSpring) {
							isShowingModels = false
							isShowingHistory = false
						}
					},
					onDownload: { model in
						onDownloadModel(model)
					}
				)
				.frame(width: geometry.size.width)
				.frame(maxHeight: .infinity)
				.depthLayer(isActive: isShowingModels, edge: .trailing)
				.opacity(isShowingModels ? 1 : 0)
				.allowsHitTesting(isShowingModels)
				.zIndex(3)
			}
			.animation(screenSpring, value: isShowingHistory)
			.animation(screenSpring, value: isShowingModels)
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
				dismissKeyboard()
				withAnimation(screenSpring) {
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
			.scrollDismissesKeyboard(.interactively)

			Input(text: $inputText) { text in
				send(text)
			}
			.disabled(runtime.isLoading || runtime.isGenerating)
			.opacity(runtime.isLoading ? 0.5 : 1)
			.padding(.horizontal, 14)
			.padding(.vertical, 12)
		}
		.background(Color(uiColor: .systemBackground))
		.simultaneousGesture(
			DragGesture(minimumDistance: 16)
				.onEnded { value in
					guard value.translation.height > 28 else { return }
					dismissKeyboard()
				}
		)
	}

	private func send(_ text: String) {
		dismissKeyboard()
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

	private func dismissKeyboard() {
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
	}
}

private enum ScreenEdge {
	case leading
	case trailing
}

private struct DepthLayerModifier: ViewModifier {
	let isActive: Bool
	let edge: ScreenEdge

	func body(content: Content) -> some View {
		content
			.blur(radius: isActive ? 0 : 8)
			.scaleEffect(isActive ? 1 : 0.94)
			.rotation3DEffect(
				.degrees(isActive ? 0 : (edge == .leading ? -4 : 4)),
				axis: (x: 0, y: 1, z: 0),
				perspective: 0.75
			)
			.offset(x: isActive ? 0 : (edge == .leading ? -28 : 28))
	}
}

private extension View {
	func depthLayer(isActive: Bool, edge: ScreenEdge) -> some View {
		modifier(DepthLayerModifier(isActive: isActive, edge: edge))
	}
}

#Preview {
	ChatView(runtime: BeaconModelRuntime())
}
