import Combine
import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class NotificationRouter: ObservableObject {
	@Published var chatIDToOpen: ChatConversation.ID?

	func openChat(id: ChatConversation.ID) {
		chatIDToOpen = id
	}

	func consumeChatOpenRequest() {
		chatIDToOpen = nil
	}
}

#if canImport(UIKit)
final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
	weak var notificationRouter: NotificationRouter? {
		didSet { deliverPendingChatIDIfNeeded() }
	}
	private var pendingChatID: ChatConversation.ID?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		UNUserNotificationCenter.current().delegate = self
		return true
	}

	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
		guard let chatID = Self.chatID(from: response.notification.request.content.userInfo) else { return }

		await MainActor.run {
			if let notificationRouter {
				notificationRouter.openChat(id: chatID)
			} else {
				pendingChatID = chatID
			}
		}
	}

	private func deliverPendingChatIDIfNeeded() {
		guard let pendingChatID, let notificationRouter else { return }
		notificationRouter.openChat(id: pendingChatID)
		self.pendingChatID = nil
	}

	private static func chatID(from userInfo: [AnyHashable: Any]) -> ChatConversation.ID? {
		guard userInfo["type"] as? String == "chatReminder",
			let idString = userInfo["chatId"] as? String else { return nil }

		return UUID(uuidString: idString)
	}
}
#endif
