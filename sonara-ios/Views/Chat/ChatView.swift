import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
	@State private var pendingScrollMessageID: ChatMessage.ID?
	@State private var responseTask: Task<Void, Never>?
	@StateObject private var safariViewModel = SafariViewModel()
	private let webSearchService = WebSearchService()
	private let responseHaptics = StreamingResponseHaptics()

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
				) { chat in
					pendingScrollMessageID = historyViewModel.lastUserMessageID(in: chat) ?? historyViewModel.firstMessageID(in: chat)
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
					.opacity(isShowingModels ? 1 : 0)
					.scaleEffect(isShowingModels ? 1 : 0.985)
					.animation(.easeOut(duration: 0.22), value: isShowingModels)
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
		.sheet(item: $safariViewModel.page) { page in
			SafariView(url: page.url)
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
						Image("sonara.logo")
							.resizable()
							.scaledToFit()
							.foregroundStyle(Color(uiColor: .systemGray6))
							.frame(width: 64, height: 64)
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.allowsHitTesting(false)
					}

					ScrollViewReader { scrollProxy in
						ScrollView {
							LazyVStack(alignment: .leading, spacing: 20) {
								ForEach(historyViewModel.currentMessages) { message in
									MessageBubble(
										text: message.text,
										thinkingText: message.thinkingText,
										sources: message.sources,
										role: message.role,
										isWaitingForResponse: runtime.isGenerating && message == historyViewModel.currentMessages.last,
										onOpenSource: { url in
											safariViewModel.open(url)
										}
									)
									.id(message.id)
								}
							}
							.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
							.padding(.horizontal, 18)
							.padding(.top, 24)
							.padding(.bottom, 96)
						}
						.frame(maxWidth: .infinity, minHeight: proxy.size.height)
						.scrollDismissesKeyboard(.interactively)
						.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
						.onChange(of: historyViewModel.currentMessages) { _ in
							scrollToPendingMessage(using: scrollProxy)
						}
						.onChange(of: pendingScrollMessageID) { _ in
							scrollToPendingMessage(using: scrollProxy)
						}
					}
				}
				.safeAreaBar(edge: .top, spacing: 0) {
					HeaderView {
						dismissKeyboard()
						withAnimation(screenSpring) {
							isShowingHistory = true
						}
					} onOpenModels: {
						dismissKeyboard()
						isShowingModelSwitcher = true
					} onNewChat: {
						historyViewModel.startNewChat()
						dismissKeyboard()
					}
				}
			}

			inputBar
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

	private var inputBar: some View {
		Input(text: $inputText, isGenerating: runtime.isGenerating) {
			stopGenerating()
		} onSend: { text in
			send(text)
		}
		.disabled(runtime.isLoading)
		.opacity(runtime.isLoading ? 0.5 : 1)
		.padding(.horizontal, 14)
		.padding(.vertical, 12)
		.background(alignment: .top) {
			LinearGradient(
				colors: [
					Color(uiColor: .systemBackground).opacity(0),
					Color(uiColor: .systemBackground)
				],
				startPoint: .top,
				endPoint: .bottom
			)
			.frame(height: 28)
			.offset(y: -28)
			.allowsHitTesting(false)
		}
		.background(Color(uiColor: .systemBackground))
	}

	private func send(_ text: String) {
		pendingScrollMessageID = nil
		dismissKeyboard()
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		#endif
		let responseID = historyViewModel.appendUserMessage(text, modelName: selectedModel.name)
		responseHaptics.start()

		responseTask = Task {
			do {
				let prompt = try await promptWithWebResultsIfNeeded(for: text, responseID: responseID)

				try await runtime.streamResponse(to: prompt, onThinking: { chunk in
					historyViewModel.appendAssistantThinking(chunk, to: responseID)
				}) { chunk in
					historyViewModel.appendAssistantChunk(chunk, to: responseID)
					responseHaptics.tick(for: chunk)
				}
			} catch is CancellationError {
				if historyViewModel.currentMessages.first(where: { $0.id == responseID })?.text.isEmpty == true {
					historyViewModel.replaceMessage(responseID, with: "Stopped.")
				}
			} catch {
				historyViewModel.replaceMessage(responseID, with: error.localizedDescription)
			}

			responseHaptics.stop()
			responseTask = nil
		}
	}

	private func stopGenerating() {
		responseTask?.cancel()
		responseTask = nil
		responseHaptics.stop()
	}

	private func scrollToPendingMessage(using scrollProxy: ScrollViewProxy) {
		guard let pendingScrollMessageID else { return }

		Task { @MainActor in
			guard historyViewModel.currentMessages.contains(where: { $0.id == pendingScrollMessageID }) else { return }
			scrollProxy.scrollTo(pendingScrollMessageID, anchor: .top)
			self.pendingScrollMessageID = nil
		}
	}

	private func promptWithWebResultsIfNeeded(for text: String, responseID: ChatMessage.ID) async throws -> String {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		let lowercased = trimmed.lowercased()

		if lowercased == "/noweb" {
			return "Ask the user what they want to answer without web search."
		}

		if lowercased.hasPrefix("/noweb ") {
			return String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
		}

		guard let query = webSearchQuery(for: text) else { return text }
		guard !query.isEmpty else { return "Ask the user what they want to search for." }

		historyViewModel.appendAssistantThinking("Searching the web for: \(query)\n", to: responseID)
		let results = try await webSearchService.search(String(query))
		historyViewModel.replaceAssistantSources(results.map(Source.init), for: responseID)
		historyViewModel.appendAssistantThinking("Found \(results.count) web result\(results.count == 1 ? "" : "s").\n", to: responseID)

		let context = results.enumerated().map { index, result in
			"""
			[\(index + 1)] \(result.title)
			URL: \(result.url.absoluteString)
			Summary: \(result.description)
			"""
		}.joined(separator: "\n\n")

		return """
		Answer the user's question using the web search results below. Cite sources by number when using them. If the results are not enough, say what is missing.

		Question: \(query)

		Web search results:
		\(context)
		"""
	}

	private func webSearchQuery(for text: String) -> String? {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		let lowercased = trimmed.lowercased()

		if lowercased == "/noweb" {
			return nil
		}

		if lowercased.hasPrefix("/noweb ") {
			return nil
		}

		if lowercased == "/web" {
			return ""
		}

		if lowercased.hasPrefix("/web ") {
			return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
		}

		guard shouldUseWebSearch(for: lowercased) else { return nil }
		return trimmed
	}

	private func shouldUseWebSearch(for lowercasedText: String) -> Bool {
		let currentSignals = [
			"latest", "current", "today", "right now", "this week", "this month", "this year",
			"news", "breaking", "recent", "newest", "updated", "price", "stock", "weather",
			"score", "schedule", "release date", "available now", "who won", "what happened"
		]

		if currentSignals.contains(where: lowercasedText.contains) {
			return true
		}

		let searchPhrases = [
			"search the web", "look up", "google", "find sources", "find articles", "cite sources"
		]

		if searchPhrases.contains(where: lowercasedText.contains) {
			return true
		}

		return lowercasedText.contains("2026")
	}

	private func dismissKeyboard() {
		#if canImport(UIKit)
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
		#endif
	}

	private func select(_ model: BeaconModel) {
		selectedModelID = model.id
		isShowingModelSwitcher = false
	}

	private func showMarketplace() {
		var transaction = Transaction()
		transaction.disablesAnimations = true
		withTransaction(transaction) {
			isModelMarketplaceMounted = true
		}

		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(40))
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
		return ids.contains(model.id)
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
			#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
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

@MainActor
private final class StreamingResponseHaptics {
	#if canImport(UIKit)
	private let generator = UIImpactFeedbackGenerator(style: .light)
	#endif
	private var lastImpactTime = Date.distantPast
	private var pendingText = ""

	func start() {
		pendingText = ""
		lastImpactTime = .distantPast
		#if canImport(UIKit)
		generator.prepare()
		#endif
	}

	func tick(for chunk: String) {
		pendingText += chunk

		let now = Date()
		let hasTextBoundary = pendingText.contains("\n") || pendingText.count >= 40
		guard hasTextBoundary, now.timeIntervalSince(lastImpactTime) >= 0.45 else { return }

		#if canImport(UIKit)
		generator.impactOccurred(intensity: 0.18)
		generator.prepare()
		#endif
		lastImpactTime = now
		pendingText = ""
	}

	func stop() {
		pendingText = ""
	}
}

#Preview {
	ChatView(runtime: BeaconModelRuntime())
}
