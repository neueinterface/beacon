import Foundation

enum MockStartedChats {
    static let items: [StartedChat] = [
        StartedChat(
            id: UUID(),
            firstMessage: "Can you help me brainstorm the first onboarding flow?",
            modelName: "Llama 3.2 3B",
            updatedAt: .now.addingTimeInterval(-900),
            unreadCount: 0
        ),
        StartedChat(
            id: UUID(),
            firstMessage: "Give me 10 concise app naming ideas.",
            modelName: "DeepSeek Distill",
            updatedAt: .now.addingTimeInterval(-3600),
            unreadCount: 2
        ),
        StartedChat(
            id: UUID(),
            firstMessage: "Compare speed and quality between these models.",
            modelName: "Code Assistant",
            updatedAt: .now.addingTimeInterval(-8900),
            unreadCount: 0
        ),
        StartedChat(
            id: UUID(),
            firstMessage: "Help me map out Phase 1 UI milestones.",
            modelName: "Llama 3.2 3B",
            updatedAt: .now.addingTimeInterval(-17200),
            unreadCount: 1
        )
    ]
}
