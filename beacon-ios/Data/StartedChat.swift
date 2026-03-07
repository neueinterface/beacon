import Foundation

struct StartedChat: Identifiable, Hashable {
    let id: UUID
    let firstMessage: String
    let modelName: String
    let updatedAt: Date
    let unreadCount: Int
}
