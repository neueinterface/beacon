import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct ChatView: View {
	@Environment(\.scenePhase) private var scenePhase
	@ObservedObject var runtime: BeaconModelRuntime
	let models: [BeaconModel]
	var onDownloadModel: (BeaconModel) -> Void = { _ in }
	@StateObject private var historyViewModel = ChatHistoryViewModel()
	@AppStorage("selectedModelID") private var selectedModelID = ""
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@State private var inputText = ""
	@State private var isWebSearchTagged = false
	@State private var isShowingHistory = false
	@State private var isShowingModelMarketplace = false
	@State private var isShowingModelSwitcher = false
	@State private var isShowingSettings = false
	@State private var shouldOpenMarketplaceAfterModelSwitcherDismisses = false
	@State private var pendingScrollMessageID: ChatMessage.ID?
	@State private var responseTask: Task<Void, Never>?
	@State private var switchedModelName: String?
	@State private var modelSwitchToastTask: Task<Void, Never>?
	@State private var searchQuota: SearchQuota?
	@State private var webSearchStatusIndex = 0
	@StateObject private var safariViewModel = SafariViewModel()
	private let webSearchService = WebSearchService()
	private let responseHaptics = StreamingResponseHaptics()

	private let screenSpring = Animation.spring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.12)

	private var selectedModel: BeaconModel {
		ModelCatalog.model(id: selectedModelID, in: models) ?? ModelCatalog.defaultModel(in: models)
	}

	private var downloadedModels: [BeaconModel] {
		models.filter(isDownloaded)
	}

	private var isWebSearchUnavailable: Bool {
		searchQuota?.isExhausted == true
	}

	var body: some View {
		GeometryReader { geometry in
			ZStack(alignment: .leading) {
				chatContent
					.scaleEffect(isShowingHistory ? 0.98 : 1, anchor: .top)
					.opacity(isShowingHistory ? 0.76 : 1)
					.zIndex(0)

				if isShowingHistory {
					ChatHistoryDrawerView(
						viewModel: historyViewModel,
						onClose: {
							withAnimation(screenSpring) {
								isShowingHistory = false
							}
						},
						onNewChat: {
							historyViewModel.startNewChat()
							withAnimation(screenSpring) {
								isShowingHistory = false
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
						}
					}
					.frame(width: geometry.size.width)
					.frame(maxHeight: .infinity)
					.transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
					.zIndex(2)
				}
			}
			.animation(screenSpring, value: isShowingHistory)
		}
		.background(Color(uiColor: .systemBackground))
		.overlay(alignment: .bottom) {
			if let switchedModelName {
				ModelSwitchToast(modelName: switchedModelName)
					.padding(.bottom, 104)
					.transition(.opacity.combined(with: .scale(scale: 0.96)))
			}
		}
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
		#if os(macOS)
		.sheet(isPresented: $isShowingModelMarketplace) {
			ModelMarketPlaceView(
				models: models,
				onClose: {
					hideMarketplace()
				},
				onDownload: { model in
					onDownloadModel(model)
				}
			)
		}
		#else
		.fullScreenCover(isPresented: $isShowingModelMarketplace) {
			ModelMarketPlaceView(
				models: models,
				onClose: {
					hideMarketplace()
				},
				onDownload: { model in
					onDownloadModel(model)
				}
			)
		}
		#endif
		.sheet(item: $safariViewModel.page) { page in
			SafariView(url: page.url)
		}
		.task(id: selectedModelID) {
			await ensureSelectedModelLoaded()
		}
		.task {
			await refreshSearchQuota()
		}
		.onChange(of: scenePhase) { _, phase in
			switch phase {
			case .active:
				Task {
					await ensureSelectedModelLoaded()
					await refreshSearchQuota()
				}
			case .background:
				_ = runtime.unloadIfIdle()
			default:
				break
			}
		}
		.onDisappear {
			modelSwitchToastTask?.cancel()
		}
	}

	private var chatContent: some View {
		NavigationStack {
			ZStack {
				if historyViewModel.currentMessages.isEmpty {
					Image("semera.logo")
						.resizable()
						.scaledToFit()
						.foregroundStyle(Color(uiColor: .systemGray6))
						.frame(width: 64, height: 64)
						.allowsHitTesting(false)
				}

				VStack(spacing: 0) {
					GeometryReader { proxy in
						ZStack {
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
					}

					inputBar
				}
			}
			.background(Color(uiColor: .systemBackground))
			.simultaneousGesture(
				DragGesture(minimumDistance: 16)
					.onEnded { value in
						guard value.translation.height > 28 else { return }
						dismissKeyboard()
					}
			)
			.navigationTitle("")
			#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
			.toolbarRole(.navigationStack)
			.toolbarVisibility(.visible, for: .navigationBar)
			#endif
			.toolbar {
				#if os(macOS)
				ToolbarItemGroup(placement: .automatic) {
					chatToolbarButtons
				}
				#else
				ToolbarItemGroup(placement: .topBarLeading) {
					Button {
						playHeaderHaptic()
						dismissKeyboard()
						withAnimation(screenSpring) {
							isShowingHistory = true
						}
					} label: {
						Image("menu.icon")
							.renderingMode(.template)
					}
					.accessibilityLabel("Open chat history")

					Button {
						playHeaderHaptic()
						dismissKeyboard()
						isShowingModelSwitcher = true
					} label: {
						Image("playground.icon")
							.renderingMode(.template)
					}
					.accessibilityLabel("Switch model")
				}

				ToolbarItem(placement: .topBarTrailing) {
					Button {
						playHeaderHaptic()
						historyViewModel.startNewChat()
						dismissKeyboard()
					} label: {
						Image("chat.icon")
							.renderingMode(.template)
					}
					.accessibilityLabel("New chat")
				}
				#endif
			}
		}
	}

	#if os(macOS)
	@ViewBuilder
	private var chatToolbarButtons: some View {
		Button {
			dismissKeyboard()
			withAnimation(screenSpring) {
				isShowingHistory = true
			}
		} label: {
			Image("menu.icon")
				.renderingMode(.template)
		}
		.accessibilityLabel("Open chat history")

		Button {
			dismissKeyboard()
			isShowingModelSwitcher = true
		} label: {
			Image("playground.icon")
				.renderingMode(.template)
		}
		.accessibilityLabel("Switch model")

		Button {
			historyViewModel.startNewChat()
			dismissKeyboard()
		} label: {
			Image("chat.icon")
				.renderingMode(.template)
		}
		.accessibilityLabel("New chat")
	}
	#endif

	private var inputBar: some View {
		Input(text: $inputText, isWebSearchTagged: $isWebSearchTagged, isGenerating: runtime.isGenerating, isWebSearchUnavailable: isWebSearchUnavailable) {
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
		let usesTaggedWebSearch = isWebSearchTagged || text.localizedCaseInsensitiveContains("@web")
		let displayText = text.removingWebTagTrigger()
		isWebSearchTagged = false

		let responseID = historyViewModel.appendUserMessage(displayText, modelName: selectedModel.name)
		responseHaptics.start()

		responseTask = Task {
			do {
				await ensureSelectedModelLoaded()
				let prompt = try await promptWithWebResultsIfNeeded(for: displayText, forceWebSearch: usesTaggedWebSearch, responseID: responseID)

				try await runtime.streamResponse(to: prompt, onThinking: { chunk in
					historyViewModel.appendAssistantThinking(chunk, to: responseID)
				}) { chunk in
					historyViewModel.appendAssistantChunk(chunk, to: responseID)
					responseHaptics.tick(for: chunk)
				}

				responseHaptics.finish()
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

	private func ensureSelectedModelLoaded() async {
		guard !runtime.isReady(for: selectedModel) else { return }

		await runtime.load(selectedModel)
	}

	private func scrollToPendingMessage(using scrollProxy: ScrollViewProxy) {
		guard let pendingScrollMessageID else { return }

		Task { @MainActor in
			guard historyViewModel.currentMessages.contains(where: { $0.id == pendingScrollMessageID }) else { return }
			scrollProxy.scrollTo(pendingScrollMessageID, anchor: .top)
			self.pendingScrollMessageID = nil
		}
	}

	private func promptWithWebResultsIfNeeded(for text: String, forceWebSearch: Bool = false, responseID: ChatMessage.ID) async throws -> String {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		let lowercased = trimmed.lowercased()

		if lowercased == "/noweb" {
			return "Ask the user what they want to answer without web search."
		}

		if lowercased.hasPrefix("/noweb ") {
			return String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
		}

		guard let query = webSearchQuery(for: text, forceWebSearch: forceWebSearch) else { return text }
		guard !query.isEmpty else { return "Ask the user what they want to search for." }
		if let searchQuota, searchQuota.isExhausted {
			throw WebSearchService.WebSearchError.dailyLimitExceeded(searchQuota)
		}

		historyViewModel.appendAssistantThinking("\(nextWebSearchStatus())\n", to: responseID)
		let results: [WebSearchResult]
		do {
			results = try await webSearchService.search(String(query), chatID: historyViewModel.currentChatID)
		} catch let error as WebSearchService.WebSearchError {
			if case let .dailyLimitExceeded(quota) = error {
				updateSearchQuota(quota)
			}
			throw error
		}

		await refreshSearchQuota()
		historyViewModel.replaceAssistantSources(results.map(Source.init), for: responseID)

		let context = results.enumerated().map { index, result in
			"""
			[\(index + 1)] \(result.title)
			URL: \(result.url.absoluteString)
			Summary: \(result.description)
			"""
		}.joined(separator: "\n\n")

		return """
		Answer the user's question using the web search results below.

		Formatting:
		- Do not write one long paragraph.
		- Use short paragraphs, bullets, or numbered steps when helpful.
		- Start with the direct answer.
		- Keep the answer concise unless the user asks for detail.

		Do not include source URLs, markdown links, citations, footnotes, or a sources/references section in the answer text. The app shows sources separately in a dropdown. If the results are not enough, say what is missing.

		Question: \(query)

		Web search results:
		\(context)
		"""
	}

	private func webSearchQuery(for text: String, forceWebSearch: Bool = false) -> String? {
		let trimmed = text.removingWebTagTrigger().trimmingCharacters(in: .whitespacesAndNewlines)
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

		if forceWebSearch {
			return trimmed
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

	private func nextWebSearchStatus() -> String {
		let statuses = ["Searching the interwebs", "Searching the web", "Web surfing"]
		let status = statuses[webSearchStatusIndex % statuses.count]
		webSearchStatusIndex += 1
		return status
	}

	private func refreshSearchQuota() async {
		guard let quota = try? await webSearchService.quota() else { return }
		updateSearchQuota(quota)
	}

	private func updateSearchQuota(_ quota: SearchQuota) {
		withAnimation(.smooth(duration: 0.2)) {
			searchQuota = quota
			if quota.isExhausted {
				isWebSearchTagged = false
			}
		}

		if quota.isExhausted {
			scheduleSearchResetNotification(at: quota.resetAt)
		} else {
			UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [searchResetNotificationID])
		}
	}

	private var searchResetNotificationID: String {
		"web-search-quota-reset"
	}

	private func scheduleSearchResetNotification(at resetAt: Date) {
		guard resetAt > Date() else { return }

		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
			guard granted else { return }

			let content = UNMutableNotificationContent()
			content.title = "Web search is available again"
			content.body = "Your daily web search limit has reset."
			content.sound = .default

			let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: resetAt)
			let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
			let request = UNNotificationRequest(identifier: searchResetNotificationID, content: content, trigger: trigger)

			UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [searchResetNotificationID])
			UNUserNotificationCenter.current().add(request)
		}
	}

	private func dismissKeyboard() {
		#if canImport(UIKit)
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
		#endif
	}

	private func playHeaderHaptic() {
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		#endif
	}

	private func select(_ model: BeaconModel) {
		let didChange = selectedModelID != model.id
		selectedModelID = model.id
		isShowingModelSwitcher = false

		if didChange {
			showModelSwitchToast(for: model.name)
		}
	}

	private func showModelSwitchToast(for modelName: String) {
		modelSwitchToastTask?.cancel()
		withAnimation(.smooth(duration: 0.2)) {
			switchedModelName = modelName
		}

		modelSwitchToastTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(1.8))
			withAnimation(.smooth(duration: 0.2)) {
				switchedModelName = nil
			}
		}
	}

	private func showMarketplace() {
		withAnimation(screenSpring) {
			isShowingHistory = false
		}

		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(120))
			isShowingModelMarketplace = true
		}
	}

	private func hideMarketplace() {
		isShowingModelMarketplace = false
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
			.toolbarVisibility(.visible, for: .navigationBar)
			#endif
		}
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

	func finish() {
		pendingText = ""
		#if canImport(UIKit)
		UINotificationFeedbackGenerator().notificationOccurred(.success)
		#endif
	}

	func stop() {
		pendingText = ""
	}
}

#Preview {
	ChatView(runtime: BeaconModelRuntime(), models: ModelCatalog.availableModels)
}
