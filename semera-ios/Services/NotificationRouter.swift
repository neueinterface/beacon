import Combine
import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class NotificationRouter: ObservableObject {
	@Published var chatIDToOpen: ChatConversation.ID?
	@Published var quickActionToOpen: HomeScreenQuickAction?

	func openChat(id: ChatConversation.ID) {
		chatIDToOpen = id
	}

	func consumeChatOpenRequest() {
		chatIDToOpen = nil
	}

	func openQuickAction(_ action: HomeScreenQuickAction) {
		quickActionToOpen = action
	}

	func consumeQuickActionRequest() {
		quickActionToOpen = nil
	}
}

enum HomeScreenQuickAction: String {
	case newChat = "com.semera.new-chat"
	case changeAppIcon = "com.semera.change-app-icon"
	case seeModels = "com.semera.see-models"
}

#if canImport(UIKit)
final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
	weak var notificationRouter: NotificationRouter? {
		didSet {
			deliverPendingChatIDIfNeeded()
			deliverPendingQuickActionIfNeeded()
		}
	}
	private var pendingChatID: ChatConversation.ID?
	private var pendingQuickAction: HomeScreenQuickAction?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		UNUserNotificationCenter.current().delegate = self
		application.shortcutItems = Self.shortcutItems

		if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
			let action = HomeScreenQuickAction(rawValue: shortcutItem.type) {
			pendingQuickAction = action
			return false
		}

		return true
	}

	func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
		guard let action = HomeScreenQuickAction(rawValue: shortcutItem.type) else {
			completionHandler(false)
			return
		}

		if let notificationRouter {
			notificationRouter.openQuickAction(action)
		} else {
			pendingQuickAction = action
		}

		completionHandler(true)
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

	private func deliverPendingQuickActionIfNeeded() {
		guard let pendingQuickAction, let notificationRouter else { return }
		notificationRouter.openQuickAction(pendingQuickAction)
		self.pendingQuickAction = nil
	}

	private static var shortcutItems: [UIApplicationShortcutItem] {
		[
			UIApplicationShortcutItem(
				type: HomeScreenQuickAction.newChat.rawValue,
				localizedTitle: "New Chat",
				localizedSubtitle: nil,
				icon: UIApplicationShortcutIcon(systemImageName: "plus.message"),
				userInfo: nil
			),
			UIApplicationShortcutItem(
				type: HomeScreenQuickAction.changeAppIcon.rawValue,
				localizedTitle: "Change App Icon",
				localizedSubtitle: nil,
				icon: UIApplicationShortcutIcon(systemImageName: "app.badge"),
				userInfo: nil
			),
			UIApplicationShortcutItem(
				type: HomeScreenQuickAction.seeModels.rawValue,
				localizedTitle: "See Models",
				localizedSubtitle: nil,
				icon: UIApplicationShortcutIcon(systemImageName: "square.stack.3d.up"),
				userInfo: nil
			)
		]
	}

	private static func chatID(from userInfo: [AnyHashable: Any]) -> ChatConversation.ID? {
		guard userInfo["type"] as? String == "chatReminder",
			let idString = userInfo["chatId"] as? String else { return nil }

		return UUID(uuidString: idString)
	}
}
#endif
