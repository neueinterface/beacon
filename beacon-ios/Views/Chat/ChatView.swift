import SwiftUI
import UIKit

struct ChatView: View {
	@ObservedObject var runtime: BeaconModelRuntime
	var onDownloadModel: (BeaconModel) -> Void = { _ in }
	@StateObject private var historyViewModel = ChatHistoryViewModel()
	@AppStorage("selectedModelID") private var selectedModelID = ""
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@State private var inputText = ""
	@State private var isShowingHistory = false
	@State private var isShowingModels = false
	@State private var isModelMarketplaceMounted = false
	@State private var isShowingModelSwitcher = false
	@State private var isShowingSettings = false
	@State private var shouldOpenMarketplaceAfterModelSwitcherDismisses = false

	private let screenSpring = Animation.spring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.12)

	private var selectedModel: BeaconModel {
		ModelCatalog.model(id: selectedModelID) ?? ModelCatalog.defaultModel
	}

	private var downloadedModels: [BeaconModel] {
		ModelCatalog.availableModels.filter(isDownloaded)
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
						showMarketplace()
					},
					onOpenSettings: {
						isShowingSettings = true
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

				if isModelMarketplaceMounted {
					ModelMarketPlaceView(
						models: ModelCatalog.availableModels,
						onClose: {
							hideMarketplace()
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
			}
			.animation(screenSpring, value: isShowingHistory)
			.animation(screenSpring, value: isShowingModels)
		}
		.background(Color(uiColor: .systemBackground))
		.sheet(isPresented: $isShowingModelSwitcher, onDismiss: openMarketplaceAfterModelSwitcherDismissesIfNeeded) {
			ChatModelSwitcherSheet(
				models: downloadedModels,
				selectedModelID: selectedModel.id,
				onSelect: { model in
					select(model)
				},
				onOpenMarketplace: {
					shouldOpenMarketplaceAfterModelSwitcherDismisses = true
					isShowingModelSwitcher = false
				}
			)
			.presentationDetents([.medium, .large])
			.presentationDragIndicator(.visible)
		}
		.sheet(isPresented: $isShowingSettings) {
			SettingsView(chatHistoryViewModel: historyViewModel)
		}
		.task(id: selectedModelID) {
			guard !runtime.isReady(for: selectedModel) else { return }
			await runtime.load(selectedModel)
		}
	}

	private var chatContent: some View {
		VStack(spacing: 0) {
			GeometryReader { proxy in
				ZStack {
					if historyViewModel.currentMessages.isEmpty {
						Image("beacon.logo")
							.resizable()
							.scaledToFit()
							.foregroundStyle(Color(uiColor: .systemGray6))
							.frame(width: 64, height: 64)
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.allowsHitTesting(false)
					}

					ScrollView {
						LazyVStack(alignment: .leading, spacing: 20) {
							ForEach(historyViewModel.currentMessages) { message in
								MessageBubble(
									text: message.text,
									role: message.role,
									isWaitingForResponse: runtime.isGenerating && message == historyViewModel.currentMessages.last
								)
							}
						}
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
						.padding(.horizontal, 18)
						.padding(.top, 24)
						.padding(.bottom, 18)
					}
					.frame(maxWidth: .infinity, minHeight: proxy.size.height)
					.scrollDismissesKeyboard(.interactively)
					.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
				}
				.safeAreaBar(edge: .top, spacing: 0) {
					HeaderView {
						dismissKeyboard()
						withAnimation(screenSpring) {
							isShowingHistory = true
						}
					} onNewChat: {
						historyViewModel.startNewChat()
						dismissKeyboard()
					}
				}
			}

			Input(text: $inputText, onOpenModels: {
				dismissKeyboard()
				isShowingModelSwitcher = true
			}) { text in
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

	private func select(_ model: BeaconModel) {
		selectedModelID = model.id
		isShowingModelSwitcher = false
	}

	private func showMarketplace() {
		isModelMarketplaceMounted = true

		Task { @MainActor in
			await Task.yield()
			withAnimation(screenSpring) {
				isShowingHistory = false
				isShowingModels = true
			}
		}
	}

	private func hideMarketplace() {
		withAnimation(screenSpring) {
			isShowingModels = false
			isShowingHistory = false
		}

		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(420))
			if !isShowingModels {
				isModelMarketplaceMounted = false
			}
		}
	}

	private func openMarketplaceAfterModelSwitcherDismissesIfNeeded() {
		guard shouldOpenMarketplaceAfterModelSwitcherDismisses else { return }
		shouldOpenMarketplaceAfterModelSwitcherDismisses = false

		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(180))
			showMarketplace()
		}
	}

	private func isDownloaded(_ model: BeaconModel) -> Bool {
		if model.isBuiltIn { return true }
		let ids = Set(downloadedModelIDs.split(separator: ",").map(String.init))
		return ids.contains(model.id) || FileManager.default.fileExists(atPath: cacheDirectory(for: model).path)
	}

	private func cacheDirectory(for model: BeaconModel) -> URL {
		FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("huggingface")
			.appendingPathComponent("hub")
			.appendingPathComponent("models--\(model.repositoryID.replacingOccurrences(of: "/", with: "--"))")
	}
}

private struct ChatModelSwitcherSheet: View {
	let models: [BeaconModel]
	let selectedModelID: String
	var onSelect: (BeaconModel) -> Void
	var onOpenMarketplace: () -> Void

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				List(models) { model in
					Button {
						onSelect(model)
					} label: {
						HStack(spacing: 14) {
							Text(model.name)
								.font(.system(size: 16, weight: .medium))
								.foregroundStyle(.primary)

							Spacer()

							if selectedModelID == model.id {
								Image(systemName: "checkmark.circle.fill")
									.font(.system(size: 20, weight: .semibold))
									.foregroundStyle(.primary)
							}
						}
						.padding(.vertical, 6)
					}
					.buttonStyle(.plain)
				}

				BeaconButton("Open Model Marketplace", variant: .secondary, leadingAssetIcon: "playground.icon", action: onOpenMarketplace)
					.padding(.horizontal, 18)
					.padding(.top, 12)
					.padding(.bottom, 16)
			}
			.navigationTitle("Switch Model")
			.navigationBarTitleDisplayMode(.inline)
		}
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
