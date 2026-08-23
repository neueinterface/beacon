import SwiftUI
import PhotosUI
import Photos
import UserNotifications
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct ChatView: View {
	@Environment(\.scenePhase) private var scenePhase
	@ObservedObject var runtime: BeaconModelRuntime
	let models: [BeaconModel]
	@ObservedObject var notificationRouter = NotificationRouter()
	var onDownloadModel: (BeaconModel) -> Void = { _ in }
	@StateObject private var historyViewModel = ChatHistoryViewModel()
	@AppStorage("selectedModelID") private var selectedModelID = ""
	@AppStorage("downloadedModelIDs") private var downloadedModelIDs = ""
	@AppStorage("notificationsEnabled") private var notificationsEnabled = false
	#if false // Web search is not currently available.
	// Web search is not part of the current release.
	private let webSearchEnabled = false
	#endif
	@State private var inputText = ""
	@State private var selectedImageItem: PhotosPickerItem?
	@State private var attachedImageData: Data?
	@State private var isShowingPhotoPicker = false
	@State private var isShowingPhotoAccessAlert = false
	#if false // Web search is not currently available.
	@State private var isWebSearchTagged = false
	#endif
	@State private var isShowingHistory = false
	@State private var isShowingModelMarketplace = false
	@State private var isShowingModelSwitcher = false
	@State private var isShowingSettings = false
	@State private var isShowingAppIconPicker = false
	@State private var shouldOpenMarketplaceAfterModelSwitcherDismisses = false
	@State private var pendingScrollMessageID: ChatMessage.ID?
	@State private var responseTask: Task<Void, Never>?
	@State private var isPreparingResponse = false
	@State private var switchedModelName: String?
	@State private var modelSwitchToastTask: Task<Void, Never>?
	#if false // Web search is not currently available.
	@State private var backendStatus: BackendStatus?
	@State private var searchQuota: SearchQuota?
	@State private var isBackendUnavailable = false
	@State private var isWebSearchDisabledByBackend = false
	@State private var lastWebSearchStatus = ""
	#endif
	#if false // Web search source links are not currently available.
	@StateObject private var safariViewModel = SafariViewModel()
	#endif
	#if false // Web search is not currently available.
	private let backendStatusService = BackendStatusService()
	private let webSearchService = WebSearchService()
	#endif
	private let responseHaptics = StreamingResponseHaptics()

	private let screenSpring = Animation.spring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.12)

	private var selectedModel: BeaconModel {
		ModelCatalog.model(id: selectedModelID, in: models) ?? ModelCatalog.defaultModel(in: models)
	}

	private var downloadedModels: [BeaconModel] {
		models.filter(isDownloaded)
	}

	private var isAssistantBusy: Bool {
		isPreparingResponse || runtime.isGenerating || responseTask != nil
	}

	#if false // Web search is not currently available.
	private var isWebSearchUnavailable: Bool {
		!webSearchEnabled || isBackendUnavailable || isWebSearchDisabledByBackend || backendStatus?.allowsWebSearch == false || searchQuota?.isExhausted == true
	}

	private var webSearchUnavailableTitle: String {
		if !webSearchEnabled {
			return "Web search is off"
		}

		if let searchQuota, searchQuota.isExhausted {
			return "Resets at \(searchQuota.resetAt.formatted(date: .omitted, time: .shortened))"
		}

		if isBackendUnavailable || backendStatus?.ok == false {
			return "Backend unavailable"
		}

		if isWebSearchDisabledByBackend || backendStatus?.features.webSearch == false {
			return "Web search disabled"
		}

		return "Daily limit reached"
	}

	private var webSearchPillTitle: String {
		guard let searchQuota, !searchQuota.isExhausted else { return "Search Web" }
		return "Search Web (\(searchQuota.remaining) left)"
	}
	#endif

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
			SettingsView(chatHistoryViewModel: historyViewModel, models: models, onDownloadModel: onDownloadModel)
		}
		.sheet(isPresented: $isShowingAppIconPicker) {
			NavigationStack {
				AppIconPickerView()
			}
		}
		.alert("Photo Access Needed", isPresented: $isShowingPhotoAccessAlert) {
			Button("OK") { }
		} message: {
			Text("Allow photo access in Settings to attach an image to your message.")
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
		#if false // Web search source links are not currently available.
		.sheet(item: $safariViewModel.page) { page in
			SafariView(url: page.url)
		}
		#endif
		.task(id: selectedModelID) {
			await ensureSelectedModelLoaded()
		}
		#if false // Web search is not currently available.
		.task {
			guard webSearchEnabled else { return }
			await refreshBackendStatus()
			await refreshSearchQuota()
		}
		.onChange(of: scenePhase) { _, phase in
			switch phase {
			case .active:
				Task {
					await ensureSelectedModelLoaded()
					guard webSearchEnabled else { return }
					await refreshBackendStatus()
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
		.onAppear {
			if let action = notificationRouter.quickActionToOpen {
				handleQuickAction(action)
			}
		}
		.onChange(of: notificationRouter.chatIDToOpen) { _, chatID in
			guard let chatID else { return }
			openChatFromNotification(chatID)
		}
		.onChange(of: notificationRouter.quickActionToOpen) { _, action in
			guard let action else { return }
			handleQuickAction(action)
		}
		.onChange(of: webSearchEnabled) { _, isEnabled in
			if !isEnabled {
				withAnimation(.smooth(duration: 0.2)) {
					isWebSearchTagged = false
				}
				return
			}

			Task {
				await refreshBackendStatus()
				await refreshSearchQuota()
			}
		}
		#endif
	}

	private var chatContent: some View {
		NavigationStack {
			ZStack {
				if historyViewModel.currentMessages.isEmpty {
					Image("beacon.logo")
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
												imageData: message.imageData,
												thinkingText: message.thinkingText,
												requiresVisionModel: message.requiresVisionModel,
												onDownloadVisionModel: downloadVisionModel,
												role: message.role,
												isWaitingForResponse: isAssistantBusy && message == historyViewModel.currentMessages.last
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
						Image("switch.icon")
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
			Image("switch.icon")
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
		VStack(alignment: .leading, spacing: 8) {
			Input(
				text: $inputText,
				placeholder: "Message",
				isGenerating: isAssistantBusy,
				hasAttachment: attachedImageData != nil,
				attachmentData: attachedImageData,
				onAttachImage: {
					requestPhotoAccess()
				},
				canAttachImages: selectedModel.supportsImages,
				onRemoveAttachment: {
					attachedImageData = nil
				},
				onStop: {
					stopGenerating()
				},
				onSend: { text in
					send(text, imageData: attachedImageData)
					attachedImageData = nil
				}
			)
			.photosPicker(
				isPresented: $isShowingPhotoPicker,
				selection: $selectedImageItem,
				matching: .images,
				preferredItemEncoding: .current
			)
		}
		.task(id: selectedImageItem) {
			guard let selectedImageItem,
				  let data = try? await selectedImageItem.loadTransferable(type: Data.self) else { return }
			attachedImageData = await Task.detached(priority: .userInitiated) {
				Self.normalizedImageData(from: data)
			}.value
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

	private func send(_ text: String, imageData: Data? = nil) {
		pendingScrollMessageID = nil
		dismissKeyboard()
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		#endif
		let displayText = text
		let responseModel = imageData == nil ? selectedModel : visionModel ?? selectedModel
		let conversationHistory = historyViewModel.currentMessages

		let responseID = historyViewModel.appendUserMessage(displayText, imageData: imageData, modelName: responseModel.name)
		if imageData != nil {
			guard let visionModel, isDownloaded(visionModel) else {
				historyViewModel.replaceMessage(responseID, with: "To read images, download the on-device vision model.")
				historyViewModel.requireVisionModel(for: responseID)
				return
			}
		}

		scheduleChatReminder(for: displayText)
		responseHaptics.start()
		isPreparingResponse = true

		responseTask = Task {
			do {
				await ensureModelLoaded(responseModel)
				let prompt: String
				if imageData != nil {
					let question = displayText.isEmpty ? "Describe this image." : displayText
					prompt = "Analyze the attached image and answer the user's question using what you can see. User question: \(question)"
				} else {
					prompt = displayText
				}

				isPreparingResponse = false
				try await runtime.streamResponse(to: prompt, imageData: imageData, conversationHistory: conversationHistory, onThinking: { chunk in
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
				isPreparingResponse = false
				historyViewModel.replaceMessage(responseID, with: error.localizedDescription)
			}

			isPreparingResponse = false
			responseHaptics.stop()
			responseTask = nil
		}
	}

	private func requestPhotoAccess() {
		PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
			Task { @MainActor in
				switch status {
				case .authorized, .limited:
					isShowingPhotoPicker = true
				default:
					isShowingPhotoAccessAlert = true
				}
			}
		}
	}

	nonisolated private static func normalizedImageData(from data: Data) -> Data {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return data }
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceThumbnailMaxPixelSize: 1_024,
			kCGImageSourceShouldCacheImmediately: true
		]
		guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return data }

		let output = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return data }
		CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
		guard CGImageDestinationFinalize(destination) else { return data }
		return output as Data
	}

	private func stopGenerating() {
		responseTask?.cancel()
		responseTask = nil
		isPreparingResponse = false
		responseHaptics.stop()
	}

	private var visionModel: BeaconModel? {
		models.first(where: \.supportsImages)
	}

	private func downloadVisionModel() {
		guard let visionModel else { return }
		onDownloadModel(visionModel)
	}

	private func ensureSelectedModelLoaded() async {
		await ensureModelLoaded(selectedModel)
	}

	private func ensureModelLoaded(_ model: BeaconModel) async {
		guard !runtime.isReady(for: model) else { return }

		await runtime.load(model)
	}

	private func scrollToPendingMessage(using scrollProxy: ScrollViewProxy) {
		guard let pendingScrollMessageID else { return }

		Task { @MainActor in
			guard historyViewModel.currentMessages.contains(where: { $0.id == pendingScrollMessageID }) else { return }
			scrollProxy.scrollTo(pendingScrollMessageID, anchor: .top)
			self.pendingScrollMessageID = nil
		}
	}

	#if false // Web search is not currently available.
	private func promptWithWebResultsIfNeeded(for text: String, forceWebSearch: Bool = false, responseID: ChatMessage.ID) async throws -> String {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		let lowercased = trimmed.lowercased()
		let explicitlyRequestedWebSearch = forceWebSearch || lowercased == "/web" || lowercased.hasPrefix("/web ")

		if lowercased == "/noweb" {
			return "Ask the user what they want to answer without web search."
		}

		if lowercased.hasPrefix("/noweb ") {
			return String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
		}

		guard webSearchEnabled else { return text }

		guard let query = webSearchQuery(for: text, forceWebSearch: forceWebSearch) else { return text }
		guard !query.isEmpty else { return "Ask the user what they want to search for." }
		if isBackendUnavailable || backendStatus?.ok == false {
			return text
		}

		if isWebSearchDisabledByBackend || backendStatus?.features.webSearch == false {
			return text
		}

		if let searchQuota, searchQuota.isExhausted {
			return text
		}

		historyViewModel.appendAssistantThinking("\(nextWebSearchStatus())\n", to: responseID)
		let response: WebSearchResponse
		do {
			response = try await webSearchService.search(String(query), chatID: historyViewModel.currentChatID)
		} catch let error as WebSearchService.WebSearchError {
			handleWebSearchError(error)
			if explicitlyRequestedWebSearch {
				throw error
			}
			historyViewModel.appendAssistantThinking("Thinking\n", to: responseID)
			return text
		}

		if let quota = response.quota {
			updateSearchQuota(quota)
		} else {
			await refreshSearchQuota()
		}
		historyViewModel.replaceAssistantSources(response.results.map(Source.init), for: responseID)

		let context = response.results.enumerated().map { index, result in
			"""
			[\(index + 1)] \(result.title)
			URL: \(result.url.absoluteString)
			Summary: \(result.description)
			"""
		}.joined(separator: "\n\n")

		return """
		Answer the user's question using the web search results below.

		Formatting:
		- Do not start with labels like "Answer:", "Response:", or "Summary:".
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
		let availableStatuses = statuses.filter { $0 != lastWebSearchStatus }
		let status = (availableStatuses.randomElement() ?? statuses.randomElement()) ?? "Searching the web"
		lastWebSearchStatus = status
		return status
	}

	private func refreshSearchQuota() async {
		guard webSearchEnabled else { return }

		do {
			let quota = try await webSearchService.quota(chatID: historyViewModel.currentChatID)
			isWebSearchDisabledByBackend = false
			updateSearchQuota(quota)
		} catch let error as WebSearchService.WebSearchError {
			handleWebSearchError(error)
		} catch {
			return
		}
	}

	private func refreshBackendStatus() async {
		guard webSearchEnabled else { return }

		guard let status = try? await backendStatusService.status() else { return }
		withAnimation(.smooth(duration: 0.2)) {
			backendStatus = status
			isBackendUnavailable = !status.ok || !status.features.backend
			isWebSearchDisabledByBackend = !status.allowsWebSearch
			if !status.allowsWebSearch {
				isWebSearchTagged = false
			}
		}
	}

	private func handleWebSearchError(_ error: WebSearchService.WebSearchError) {
		switch error {
		case let .dailyLimitExceeded(quota):
			updateSearchQuota(quota)
		case .webSearchDisabled:
			withAnimation(.smooth(duration: 0.2)) {
				isWebSearchDisabledByBackend = true
				isWebSearchTagged = false
			}
		case .backendDisabled:
			withAnimation(.smooth(duration: 0.2)) {
				isBackendUnavailable = true
				isWebSearchTagged = false
			}
		default:
			break
		}
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
	#endif

	#if false // Web search quota notifications are not currently available.
	private var searchResetNotificationID: String {
		"web-search-quota-reset"
	}
	#endif

	private func chatReminderNotificationID(for chatID: ChatConversation.ID) -> String {
		"chat-reminder-\(chatID.uuidString)"
	}

	private func scheduleChatReminder(for message: String) {
		guard notificationsEnabled, let chatID = historyViewModel.currentChatID else { return }
		let snippet = message.notificationSnippet(maxLength: 120)
		guard !snippet.isEmpty else { return }

		UNUserNotificationCenter.current().getNotificationSettings { settings in
			guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

			let content = UNMutableNotificationContent()
			content.title = "Don't forget chatting"
			content.body = "\"\(snippet)\""
			content.sound = .default
			content.userInfo = [
				"type": "chatReminder",
				"chatId": chatID.uuidString
			]

			let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
			let identifier = chatReminderNotificationID(for: chatID)
			let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

			UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
			UNUserNotificationCenter.current().add(request)
		}
	}

	private func openChatFromNotification(_ chatID: ChatConversation.ID) {
		guard let chat = historyViewModel.selectChat(id: chatID) else {
			notificationRouter.consumeChatOpenRequest()
			return
		}

		isShowingHistory = false
		isShowingSettings = false
		isShowingModelMarketplace = false
		pendingScrollMessageID = historyViewModel.lastUserMessageID(in: chat) ?? historyViewModel.firstMessageID(in: chat)
		UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [chatReminderNotificationID(for: chatID)])
		notificationRouter.consumeChatOpenRequest()
	}

	private func handleQuickAction(_ action: HomeScreenQuickAction) {
		dismissKeyboard()

		switch action {
		case .newChat:
			isShowingHistory = false
			isShowingSettings = false
			isShowingAppIconPicker = false
			isShowingModelMarketplace = false
			historyViewModel.startNewChat()
		case .changeAppIcon:
			isShowingHistory = false
			isShowingSettings = false
			isShowingModelMarketplace = false
			isShowingAppIconPicker = true
		case .seeModels:
			isShowingHistory = false
			isShowingSettings = false
			isShowingAppIconPicker = false
			isShowingModelMarketplace = true
		}

		notificationRouter.consumeQuickActionRequest()
	}

	#if false // Web search is not currently available.
	private func scheduleSearchResetNotification(at resetAt: Date) {
		guard resetAt > Date() else { return }
		guard notificationsEnabled else { return }

		UNUserNotificationCenter.current().getNotificationSettings { settings in
			guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

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
	#endif

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
							Text(model.supportsImages ? "\(model.name) (Image)" : model.name)
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

private extension String {
	func notificationSnippet(maxLength: Int) -> String {
		let normalized = split(whereSeparator: \.isNewline)
			.joined(separator: " ")
			.replacingOccurrences(of: "  ", with: " ")
			.trimmingCharacters(in: .whitespacesAndNewlines)

		guard normalized.count > maxLength else { return normalized }
		return String(normalized.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
	}
}

#Preview {
	ChatView(runtime: BeaconModelRuntime(), models: ModelCatalog.availableModels)
}
