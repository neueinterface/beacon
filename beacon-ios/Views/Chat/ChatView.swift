import SwiftUI

struct ChatView: View {
	@State private var draft = ""
	@State private var isHistoryPresented = false
	@State private var messages: [ChatMessage] = [
		ChatMessage(role: .assistant, text: "Hello! This is a placeholder response from the model.")
	]
	private let previousChats = MockStartedChats.items

	var body: some View {
		VStack(spacing: 0) {
			HeaderView(title: "Local Chat") {
				isHistoryPresented = true
			}

			messagesList

			Input(text: $draft) { text in
				sendMessage(text)
			}
			.padding(.horizontal, 12)
			.padding(.top, 8)
			.padding(.bottom, 10)
			.background(.white)
		}
		.background(Color(UIColor.white))
		.sheet(isPresented: $isHistoryPresented) {
			ChatHistoryView(chats: previousChats)
		}
	}

	private var messagesList: some View {
		ScrollViewReader { proxy in
			ScrollView {
				LazyVStack(spacing: 10) {
					ForEach(messages) { message in
						MessageBubble(text: message.text, role: message.role)
							.id(message.id)
							.transition(
								.asymmetric(
									insertion: .move(edge: .bottom)
										.combined(with: .opacity)
										.combined(with: .scale(scale: 0.98, anchor: .bottom)),
									removal: .opacity
								)
							)
					}
				}
				.padding(.horizontal, 12)
				.padding(.top, 14)
				.padding(.bottom, 8)
			}
			.onChange(of: messages.count) {
				guard let lastID = messages.last?.id else { return }
				withAnimation(.easeOut(duration: 0.25)) {
					proxy.scrollTo(lastID, anchor: .bottom)
				}
			}
		}
	}

	private func sendMessage(_ text: String) {
		withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
			messages.append(ChatMessage(role: .user, text: text))
		}

		Task {
			try? await Task.sleep(for: .milliseconds(450))
			await MainActor.run {
				withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
					messages.append(
						ChatMessage(
							role: .assistant,
							text: "Hello! This is a placeholder response from the model."
						)
					)
				}
			}
		}
	}
}

private struct ChatMessage: Identifiable {
	let id = UUID()
	let role: MessageBubble.Role
	let text: String
}

#Preview {
	ChatView()
}

