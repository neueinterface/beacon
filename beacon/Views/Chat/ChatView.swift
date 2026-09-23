import SwiftUI
import PhotosUI
import Photos
import UserNotifications
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

private struct FailedResponse {
	let responseID: ChatMessage.ID
	let text: String
	let imageDatas: [Data]
	let model: BeaconModel
	let conversationHistory: [ChatMessage]
	let forceWebSearch: Bool
}

struct ResponseAttemptTracker {
	private(set) var activeID: UUID?

	mutating func begin() -> UUID {
		let id = UUID()
		activeID = id
		return id
	}

	func owns(_ id: UUID) -> Bool {
		activeID == id
	}

	mutating func finish(_ id: UUID) -> Bool {
		guard owns(id) else { return false }
		activeID = nil
		return true
	}
}

enum ResponseRetryPolicy {
	static func shouldForceWebSearch(wasForced: Bool, usedWebSearch: Bool) -> Bool {
		wasForced || usedWebSearch
	}
}

enum ImageResponseRouting {
	static func usesVisionBridge(for model: BeaconModel) -> Bool {
		!model.supportsImages
	}

	static func analysisPrompt(for question: String) -> String {
		let request = question.trimmingCharacters(in: .whitespacesAndNewlines)
		let focus = request.isEmpty ? "The user has not included a specific question." : "The user asks: \(request)"
		return """
			Analyze this image for another on-device language model. Describe the visible subjects, objects, setting, actions, spatial relationships, notable details, and any readable text. Be factual and detailed, and prioritize information needed to answer the user's request. Do not answer the user directly.

			\(focus)
			"""
	}

	static func responsePrompt(question: String, visualAnalysis: String) -> String {
		let request = question.trimmingCharacters(in: .whitespacesAndNewlines)
		let userRequest = request.isEmpty ? "Describe this image." : request
		return """
			Answer the user's request using the private visual analysis below. Treat it as your visual context, do not mention the analysis handoff or claim that you cannot see the image, and do not invent details that are not present.

			User request:
			\(userRequest)

			Visual analysis:
			\(visualAnalysis)
			"""
	}
}

struct ChatView: View {
	@Environment(\.scenePhase) private var scenePhase
	@ObservedObject var runtime: BeaconModelRuntime
	let models: [BeaconModel]
	var onDownloadModel: (BeaconModel) -> Void = { _ in }
	@ObservedObject var notificationRouter = NotificationRouter()
	@StateObject private var historyViewModel = ChatHistoryViewModel()
	@AppStorage("selectedModelID") private var selectedModelID = ""
	@AppStorage("notificationsEnabled") private var notificationsEnabled = false
	#if false // Web search is not currently available.
	// Web search is not part of the current release.
	private let webSearchEnabled = false
	#endif
	@State private var inputText = ""
	@State private var selectedImageItem: [PhotosPickerItem] = []
	@State private var attachedImageData: [Data] = []
	@State private var isShowingPhotoPicker = false
	@State private var isShowingPhotoAccessAlert = false
	#if false // Web search is not currently available.
	@State private var isWebSearchTagged = false
	#endif
	@State private var isShowingHistory = false
	@State private var isShowingSettings = false
	@State private var isShowingModels = false
	@State private var isShowingAppIconPicker = false
	@State private var quickActionPresentationTask: Task<Void, Never>?
	@State private var pendingScrollMessageID: ChatMessage.ID?
	@State private var enteringUserMessageID: ChatMessage.ID?
	@State private var responseTask: Task<Void, Never>?
	@State private var responseAttemptTracker = ResponseAttemptTracker()
	@State private var isPreparingResponse = false
	@State private var isSearchingWeb = false
	@State private var isAnalyzingImage = false
	@State private var failedResponse: FailedResponse?
	@State private var switchedModelName: String?
	@State private var modelSwitchToastTask: Task<Void, Never>?
	@State private var actionToastText: String?
	@State private var actionToastTask: Task<Void, Never>?
	#if false // Web search is not currently available.
	@State private var backendStatus: BackendStatus?
	@State private var searchQuota: SearchQuota?
	@State private var isBackendUnavailable = false
	@State private var isWebSearchDisabledByBackend = false
	@State private var lastWebSearchStatus = ""
	#endif
	@StateObject private var safariViewModel = SafariViewModel()
	#if false // Web search is not currently available.
	private let backendStatusService = BackendStatusService()
	private let webSearchService = WebSearchService()
	#endif
	private let responseHaptics = StreamingResponseHaptics()
	private let webSearchClient = WebSearchMCPClient()

	private let screenSpring = Animation.spring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.12)

	private var selectedModel: BeaconModel {
		ModelCatalog.model(id: selectedModelID, in: models) ?? ModelCatalog.defaultModel(in: models)
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
                        onOpenSettings: {
                            isShowingSettings = true
                        },
                        onOpenModels: {
                            isShowingModels = true
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
		.background(Color(uiColor: .systemGray6).opacity(0.5))
		.overlay(alignment: .bottom) {
			if let switchedModelName {
				ModelSwitchToast(modelName: switchedModelName)
					.padding(.bottom, 104)
					.transition(.opacity.combined(with: .scale(scale: 0.96)))
			}
		}
		.overlay(alignment: .top) {
			if let actionToastText {
				ActionToast(text: actionToastText, onDismiss: dismissActionToast)
					.padding(.top, 12)
					.transition(.scale(scale: 0.9, anchor: .top).combined(with: .move(edge: .top)).combined(with: .opacity))
					.zIndex(10)
			}
		}
		.sheet(isPresented: $isShowingSettings) {
			SettingsView(chatHistoryViewModel: historyViewModel)
		}
		.sheet(isPresented: $isShowingModels) {
			ModelMarketPlaceView(
				models: models,
				onClose: { isShowingModels = false },
				onDownload: { model in
					isShowingModels = false
					onDownloadModel(model)
				},
				onSelect: select
			)
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
		.sheet(item: $safariViewModel.page) { page in
			SafariView(url: page.url)
		}
		.task(id: selectedModelID) {
			await ensureSelectedModelLoaded()
		}
		.onChange(of: scenePhase) { _, phase in
			switch phase {
			case .active:
				Task { await ensureSelectedModelLoaded() }
			case .background:
				stopGenerating()
				_ = runtime.unloadIfIdle()
			default:
				break
			}
		}
		.onDisappear {
			modelSwitchToastTask?.cancel()
			actionToastTask?.cancel()
			quickActionPresentationTask?.cancel()
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
		#if false // Web search is not currently available.
		.task {
			guard webSearchEnabled else { return }
			await refreshBackendStatus()
			await refreshSearchQuota()
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
											messageBubble(for: message)
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
			.background(Color(uiColor: .systemGray6).opacity(0.5))
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
				}

				ToolbarItem(placement: .topBarTrailing) {
					Button {
						playHeaderHaptic()
						historyViewModel.startNewChat()
						dismissKeyboard()
					} label: {
						Image("newchat.icon")
							.renderingMode(.template)
					}
					.accessibilityLabel("New chat")
				}
				#endif
			}
		}
	}

	@ViewBuilder
	private func messageBubble(for message: ChatMessage) -> some View {
		MessageBubble(
			text: message.text,
			imageDatas: message.imageDatas,
			informationCard: message.informationCard,
			sources: message.sources,
			role: message.role,
			animatesEntrance: message.id == enteringUserMessageID,
			isWaitingForResponse: isAssistantBusy && message == historyViewModel.currentMessages.last,
			thinkingText: message.thinkingText,
			onOpenSource: safariViewModel.open,
			showsRetry: failedResponse?.responseID == message.id,
			onRetry: retryResponse,
			onCopy: { showActionToast("Copied message") },
		)
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
			historyViewModel.startNewChat()
			dismissKeyboard()
		} label: {
			Image("newchat.icon")
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
					hasAttachment: !attachedImageData.isEmpty,
				attachmentData: attachedImageData,
				onAttachImage: {
					requestPhotoAccess()
				},
				canAttachImages: false,
				showsConversationStarters: historyViewModel.currentMessages.isEmpty,
				onRemoveAttachment: { index in
					guard attachedImageData.indices.contains(index) else { return }
					attachedImageData.remove(at: index)
					selectedImageItem = []
				},
				onStop: {
					stopGenerating()
				},
				onSend: { text in
					send(text, imageDatas: attachedImageData)
					attachedImageData = []
					selectedImageItem = []
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
			let items = selectedImageItem
			selectedImageItem = []
			for item in items {
				guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
				let normalized = await Task.detached(priority: .userInitiated) {
					Self.normalizedImageData(from: data)
				}.value
				attachedImageData.append(normalized)
			}
		}
		.disabled(runtime.isLoading)
		.opacity(runtime.isLoading ? 0.5 : 1)
		.padding(.horizontal, 14)
		.padding(.vertical, 12)
		.background(alignment: .top) {
			LinearGradient(
				colors: [
					Color(uiColor: .systemGray6).opacity(0),
					Color(uiColor: .systemGray6).opacity(0.5)
				],
				startPoint: .top,
				endPoint: .bottom
			)
			.frame(height: 28)
			.offset(y: -28)
			.allowsHitTesting(false)
		}
		.background(Color(uiColor: .systemGray6).opacity(0.5))
	}

	private func send(_ text: String, imageDatas: [Data] = []) {
		guard !isAssistantBusy else { return }
		failedResponse = nil
		isPreparingResponse = true
		dismissKeyboard()
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		#endif
		let displayText = text
		let responseModel = selectedModel
		let conversationHistory = historyViewModel.currentMessages

		let responseID = historyViewModel.appendUserMessage(displayText, imageDatas: imageDatas, modelName: responseModel.name)
		let userMessageID = historyViewModel.currentMessages.dropLast().last?.id
		pendingScrollMessageID = userMessageID
		enteringUserMessageID = userMessageID
		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(400))
			guard enteringUserMessageID == userMessageID else { return }
			enteringUserMessageID = nil
		}
		scheduleChatReminder(for: displayText)
		startResponse(
			text: displayText,
			imageDatas: imageDatas,
			model: responseModel,
			responseID: responseID,
			conversationHistory: conversationHistory
		)
	}

	private func retryResponse() {
		guard !isAssistantBusy, let failedResponse else { return }
		self.failedResponse = nil
		isPreparingResponse = true
		historyViewModel.replaceMessage(failedResponse.responseID, with: "")
		historyViewModel.replaceAssistantSources([], for: failedResponse.responseID)
		historyViewModel.replaceAssistantInformationCard(nil, for: failedResponse.responseID)
		startResponse(
			text: failedResponse.text,
			imageDatas: failedResponse.imageDatas,
			model: failedResponse.model,
			responseID: failedResponse.responseID,
			conversationHistory: failedResponse.conversationHistory,
			forceWebSearch: failedResponse.forceWebSearch
		)
	}

	private func startResponse(
		text: String,
		imageDatas: [Data] = [],
		model: BeaconModel,
		responseID: ChatMessage.ID,
		conversationHistory: [ChatMessage],
		forceWebSearch: Bool = false
	) {
		responseHaptics.start()
		let attemptID = responseAttemptTracker.begin()

		responseTask = Task {
			do {
				let prompt: String
				let responseImageData: Data?
				if !imageDatas.isEmpty, ImageResponseRouting.usesVisionBridge(for: model) {
					var analyses: [String] = []
					for imageData in imageDatas {
						analyses.append(try await analyzeImage(imageData, question: text))
					}
					let visualAnalysis = analyses.enumerated().map { "Image \($0.offset + 1):\n\($0.element)" }.joined(separator: "\n\n")
					prompt = ImageResponseRouting.responsePrompt(question: text, visualAnalysis: visualAnalysis)
					responseImageData = nil
				} else if let imageData = imageDatas.first {
					let question = text.isEmpty ? "Describe this image." : text
					prompt = "Analyze the attached image and answer the user's question using what you can see. User question: \(question)"
					responseImageData = imageData
				} else {
					prompt = try await promptWithWebResultsIfNeeded(
						for: text,
						responseID: responseID,
						conversationHistory: conversationHistory,
						forceWebSearch: forceWebSearch
					)
					responseImageData = nil
				}
				let hasWebSources = historyViewModel.currentMessages.first(where: { $0.id == responseID })?.sources.isEmpty == false
				let additionalInstructions = responseInstructions(hasWebSources: hasWebSources)

				// Web search can suspend long enough for the app to release an idle model.
				try await ensureModelLoaded(model)
				isPreparingResponse = false
				try await runtime.streamResponse(
					to: prompt,
					imageData: responseImageData,
					conversationHistory: hasWebSources ? [] : conversationHistory,
					additionalInstructions: additionalInstructions,
					// Keep model reasoning private; the UI shows only user-facing status text.
					onThinking: { _ in }
				) { chunk in
					historyViewModel.appendAssistantChunk(chunk, to: responseID)
					responseHaptics.tick(for: chunk)
				}
				#if DEBUG
				if let response = historyViewModel.currentMessages.first(where: { $0.id == responseID }), !response.sources.isEmpty {
					print("WebSearchPipeline final response: \(response.text)")
				}
				#endif

				responseHaptics.finish()
			} catch is CancellationError {
				if responseAttemptTracker.owns(attemptID),
				   historyViewModel.currentMessages.first(where: { $0.id == responseID })?.text.isEmpty == true {
					historyViewModel.replaceMessage(responseID, with: "Stopped.")
				}
			} catch let error as WebSearchMCPClient.ClientError {
				guard responseAttemptTracker.owns(attemptID) else { return }
				isPreparingResponse = false
				failedResponse = FailedResponse(
					responseID: responseID,
					text: text,
					imageDatas: imageDatas,
					model: model,
					conversationHistory: conversationHistory,
					forceWebSearch: true
				)
				historyViewModel.replaceMessage(responseID, with: "There was an error searching the web.")
			} catch {
				guard responseAttemptTracker.owns(attemptID) else { return }
				isPreparingResponse = false
				let usedWebSearch = historyViewModel.currentMessages.first(where: { $0.id == responseID })?.sources.isEmpty == false
				failedResponse = FailedResponse(
					responseID: responseID,
					text: text,
					imageDatas: imageDatas,
					model: model,
					conversationHistory: conversationHistory,
					forceWebSearch: ResponseRetryPolicy.shouldForceWebSearch(
						wasForced: forceWebSearch,
						usedWebSearch: usedWebSearch
					)
				)
				historyViewModel.replaceMessage(responseID, with: error.localizedDescription)
			}

			guard responseAttemptTracker.finish(attemptID) else { return }
			isPreparingResponse = false
			isSearchingWeb = false
			isAnalyzingImage = false
			responseHaptics.stop()
			responseTask = nil
			if scenePhase == .background {
				_ = runtime.unloadIfIdle()
			}
		}
	}

	private func analyzeImage(_ imageData: Data, question: String) async throws -> String {
		guard let visionModel else { throw BeaconModelRuntime.RuntimeError.imageModelRequired }
		isAnalyzingImage = true
		defer { isAnalyzingImage = false }

		try await ensureModelLoaded(visionModel)
		var analysis = ""
		try await runtime.streamResponse(
			to: ImageResponseRouting.analysisPrompt(for: question),
			imageData: imageData,
			conversationHistory: []
		) { chunk in
			analysis += chunk
		}

		let result = analysis.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !result.isEmpty else {
			throw BeaconModelRuntime.RuntimeError.invalidImage
		}
		return result
	}

	private func responseInstructions(hasWebSources: Bool) -> String? {
		var sections: [String] = ["""
			Response length:
			- Reply like a helpful person texting: direct, conversational, and concise.
			- Usually use one or two short paragraphs and stay under 120 words.
			- Do not add a closing question or suggestion unless it is useful.
			Markdown:
			- Use Markdown only when it improves clarity.
			- Use **bold** sparingly for an important term or conclusion.
			- Do not use headings or lists for a simple answer.
			"""]
		if hasWebSources {
			sections.append(WebSearchGrounding.instructions)
		}
		return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
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
	}

	private func showActionToast(_ text: String) {
		actionToastTask?.cancel()
		withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
			actionToastText = text
		}
		actionToastTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(2))
			guard !Task.isCancelled else { return }
			dismissActionToast()
		}
	}

	private func dismissActionToast() {
		actionToastTask?.cancel()
		withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
			actionToastText = nil
		}
	}

	private func promptWithWebResultsIfNeeded(for text: String, responseID: ChatMessage.ID, conversationHistory: [ChatMessage], forceWebSearch: Bool = false) async throws -> String {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		let lowercased = trimmed.lowercased()
		if lowercased == "/noweb" { return "Ask the user what they would like help with." }
		if lowercased.hasPrefix("/noweb ") {
			return String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
		}

		let hasWebCommand = lowercased == "/web" || lowercased.hasPrefix("/web ")
		let isForced = forceWebSearch || hasWebCommand
		let forcedQuery = lowercased.hasPrefix("/web ")
			? String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
			: forceWebSearch ? trimmed : ""
		if isForced && forcedQuery.isEmpty { return "Ask the user what they want to search for." }
		guard webSearchClient.isConfigured else {
			if isForced || BeaconModelRuntime.fallbackWebSearchQuery(for: trimmed) != nil {
				#if DEBUG
				print("WebSearchPipeline search requested but MCP endpoint is not configured in the app bundle")
				#endif
				throw WebSearchMCPClient.ClientError.notConfigured
			}
			return text
		}
		let query: String?
		if isForced {
			query = forcedQuery
			#if DEBUG
			print("WebSearchPipeline original query: \(text)")
			print("WebSearchPipeline router decision: search_web (forced)")
			print("WebSearchPipeline generated search query: \(forcedQuery)")
			#endif
		} else {
			do {
				query = try await runtime.webSearchQuery(for: trimmed, conversationHistory: conversationHistory)
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				query = nil
				#if DEBUG
				print("WebSearchPipeline original query: \(text)")
				print("WebSearchPipeline router decision: unavailable")
				print("WebSearchPipeline generated search query: none")
				#endif
			}
		}
		guard let query, !query.isEmpty else { return text }
		let searchQuery = query

		isSearchingWeb = true
		historyViewModel.appendAssistantThinking("Searching web: \(searchQuery)\n", to: responseID)
		defer { isSearchingWeb = false }
		do {
			let response = try await webSearchClient.search(searchQuery)
			let results = Array(response.results.filter { $0.url.scheme == "https" }.prefix(5))
			guard !results.isEmpty else { throw WebSearchMCPClient.ClientError.invalidResponse }

			let sources = results.map { Source(title: $0.title, url: $0.url, description: $0.snippet) }
			historyViewModel.replaceAssistantSources(sources, for: responseID)
			historyViewModel.replaceAssistantInformationCard(
				InformationCardContent(
					title: informationCardTitle(for: isForced ? forcedQuery : text),
					imageURL: results.first?.imageURL
				),
				for: responseID
			)
			let groundedPrompt = WebSearchGrounding.prompt(
				question: isForced ? forcedQuery : text,
				query: query,
				results: results
			)
			#if DEBUG
			let rankedResults = results.enumerated().map { "[\($0.offset + 1)] \($0.element.source) | \($0.element.title) | \($0.element.snippet)" }.joined(separator: "\n")
			print("WebSearchPipeline ranked normalized results:\n\(rankedResults)")
			print("WebSearchPipeline final model context:\nSYSTEM:\n\(WebSearchGrounding.instructions)\n\nPROMPT:\n\(groundedPrompt)")
			#endif
			return groundedPrompt
		} catch is CancellationError {
			throw CancellationError()
		} catch let error as WebSearchMCPClient.ClientError {
			throw error
		} catch {
			try Task.checkCancellation()
			throw WebSearchMCPClient.ClientError.requestFailed(error.localizedDescription)
		}
	}

	private func informationCardTitle(for query: String) -> String {
		var topic = query
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.trimmingCharacters(in: CharacterSet(charactersIn: "?.!"))
		for prefix in ["why is ", "why are ", "what is ", "what are ", "who is ", "who was ", "how does ", "how did "] {
			if topic.lowercased().hasPrefix(prefix) {
				topic = String(topic.dropFirst(prefix.count))
				break
			}
		}
		topic = topic
			.replacingOccurrences(of: #"\s+so\s+important$"#, with: "", options: .regularExpression)
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let truncatedTopic = topic.isEmpty ? "this topic" : topic.prefix(80)
		return "A closer look at \(truncatedTopic)"
	}
	private var visionModel: BeaconModel? {
		models.first(where: \.supportsImages)
	}

	private func ensureSelectedModelLoaded() async {
		do {
			try await ensureModelLoaded(selectedModel)
		} catch {
			// The runtime publishes loading errors for the model UI.
		}
	}

	private func ensureModelLoaded(_ model: BeaconModel) async throws {
		guard !runtime.isReady(for: model) else { return }

		await runtime.load(model)
		try Task.checkCancellation()
		guard runtime.isReady(for: model) else {
			throw BeaconModelRuntime.RuntimeError.modelLoadFailed(
				runtime.errorMessage ?? "Beacon could not load \(model.name)."
			)
		}
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
		pendingScrollMessageID = historyViewModel.lastUserMessageID(in: chat) ?? historyViewModel.firstMessageID(in: chat)
		UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [chatReminderNotificationID(for: chatID)])
		notificationRouter.consumeChatOpenRequest()
	}

	private func handleQuickAction(_ action: HomeScreenQuickAction) {
		dismissKeyboard()
		quickActionPresentationTask?.cancel()
		isShowingHistory = false
		isShowingSettings = false
		isShowingAppIconPicker = false
		isShowingPhotoPicker = false
		safariViewModel.close()

		switch action {
		case .newChat:
			stopGenerating()
			historyViewModel.startNewChat()
		case .changeAppIcon:
			presentQuickActionDestination { isShowingAppIconPicker = true }
		}

		notificationRouter.consumeQuickActionRequest()
	}

	private func presentQuickActionDestination(_ present: @escaping @MainActor () -> Void) {
		quickActionPresentationTask = Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(200))
			guard !Task.isCancelled else { return }
			present()
		}
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
